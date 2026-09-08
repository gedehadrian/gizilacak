import { NextRequest, NextResponse } from "next/server";
import { randomBytes } from "crypto";
import { supabaseAdmin, isSupabaseAdminConfigured } from "@/lib/supabase-admin";
import { getSession } from "@/lib/session";

function numOrNull(v: unknown): number | null {
  if (v === undefined || v === null || v === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function strArray(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v.map((x) => String(x).trim()).filter(Boolean).slice(0, 50);
}

export async function GET() {
  if (!isSupabaseAdminConfigured()) {
    return NextResponse.json({ ok: false, error: "Server belum dikonfigurasi." }, { status: 500 });
  }
  const session = await getSession("dapur");
  if (!session?.id) {
    return NextResponse.json({ ok: false, error: "Belum masuk." }, { status: 401 });
  }

  const { data, error } = await supabaseAdmin
    .from("batch")
    .select("*")
    .eq("dapur_id", session.id)
    .order("created_at", { ascending: false })
    .limit(20);

  if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  return NextResponse.json({ ok: true, batches: data ?? [] });
}

export async function POST(req: NextRequest) {
  if (!isSupabaseAdminConfigured()) {
    return NextResponse.json({ ok: false, error: "Server belum dikonfigurasi." }, { status: 500 });
  }
  const session = await getSession("dapur");
  if (!session?.id) {
    return NextResponse.json({ ok: false, error: "Belum masuk." }, { status: 401 });
  }

  const body = (await req.json().catch(() => null)) as Record<string, unknown> | null;
  if (!body) {
    return NextResponse.json({ ok: false, error: "Payload tidak valid." }, { status: 400 });
  }

  const namaMenu = String(body.nama_komponen_menu || "").trim();
  if (!namaMenu) {
    return NextResponse.json({ ok: false, error: "Nama komponen menu wajib diisi." }, { status: 400 });
  }

  const waktuSelesai = body.waktu_selesai_masak ? new Date(String(body.waktu_selesai_masak)) : null;
  if (!waktuSelesai || Number.isNaN(waktuSelesai.getTime())) {
    return NextResponse.json({ ok: false, error: "Waktu selesai masak tidak valid." }, { status: 400 });
  }

  const waktuKirimRaw = body.waktu_kirim ? new Date(String(body.waktu_kirim)) : null;
  const ambang = Number(body.ambang_batas_konsumsi_jam) || 4;
  if (ambang <= 0 || ambang > 48) {
    return NextResponse.json({ ok: false, error: "Ambang batas konsumsi tidak masuk akal (0-48 jam)." }, { status: 400 });
  }

  const token = randomBytes(12).toString("hex");

  const payload = {
    dapur_id: session.id,
    nama_komponen_menu: namaMenu.slice(0, 200),
    waktu_selesai_masak: waktuSelesai.toISOString(),
    waktu_kirim: waktuKirimRaw && !Number.isNaN(waktuKirimRaw.getTime()) ? waktuKirimRaw.toISOString() : null,
    kalori: numOrNull(body.kalori),
    protein: numOrNull(body.protein),
    karbohidrat: numOrNull(body.karbohidrat),
    lemak: numOrNull(body.lemak),
    daftar_alergen: strArray(body.daftar_alergen),
    daftar_bahan: strArray(body.daftar_bahan),
    ambang_batas_konsumsi_jam: ambang,
    kode_qr: token,
    status: "dikirim",
  };

  const { data, error } = await supabaseAdmin.from("batch").insert(payload).select().single();
  if (error) return NextResponse.json({ ok: false, error: error.message }, { status: 500 });

  return NextResponse.json({ ok: true, batch: data });
}
