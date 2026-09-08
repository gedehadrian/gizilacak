// DEPRECATED — client anon Supabase ini TIDAK LAGI dipakai di mana pun.
// Semua akses DB sekarang lewat API routes server yang memakai
// src/lib/supabase-admin.ts (service role). File ini sengaja tidak dihapus
// (device tool tidak bisa hapus file tanpa izin delete eksplisit dari user)
// tapi tidak diimpor dari mana pun lagi — aman dihapus manual kapan saja.
import { createClient, SupabaseClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase: SupabaseClient = createClient(
  supabaseUrl || "https://placeholder.supabase.co",
  supabaseAnonKey || "placeholder"
);

export function isSupabaseConfigured(): boolean {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY &&
      !process.env.NEXT_PUBLIC_SUPABASE_URL.includes("xxxxx")
  );
}
