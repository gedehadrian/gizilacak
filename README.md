# GiziLacak

Sistem pelacakan waktu produksi dan informasi gizi berbasis kode QR pada
kemasan program Makan Bergizi Gratis (MBG).

Satu kode QR mewakili satu pengiriman ke satu sekolah untuk satu waktu makan.
Siswa dan guru memindainya dengan kamera ponsel biasa — tanpa akun dan tanpa
memasang aplikasi — lalu melihat waktu produksi, batas waktu konsumsi, serta
gizi, bahan, dan alergen setiap komponen menu.

## Dua bagian

| Folder | Isi | Pengguna |
|---|---|---|
| `app/` | Aplikasi Flutter | Staf SPPG dan guru sekolah |
| `web/` | Next.js 16 | Siswa dan guru yang memindai QR |

Seluruh pekerjaan operasional — kebijakan konsumsi, menu, produksi, kiriman,
penerimaan, langganan — dikerjakan di aplikasi. Web tidak punya halaman login:
ia hanya melayani halaman hasil pemindaian dan dua endpoint mesin (webhook
pembayaran dan pembuatan transaksi Midtrans).

Aplikasi berbicara langsung ke Supabase di bawah Row Level Security. Aturan
penting ditegakkan di database, bukan di antarmuka: satu QR aktif per kiriman,
pengiriman menolak berangkat tanpa langganan aktif dan tanpa sisa kuota, dan
kebijakan waktu konsumsi disalin sebagai snapshot ke tiap batch sehingga
perubahan aturan tidak mengubah catatan batch yang sudah berjalan.

## Menjalankan

**Basis data.** Terapkan berkas di `web/supabase/migrations/` secara berurutan
lewat SQL Editor di dashboard Supabase.

**Web**

```bash
cp web/.env.example web/.env.local   # isi nilainya
cd web && npm install && npm run dev
```

**Aplikasi**

```bash
cp app/.env.example app/.env         # isi nilainya
cd app && flutter pub get && flutter run
```

`WEB_APP_URL` di `app/.env` menentukan alamat yang tertanam di dalam QR. Saat
menguji dengan ponsel sungguhan, isi dengan alamat yang bisa dijangkau ponsel
itu — bukan `localhost`.

## Uji

```bash
cd app && flutter analyze --no-fatal-infos && flutter test
cd web && npm test && npm run build
```

## Status

Purwarupa untuk Lomba Kreativitas dan Inovasi (Kanvas) Gemilang Kabupaten
Tangerang 2026. Bukan duplikasi sistem produksi Badan Gizi Nasional, melainkan
lapisan verifikasi mandiri di titik konsumsi.
