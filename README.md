# GiziLacak — Proyek Kanvas Gemilang 2026

Sistem verifikasi dan ketertelusuran batas waktu konsumsi MBG berbasis QR di sekolah Kabupaten Tangerang.

Status: **tahap bangun cepat (sprint 5 hari)** menuju deadline pendaftaran **13 September 2026**.

## Isi folder ini

- `BRAINSTORM.md` — hasil brainstorm ide: positioning vs ANUSA & sistem BGN yang sudah ada, pembeda, risiko, dan keputusan yang sudah diambil.
- `PLAN.md` — rencana eksekusi 5 hari + pembagian kerja Claude (scaffolding & dokumen) vs Cursor (iterasi UI/fitur + Figma dev kit).
- `docs/competition-requirements.md` — ringkasan ketentuan lomba Kanvas Gemilang 2026 (syarat, sistematika proposal, bobot penilaian, jadwal, hadiah).
- `docs/data-model.md` — model data & arsitektur sistem.
- `docs/design-system.md` — acuan desain (Figma DashStack Admin Dashboard UI Kit) dan cara adaptasinya ke kebutuhan GiziLacak.
- `web/` — aplikasi Next.js (dibuat di langkah berikutnya).

## Idenya secara singkat

GiziLacak adalah **lapisan verifikasi independen** di titik penerimaan makanan MBG di sekolah — bukan sistem pelaporan produksi baru yang menduplikasi SIPGN Produksi/Reviu MBG/Radar MBG milik BGN. Staf SPPG mencatat waktu matang & kirim → sistem terbitkan satu QR per paket/batch → petugas sekolah memindai saat diterima → halaman publik menampilkan waktu matang, batas konsumsi, dan status ("masih dalam batas waktu konsumsi", bukan "aman") → guru mencatat diterima/ditolak/dilaporkan → riwayat dapat ditelusuri per batch saat ada insiden.

Lihat `BRAINSTORM.md` untuk detail lengkap.
