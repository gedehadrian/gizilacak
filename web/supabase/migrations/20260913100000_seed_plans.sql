-- Tiga paket awal beserta versi pertamanya yang langsung terbit.
--
-- Batas kiriman disusun dari cara kerja sebenarnya: satu kiriman = satu
-- pengiriman ke satu sekolah untuk satu waktu makan. Dengan sekitar 22 hari
-- sekolah per bulan, SPPG yang melayani 15 sekolah membutuhkan ±330 kiriman,
-- jadi angkanya dibulatkan ke atas agar ada ruang untuk kiriman tambahan dan
-- pengiriman ulang.
--
-- HARGA DI BAWAH INI MASIH PERKIRAAN. Sesuaikan sebelum dipakai ke pelanggan
-- sungguhan — cukup ubah nilainya di sini lalu terbitkan versi baru dari
-- Konsol platform, karena harga selalu diambil server dari katalog, bukan dari
-- aplikasi.
--
-- Aman dijalankan berulang: paket dikunci `code`, versi dikunci (plan_id, version).

-- Katalog lama memakai kode `sandbox-contoh` untuk paket yang sebenarnya paket
-- produk. Dinaikkan lebih dulu ke `standar` supaya tidak bertabrakan dengan
-- baris di bawah — `plans.code` unik, jadi menyisipkan `standar` sementara
-- baris lama masih ada akan menggagalkan migrasi ini atau migrasi berikutnya,
-- tergantung urutan jalannya.
update public.plans
set code = 'standar'
where code = 'sandbox-contoh'
  and not exists (select 1 from public.plans where code = 'standar');

insert into public.plans (code, name, description, active) values
  (
    'dasar',
    'Dasar',
    'Untuk SPPG yang melayani beberapa sekolah terdekat.',
    true
  ),
  (
    'standar',
    'Standar',
    'Untuk SPPG satu kecamatan dengan operasional harian penuh.',
    true
  ),
  (
    'lanjutan',
    'Lanjutan',
    'Untuk SPPG besar dengan banyak sekolah dan tim bertingkat.',
    true
  )
on conflict (code) do nothing;

insert into public.plan_versions (
  plan_id, version, price_rp, period_months,
  staff_limit, school_limit, delivery_limit, published_at
)
select p.id, v.version, v.price_rp, 1,
       v.staff_limit, v.school_limit, v.delivery_limit, now()
from (values
  ('dasar',     1,   250000,  10,  5,  150),
  ('standar',   1,   650000,  25, 15,  400),
  ('lanjutan',  1,  1500000,  60, 40, 1000)
) as v(code, version, price_rp, staff_limit, school_limit, delivery_limit)
join public.plans p on p.code = v.code
on conflict (plan_id, version) do nothing;
