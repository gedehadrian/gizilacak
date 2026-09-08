import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin, isSupabaseAdminConfigured } from "@/lib/supabase-admin";

// Seeding data demo TIDAK LAGI dipanggil otomatis dari halaman manapun.
// Jalankan manual SATU KALI (mis. lewat curl atau Postman) setelah deploy:
//
//   curl -X POST https://<domain-kamu>/api/seed -H "X-Seed-Secret: <isi SEED_SECRET>"
//
// Wajib set SEED_SECRET di .env.local / env Vercel, kalau tidak endpoint ini
// selalu menolak (fail-closed, bukan fail-open).
const DAPUR_PIN_HASH =
  "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4"; // 1234
const SEKOLAH_PIN_HASH =
  "f8638b979b2f4f793ddb6dbd197e0ee25a7a6ea32b0ae22f5e3c5d119d839e75"; // 5678

export async function POST(req: NextRequest) {
  const expected = process.env.SEED_SECRET;
  const given = req.headers.get("x-seed-secret");
  if (!expected || !given || given !== expected) {
    return NextResponse.json({ ok: false, error: "Tidak diizinkan." }, { status: 403 });
  }

  if (!isSupabaseAdminConfigured()) {
    return NextResponse.json({ ok: false, error: "Server belum dikonfigurasi." }, { status: 500 });
  }

  const { data: dapurExisting } = await supabaseAdmin
    .from("dapur")
    .select("id")
    .eq("kode_dapur", "SPPG-CISAUIK")
    .maybeSingle();

  if (!dapurExisting) {
    const { error } = await supabaseAdmin.from("dapur").insert({
      nama: "SPPG Cisauk Demo",
      alamat: "Kab. Tangerang",
      kode_dapur: "SPPG-CISAUIK",
      pin_hash: DAPUR_PIN_HASH,
    });
    if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  }

  const { data: sekolahExisting } = await supabaseAdmin
    .from("sekolah")
    .select("id")
    .eq("kode_sekolah", "SDN-CONTOH")
    .maybeSingle();

  if (!sekolahExisting) {
    const { error } = await supabaseAdmin.from("sekolah").insert({
      nama: "SDN Contoh Tangerang",
      alamat: "Kab. Tangerang",
      kode_sekolah: "SDN-CONTOH",
      pin_hash: SEKOLAH_PIN_HASH,
    });
    if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
