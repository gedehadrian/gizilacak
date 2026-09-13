# GiziLacak

Purwarupa SaaS verifikasi batas waktu konsumsi MBG di titik penerimaan sekolah (Kanvas Gemilang 2026). Bukan duplikasi sistem produksi BGN. Satu QR per kiriman sekolah, dapat dipindai berulang.

Aplikasi web: folder `web/` (Next.js 16, Supabase, Midtrans Snap).

## Setup

1. Salin `web/.env.example` → `web/.env.local` (lihat `docs/ENV_SETUP.md`).
2. `cd web && npm install`
3. `npm run dev` → http://localhost:3000
4. Daftar di `/daftar`, verifikasi email, `/onboarding`, pilih organisasi.
5. Beli paket contoh di `/paket` (checkout Midtrans hanya jika `MIDTRANS_SERVER_KEY` terisi).
6. Menu → batch (catat matang) → finalisasi → hubungkan sekolah → kiriman → dispatch → scan QR → receipt sekolah.

## Test

```bash
cd web
npm test
npm run build
```

## Deploy

Tidak dijalankan dari sesi ini. Bind ke `0.0.0.0:$PORT` di host Linux. Filesystem ephemeral: jangan andalkan unggahan lokal.

## Dokumentasi

- `docs/IMPLEMENTATION_STATUS.md`
- `docs/ENV_SETUP.md`
- `docs/TEST_RESULTS.md`
- `docs/MIGRATION_REPORT.md`
- `GIZILACAK_FULL_FUNCTIONAL_SPEC.md`
