export type StatusKonsumsi = "dalam-batas" | "mendekati-batas" | "lewat-batas";

export interface Dapur {
  id: string;
  nama: string;
  alamat: string | null;
  kode_dapur: string;
  pin_hash: string;
}

export interface Sekolah {
  id: string;
  nama: string;
  alamat: string | null;
  kode_sekolah: string;
  pin_hash: string;
}

export interface Batch {
  id: string;
  dapur_id: string;
  nama_komponen_menu: string;
  waktu_selesai_masak: string;
  waktu_kirim: string | null;
  kalori: number | null;
  protein: number | null;
  karbohidrat: number | null;
  lemak: number | null;
  daftar_alergen: string[] | null;
  daftar_bahan: string[] | null;
  ambang_batas_konsumsi_jam: number;
  kode_qr: string;
  status: string;
  created_at: string;
  dapur?: Dapur | null;
}

export interface ScanLog {
  id: string;
  batch_id: string;
  waktu_scan: string;
  peran_pemindai: string | null;
}

export interface Laporan {
  id: string;
  batch_id: string;
  sekolah_id: string | null;
  waktu_lapor: string;
  jenis: "diterima" | "ditolak" | "dilaporkan_bermasalah" | string;
  catatan: string | null;
  nama_pelapor: string | null;
}
