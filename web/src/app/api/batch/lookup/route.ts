import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin, isSupabaseAdminConfigured } from "@/lib/supabase-admin";
import { getSession } from "@/lib/session";

export async function GET(req: NextRequest) {
  if (!isSupabaseAdminConfigured()) {
    return NextResponse.json({ ok: false, error: "Server belum dikonfigurasi." }, { status: 500 });
  }
  const session = await getSession("sekolah");
  if (!session?.id) {
    return NextResponse.json({ ok: false, error: "Belum masuk." }, { status: 401 });
  }

  const token = req.nextUrl.searchParams.get("token")?.trim();
  if (!token) {
    return NextResponse.json({ ok: false, error: "Token wajib diisi." }, { status: 400 });
  }

  const { data, error } = await supabaseAdmin
    .from("batch")
    .select("id, nama_komponen_menu, waktu_selesai_masak, kode_qr")
    .eq("kode_qr", token)
    .maybeSingle();

  if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  return NextResponse.json({ ok: true, batch: data ?? null });
}
