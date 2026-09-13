import "server-only";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { createSupabaseServer } from "@/lib/supabase/server";

export async function getActiveTenantId() {
  return (await cookies()).get("gzl_tenant")?.value ?? null;
}

export async function getActiveSchoolId() {
  return (await cookies()).get("gzl_school")?.value ?? null;
}

export async function requireAppTenant() {
  const supabase = await createSupabaseServer();
  const { data } = await supabase.auth.getUser();
  if (!data.user) redirect("/masuk");
  const tenantId = await getActiveTenantId();
  if (!tenantId) redirect("/pilih-organisasi");
  const { data: mem } = await supabase
    .from("tenant_memberships")
    .select("role, tenants(name, sppg_code)")
    .eq("tenant_id", tenantId)
    .eq("user_id", data.user.id)
    .eq("status", "active")
    .maybeSingle();
  if (!mem) redirect("/pilih-organisasi");
  const tenants = mem.tenants as unknown as { name: string; sppg_code: string } | null;
  return { supabase, user: data.user, tenantId, role: mem.role as string, tenantName: tenants?.name ?? "SPPG" };
}

export async function requireAppSchool() {
  const supabase = await createSupabaseServer();
  const { data } = await supabase.auth.getUser();
  if (!data.user) redirect("/masuk");
  const schoolId = await getActiveSchoolId();
  if (!schoolId) redirect("/pilih-organisasi");
  const { data: mem } = await supabase
    .from("school_memberships")
    .select("role, schools(name)")
    .eq("school_id", schoolId)
    .eq("user_id", data.user.id)
    .eq("status", "active")
    .maybeSingle();
  if (!mem) redirect("/pilih-organisasi");
  const schools = mem.schools as unknown as { name: string } | null;
  return { supabase, user: data.user, schoolId, role: mem.role as string, schoolName: schools?.name ?? "Sekolah" };
}
