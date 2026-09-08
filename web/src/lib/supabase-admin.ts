import "server-only";
import { createClient, SupabaseClient } from "@supabase/supabase-js";

// HANYA dipakai di server (API routes / Server Components).
// Service role key membypass RLS sepenuhnya — JANGAN PERNAH import file ini
// dari komponen "use client" atau expose nilainya ke browser.
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  // Tidak melempar error saat build/import supaya halaman lain tetap render;
  // tiap API route yang pakai client ini wajib cek isSupabaseAdminConfigured()
  // dan mengembalikan 500 yang jelas kalau belum dikonfigurasi.
  console.warn(
    "[supabase-admin] NEXT_PUBLIC_SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY belum diisi di .env.local"
  );
}

export const supabaseAdmin: SupabaseClient = createClient(
  supabaseUrl || "https://placeholder.supabase.co",
  serviceRoleKey || "placeholder",
  { auth: { persistSession: false } }
);

export function isSupabaseAdminConfigured(): boolean {
  return Boolean(
    supabaseUrl && serviceRoleKey && !supabaseUrl.includes("xxxxx")
  );
}
