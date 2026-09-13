-- Produksi, kiriman, QR, receipt, insiden, expenses, notifications, exports

create table if not exists public.consumption_policies (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  version int not null,
  name text not null,
  duration_minutes int not null check (duration_minutes > 0),
  warning_minutes int not null,
  source_note text not null default '',
  approved_by uuid not null references public.profiles(id) on delete restrict,
  effective_from timestamptz not null default now(),
  retired_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, version),
  unique (tenant_id, id),
  check (warning_minutes > 0 and warning_minutes < duration_minutes)
);

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  name text not null,
  description text,
  archived_at timestamptz,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id)
);

create table if not exists public.recipe_components (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  recipe_id uuid not null,
  name text not null,
  portion_grams numeric(12,3) check (portion_grams is null or portion_grams >= 0),
  kcal numeric(12,3) check (kcal is null or kcal >= 0),
  protein_g numeric(12,3) check (protein_g is null or protein_g >= 0),
  carbs_g numeric(12,3) check (carbs_g is null or carbs_g >= 0),
  fat_g numeric(12,3) check (fat_g is null or fat_g >= 0),
  ingredients text[] not null default '{}',
  allergens text[] not null default '{}',
  allergen_state text not null default 'unknown' check (allergen_state in ('known','unknown')),
  nutrition_source text,
  position int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, recipe_id) references public.recipes(tenant_id, id) on delete restrict
);

create table if not exists public.batches (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  code text not null,
  recipe_id uuid,
  production_date date not null,
  status text not null default 'draft' check (status in ('draft','ready','canceled')),
  notes text,
  created_by uuid not null references public.profiles(id) on delete restrict,
  finalized_by uuid references public.profiles(id) on delete restrict,
  finalized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, code),
  unique (tenant_id, id)
);

create table if not exists public.batch_components (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  batch_id uuid not null,
  name text not null,
  portions_produced int not null check (portions_produced > 0),
  cooked_at timestamptz,
  policy_id uuid not null,
  duration_minutes_snapshot int not null,
  warning_minutes_snapshot int not null,
  consume_by timestamptz,
  kcal numeric(12,3),
  protein_g numeric(12,3),
  carbs_g numeric(12,3),
  fat_g numeric(12,3),
  portion_grams numeric(12,3),
  ingredients text[] not null default '{}',
  allergens text[] not null default '{}',
  allergen_state text not null default 'unknown',
  nutrition_source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, batch_id) references public.batches(tenant_id, id) on delete restrict,
  foreign key (tenant_id, policy_id) references public.consumption_policies(tenant_id, id) on delete restrict
);

create table if not exists public.deliveries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  school_id uuid not null references public.schools(id) on delete restrict,
  code text not null,
  status text not null default 'draft' check (status in ('draft','dispatched','completed','canceled')),
  scheduled_at timestamptz,
  dispatched_at timestamptz,
  completed_at timestamptz,
  created_by uuid not null references public.profiles(id) on delete restrict,
  dispatched_by uuid references public.profiles(id) on delete restrict,
  version int not null default 1,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, code),
  unique (tenant_id, idempotency_key),
  unique (tenant_id, id),
  unique (tenant_id, id, school_id),
  foreign key (tenant_id, school_id) references public.tenant_schools(tenant_id, school_id) on delete restrict
);

create table if not exists public.delivery_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  delivery_id uuid not null,
  batch_component_id uuid not null,
  portions int not null check (portions > 0),
  created_at timestamptz not null default now(),
  unique (delivery_id, batch_component_id),
  unique (tenant_id, id),
  unique (tenant_id, delivery_id, id),
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict,
  foreign key (tenant_id, batch_component_id) references public.batch_components(tenant_id, id) on delete restrict
);

create table if not exists public.qr_labels (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  delivery_id uuid not null,
  token text not null unique,
  issued_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoke_reason text,
  version int not null default 1,
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, delivery_id) references public.deliveries(tenant_id, id) on delete restrict
);

create unique index if not exists qr_labels_one_active
  on public.qr_labels(delivery_id) where revoked_at is null;

create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  delivery_id uuid not null,
  delivery_item_id uuid not null unique,
  school_id uuid not null,
  received_by uuid not null references public.profiles(id) on delete restrict,
  received_at timestamptz not null default now(),
  accepted_portions int not null check (accepted_portions >= 0),
  rejected_portions int not null check (rejected_portions >= 0),
  reason text,
  condition_note text,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  unique (tenant_id, idempotency_key),
  foreign key (tenant_id, delivery_id, school_id) references public.deliveries(tenant_id, id, school_id) on delete restrict,
  foreign key (tenant_id, delivery_id, delivery_item_id) references public.delivery_items(tenant_id, delivery_id, id) on delete restrict
);

create table if not exists public.scan_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  qr_label_id uuid not null,
  scanned_at timestamptz not null default now(),
  actor_user_id uuid references public.profiles(id) on delete restrict,
  actor_kind text not null check (actor_kind in ('public','school','staff')),
  event_key text not null,
  created_at timestamptz not null default now(),
  unique (qr_label_id, event_key)
);

create table if not exists public.incidents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  delivery_id uuid not null,
  school_id uuid not null,
  reported_by uuid not null references public.profiles(id) on delete restrict,
  category text not null check (category in ('quality','late','missing_information','other')),
  description text not null,
  status text not null default 'open' check (status in ('open','in_review','resolved','closed')),
  severity text not null check (severity in ('low','medium','high')),
  assigned_to uuid references public.profiles(id) on delete restrict,
  reported_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, delivery_id, school_id) references public.deliveries(tenant_id, id, school_id) on delete restrict
);

create table if not exists public.incident_updates (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null,
  incident_id uuid not null,
  author_id uuid not null references public.profiles(id) on delete restrict,
  message text not null,
  from_status text,
  to_status text,
  visibility text not null default 'shared' check (visibility in ('shared','internal')),
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, incident_id) references public.incidents(tenant_id, id) on delete restrict
);

create table if not exists public.tenant_expenses (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  batch_id uuid,
  category text not null check (category in ('ingredients','packaging','transport','labor','other')),
  description text not null,
  amount_rp bigint not null check (amount_rp >= 0),
  expense_date date not null,
  status text not null default 'draft' check (status in ('draft','posted','void')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id)
);

create table if not exists public.attachments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  incident_id uuid,
  tenant_expense_id uuid,
  storage_path text not null unique,
  original_name text not null,
  mime_type text not null,
  size_bytes int not null check (size_bytes > 0),
  uploaded_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending','ready','rejected')),
  created_at timestamptz not null default now(),
  check (
    (incident_id is not null and tenant_expense_id is null)
    or (incident_id is null and tenant_expense_id is not null)
  )
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete restrict,
  school_id uuid references public.schools(id) on delete restrict,
  recipient_id uuid not null references public.profiles(id) on delete restrict,
  type text not null,
  title text not null,
  body text not null,
  target_path text not null,
  read_at timestamptz,
  dedupe_key text not null,
  created_at timestamptz not null default now(),
  unique (recipient_id, dedupe_key)
);

create table if not exists public.exports (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete restrict,
  school_id uuid references public.schools(id) on delete restrict,
  requested_by uuid not null references public.profiles(id) on delete restrict,
  kind text not null check (kind in ('operations','finance','invoice')),
  filters jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','ready','failed','expired')),
  storage_path text,
  expires_at timestamptz,
  error_code text,
  created_at timestamptz not null default now()
);

create index if not exists idx_batches_tenant on public.batches(tenant_id, created_at desc);
create index if not exists idx_deliveries_school on public.deliveries(school_id, status, created_at desc);
create index if not exists idx_incidents_tenant on public.incidents(tenant_id, status, reported_at desc);
create index if not exists idx_scan_logs_qr on public.scan_logs(qr_label_id, scanned_at desc);
create index if not exists idx_notifications_recipient on public.notifications(recipient_id, read_at, created_at desc);
