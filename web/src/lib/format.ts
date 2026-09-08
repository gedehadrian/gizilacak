import { format, addHours } from "date-fns";
import { id as localeId } from "date-fns/locale";

export function formatWaktu(iso: string | Date): string {
  const d = typeof iso === "string" ? new Date(iso) : iso;
  return format(d, "dd MMM yyyy HH:mm", { locale: localeId });
}

export function hitungBatasKonsumsi(
  waktuSelesaiMasak: string | Date,
  ambangJam: number
): Date {
  const d =
    typeof waktuSelesaiMasak === "string"
      ? new Date(waktuSelesaiMasak)
      : waktuSelesaiMasak;
  return addHours(d, ambangJam);
}

export function formatSelisihJam(selisihJam: number): string {
  const jam = Math.floor(Math.abs(selisihJam));
  const menit = Math.round((Math.abs(selisihJam) - jam) * 60);
  if (jam === 0) return `${menit} menit`;
  return `${jam} jam ${menit} menit`;
}

export function generateToken(): string {
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return crypto.randomUUID().replace(/-/g, "").slice(0, 16);
  }
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

export function splitCsv(input: string): string[] {
  return input
    .split(/[,;\n]/)
    .map((s) => s.trim())
    .filter(Boolean);
}
