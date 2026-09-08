-- GiziLacak — skema database (Supabase/Postgres)
-- Lihat docs/data-model.md di root proyek untuk penjelasan tiap entitas.
--
-- CARA JALANKAN: tempel seluruh isi file ini di Supabase Dashboard > SQL Editor > Run.
-- Aman dijalankan berkali-kali (semua statement idempotent).

create table if not exists dapur (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  alamat text,
  kode_dapur text unique not null,
  pin_hash text not null,
  created_at timestamptz default now()
);

create table if not exists sekolah (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  alamat text,
  kode_sekolah text unique not null,
  pin_hash text not null,
  created_at timestamptz default now()
);

create table if not exists batch (
  id uuid primary key default gen_random_uuid(),
  dapur_id uuid references dapur(id) not null,
  nama_komponen_menu text not null,
  waktu_selesai_masak timestamptz not null,
  waktu_kirim timestamptz,
  kalori numeric,
  protein numeric,
  karbohidrat numeric,
  lemak numeric,
  daftar_alergen text[],
  daftar_bahan text[],
  ambang_batas_konsumsi_jam numeric not null default 4,
  kode_qr text unique not null, -- token unik untuk URL /scan/[token]
  status text not null default 'dibuat', -- dibuat | dikirim | diterima | ditolak
  created_at timestamptz default now()
);

create table if not exists scan_log (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid references batch(id) not null,
  waktu_scan timestamptz default now(),
  peran_pemindai text -- siswa | guru | publik
);

create table if not exists laporan (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid references batch(id) not null,
  sekolah_id uuid references sekolah(id),
  waktu_lapor timestamptz default now(),
  jenis text not null, -- diterima | ditolak | dilaporkan_bermasalah
  catatan text,
  nama_pelapor text
);

-- Index untuk pencarian cepat saat penelusuran batch
create index if not exists idx_batch_dapur on batch(dapur_id);
create index if not exists idx_scanlog_batch on scan_log(batch_id);
create index if not exists idx_laporan_batch on laporan(batch_id);
create index if not exists idx_batch_kode_qr on batch(kode_qr);
create index if not exists idx_laporan_sekolah on laporan(sekolah_id);

-- =====================================================================
-- ROW LEVEL SECURITY — DIKUNCI PENUH UNTUK ANON/CLIENT.
--
-- Seluruh baca/tulis aplikasi (halaman staf, scan publik, laporan guru,
-- dashboard admin) sekarang lewat API routes Next.js di server, yang
-- memakai SUPABASE_SERVICE_ROLE_KEY (lihat src/lib/supabase-admin.ts).
-- Service role key MEMBYPASS RLS sepenuhnya, jadi kebijakan di bawah ini
-- sengaja TIDAK memberi akses apapun ke role `anon`/`authenticated` —
-- browser tidak pernah bicara langsung ke Supabase.
--
-- Kalau sebelumnya kamu sudah menjalankan versi lama schema ini (yang
-- policy-nya "for all using (true)"), jalankan ulang file ini — DROP
-- POLICY di bawah akan membersihkan policy lama itu sebelum RLS aktif
-- penuh tanpa policy anon sama sekali.
-- =====================================================================

alter table dapur enable row level security;
alter table sekolah enable row level security;
alter table batch enable row level security;
alter table scan_log enable row level security;
alter table laporan enable row level security;

drop policy if exists "dapur_all_anon" on dapur;
drop policy if exists "sekolah_all_anon" on sekolah;
drop policy if exists "batch_all_anon" on batch;
drop policy if exists "scan_log_all_anon" on scan_log;
drop policy if exists "laporan_all_anon" on laporan;

-- Tidak ada policy anon yang dibuat di sini secara sengaja — default Postgres RLS
-- adalah "deny all" ketika RLS aktif tanpa policy. Service role selalu bisa akses
-- (service role membypass RLS by design di Supabase, bukan lewat policy).

-- Seed demo (PIN dapur=1234, PIN sekolah=5678 — SHA-256).
-- Catatan: dijalankan lagi di sini idempotent, tapi cara resmi menambah data
-- demo setelah deploy adalah lewat `npm run seed` (lihat scripts/seed.mjs),
-- bukan lagi otomatis dari halaman manapun.
insert into dapur (nama, alamat, kode_dapur, pin_hash)
select 'SPPG Cisauk Demo', 'Kab. Tangerang', 'SPPG-CISAUIK', '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4'
where not exists (select 1 from dapur where kode_dapur = 'SPPG-CISAUIK');

insert into sekolah (nama, alamat, kode_sekolah, pin_hash)
select 'SDN Contoh Tangerang', 'Kab. Tangerang', 'SDN-CONTOH', 'f8638b979b2f4f793ddb6dbd197e0ee25a7a6ea32b0ae22f5e3c5d119d839e75'
where not exists (select 1 from sekolah where kode_sekolah = 'SDN-CONTOH');
