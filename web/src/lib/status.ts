// Logika status batas waktu konsumsi.
// PENTING: jangan pakai kata "aman" di UI — lihat BRAINSTORM.md bagian 4.
// Gunakan "masih dalam batas waktu konsumsi" / "melewati batas waktu konsumsi".

export type StatusKonsumsi = "dalam-batas" | "mendekati-batas" | "lewat-batas";

export interface HasilStatus {
  status: StatusKonsumsi;
  label: string;
  selisihJam: number;
}

export function hitungStatusKonsumsi(
  waktuSelesaiMasak: Date,
  ambangJam: number = 4,
  sekarang: Date = new Date()
): HasilStatus {
  const selisihMs = sekarang.getTime() - waktuSelesaiMasak.getTime();
  const selisihJam = selisihMs / (1000 * 60 * 60);
  const rasio = selisihJam / ambangJam;

  if (rasio > 1) {
    return { status: "lewat-batas", label: "Melewati batas waktu konsumsi", selisihJam };
  }
  if (rasio >= 0.75) {
    return { status: "mendekati-batas", label: "Mendekati batas waktu konsumsi", selisihJam };
  }
  return { status: "dalam-batas", label: "Masih dalam batas waktu konsumsi", selisihJam };
}
