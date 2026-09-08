import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin, isSupabaseAdminConfigured } from "@/lib/supabase-admin";
import { hashPinSyncNode } from "@/lib/pin";
import { setSessionCookie } from "@/lib/session";
import { checkRateLimit, clientIp } from "@/lib/rate-limit";

export async function POST(req: NextRequest) {
  if (!isSupabaseAdminConfigured()) {
    return NextResponse.json(
      { ok: false, error: "Server belum dikonfigurasi (SUPABASE_SERVICE_ROLE_KEY kosong)." },
      { status: 500 }
    );
  }

  if (!checkRateLimit(`auth:sekolah:${clientIp(req)}`, 8, 5 * 60 * 1000)) {
    return NextResponse.json(
      { ok: false, error: "Terlalu banyak percobaan. Coba lagi beberapa menit lagi." },
      { status: 429 }
    );
  }

  const body = (await req.json().catch(() => null)) as { pin?: string } | null;
  const pin = body?.pin?.trim() ?? "";
  if (!pin) {
    return NextResponse.json({ ok: false, error: "PIN wajib diisi" }, { status: 400 });
  }

  const pinHash = hashPinSyncNode(pin);
  const { data, error } = await supabaseAdmin
    .from("sekolah")
    .select("id, nama, kode_sekolah")
    .eq("pin_hash", pinHash)
    .maybeSingle();

  if (error) {
    return NextResponse.json({ ok: false, error: "Gagal memverifikasi PIN." }, { status: 500 });
  }
  if (!data) {
    return NextResponse.json({ ok: false, error: "PIN sekolah tidak cocok." }, { status: 401 });
  }

  await setSessionCookie("sekolah", { id: data.id, nama: data.nama, kode: data.kode_sekolah });
  return NextResponse.json({ ok: true, sekolah: data });
}
