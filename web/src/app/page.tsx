import Link from "next/link";

export default function Home() {
  return (
    <main className="min-h-screen bg-background">
      <div className="relative overflow-hidden">
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(72,128,255,0.18),transparent_45%),radial-gradient(circle_at_bottom_left,rgba(0,182,155,0.12),transparent_40%)]"
        />
        <header className="relative mx-auto flex max-w-5xl items-center justify-between px-4 py-5 sm:px-6">
          <p className="text-xl font-extrabold tracking-tight">
            <span className="text-primary">Gizi</span>
            <span className="text-foreground">Lacak</span>
          </p>
          <nav className="flex gap-2 text-xs font-semibold sm:text-sm">
            <Link href="/staf" className="rounded-xl px-3 py-2 hover:bg-card">
              Staf
            </Link>
            <Link href="/lapor" className="rounded-xl px-3 py-2 hover:bg-card">
              Guru
            </Link>
            <Link
              href="/admin"
              className="rounded-xl bg-primary px-3 py-2 text-white"
            >
              Admin
            </Link>
          </nav>
        </header>

        <section className="relative mx-auto max-w-5xl px-4 pb-16 pt-8 sm:px-6 sm:pt-14">
          <p className="text-xs font-bold uppercase tracking-[0.18em] text-primary">
            Kanvas Gemilang 2026 · Kab. Tangerang
          </p>
          <h1 className="mt-3 max-w-3xl text-3xl font-extrabold leading-tight tracking-tight sm:text-5xl">
            Verifikasi batas waktu konsumsi MBG di titik penerimaan sekolah
          </h1>
          <p className="mt-4 max-w-2xl text-sm leading-relaxed text-muted sm:text-base">
            GiziLacak adalah lapisan verifikasi independen berbasis QR — bukan
            duplikasi sistem produksi BGN. Staf SPPG mencatat waktu matang,
            sekolah memindai QR, status dihitung otomatis, dan riwayat bisa
            ditelusuri saat ada dugaan insiden.
          </p>
          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <Link
              href="/staf"
              className="rounded-xl bg-primary px-5 py-3 text-center text-sm font-bold text-white"
            >
              Mulai sebagai Staf SPPG
            </Link>
            <Link
              href="/lapor"
              className="rounded-xl border border-border bg-card px-5 py-3 text-center text-sm font-bold"
            >
              Laporkan sebagai Guru/UKS
            </Link>
          </div>
        </section>
      </div>

      <section className="mx-auto grid max-w-5xl gap-4 px-4 pb-16 sm:grid-cols-3 sm:px-6">
        <Step
          n="01"
          title="Catat & terbitkan QR"
          body="Staf SPPG input waktu selesai masak, gizi, alergen, lalu sistem terbitkan QR unik per batch."
        />
        <Step
          n="02"
          title="Scan di sekolah"
          body="Petugas/siswa buka QR dari kamera HP. Status hijau/kuning/merah muncul tanpa install aplikasi."
        />
        <Step
          n="03"
          title="Lapor & telusuri"
          body="Guru mencatat diterima/ditolak/bermasalah. Admin menelusuri timeline scan + laporan per batch."
        />
      </section>

      <section className="border-y border-border bg-card">
        <div className="mx-auto max-w-5xl px-4 py-10 sm:px-6">
          <h2 className="text-xl font-extrabold">Status yang ditampilkan</h2>
          <p className="mt-2 max-w-2xl text-sm text-muted">
            Label mengikuti selisih waktu terhadap ambang konsumsi (default 4
            jam). Tidak memakai istilah yang menyesatkan.
          </p>
          <div className="mt-6 grid gap-3 sm:grid-cols-3">
            <Pill
              color="bg-success-bg text-success"
              title="Masih dalam batas waktu konsumsi"
            />
            <Pill
              color="bg-warning-bg text-warning"
              title="Mendekati batas waktu konsumsi"
            />
            <Pill
              color="bg-danger-bg text-danger"
              title="Melewati batas waktu konsumsi"
            />
          </div>
        </div>
      </section>

      <footer className="mx-auto max-w-5xl px-4 py-10 text-center text-xs text-muted sm:px-6">
        GiziLacak · Purwarupa untuk Lomba Kanvas Gemilang 2026 (Bappeda Kab.
        Tangerang)
      </footer>
    </main>
  );
}

function Step({
  n,
  title,
  body,
}: {
  n: string;
  title: string;
  body: string;
}) {
  return (
    <article className="rounded-[14px] bg-card p-5 shadow-[var(--shadow-card)]">
      <p className="text-xs font-bold text-primary">{n}</p>
      <h3 className="mt-2 text-base font-extrabold">{title}</h3>
      <p className="mt-2 text-sm leading-relaxed text-muted">{body}</p>
    </article>
  );
}

function Pill({ color, title }: { color: string; title: string }) {
  return (
    <div className={`rounded-2xl px-4 py-4 text-sm font-bold ${color}`}>
      {title}
    </div>
  );
}
