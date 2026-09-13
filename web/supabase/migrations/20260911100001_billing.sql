-- Billing: plans, invoices, payments, counters, platform expenses

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text not null default '',
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.plan_versions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete restrict,
  version int not null,
  price_rp bigint not null check (price_rp >= 0),
  period_months int not null default 1 check (period_months = 1),
  staff_limit int not null check (staff_limit > 0),
  school_limit int not null check (school_limit > 0),
  delivery_limit int not null check (delivery_limit > 0),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique (plan_id, version)
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  number text not null unique,
  plan_version_id uuid not null references public.plan_versions(id) on delete restrict,
  status text not null default 'open' check (status in ('draft','open','paid','expired','void')),
  purpose text not null check (purpose in ('initial','renewal')),
  currency text not null default 'IDR',
  subtotal_rp bigint not null check (subtotal_rp >= 0),
  discount_rp bigint not null default 0 check (discount_rp >= 0),
  tax_rp bigint not null default 0 check (tax_rp >= 0),
  total_rp bigint not null check (total_rp >= 0),
  issued_at timestamptz,
  due_at timestamptz not null,
  paid_at timestamptz,
  service_start timestamptz,
  service_end timestamptz,
  billing_snapshot jsonb not null default '{}'::jsonb,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, idempotency_key),
  unique (tenant_id, id),
  check (total_rp = subtotal_rp - discount_rp + tax_rp)
);

create table if not exists public.invoice_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  invoice_id uuid not null,
  description text not null,
  quantity int not null check (quantity > 0),
  unit_price_rp bigint not null check (unit_price_rp >= 0),
  line_total_rp bigint not null check (line_total_rp >= 0),
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, invoice_id) references public.invoices(tenant_id, id) on delete restrict,
  check (line_total_rp = quantity * unit_price_rp)
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  plan_version_id uuid not null references public.plan_versions(id) on delete restrict,
  status text not null check (status in ('pending','active','expired','canceled')),
  period_start timestamptz not null,
  period_end timestamptz not null,
  cancel_at_period_end boolean not null default false,
  source_invoice_id uuid unique,
  price_rp_snapshot bigint not null check (price_rp_snapshot >= 0),
  limits_snapshot jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  check (period_end > period_start),
  foreign key (source_invoice_id) references public.invoices(id) on delete restrict
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  invoice_id uuid not null,
  provider text not null default 'midtrans' check (provider = 'midtrans'),
  environment text not null check (environment in ('sandbox','production')),
  order_id text not null,
  provider_transaction_id text,
  status text not null default 'created' check (status in ('created','pending','paid','failed','expired','refunded','partially_refunded')),
  amount_rp bigint not null check (amount_rp >= 0),
  refunded_rp bigint not null default 0 check (refunded_rp >= 0),
  fee_rp bigint,
  fee_source text,
  checkout_url text,
  expires_at timestamptz,
  verified_at timestamptz,
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, environment, order_id),
  unique (tenant_id, id),
  check (refunded_rp <= amount_rp),
  foreign key (tenant_id, invoice_id) references public.invoices(tenant_id, id) on delete restrict
);

create unique index if not exists payments_provider_tx_uidx
  on public.payments(provider, environment, provider_transaction_id)
  where provider_transaction_id is not null;

create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid references public.payments(id) on delete restrict,
  provider text not null,
  environment text not null,
  dedupe_key text not null,
  received_at timestamptz not null default now(),
  verified_at timestamptz,
  processed_at timestamptz,
  status text not null default 'received' check (status in ('received','processed','failed','ignored')),
  payload_redacted jsonb not null default '{}'::jsonb,
  error_code text,
  retry_count int not null default 0,
  created_at timestamptz not null default now(),
  unique (provider, environment, dedupe_key)
);

create table if not exists public.usage_counters (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  period_start timestamptz not null,
  period_end timestamptz not null,
  metric text not null check (metric = 'deliveries'),
  used int not null default 0 check (used >= 0),
  limit_snapshot int not null check (limit_snapshot > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, period_start, metric)
);

create table if not exists public.platform_expenses (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  description text not null,
  amount_rp bigint not null check (amount_rp >= 0),
  incurred_on date not null,
  paid_on date,
  kind text not null check (kind in ('fixed','variable')),
  status text not null default 'draft' check (status in ('draft','posted','void')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_invoices_tenant on public.invoices(tenant_id, status, due_at);
create index if not exists idx_payments_invoice on public.payments(invoice_id);

drop trigger if exists trg_plans_updated on public.plans;
create trigger trg_plans_updated before update on public.plans for each row execute function public.set_updated_at();
drop trigger if exists trg_invoices_updated on public.invoices;
create trigger trg_invoices_updated before update on public.invoices for each row execute function public.set_updated_at();
drop trigger if exists trg_subs_updated on public.subscriptions;
create trigger trg_subs_updated before update on public.subscriptions for each row execute function public.set_updated_at();
drop trigger if exists trg_pay_updated on public.payments;
create trigger trg_pay_updated before update on public.payments for each row execute function public.set_updated_at();
drop trigger if exists trg_usage_updated on public.usage_counters;
create trigger trg_usage_updated before update on public.usage_counters for each row execute function public.set_updated_at();

-- Aktivasi invoice berbayar (dipanggil service role setelah webhook terverifikasi)
create or replace function public.activate_paid_invoice(_invoice_id uuid, _payment_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  inv public.invoices%rowtype;
  pv public.plan_versions%rowtype;
  last_end timestamptz;
  pstart timestamptz;
  pend timestamptz;
  sub_id uuid;
begin
  select * into inv from public.invoices where id = _invoice_id for update;
  if not found then
    raise exception 'invoice_not_found';
  end if;
  if inv.status = 'paid' then
    select id into sub_id from public.subscriptions where source_invoice_id = inv.id;
    return sub_id;
  end if;
  if inv.status not in ('open','draft') then
    raise exception 'invoice_not_payable';
  end if;

  select * into pv from public.plan_versions where id = inv.plan_version_id;

  select max(period_end) into last_end
  from public.subscriptions
  where tenant_id = inv.tenant_id
    and status in ('active','expired','canceled')
    and period_end > now();

  if last_end is not null and last_end > now() then
    pstart := last_end;
  else
    pstart := now();
  end if;
  pend := pstart + make_interval(months => coalesce(pv.period_months, 1));

  update public.invoices
  set status = 'paid', paid_at = now(), service_start = pstart, service_end = pend
  where id = inv.id;

  update public.payments
  set status = 'paid', verified_at = now(), settled_at = now()
  where id = _payment_id and status <> 'paid';

  insert into public.subscriptions (
    tenant_id, plan_version_id, status, period_start, period_end,
    source_invoice_id, price_rp_snapshot, limits_snapshot
  ) values (
    inv.tenant_id, inv.plan_version_id, 'active', pstart, pend,
    inv.id, inv.total_rp,
    jsonb_build_object(
      'staff_limit', pv.staff_limit,
      'school_limit', pv.school_limit,
      'delivery_limit', pv.delivery_limit
    )
  ) returning id into sub_id;

  insert into public.usage_counters (tenant_id, period_start, period_end, metric, used, limit_snapshot)
  values (inv.tenant_id, pstart, pend, 'deliveries', 0, pv.delivery_limit)
  on conflict (tenant_id, period_start, metric) do nothing;

  insert into public.audit_logs (tenant_id, action, entity_type, entity_id, occurred_at, after_redacted)
  values (inv.tenant_id, 'billing.invoice_paid', 'invoices', inv.id, now(), jsonb_build_object('subscription_id', sub_id));

  return sub_id;
end;
$$;

revoke all on function public.activate_paid_invoice(uuid, uuid) from public;
grant execute on function public.activate_paid_invoice(uuid, uuid) to service_role;
