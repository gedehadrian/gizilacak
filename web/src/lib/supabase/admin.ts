import "server-only";
import { createClient } from "@supabase/supabase-js";
import { getPublicSupabaseConfig, getServiceRoleKey } from "./env";

/** Privileged client: webhook, jobs, QR publik whitelist, provisioning. Bukan bypass operasional UI. */
export function createSupabaseAdmin() {
  const { url } = getPublicSupabaseConfig();
  const key = getServiceRoleKey();
  if (!key) throw new Error("SUPABASE_SECRET_KEY / SUPABASE_SERVICE_ROLE_KEY belum diisi.");
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

export function isAdminConfigured() {
  return Boolean(getServiceRoleKey());
}
