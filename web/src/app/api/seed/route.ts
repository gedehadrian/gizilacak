import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

const DAPUR_PIN_HASH =
  "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4"; // 1234
const SEKOLAH_PIN_HASH =
  "f8638b979b2f4f793ddb6dbd197e0ee25a7a6ea32b0ae22f5e3c5d119d839e75"; // 5678

export async function POST() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) {
    return NextResponse.json({ error: "Supabase belum dikonfigurasi" }, { status: 500 });
  }

  const supabase = createClient(url, key);

  const { data: dapurExisting } = await supabase
    .from("dapur")
    .select("id")
    .eq("kode_dapur", "SPPG-CISAUIK")
    .maybeSingle();

  if (!dapurExisting) {
    const { error } = await supabase.from("dapur").insert({
      nama: "SPPG Cisauk Demo",
      alamat: "Kab. Tangerang",
      kode_dapur: "SPPG-CISAUIK",
      pin_hash: DAPUR_PIN_HASH,
    });
    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
  }

  const { data: sekolahExisting } = await supabase
    .from("sekolah")
    .select("id")
    .eq("kode_sekolah", "SDN-CONTOH")
    .maybeSingle();

  if (!sekolahExisting) {
    const { error } = await supabase.from("sekolah").insert({
      nama: "SDN Contoh Tangerang",
      alamat: "Kab. Tangerang",
      kode_sekolah: "SDN-CONTOH",
      pin_hash: SEKOLAH_PIN_HASH,
    });
    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
  }

  return NextResponse.json({ ok: true });
}
