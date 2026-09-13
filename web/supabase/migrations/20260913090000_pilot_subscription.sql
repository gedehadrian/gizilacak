-- Jalur uji coba (pilot): memberi SPPG langganan aktif tanpa tagihan.
--
-- Mitra pilot tidak membayar, tapi tetap harus melewati pemeriksaan yang sama
-- dengan pelanggan biasa. Daripada melubangi `dispatch_delivery` dengan
-- pengecualian, pilot diberi langganan sungguhan seharga nol. Akibatnya kuota,
-- masa berlaku, dan penghitungan pemakaian berperilaku persis seperti di
-- produksi — yang justru penting, karena uji coba lapangan harus menguji
-- sistem yang sebenarnya, bukan versi yang dilonggarkan.
--
-- Hanya operator platform yang boleh memanggilnya, dan setiap pemberian
-- tercatat di audit_logs beserta alasannya.

create or replace function public.grant_pilot_subscription(
  _tenant_id uuid,
  _plan_version_id uuid,
  _months int,
  _reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  pv public.plan_versions%rowtype;
  last_end timestamptz;
  pstart timestamptz;
  pend timestamptz;
  sub_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.is_platform_admin() then raise exception 'forbidden'; end if;

  if _months is null or _months < 1 or _months > 24 then
    raise exception 'invalid_period';
  end if;
  if _reason is null or length(btrim(_reason)) < 3 then
    raise exception 'pilot_reason_required';
  end if;

  if not exists (select 1 from public.tenants where id = _tenant_id) then
    raise exception 'tenant_not_found';
  end if;

  select * into pv from public.plan_versions where id = _plan_version_id;
  if not found then raise exception 'plan_version_not_found'; end if;
  if pv.published_at is null then raise exception 'plan_unpublished'; end if;

  -- Menyambung ke periode berjalan kalau ada, meniru activate_paid_invoice.
  select max(period_end) into last_end
  from public.subscriptions
  where tenant_id = _tenant_id
    and status in ('active','expired','canceled')
    and period_end > now();

  if last_end is not null and last_end > now() then
    pstart := last_end;
  else
    pstart := now();
  end if;
  pend := pstart + make_interval(months => _months);

  insert into public.subscriptions (
    tenant_id, plan_version_id, status, period_start, period_end,
    source_invoice_id, price_rp_snapshot, limits_snapshot
  ) values (
    _tenant_id, pv.id, 'active', pstart, pend,
    null, 0,
    jsonb_build_object(
      'staff_limit', pv.staff_limit,
      'school_limit', pv.school_limit,
      'delivery_limit', pv.delivery_limit,
      'pilot', true
    )
  ) returning id into sub_id;

  -- Tanpa baris ini dispatch tetap ditolak dengan quota_exceeded.
  insert into public.usage_counters (
    tenant_id, period_start, period_end, metric, used, limit_snapshot
  ) values (
    _tenant_id, pstart, pend, 'deliveries', 0, pv.delivery_limit
  )
  on conflict (tenant_id, period_start, metric) do nothing;

  insert into public.audit_logs (
    tenant_id, actor_id, action, entity_type, entity_id, occurred_at,
    reason, after_redacted
  ) values (
    _tenant_id, auth.uid(), 'billing.pilot_granted', 'subscriptions', sub_id,
    now(), btrim(_reason),
    jsonb_build_object(
      'plan_version_id', pv.id,
      'months', _months,
      'period_start', pstart,
      'period_end', pend
    )
  );

  return sub_id;
end;
$$;

revoke all on function public.grant_pilot_subscription(uuid, uuid, int, text) from public;
grant execute on function public.grant_pilot_subscription(uuid, uuid, int, text) to authenticated;
