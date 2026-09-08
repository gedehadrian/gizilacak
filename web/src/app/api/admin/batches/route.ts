import { NextResponse } from "next/server";
import { supabaseAdmin, isSupabaseAdminConfigured } from "@/lib/supabase-admin";
import { getSession } from "@/lib/session";

export async function GET() {
  if (!isSupabaseAdminConfigured()) {
    return NextResponse.json({ ok: false, error: "Server belum dikonfigurasi." }, { status: 500 });
  }
  const session = await getSession("admin");
  if (!session) {
    return NextResponse.json({ ok: false, error: "Belum masuk." }, { status: 401 });
  }

  const { data, error } = await supabaseAdmin
    .from("batch")
    .select("*, dapur:dapur_id(nama, kode_dapur)")
    .order("created_at", { ascending: false })
    .limit(100);

  if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 });

  const batches = (data ?? []) as Array<Record<string, unknown> & { id: string }>;
  const withCounts = await Promise.all(
    batches.map(async (b) => {
      const [{ count: scanCount }, { count: laporanCount }] = await Promise.all([
        supabaseAdmin.from("scan_log").select("*", { count: "exact", head: true }).eq("batch_id", b.id),
        supabaseAdmin.from("laporan").select("*", { count: "exact", head: true }).eq("batch_id", b.id),
      ]);
      return { ...b, scan_count: scanCount ?? 0, laporan_count: laporanCount ?? 0 };
    })
  );

  return NextResponse.json({ ok: true, batches: withCounts });
}
