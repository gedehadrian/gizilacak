import { StatusBadge } from "@/components/StatusBadge";
import { ScanEvent } from "@/components/ScanEvent";
import { formatWaktu } from "@/lib/format";
import { isAdminConfigured } from "@/lib/supabase/admin";
import { loadPublicScan } from "@/modules/delivery/public-scan";
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function ScanPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  if (!isAdminConfigured()) {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center gap-3 p-6 text-center">
        <p className="font-bold">Data belum dapat diverifikasi</p>
        <p className="text-sm text-muted">Lookup publik belum dikonfigurasi di server.</p>
      </main>
    );
  }

  const dto = await loadPublicScan(token);
  if (!dto.valid) {
    return (
      <main className="mx-auto flex min-h-screen max-w-md flex-col items-center justify-center gap-4 bg-background p-6 text-center">
        <p className="text-sm font-semibold text-danger">{dto.message || "QR tidak valid"}</p>
        <Link href="/" className="text-sm font-bold text-primary underline">
          Kembali ke beranda
        </Link>
      </main>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-md bg-background px-4 py-6">
      <ScanEvent token={token} />
      <header className="mb-5 text-center">
        <p className="text-sm font-extrabold">
          <span className="text-primary">Gizi</span>Lacak
        </p>
        <p className="text-xs text-muted">Verifikasi batas waktu konsumsi · satu QR per kiriman sekolah</p>
      </header>
      <section className="rounded-[14px] bg-card p-5 text-center shadow-[var(--shadow-card)]">
        <StatusBadge status={dto.overall.status} label={dto.overall.label} size="lg" />
        <p className="mt-4 text-sm text-muted">
          {dto.delivery?.sppg_name} {dto.delivery?.sppg_code ? `(${dto.delivery.sppg_code})` : ""}
        </p>
        <p className="text-sm font-semibold">{dto.delivery?.code}</p>
        {dto.delivery?.school_name ? <p className="text-xs text-muted">Tujuan: {dto.delivery.school_name}</p> : null}
        {dto.message ? <p className="mt-2 text-xs text-muted">{dto.message}</p> : null}
      </section>
      <section className="mt-4 space-y-3">
        {dto.components.map((c) => (
          <article key={c.name + (c.cooked_at ?? "")} className="rounded-[14px] bg-card p-4 shadow-[var(--shadow-card)]">
            <div className="flex items-start justify-between gap-2">
              <h2 className="font-extrabold">{c.name}</h2>
              <StatusBadge status={c.status.status} label={c.status.label} />
            </div>
            <dl className="mt-3 space-y-1 text-sm">
              <Row k="Matang" v={c.cooked_at ? formatWaktu(c.cooked_at) : "belum tersedia"} />
              <Row k="Batas konsumsi" v={c.consume_by ? formatWaktu(c.consume_by) : "belum tersedia"} />
              <Row k="Energi" v={c.kcal == null ? "belum tersedia" : `${c.kcal} kkal`} />
              <Row k="Protein" v={c.protein_g == null ? "belum tersedia" : `${c.protein_g} g`} />
              <Row k="Karbohidrat" v={c.carbs_g == null ? "belum tersedia" : `${c.carbs_g} g`} />
              <Row k="Lemak" v={c.fat_g == null ? "belum tersedia" : `${c.fat_g} g`} />
              <Row k="Bahan" v={c.ingredients.length ? c.ingredients.join(", ") : "belum tersedia"} />
              <Row k="Alergen" v={c.allergen_state === "unknown" ? "belum tersedia" : c.allergens.join(", ") || "tidak dicantumkan"} />
            </dl>
          </article>
        ))}
      </section>
      <p className="mt-4 text-center text-xs text-muted">
        Diambil {formatWaktu(dto.fetched_at)} · acuan server {formatWaktu(dto.server_now)}. Bukan jaminan bebas kontaminasi.
      </p>
      {dto.kind === "delivery" && dto.delivery?.status === "dispatched" ? (
        <p className="mt-4 text-center text-sm">
          Petugas sekolah:{" "}
          <Link href={`/masuk?next=/sekolah`} className="font-bold text-primary">
            masuk untuk penerimaan / laporan
          </Link>
        </p>
      ) : null}
    </main>
  );
}

function Row({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-muted">{k}</dt>
      <dd className="text-right font-semibold">{v}</dd>
    </div>
  );
}
