-- Katalog tampil sebagai paket produk, bukan lingkungan uji.
update public.plans
set
  code = 'standar',
  name = 'GiziLacak Standar',
  description = 'Langganan bulanan untuk produksi, kiriman sekolah, dan verifikasi penerimaan.'
where code = 'sandbox-contoh';
