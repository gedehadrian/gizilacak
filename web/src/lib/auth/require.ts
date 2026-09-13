import "server-only";
import type { User } from "@supabase/supabase-js";
import { createSupabaseServer } from "@/lib/supabase/server";
import { getPublicSupabaseConfig } from "@/lib/supabase/env";
import { jsonError } from "@/lib/http";

export type TenantRole = "owner" | "manager" | "operator" | "finance" | "viewer";
export type SchoolRole = "admin" | "staff";
type Server = Awaited<ReturnType<typeof createSupabaseServer>>;
type Fail = { ok: false; error: ReturnType<typeof jsonError> };
type UserOk = { ok: true; supabase: Server; user: User };
type TenantOk = UserOk & { membership: { role: string; status: string; tenant_id: string } };
type SchoolOk = UserOk & { membership: { role: string; status: string; school_id: string } };

export async function requireUser(): Promise<Fail | UserOk> {
  const supabase = await createSupabaseServer();
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) return { ok: false, error: jsonError(401, "unauthenticated", "Belum masuk.") };
  return { ok: true, supabase, user: data.user };
}

export async function requireTenant(tenantId: string, roles?: TenantRole[]): Promise<Fail | TenantOk> {
  const auth = await requireUser();
  if (!auth.ok) return auth;
  const { supabase, user } = auth;
  const { data: membership } = await supabase
    .from("tenant_memberships")
    .select("role, status, tenant_id")
    .eq("tenant_id", tenantId)
    .eq("user_id", user.id)
    .eq("status", "active")
    .maybeSingle();
  if (!membership) return { ok: false, error: jsonError(403, "forbidden", "Tidak berhak pada organisasi ini.") };
  if (roles && !roles.includes(membership.role as TenantRole)) {
    return { ok: false, error: jsonError(403, "forbidden", "Peran tidak mencukupi.") };
  }
  return { ok: true, supabase, user, membership };
}

export async function requireSchool(schoolId: string, roles?: SchoolRole[]): Promise<Fail | SchoolOk> {
  const auth = await requireUser();
  if (!auth.ok) return auth;
  const { supabase, user } = auth;
  const { data: membership } = await supabase
    .from("school_memberships")
    .select("role, status, school_id")
    .eq("school_id", schoolId)
    .eq("user_id", user.id)
    .eq("status", "active")
    .maybeSingle();
  if (!membership) return { ok: false, error: jsonError(403, "forbidden", "Tidak berhak pada sekolah ini.") };
  if (roles && !roles.includes(membership.role as SchoolRole)) {
    return { ok: false, error: jsonError(403, "forbidden", "Peran sekolah tidak mencukupi.") };
  }
  return { ok: true, supabase, user, membership };
}

export async function requirePlatformAdmin(): Promise<Fail | UserOk> {
  const auth = await requireUser();
  if (!auth.ok) return auth;
  const { data } = await auth.supabase
    .from("platform_users")
    .select("active")
    .eq("user_id", auth.user.id)
    .eq("active", true)
    .maybeSingle();
  if (!data) return { ok: false, error: jsonError(403, "forbidden", "Bukan operator platform.") };
  return auth;
}

/**
 * Auth untuk app Flutter: `Authorization: Bearer <access token Supabase>` plus
 * header `x-gzl-tenant`. Dipakai karena app tidak punya cookie sesi web.
 * Client dibuat dengan token pengguna, jadi RLS tetap berlaku seperti biasa.
 */
export async function requireTenantFromBearer(
  req: Request,
  roles?: TenantRole[]
): Promise<Fail | TenantOk> {
  const header = req.headers.get("authorization") ?? "";
  const token = header.toLowerCase().startsWith("bearer ") ? header.slice(7).trim() : "";
  if (!token) return { ok: false, error: jsonError(401, "unauthenticated", "Belum masuk.") };

  const tenantId = req.headers.get("x-gzl-tenant") ?? "";
  if (!tenantId) {
    return { ok: false, error: jsonError(400, "no_tenant", "Pilih organisasi SPPG terlebih dahulu.") };
  }

  const { createClient } = await import("@supabase/supabase-js");
  const { url, key } = getPublicSupabaseConfig();
  const supabase = createClient(url, key, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  }) as unknown as Server;

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    return { ok: false, error: jsonError(401, "unauthenticated", "Sesi tidak sah atau kedaluwarsa.") };
  }

  const { data: membership } = await supabase
    .from("tenant_memberships")
    .select("role, status, tenant_id")
    .eq("tenant_id", tenantId)
    .eq("user_id", data.user.id)
    .eq("status", "active")
    .maybeSingle();
  if (!membership) {
    return { ok: false, error: jsonError(403, "forbidden", "Tidak berhak pada organisasi ini.") };
  }
  if (roles && !roles.includes(membership.role as TenantRole)) {
    return { ok: false, error: jsonError(403, "forbidden", "Peran tidak mencukupi.") };
  }
  return { ok: true, supabase, user: data.user, membership };
}

/** Menerima bearer token dari app, atau cookie kalau masih dipanggil dari web. */
export async function requireTenantFlexible(
  req: Request,
  roles?: TenantRole[]
): Promise<Fail | TenantOk> {
  if ((req.headers.get("authorization") ?? "").toLowerCase().startsWith("bearer ")) {
    return requireTenantFromBearer(req, roles);
  }
  return requireTenantFromCookie(roles);
}

export async function requireTenantFromCookie(roles?: TenantRole[]): Promise<Fail | TenantOk> {
  const { cookies } = await import("next/headers");
  const tenantId = (await cookies()).get("gzl_tenant")?.value;
  if (!tenantId) return { ok: false, error: jsonError(400, "no_tenant", "Pilih organisasi SPPG terlebih dahulu.") };
  return requireTenant(tenantId, roles);
}

export async function requireSchoolFromCookie(roles?: SchoolRole[]): Promise<Fail | SchoolOk> {
  const { cookies } = await import("next/headers");
  const schoolId = (await cookies()).get("gzl_school")?.value;
  if (!schoolId) return { ok: false, error: jsonError(400, "no_school", "Pilih sekolah terlebih dahulu.") };
  return requireSchool(schoolId, roles);
}

export function mapPgError(message: string) {
  const table: Record<string, { status: number; code: string; message: string }> = {
    not_authenticated: { status: 401, code: "unauthenticated", message: "Belum masuk." },
    forbidden: { status: 403, code: "forbidden", message: "Tidak berhak." },
    batch_not_found: { status: 404, code: "not_found", message: "Batch tidak ditemukan." },
    batch_not_draft: { status: 409, code: "conflict", message: "Batch bukan draf." },
    components_incomplete: { status: 422, code: "invalid", message: "Semua komponen wajib punya waktu matang." },
    delivery_not_found: { status: 404, code: "not_found", message: "Kiriman tidak ditemukan." },
    delivery_not_draft: { status: 409, code: "conflict", message: "Kiriman bukan draf." },
    school_not_linked: { status: 422, code: "invalid", message: "Sekolah belum terhubung aktif." },
    no_entitlement: { status: 409, code: "no_entitlement", message: "Langganan aktif tidak ditemukan. Dispatch diblokir." },
    quota_exceeded: { status: 409, code: "quota", message: "Kuota kiriman periode ini habis." },
    over_allocated: { status: 409, code: "over_allocated", message: "Alokasi porsi melebihi produksi." },
    batch_not_ready: { status: 409, code: "conflict", message: "Komponen berasal dari batch yang belum final." },
    item_not_found: { status: 404, code: "not_found", message: "Item kiriman tidak ditemukan." },
    delivery_not_dispatched: { status: 409, code: "conflict", message: "Kiriman belum dikirim." },
    portions_mismatch: { status: 422, code: "invalid", message: "Jumlah diterima+ditolak harus sama dengan porsi kiriman." },
    reason_required: { status: 422, code: "invalid", message: "Alasan wajib jika ada porsi ditolak." },
    plan_unpublished: { status: 422, code: "invalid", message: "Versi paket belum terbit." },
    plan_inactive: { status: 422, code: "invalid", message: "Paket tidak aktif." },
    invite_not_found: { status: 404, code: "not_found", message: "Undangan tidak ditemukan." },
    invite_inactive: { status: 409, code: "conflict", message: "Undangan kedaluwarsa, dicabut, atau sudah dipakai." },
    email_mismatch: { status: 403, code: "forbidden", message: "Email akun tidak sama dengan undangan." },
    invoice_not_found: { status: 404, code: "not_found", message: "Invoice tidak ditemukan." },
    invoice_not_payable: { status: 409, code: "conflict", message: "Invoice tidak dapat dilunasi." },
  };
  for (const [k, v] of Object.entries(table)) {
    if (message.includes(k)) return jsonError(v.status, v.code, v.message);
  }
  if (message.includes("duplicate key")) return jsonError(409, "conflict", "Data duplikat. Coba kode lain atau muat ulang.");
  return jsonError(400, "rpc_error", message.replace(/_/g, " "));
}

export async function membershipsForUser(userId: string) {
  const supabase = await createSupabaseServer();
  const [{ data: tenants }, { data: schools }] = await Promise.all([
    supabase
      .from("tenant_memberships")
      .select("tenant_id, role, status, tenants(name, sppg_code, status)")
      .eq("user_id", userId)
      .eq("status", "active"),
    supabase
      .from("school_memberships")
      .select("school_id, role, status, schools(name, school_code, status)")
      .eq("user_id", userId)
      .eq("status", "active"),
  ]);
  return { tenants: tenants ?? [], schools: schools ?? [] };
}
