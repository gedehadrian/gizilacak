-- Expand: identity + organisasi. Tabel legacy (dapur, sekolah, batch, scan_log, laporan) TIDAK dihapus.

create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ========== A. Akun dan organisasi ==========
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  full_name text not null default '',
  phone text,
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sppg_code text not null unique,
  address text not null default '',
  billing_email text not null,
  timezone text not null default 'Asia/Jakarta',
  status text not null default 'active' check (status in ('active','suspended','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id)
);

create table if not exists public.tenant_memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  role text not null check (role in ('owner','manager','operator','finance','viewer')),
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, user_id),
  unique (tenant_id, id)
);

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  school_code text not null unique,
  address text not null default '',
  status text not null default 'active' check (status in ('active','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.school_memberships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  role text not null check (role in ('admin','staff')),
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, user_id),
  unique (school_id, id)
);

create table if not exists public.tenant_schools (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  school_id uuid not null references public.schools(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending','active','inactive')),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, school_id),
  unique (tenant_id, id)
);

create table if not exists public.invitations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete restrict,
  school_id uuid references public.schools(id) on delete restrict,
  email text not null,
  role text not null,
  token_hash text not null unique,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  invited_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint invitations_one_target check (
    (tenant_id is not null and school_id is null) or (tenant_id is null and school_id is not null)
  )
);

create table if not exists public.platform_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete restrict,
  role text not null default 'admin' check (role = 'admin'),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete restrict,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  occurred_at timestamptz not null default now(),
  request_id text not null default gen_random_uuid()::text,
  before_redacted jsonb,
  after_redacted jsonb,
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.rate_limit_buckets (
  key_hash text primary key,
  window_start timestamptz not null,
  count int not null default 0,
  expires_at timestamptz not null
);

create table if not exists public.legacy_id_map (
  legacy_table text not null,
  legacy_id uuid not null,
  target_table text not null,
  target_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (legacy_table, legacy_id, target_table)
);

create index if not exists idx_tenant_memberships_user on public.tenant_memberships(user_id, status, tenant_id);
create index if not exists idx_school_memberships_user on public.school_memberships(user_id, status, school_id);
create index if not exists idx_audit_tenant on public.audit_logs(tenant_id, occurred_at desc);

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists trg_tenants_updated on public.tenants;
create trigger trg_tenants_updated before update on public.tenants for each row execute function public.set_updated_at();
drop trigger if exists trg_tm_updated on public.tenant_memberships;
create trigger trg_tm_updated before update on public.tenant_memberships for each row execute function public.set_updated_at();
drop trigger if exists trg_schools_updated on public.schools;
create trigger trg_schools_updated before update on public.schools for each row execute function public.set_updated_at();
drop trigger if exists trg_sm_updated on public.school_memberships;
create trigger trg_sm_updated before update on public.school_memberships for each row execute function public.set_updated_at();
drop trigger if exists trg_ts_updated on public.tenant_schools;
create trigger trg_ts_updated before update on public.tenant_schools for each row execute function public.set_updated_at();
drop trigger if exists trg_pu_updated on public.platform_users;
create trigger trg_pu_updated before update on public.platform_users for each row execute function public.set_updated_at();

-- Helpers (SECURITY DEFINER, boolean lookup only)
create or replace function public.is_tenant_member(_tid uuid, _roles text[] default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.tenant_memberships
    where tenant_id = _tid
      and user_id = auth.uid()
      and status = 'active'
      and (_roles is null or role = any(_roles))
  );
$$;

create or replace function public.is_school_member(_sid uuid, _roles text[] default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.school_memberships
    where school_id = _sid
      and user_id = auth.uid()
      and status = 'active'
      and (_roles is null or role = any(_roles))
  );
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.platform_users
    where user_id = auth.uid() and active = true
  );
$$;

revoke all on function public.is_tenant_member(uuid, text[]) from public;
revoke all on function public.is_school_member(uuid, text[]) from public;
revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_tenant_member(uuid, text[]) to authenticated;
grant execute on function public.is_school_member(uuid, text[]) to authenticated;
grant execute on function public.is_platform_admin() to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

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
  values (_name, _sppg_code, coalesce(_address,''), _billing_email)
  returning id into tid;

  insert into public.tenant_memberships (tenant_id, user_id, role, status)
  values (tid, uid, 'owner', 'active');

  insert into public.audit_logs (tenant_id, actor_id, action, entity_type, entity_id, occurred_at, request_id)
  values (tid, uid, 'tenant.onboard', 'tenants', tid, now(), gen_random_uuid()::text);

  return tid;
end;
$$;

revoke all on function public.onboard_tenant(text,text,text,text) from public;
grant execute on function public.onboard_tenant(text,text,text,text) to authenticated;
