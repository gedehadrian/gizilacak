import "server-only";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { getPublicSupabaseConfig, getServiceRoleKey } from "@/lib/supabase/env";

export function isSupabaseAdminConfigured(): boolean {
  try {
    const { url } = getPublicSupabaseConfig();
    const key = getServiceRoleKey();
    return Boolean(url && key && !url.includes("xxxxx"));
  } catch {
    return false;
  }
}

export const supabaseAdmin: SupabaseClient = (() => {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://placeholder.supabase.co";
  const key = getServiceRoleKey() || "placeholder";
  return createClient(url, key, { auth: { persistSession: false } });
})();
