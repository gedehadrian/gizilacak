import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin, isSupabaseAdminConfigured } from "@/lib/supabase-admin";
import { getSession } from "@/lib/session";

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  if (!isSupabaseAdminConfigured()) {
    return NextResponse.json({ ok: false, error: "Server belum dikonfigurasi." }, { status: 500 });
  }
  const session = await getSession("admin");
  if (!session) {
    return NextResponse.json({ ok: false, error: "Belum masuk." }, { status: 401 });
  }

  const { id } = await params;

  const [scanRes, lapRes] = await Promise.all([
    supabaseAdmin.from("scan_log").select("*").eq("batch_id", id).order("waktu_scan", { ascending: false }),
    supabaseAdmin.from("laporan").select("*").eq("batch_id", id).order("waktu_lapor", { ascending: false }),
  ]);

  if (scanRes.error) return NextResponse.json({ ok: false, error: scanRes.error.message }, { status: 500 });
  if (lapRes.error) return NextResponse.json({ ok: false, error: lapRes.error.message }, { status: 500 });

  return NextResponse.json({
    ok: true,
    scans: scanRes.data ?? [],
    laporans: lapRes.data ?? [],
  });
}
