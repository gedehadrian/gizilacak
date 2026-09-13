-- RPC transaksi + RLS. Tabel legacy tetap tanpa policy anon.

create or replace function public.finalize_batch(_batch_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  b public.batches%rowtype;
  missing int;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into b from public.batches where id = _batch_id for update;
  if not found then raise exception 'batch_not_found'; end if;
  if not public.is_tenant_member(b.tenant_id, array['owner','manager','operator']) then
    raise exception 'forbidden';
  end if;
  if b.status <> 'draft' then raise exception 'batch_not_draft'; end if;

  select count(*) into missing from public.batch_components
  where batch_id = b.id and (cooked_at is null or consume_by is null);
  if missing > 0 then raise exception 'components_incomplete'; end if;

  update public.batch_components
  set consume_by = cooked_at + make_interval(mins => duration_minutes_snapshot)
  where batch_id = b.id and consume_by is null and cooked_at is not null;

  update public.batches
  set status = 'ready', finalized_by = auth.uid(), finalized_at = now()
  where id = b.id;

  insert into public.audit_logs(tenant_id, actor_id, action, entity_type, entity_id, occurred_at)
  values (b.tenant_id, auth.uid(), 'batch.finalize', 'batches', b.id, now());
end;
$$;

create or replace function public.dispatch_delivery(_delivery_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  d public.deliveries%rowtype;
  sub public.subscriptions%rowtype;
  token text;
  over_alloc int;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into d from public.deliveries where id = _delivery_id for update;
  if not found then raise exception 'delivery_not_found'; end if;
  if not public.is_tenant_member(d.tenant_id, array['owner','manager','operator']) then
    raise exception 'forbidden';
  end if;
  if d.status = 'dispatched' then
    select qr.token into token from public.qr_labels qr
    where qr.delivery_id = d.id and qr.revoked_at is null;
    return token;
  end if;
  if d.status <> 'draft' then raise exception 'delivery_not_draft'; end if;

  if not exists (
    select 1 from public.tenant_schools ts
    where ts.tenant_id = d.tenant_id and ts.school_id = d.school_id and ts.status = 'active'
  ) then
    raise exception 'school_not_linked';
  end if;

  select * into sub from public.subscriptions
  where tenant_id = d.tenant_id and status = 'active'
    and period_start <= now() and period_end > now()
  order by period_end desc
  limit 1
  for update;
  if not found then raise exception 'no_entitlement'; end if;

  perform 1 from public.usage_counters
  where tenant_id = d.tenant_id and metric = 'deliveries'
    and period_start = sub.period_start
  for update;
  update public.usage_counters
  set used = used + 1
  where tenant_id = d.tenant_id and metric = 'deliveries' and period_start = sub.period_start
    and used < limit_snapshot;
  if not found then raise exception 'quota_exceeded'; end if;

  select count(*) into over_alloc
  from public.delivery_items di
  join public.batch_components bc on bc.id = di.batch_component_id
  where di.delivery_id = d.id
    and (
      select coalesce(sum(di2.portions),0)
      from public.delivery_items di2
      join public.deliveries d2 on d2.id = di2.delivery_id
      where di2.batch_component_id = bc.id
        and d2.status in ('draft','dispatched','completed')
    ) > bc.portions_produced;
  if over_alloc > 0 then raise exception 'over_allocated'; end if;

  if exists (
    select 1 from public.delivery_items di
    join public.batch_components bc on bc.id = di.batch_component_id
    join public.batches b on b.id = bc.batch_id
    where di.delivery_id = d.id and b.status <> 'ready'
  ) then
    raise exception 'batch_not_ready';
  end if;

  token := encode(gen_random_bytes(16), 'hex');
  insert into public.qr_labels (tenant_id, delivery_id, token)
  values (d.tenant_id, d.id, token);

  update public.deliveries
  set status = 'dispatched', dispatched_at = now(), dispatched_by = auth.uid()
  where id = d.id;

  insert into public.audit_logs(tenant_id, actor_id, action, entity_type, entity_id, occurred_at)
  values (d.tenant_id, auth.uid(), 'delivery.dispatch', 'deliveries', d.id, now());

  return token;
end;
$$;

create or replace function public.submit_receipt(
  _delivery_item_id uuid,
  _accepted int,
  _rejected int,
  _reason text,
  _note text,
  _idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  di public.delivery_items%rowtype;
  d public.deliveries%rowtype;
  rid uuid;
  remaining int;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into di from public.delivery_items where id = _delivery_item_id for update;
  if not found then raise exception 'item_not_found'; end if;
  select * into d from public.deliveries where id = di.delivery_id for update;
  if d.status <> 'dispatched' then raise exception 'delivery_not_dispatched'; end if;
  if not public.is_school_member(d.school_id, null) then raise exception 'forbidden'; end if;
  if _accepted < 0 or _rejected < 0 or (_accepted + _rejected) <> di.portions then
    raise exception 'portions_mismatch';
  end if;
  if _rejected > 0 and coalesce(trim(_reason),'') = '' then raise exception 'reason_required'; end if;

  insert into public.receipts (
    tenant_id, delivery_id, delivery_item_id, school_id, received_by,
    accepted_portions, rejected_portions, reason, condition_note, idempotency_key
  ) values (
    d.tenant_id, d.id, di.id, d.school_id, auth.uid(),
    _accepted, _rejected, _reason, _note, _idempotency_key
  )
  on conflict (delivery_item_id) do update set delivery_item_id = excluded.delivery_item_id
  returning id into rid;

  select count(*) into remaining
  from public.delivery_items i
  left join public.receipts r on r.delivery_item_id = i.id
  where i.delivery_id = d.id and r.id is null;
  if remaining = 0 then
    update public.deliveries set status = 'completed', completed_at = now() where id = d.id;
  end if;

  insert into public.audit_logs(tenant_id, actor_id, action, entity_type, entity_id, occurred_at)
  values (d.tenant_id, auth.uid(), 'receipt.submit', 'receipts', rid, now());
  return rid;
end;
$$;

create or replace function public.increment_rate_limit(_key_hash text, _window_seconds int, _max int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  rec public.rate_limit_buckets%rowtype;
begin
  insert into public.rate_limit_buckets(key_hash, window_start, count, expires_at)
  values (_key_hash, now(), 1, now() + make_interval(secs => _window_seconds))
  on conflict (key_hash) do update
    set count = case
      when public.rate_limit_buckets.expires_at < now() then 1
      else public.rate_limit_buckets.count + 1
    end,
    window_start = case
      when public.rate_limit_buckets.expires_at < now() then now()
      else public.rate_limit_buckets.window_start
    end,
    expires_at = case
      when public.rate_limit_buckets.expires_at < now() then now() + make_interval(secs => _window_seconds)
      else public.rate_limit_buckets.expires_at
    end
  returning * into rec;
  return rec.count <= _max;
end;
$$;

revoke all on function public.finalize_batch(uuid) from public;
revoke all on function public.dispatch_delivery(uuid) from public;
revoke all on function public.submit_receipt(uuid,int,int,text,text,text) from public;
revoke all on function public.increment_rate_limit(text,int,int) from public;
grant execute on function public.finalize_batch(uuid) to authenticated;
grant execute on function public.dispatch_delivery(uuid) to authenticated;
grant execute on function public.submit_receipt(uuid,int,int,text,text,text) to authenticated;
grant execute on function public.increment_rate_limit(text,int,int) to authenticated, service_role;

-- ========== RLS ==========
alter table public.profiles enable row level security;
alter table public.tenants enable row level security;
alter table public.tenant_memberships enable row level security;
alter table public.schools enable row level security;
alter table public.school_memberships enable row level security;
alter table public.tenant_schools enable row level security;
alter table public.invitations enable row level security;
alter table public.platform_users enable row level security;
alter table public.plans enable row level security;
alter table public.plan_versions enable row level security;
alter table public.subscriptions enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_lines enable row level security;
alter table public.payments enable row level security;
alter table public.payment_events enable row level security;
alter table public.usage_counters enable row level security;
alter table public.platform_expenses enable row level security;
alter table public.consumption_policies enable row level security;
alter table public.recipes enable row level security;
alter table public.recipe_components enable row level security;
alter table public.batches enable row level security;
alter table public.batch_components enable row level security;
alter table public.deliveries enable row level security;
alter table public.delivery_items enable row level security;
alter table public.qr_labels enable row level security;
alter table public.receipts enable row level security;
alter table public.scan_logs enable row level security;
alter table public.incidents enable row level security;
alter table public.incident_updates enable row level security;
alter table public.tenant_expenses enable row level security;
alter table public.attachments enable row level security;
alter table public.notifications enable row level security;
alter table public.exports enable row level security;
alter table public.audit_logs enable row level security;

-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_platform_admin());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- tenants
drop policy if exists tenants_select on public.tenants;
create policy tenants_select on public.tenants for select to authenticated
  using (public.is_tenant_member(id, null) or public.is_platform_admin());
drop policy if exists tenants_update on public.tenants;
create policy tenants_update on public.tenants for update to authenticated
  using (public.is_tenant_member(id, array['owner']))
  with check (public.is_tenant_member(id, array['owner']));

-- memberships
drop policy if exists tm_select on public.tenant_memberships;
create policy tm_select on public.tenant_memberships for select to authenticated
  using (public.is_tenant_member(tenant_id, null) or user_id = auth.uid() or public.is_platform_admin());
drop policy if exists tm_insert on public.tenant_memberships;
create policy tm_insert on public.tenant_memberships for insert to authenticated
  with check (public.is_tenant_member(tenant_id, array['owner']));
drop policy if exists tm_update on public.tenant_memberships;
create policy tm_update on public.tenant_memberships for update to authenticated
  using (public.is_tenant_member(tenant_id, array['owner']))
  with check (public.is_tenant_member(tenant_id, array['owner']) and tenant_id = tenant_id);

-- schools / memberships / links
drop policy if exists schools_select on public.schools;
create policy schools_select on public.schools for select to authenticated
  using (
    public.is_school_member(id, null)
    or public.is_platform_admin()
    or exists (select 1 from public.tenant_schools ts where ts.school_id = schools.id and public.is_tenant_member(ts.tenant_id, null))
  );
drop policy if exists sm_select on public.school_memberships;
create policy sm_select on public.school_memberships for select to authenticated
  using (public.is_school_member(school_id, null) or user_id = auth.uid());
drop policy if exists sm_write on public.school_memberships;
create policy sm_write on public.school_memberships for all to authenticated
  using (public.is_school_member(school_id, array['admin']))
  with check (public.is_school_member(school_id, array['admin']));
drop policy if exists ts_select on public.tenant_schools;
create policy ts_select on public.tenant_schools for select to authenticated
  using (public.is_tenant_member(tenant_id, null) or public.is_school_member(school_id, null) or public.is_platform_admin());
drop policy if exists ts_insert on public.tenant_schools;
create policy ts_insert on public.tenant_schools for insert to authenticated
  with check (public.is_tenant_member(tenant_id, array['owner','manager']));
drop policy if exists ts_update on public.tenant_schools;
create policy ts_update on public.tenant_schools for update to authenticated
  using (public.is_tenant_member(tenant_id, array['owner','manager']) or public.is_school_member(school_id, array['admin']))
  with check (public.is_tenant_member(tenant_id, array['owner','manager']) or public.is_school_member(school_id, array['admin']));

-- invitations
drop policy if exists inv_select on public.invitations;
create policy inv_select on public.invitations for select to authenticated
  using (
    (tenant_id is not null and public.is_tenant_member(tenant_id, array['owner','manager']))
    or (school_id is not null and public.is_school_member(school_id, array['admin']))
    or lower(email) = lower(coalesce((select email from auth.users where id = auth.uid()), ''))
  );

-- platform users: only self-read if admin
drop policy if exists pu_select on public.platform_users;
create policy pu_select on public.platform_users for select to authenticated
  using (user_id = auth.uid() and active);

-- plans: published readable
drop policy if exists plans_select on public.plans;
create policy plans_select on public.plans for select to authenticated using (active or public.is_platform_admin());
drop policy if exists pv_select on public.plan_versions;
create policy pv_select on public.plan_versions for select to authenticated
  using (published_at is not null or public.is_platform_admin());
drop policy if exists plans_admin on public.plans;
create policy plans_admin on public.plans for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());
drop policy if exists pv_admin on public.plan_versions;
create policy pv_admin on public.plan_versions for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

-- billing tenant scoped
drop policy if exists sub_select on public.subscriptions;
create policy sub_select on public.subscriptions for select to authenticated
  using (public.is_tenant_member(tenant_id, array['owner','finance','manager']) or public.is_platform_admin());
drop policy if exists inv_sel on public.invoices;
create policy inv_sel on public.invoices for select to authenticated
  using (public.is_tenant_member(tenant_id, array['owner','finance']) or public.is_platform_admin());
drop policy if exists invl_sel on public.invoice_lines;
create policy invl_sel on public.invoice_lines for select to authenticated
  using (public.is_tenant_member(tenant_id, array['owner','finance']) or public.is_platform_admin());
drop policy if exists pay_sel on public.payments;
create policy pay_sel on public.payments for select to authenticated
  using (public.is_tenant_member(tenant_id, array['owner','finance']) or public.is_platform_admin());
drop policy if exists usage_sel on public.usage_counters;
create policy usage_sel on public.usage_counters for select to authenticated
  using (public.is_tenant_member(tenant_id, null) or public.is_platform_admin());
drop policy if exists pexp_admin on public.platform_expenses;
create policy pexp_admin on public.platform_expenses for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());
-- payment_events: no authenticated policy (service role only)

-- tenant operational tables
drop policy if exists pol_all on public.consumption_policies;
create policy pol_all on public.consumption_policies for all to authenticated
  using (public.is_tenant_member(tenant_id, null))
  with check (public.is_tenant_member(tenant_id, array['owner','manager']));
drop policy if exists rec_all on public.recipes;
create policy rec_all on public.recipes for all to authenticated
  using (public.is_tenant_member(tenant_id, null))
  with check (public.is_tenant_member(tenant_id, array['owner','manager','operator']));
drop policy if exists recc_all on public.recipe_components;
create policy recc_all on public.recipe_components for all to authenticated
  using (public.is_tenant_member(tenant_id, null))
  with check (public.is_tenant_member(tenant_id, array['owner','manager','operator']));
drop policy if exists bat_all on public.batches;
create policy bat_all on public.batches for all to authenticated
  using (public.is_tenant_member(tenant_id, null))
  with check (public.is_tenant_member(tenant_id, array['owner','manager','operator']));
drop policy if exists batc_all on public.batch_components;
create policy batc_all on public.batch_components for all to authenticated
  using (public.is_tenant_member(tenant_id, null))
  with check (public.is_tenant_member(tenant_id, array['owner','manager','operator']));
drop policy if exists del_sel on public.deliveries;
create policy del_sel on public.deliveries for select to authenticated
  using (public.is_tenant_member(tenant_id, null) or public.is_school_member(school_id, null));
drop policy if exists del_write on public.deliveries;
create policy del_write on public.deliveries for insert to authenticated
  with check (public.is_tenant_member(tenant_id, array['owner','manager','operator']));
drop policy if exists del_upd on public.deliveries;
create policy del_upd on public.deliveries for update to authenticated
  using (public.is_tenant_member(tenant_id, array['owner','manager','operator']))
  with check (public.is_tenant_member(tenant_id, array['owner','manager','operator']));
drop policy if exists di_sel on public.delivery_items;
create policy di_sel on public.delivery_items for select to authenticated
  using (
    public.is_tenant_member(tenant_id, null)
    or exists (select 1 from public.deliveries d where d.id = delivery_id and public.is_school_member(d.school_id, null))
  );
drop policy if exists di_write on public.delivery_items;
create policy di_write on public.delivery_items for all to authenticated
  using (public.is_tenant_member(tenant_id, array['owner','manager','operator']))
  with check (public.is_tenant_member(tenant_id, array['owner','manager','operator']));
drop policy if exists qr_sel on public.qr_labels;
create policy qr_sel on public.qr_labels for select to authenticated
  using (
    public.is_tenant_member(tenant_id, null)
    or exists (select 1 from public.deliveries d where d.id = delivery_id and public.is_school_member(d.school_id, null))
  );
drop policy if exists recpt_sel on public.receipts;
create policy recpt_sel on public.receipts for select to authenticated
  using (public.is_tenant_member(tenant_id, null) or public.is_school_member(school_id, null));
drop policy if exists inc_sel on public.incidents;
create policy inc_sel on public.incidents for select to authenticated
  using (public.is_tenant_member(tenant_id, null) or public.is_school_member(school_id, null));
drop policy if exists inc_ins on public.incidents;
create policy inc_ins on public.incidents for insert to authenticated
  with check (public.is_school_member(school_id, null) or public.is_tenant_member(tenant_id, array['owner','manager','operator']));
drop policy if exists inc_upd on public.incidents;
create policy inc_upd on public.incidents for update to authenticated
  using (public.is_tenant_member(tenant_id, array['owner','manager']))
  with check (public.is_tenant_member(tenant_id, array['owner','manager']));
drop policy if exists incu_sel on public.incident_updates;
create policy incu_sel on public.incident_updates for select to authenticated
  using (
    public.is_tenant_member(tenant_id, null)
    or (visibility = 'shared' and exists (
      select 1 from public.incidents i where i.id = incident_id and public.is_school_member(i.school_id, null)
    ))
  );
drop policy if exists incu_ins on public.incident_updates;
create policy incu_ins on public.incident_updates for insert to authenticated
  with check (public.is_tenant_member(tenant_id, array['owner','manager','operator']) or public.is_school_member(
    (select school_id from public.incidents i where i.id = incident_id), null
  ));
drop policy if exists exp_all on public.tenant_expenses;
create policy exp_all on public.tenant_expenses for all to authenticated
  using (public.is_tenant_member(tenant_id, array['owner','finance','manager']))
  with check (public.is_tenant_member(tenant_id, array['owner','finance']));
drop policy if exists att_sel on public.attachments;
create policy att_sel on public.attachments for select to authenticated
  using (public.is_tenant_member(tenant_id, null) or public.is_platform_admin());
drop policy if exists att_ins on public.attachments;
create policy att_ins on public.attachments for insert to authenticated
  with check (public.is_tenant_member(tenant_id, null) or public.is_school_member(
    coalesce((select school_id from public.incidents i where i.id = incident_id), '00000000-0000-0000-0000-000000000000'::uuid),
    null
  ));
drop policy if exists notif_sel on public.notifications;
create policy notif_sel on public.notifications for select to authenticated using (recipient_id = auth.uid());
drop policy if exists notif_upd on public.notifications;
create policy notif_upd on public.notifications for update to authenticated
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());
drop policy if exists expx_sel on public.exports;
create policy expx_sel on public.exports for select to authenticated
  using (requested_by = auth.uid() or (tenant_id is not null and public.is_tenant_member(tenant_id, array['owner','manager','finance'])));
drop policy if exists aud_sel on public.audit_logs;
create policy aud_sel on public.audit_logs for select to authenticated
  using (
    public.is_platform_admin()
    or (tenant_id is not null and public.is_tenant_member(tenant_id, array['owner','manager']))
  );
drop policy if exists scan_sel on public.scan_logs;
create policy scan_sel on public.scan_logs for select to authenticated
  using (public.is_tenant_member(tenant_id, null));

grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
revoke all on public.payment_events from authenticated;
revoke all on public.rate_limit_buckets from authenticated;
revoke all on public.legacy_id_map from authenticated;
grant select, insert, update on public.payment_events to service_role;
grant all on public.rate_limit_buckets to service_role, authenticated;

-- Storage bucket private
insert into storage.buckets (id, name, public)
values ('gizilacak-private', 'gizilacak-private', false)
on conflict (id) do nothing;
