import { NextResponse } from "next/server";

// DEPRECATED — digantikan oleh /api/auth/admin (lihat src/app/api/auth/admin/route.ts).
// File ini sengaja tidak dihapus (device tool tidak bisa hapus file tanpa izin
// delete eksplisit dari user) tapi endpoint-nya dinonaktifkan supaya tidak jadi
// jalur belakang yang masih memakai fallback PIN default lama.
// Aman dihapus manual kapan saja oleh siapapun yang punya akses filesystem biasa
// (Cursor/Explorer), tidak perlu dipertahankan.
export async function POST() {
  return NextResponse.json(
    { ok: false, error: "Endpoint ini sudah dipindah ke /api/auth/admin" },
    { status: 410 }
  );
}
