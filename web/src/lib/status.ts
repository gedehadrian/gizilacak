export type StatusKonsumsi =
  | "dalam-batas"
  | "mendekati-batas"
  | "lewat-batas"
  | "belum-terverifikasi";

export interface HasilStatus {
  status: StatusKonsumsi;
  label: string;
  warningAt: Date | null;
  consumeBy: Date | null;
  serverNow: Date;
}

export function hitungStatusKonsumsiKomponen(
  cookedAt: Date | string | null,
  consumeBy: Date | string | null,
  warningMinutes: number | null,
  serverNow: Date = new Date()
): HasilStatus {
  if (!cookedAt || !consumeBy || warningMinutes == null || warningMinutes <= 0) {
    return {
      status: "belum-terverifikasi",
      label: "Data belum dapat diverifikasi",
      warningAt: null,
      consumeBy: consumeBy ? new Date(consumeBy) : null,
      serverNow,
    };
  }
  const by = new Date(consumeBy);
  const warningAt = new Date(by.getTime() - warningMinutes * 60_000);
  if (Number.isNaN(by.getTime()) || Number.isNaN(warningAt.getTime())) {
    return {
      status: "belum-terverifikasi",
      label: "Data belum dapat diverifikasi",
      warningAt: null,
      consumeBy: null,
      serverNow,
    };
  }
  if (serverNow.getTime() >= by.getTime()) {
    return { status: "lewat-batas", label: "Melewati batas waktu konsumsi", warningAt, consumeBy: by, serverNow };
  }
  if (serverNow.getTime() >= warningAt.getTime()) {
    return { status: "mendekati-batas", label: "Mendekati batas waktu konsumsi", warningAt, consumeBy: by, serverNow };
  }
  return { status: "dalam-batas", label: "Masih dalam batas waktu konsumsi", warningAt, consumeBy: by, serverNow };
}

export function statusPalingMendesak(list: HasilStatus[]): HasilStatus {
  if (list.length === 0 || list.some((x) => x.status === "belum-terverifikasi")) {
    return {
      status: "belum-terverifikasi",
      label: "Data belum dapat diverifikasi",
      warningAt: null,
      consumeBy: null,
      serverNow: list[0]?.serverNow ?? new Date(),
    };
  }
  const order: StatusKonsumsi[] = ["lewat-batas", "mendekati-batas", "dalam-batas"];
  for (const s of order) {
    const hit = list.find((x) => x.status === s);
    if (hit) return hit;
  }
  return list[0];
}

/** Kompatibilitas halaman lama: jam sejak matang vs ambang. */
export function hitungStatusKonsumsi(
  waktuSelesaiMasak: Date,
  ambangJam: number = 4,
  sekarang: Date = new Date()
): HasilStatus {
  const consumeBy = new Date(waktuSelesaiMasak.getTime() + ambangJam * 3600_000);
  const warningMinutes = Math.round(ambangJam * 60 * 0.25);
  return hitungStatusKonsumsiKomponen(waktuSelesaiMasak, consumeBy, warningMinutes, sekarang);
}
