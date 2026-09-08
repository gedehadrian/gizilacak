import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin, isSupabaseAdminConfigured } from "@/lib/supabase-admin";
import { getSession } from "@/lib/session";

const JENIS_VALID = ["diterima", "ditolak", "dilaporkan_bermasalah"] as const;

export async function GET() {
  if (!isSupabaseAdminConfigured()) {
    return NextResponse.json({ ok: false, error: "Server belum dikonfigurasi." }, { status: 500 });
  }
  const session = await getSession("sekolah");
  if (!session?.id) {
    return NextResponse.json({ ok: false, error: "Belum masuk." }, { status: 401 });
  }

  const { data, error } = await supabaseAdmin
    .from("laporan")
    .select("*")
    .eq("sekolah_id", session.id)
    .order("waktu_lapor", { ascending: false })
    .limit(10);

  if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  return NextResponse.json({ ok: true, laporan: data ?? [] });
}

export async function POST(req: NextRequest) {
  if (!isSupabaseAdminConfigured()) {
    return NextResponse.json({ ok: false, error: "Server belum dikonfigurasi." }, { status: 500 });
  }
  const session = await getSession("sekolah");
  if (!session?.id) {
    return NextResponse.json({ ok: false, error: "Belum masuk." }, { status: 401 });
  }

  const body = (await req.json().catch(() => null)) as Record<string, unknown> | null;
  const token = String(body?.token || "").trim();
  const jenis = String(body?.jenis || "");

  if (!token || !JENIS_VALID.includes(jenis as (typeof JENIS_VALID)[number])) {
    return NextResponse.json({ ok: false, error: "Data laporan tidak lengkap/valid." }, { status: 400 });
  }

  const { data: batch, error: batchErr } = await supabaseAdmin
    .from("batch")
    .select("id")
    .eq("kode_qr", token)
    .maybeSingle();

  if (batchErr) return NextResponse.json({ ok: false, error: batchErr.message }, { status: 500 });
  if (!batch) return NextResponse.json({ ok: false, error: "Batch tidak ditemukan untuk token ini." }, { status: 404 });

  const { error: insErr } = await supabaseAdmin.from("laporan").insert({
    batch_id: batch.id,
    sekolah_id: session.id,
    jenis,
    catatan: body?.catatan ? String(body.catatan).trim().slice(0, 2000) : null,
    nama_pelapor: body?.nama_pelapor ? String(body.nama_pelapor).trim().slice(0, 200) : null,
  });
  if (insErr) return NextResponse.json({ ok: false, error: insErr.message }, { status: 500 });

  if (jenis === "diterima" || jenis === "ditolak") {
    await supabaseAdmin.from("batch").update({ status: jenis }).eq("id", batch.id);
  }

  return NextResponse.json({ ok: true });
}
