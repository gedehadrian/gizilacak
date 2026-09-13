-- Onboarding sekolah, invoice atomik, draft kiriman, undangan, katalog anon.

create or replace function public.onboard_tenant(
  _name text,
  _sppg_code text,
  _address text,
  _billing_email text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  tid uuid;
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  insert into public.profiles (id, full_name)
  values (uid, coalesce((select full_name from public.profiles where id = uid), ''))
  on conflict (id) do nothing;

  insert into public.tenants (name, sppg_code, address, billing_email)
  values (_name, upper(trim(_sppg_code)), coalesce(_address,''), _billing_email)
  returning id into tid;

  insert into public.tenant_memberships (tenant_id, user_id, role, status)
  values (tid, uid, 'owner', 'active');

  insert into public.consumption_policies (
    tenant_id, version, name, duration_minutes, warning_minutes, source_note, approved_by
  ) values (
    tid, 1, 'Kebijakan awal pemilik', 240, 60,
    'Nilai awal wajib ditinjau penanggung jawab SPPG. Bukan standar nasional.',
    uid
  );

  insert into public.audit_logs (tenant_id, actor_id, action, entity_type, entity_id, occurred_at)
  values (tid, uid, 'tenant.onboard', 'tenants', tid, now());

  return tid;
end;
$$;

create or replace function public.onboard_school(
  _name text,
  _school_code text,
  _address text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  sid uuid;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  insert into public.profiles (id, full_name)
  values (uid, coalesce((select full_name from public.profiles where id = uid), ''))
  on conflict (id) do nothing;

  insert into public.schools (name, school_code, address)
  values (_name, upper(trim(_school_code)), coalesce(_address,''))
  returning id into sid;

  insert into public.school_memberships (school_id, user_id, role, status)
  values (sid, uid, 'admin', 'active');

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, occurred_at, after_redacted)
  values (uid, 'school.onboard', 'schools', sid, now(), jsonb_build_object('school_id', sid));
  return sid;
end;
$$;

create or replace function public.create_invoice_from_plan(
  _tenant_id uuid,
  _plan_version_id uuid,
  _purpose text,
  _idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  pv public.plan_versions%rowtype;
  pl public.plans%rowtype;
  existing uuid;
  iid uuid;
  inum text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not public.is_tenant_member(_tenant_id, array['owner','finance']) then
    raise exception 'forbidden';
  end if;
  if _purpose not in ('initial','renewal') then raise exception 'invalid_purpose'; end if;

  select id into existing from public.invoices
  where tenant_id = _tenant_id and idempotency_key = _idempotency_key;
  if existing is not null then return existing; end if;

  select * into pv from public.plan_versions where id = _plan_version_id;
  if not found or pv.published_at is null then raise exception 'plan_unpublished'; end if;
  select * into pl from public.plans where id = pv.plan_id;
  if not pl.active then raise exception 'plan_inactive'; end if;

  inum := 'GL-' || to_char(now() at time zone 'utc', 'YYYYMMDD') || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);

  insert into public.invoices (
    tenant_id, number, plan_version_id, status, purpose, subtotal_rp, discount_rp, tax_rp, total_rp,
    issued_at, due_at, billing_snapshot, idempotency_key
  ) values (
    _tenant_id, inum, pv.id, 'open', _purpose, pv.price_rp, 0, 0, pv.price_rp,
    now(), now() + interval '7 days',
    jsonb_build_object(
      'plan_code', pl.code, 'plan_name', pl.name, 'version', pv.version,
      'staff_limit', pv.staff_limit, 'school_limit', pv.school_limit, 'delivery_limit', pv.delivery_limit,
      'label', 'Harga dari katalog terbit. Bukan tarif yang diketik klien.'
    ),
    _idempotency_key
  ) returning id into iid;

  insert into public.invoice_lines (
    tenant_id, invoice_id, description, quantity, unit_price_rp, line_total_rp
  ) values (
    _tenant_id, iid, pl.name || ' v' || pv.version::text, 1, pv.price_rp, pv.price_rp
  );

  insert into public.audit_logs(tenant_id, actor_id, action, entity_type, entity_id, occurred_at)
  values (_tenant_id, uid, 'billing.invoice_created', 'invoices', iid, now());
  return iid;
end;
$$;

create or replace function public.create_delivery_draft(
  _tenant_id uuid,
  _school_id uuid,
  _items jsonb,
  _idempotency_key text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  existing uuid;
  did uuid;
  item jsonb;
  bc public.batch_components%rowtype;
  allocated int;
  portions int;
  dcode text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if not public.is_tenant_member(_tenant_id, array['owner','manager','operator']) then
    raise exception 'forbidden';
  end if;

  select id into existing from public.deliveries
  where tenant_id = _tenant_id and idempotency_key = _idempotency_key;
  if existing is not null then return existing; end if;

  if not exists (
    select 1 from public.tenant_schools
    where tenant_id = _tenant_id and school_id = _school_id and status = 'active'
  ) then
    raise exception 'school_not_linked';
  end if;

  dcode := 'KRM-' || to_char(now() at time zone 'utc', 'YYYYMMDD') || '-' || substr(replace(gen_random_uuid()::text,'-',''),1,6);

  insert into public.deliveries (tenant_id, school_id, code, status, created_by, idempotency_key)
  values (_tenant_id, _school_id, dcode, 'draft', uid, _idempotency_key)
  returning id into did;

  for item in select * from jsonb_array_elements(_items)
  loop
    portions := (item->>'portions')::int;
    if portions is null or portions <= 0 then raise exception 'invalid_portions'; end if;
    select * into bc from public.batch_components
    where id = (item->>'batch_component_id')::uuid and tenant_id = _tenant_id for update;
    if not found then raise exception 'component_not_found'; end if;
    if not exists (select 1 from public.batches b where b.id = bc.batch_id and b.status = 'ready') then
      raise exception 'batch_not_ready';
    end if;
    select coalesce(sum(di.portions),0) into allocated
    from public.delivery_items di
    join public.deliveries d on d.id = di.delivery_id
    where di.batch_component_id = bc.id
      and d.status in ('draft','dispatched','completed');
    if allocated + portions > bc.portions_produced then
      raise exception 'over_allocated';
    end if;
    insert into public.delivery_items (tenant_id, delivery_id, batch_component_id, portions)
    values (_tenant_id, did, bc.id, portions);
  end loop;

  insert into public.audit_logs(tenant_id, actor_id, action, entity_type, entity_id, occurred_at)
  values (_tenant_id, uid, 'delivery.draft', 'deliveries', did, now());
  return did;
end;
$$;

create or replace function public.accept_invitation(_token_hash text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  inv public.invitations%rowtype;
  jwt_email text;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  jwt_email := lower(coalesce(auth.jwt()->>'email', ''));
  select * into inv from public.invitations where token_hash = _token_hash for update;
  if not found then raise exception 'invite_not_found'; end if;
  if inv.revoked_at is not null or inv.accepted_at is not null or inv.expires_at < now() then
    raise exception 'invite_inactive';
  end if;
  if lower(inv.email) <> jwt_email then raise exception 'email_mismatch'; end if;

  if inv.tenant_id is not null then
    insert into public.tenant_memberships (tenant_id, user_id, role, status)
    values (inv.tenant_id, uid, inv.role, 'active')
    on conflict (tenant_id, user_id) do update set status = 'active', role = excluded.role;
  else
    insert into public.school_memberships (school_id, user_id, role, status)
    values (inv.school_id, uid, inv.role, 'active')
    on conflict (school_id, user_id) do update set status = 'active', role = excluded.role;
  end if;

  update public.invitations set accepted_at = now() where id = inv.id;
  return jsonb_build_object('tenant_id', inv.tenant_id, 'school_id', inv.school_id, 'role', inv.role);
end;
$$;

-- Receipt: conflict is idempotent return, not a no-op that hides errors
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

  select id into rid from public.receipts where delivery_item_id = di.id;
  if rid is not null then
    return rid;
  end if;

  insert into public.receipts (
    tenant_id, delivery_id, delivery_item_id, school_id, received_by,
    accepted_portions, rejected_portions, reason, condition_note, idempotency_key
  ) values (
    d.tenant_id, d.id, di.id, d.school_id, auth.uid(),
    _accepted, _rejected, _reason, _note, _idempotency_key
  )
  on conflict (tenant_id, idempotency_key) do nothing
  returning id into rid;

  if rid is null then
    select id into rid from public.receipts where tenant_id = d.tenant_id and idempotency_key = _idempotency_key;
    return rid;
  end if;

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

revoke all on function public.onboard_school(text,text,text) from public;
revoke all on function public.create_invoice_from_plan(uuid,uuid,text,text) from public;
revoke all on function public.create_delivery_draft(uuid,uuid,jsonb,text) from public;
revoke all on function public.accept_invitation(text) from public;
grant execute on function public.onboard_school(text,text,text) to authenticated;
grant execute on function public.create_invoice_from_plan(uuid,uuid,text,text) to authenticated;
grant execute on function public.create_delivery_draft(uuid,uuid,jsonb,text) to authenticated;
grant execute on function public.accept_invitation(text) to authenticated;

drop policy if exists inv_write on public.invitations;
create policy inv_write on public.invitations for insert to authenticated
  with check (
    (tenant_id is not null and public.is_tenant_member(tenant_id, array['owner','manager']))
    or (school_id is not null and public.is_school_member(school_id, array['admin']))
  );

drop policy if exists inv_upd on public.invitations;
create policy inv_upd on public.invitations for update to authenticated
  using (
    (tenant_id is not null and public.is_tenant_member(tenant_id, array['owner','manager']))
    or (school_id is not null and public.is_school_member(school_id, array['admin']))
  )
  with check (
    (tenant_id is not null and public.is_tenant_member(tenant_id, array['owner','manager']))
    or (school_id is not null and public.is_school_member(school_id, array['admin']))
  );

-- Katalog publik: hanya paket aktif + versi terbit
grant select on public.plans, public.plan_versions to anon, authenticated;
drop policy if exists plans_anon on public.plans;
create policy plans_anon on public.plans for select to anon using (active);
drop policy if exists pv_anon on public.plan_versions;
create policy pv_anon on public.plan_versions for select to anon using (published_at is not null);

-- Katalog demo. Kode lama sandbox-contoh diubah di migrasi 100006.
insert into public.plans (code, name, description, active)
values (
  'standar',
  'GiziLacak Standar',
  'Langganan bulanan untuk produksi, kiriman sekolah, dan verifikasi penerimaan.',
  true
)
on conflict (code) do update set
  name = excluded.name,
  active = excluded.active,
  description = excluded.description;

insert into public.plan_versions (plan_id, version, price_rp, period_months, staff_limit, school_limit, delivery_limit, published_at)
select p.id, 1, 200000, 1, 10, 20, 200, now()
from public.plans p
where p.code = 'standar'
  and not exists (select 1 from public.plan_versions pv where pv.plan_id = p.id and pv.version = 1);
