import { StatusBadge } from "@/components/StatusBadge";
import {
  formatSelisihJam,
  formatWaktu,
  hitungBatasKonsumsi,
} from "@/lib/format";
import { hitungStatusKonsumsi } from "@/lib/status";
import { supabase } from "@/lib/supabase";
import type { Batch } from "@/lib/types";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function ScanPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;

  const { data, error } = await supabase
    .from("batch")
    .select("*, dapur:dapur_id(nama, kode_dapur)")
    .eq("kode_qr", token)
    .maybeSingle();

  if (error || !data) {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center gap-4 bg-background p-6 text-center">
        <p className="text-sm font-semibold text-danger">
          Batch tidak ditemukan
        </p>
        <p className="text-sm text-muted">
          Token QR tidak valid atau data belum tersedia. Pastikan QR berasal dari
          batch GiziLacak.
        </p>
        <Link href="/" className="text-sm font-bold text-primary underline">
          Kembali ke beranda
        </Link>
      </main>
    );
  }

  const batch = data as Batch;
  const hasil = hitungStatusKonsumsi(
    new Date(batch.waktu_selesai_masak),
    Number(batch.ambang_batas_konsumsi_jam) || 4
  );
  const batas = hitungBatasKonsumsi(
    batch.waktu_selesai_masak,
    Number(batch.ambang_batas_konsumsi_jam) || 4
  );

  // Catat jejak scan (publik). Abaikan error agar halaman tetap tampil.
  await supabase.from("scan_log").insert({
    batch_id: batch.id,
    peran_pemindai: "publik",
  });

  const dapurRel = batch.dapur as
    | { nama?: string; kode_dapur?: string }
    | { nama?: string; kode_dapur?: string }[]
    | null
    | undefined;
  const dapurNama = Array.isArray(dapurRel)
    ? dapurRel[0]?.nama ?? "Dapur SPPG"
    : dapurRel?.nama ?? "Dapur SPPG";

  return (
    <main className="mx-auto min-h-screen max-w-md bg-background px-4 py-6">
      <header className="mb-5 text-center">
        <p className="text-sm font-extrabold">
          <span className="text-primary">Gizi</span>Lacak
        </p>
        <p className="text-xs text-muted">Hasil verifikasi batas waktu konsumsi</p>
      </header>

      <section className="rounded-[14px] bg-card p-5 text-center shadow-[var(--shadow-card)]">
        <StatusBadge status={hasil.status} label={hasil.label} size="lg" />
        <p className="mt-4 text-sm text-muted">
          Sudah {formatSelisihJam(hasil.selisihJam)} sejak selesai masak
        </p>
        <h1 className="mt-3 text-xl font-extrabold leading-snug">
          {batch.nama_komponen_menu}
        </h1>
        <p className="mt-1 text-sm text-muted">{dapurNama}</p>
      </section>

      <section className="mt-4 space-y-3 rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
        <Row label="Waktu selesai masak" value={formatWaktu(batch.waktu_selesai_masak)} />
        <Row label="Batas waktu konsumsi" value={formatWaktu(batas)} />
        <Row
          label="Ambang"
          value={`${batch.ambang_batas_konsumsi_jam} jam sejak matang`}
        />
        {batch.waktu_kirim ? (
          <Row label="Waktu kirim" value={formatWaktu(batch.waktu_kirim)} />
        ) : null}
      </section>

      <section className="mt-4 rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
        <h2 className="text-sm font-extrabold">Rincian gizi</h2>
        <div className="mt-3 grid grid-cols-2 gap-3 text-sm">
          <Stat label="Kalori" value={batch.kalori} unit="kkal" />
          <Stat label="Protein" value={batch.protein} unit="g" />
          <Stat label="Karbohidrat" value={batch.karbohidrat} unit="g" />
          <Stat label="Lemak" value={batch.lemak} unit="g" />
        </div>
        <div className="mt-4 space-y-2 text-sm">
          <p>
            <span className="font-semibold">Alergen: </span>
            {batch.daftar_alergen?.length
              ? batch.daftar_alergen.join(", ")
              : "—"}
          </p>
          <p>
            <span className="font-semibold">Bahan: </span>
            {batch.daftar_bahan?.length ? batch.daftar_bahan.join(", ") : "—"}
          </p>
        </div>
      </section>

      <p className="mt-4 text-center text-xs leading-relaxed text-muted">
        Status di atas hanya mengacu pada batas waktu konsumsi sejak selesai
        masak. Ini bukan jaminan kebersihan atau kualitas lain.
      </p>

      <Link
        href={`/lapor?token=${token}`}
        className="mt-5 flex w-full items-center justify-center rounded-xl bg-primary px-4 py-3 text-sm font-bold text-white"
      >
        Lapor diterima / ditolak / bermasalah
      </Link>
    </main>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start justify-between gap-3 border-b border-border pb-2 text-sm last:border-0 last:pb-0">
      <span className="text-muted">{label}</span>
      <span className="text-right font-semibold">{value}</span>
    </div>
  );
}

function Stat({
  label,
  value,
  unit,
}: {
  label: string;
  value: number | null;
  unit: string;
}) {
  return (
    <div className="rounded-xl bg-[#f5f6fa] px-3 py-2">
      <p className="text-xs text-muted">{label}</p>
      <p className="font-extrabold">
        {value == null ? "—" : `${value} ${unit}`}
      </p>
    </div>
  );
}
