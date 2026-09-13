String mapPgError(String message) {
  const table = <String, String>{
    'not_authenticated': 'Belum masuk.',
    'forbidden': 'Tidak berhak.',
    'batch_not_found': 'Batch tidak ditemukan.',
    'batch_not_draft': 'Batch bukan draf.',
    'components_incomplete': 'Semua komponen wajib punya waktu matang.',
    'delivery_not_found': 'Kiriman tidak ditemukan.',
    'delivery_not_draft': 'Kiriman bukan draf.',
    'school_not_linked': 'Sekolah belum terhubung aktif.',
    'no_entitlement': 'Langganan aktif tidak ditemukan. Dispatch diblokir.',
    'quota_exceeded': 'Kuota kiriman periode ini habis.',
    'over_allocated': 'Alokasi porsi melebihi produksi.',
    'batch_not_ready': 'Komponen berasal dari batch yang belum final.',
    'item_not_found': 'Item kiriman tidak ditemukan.',
    'delivery_not_dispatched': 'Kiriman belum dikirim.',
    'portions_mismatch': 'Jumlah diterima + ditolak harus sama dengan porsi kiriman.',
    'reason_required': 'Alasan wajib jika ada porsi ditolak.',
    'component_not_found': 'Komponen batch tidak ditemukan.',
    'invalid_portions': 'Jumlah porsi tidak valid.',
    'pilot_reason_required': 'Tulis alasan pemberian pilot.',
    'plan_version_not_found': 'Versi paket tidak ditemukan.',
    'plan_unpublished': 'Versi paket belum diterbitkan.',
    'tenant_not_found': 'SPPG tidak ditemukan.',
    'invalid_period': 'Masa berlaku pilot antara 1 dan 24 bulan.',
    'invalid_purpose': 'Jenis tagihan tidak dikenal.',
    'plan_inactive': 'Paket ini sedang tidak dijual.',
  };
  for (final entry in table.entries) {
    if (message.contains(entry.key)) return entry.value;
  }
  if (message.contains('duplicate key')) {
    return 'Data duplikat. Coba kode lain atau muat ulang.';
  }
  return message.replaceAll('_', ' ');
}
