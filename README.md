# GiziLacak — Proyek Kanvas Gemilang 2026

Sistem verifikasi dan ketertelusuran batas waktu konsumsi MBG berbasis QR di sekolah Kabupaten Tangerang.

Status: **aplikasi fungsional siap demo lokal** (sprint menuju deadline pendaftaran **13 September 2026**). Deploy Vercel menunggu login akun.

## Isi folder ini

- `BRAINSTORM.md` — hasil brainstorm ide: positioning vs ANUSA & sistem BGN yang sudah ada, pembeda, risiko, dan keputusan yang sudah diambil.
- `PLAN.md` — rencana eksekusi 5 hari + progress build.
- `docs/competition-requirements.md` — ringkasan ketentuan lomba Kanvas Gemilang 2026.
- `docs/data-model.md` — model data & arsitektur sistem.
- `docs/design-system.md` — acuan desain (Figma DashStack) dan adaptasinya.
- `web/` — aplikasi Next.js (App Router + Supabase + Tailwind).

## Idenya secara singkat

GiziLacak adalah **lapisan verifikasi independen** di titik penerimaan makanan MBG di sekolah — bukan sistem pelaporan produksi baru yang menduplikasi SIPGN Produksi/Reviu MBG/Radar MBG milik BGN. Staf SPPG mencatat waktu matang & kirim → sistem terbitkan satu QR per paket/batch → petugas sekolah memindai saat diterima → halaman publik menampilkan waktu matang, batas konsumsi, dan status ("masih dalam batas waktu konsumsi", bukan "aman") → guru mencatat diterima/ditolak/dilaporkan → riwayat dapat ditelusuri per batch saat ada insiden.

## Cara menjalankan (lokal)

```bash
cd web
cp .env.local.example .env.local   # lalu isi kredensial Supabase
npm install
npm run dev
```

Buka http://localhost:3000

### PIN demo
| Peran | PIN |
|---|---|
| Staf SPPG (dapur) | `1234` |
| Guru/UKS (sekolah) | `5678` |
| Admin dashboard | `2468` |

### Alur demo cepat
1. `/staf` → login PIN dapur → isi form batch → QR muncul.
2. Buka URL `/scan/[token]` (atau scan QR dari HP di jaringan yang sama / setelah deploy).
3. `/lapor` → login PIN sekolah → kirim diterima/ditolak/bermasalah.
4. `/admin` → login PIN admin → lihat tabel + detail timeline.

## Env yang dibutuhkan

Lihat `web/.env.local.example`:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `NEXT_PUBLIC_DEFAULT_AMBANG_JAM`
- `ADMIN_PIN` (server-side)

Setelah skema siap, jalankan isi `web/supabase/schema.sql` di SQL Editor Supabase (atau lewat MCP/CLI).
