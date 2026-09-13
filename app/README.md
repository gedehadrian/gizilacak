# GiziLacak — aplikasi staf

Aplikasi Flutter untuk SPPG dan sekolah. Tampilan Cupertino (iOS). Siswa **tidak** memakai aplikasi ini: mereka memindai QR di browser (`/scan/[token]`).

Satu QR = satu pengiriman ke satu sekolah. Label yang sama boleh dicetak ulang di banyak dus. Bukan unik per porsi.

## Prasyarat

- Flutter 3.41+
- Akun Supabase yang sama dengan `web/` (anon key publik saja)
- Langganan aktif di situs web sebelum dispatch kiriman

## Konfigurasi

```bash
cp .env.example .env
```

Isi hanya variabel publik:

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
WEB_APP_URL=http://localhost:3000
```

Jangan taruh `SERVICE_ROLE` di aplikasi ini.

`WEB_APP_URL` dipakai untuk isi QR. Di HP fisik, ganti ke URL publik situs (bukan `localhost`). Emulator Android memakai `10.0.2.2:3000` jika situs jalan di mesin host.

## Menjalankan

```bash
flutter pub get
flutter run
```

iOS Simulator paling dekat dengan desain. Di Windows: `flutter run -d windows` atau `-d chrome`. Android memakai tema Cupertino yang sama.

## Alur demo

1. Daftar / masuk
2. Buat SPPG dan/atau sekolah
3. Dari SPPG: hubungkan sekolah milik akun yang sama
4. Dari sekolah: terima undangan
5. Produksi → tandai matang → finalkan
6. Kiriman draf → dispatch (butuh langganan) → tampil QR
7. Sekolah isi diterima / ditolak

Billing, invoice, dan Midtrans tetap di web.

## Struktur

```
lib/
  theme/apple.dart     token warna & komponen
  state/session.dart   auth + organisasi aktif
  data/api.dart        Supabase + RPC
  features/auth|org|sppg|school|account
```
