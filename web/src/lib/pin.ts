import "server-only";
import { createHash } from "crypto";

/**
 * Hash PIN dengan SHA-256 (hex) — HANYA dipanggil di server (API routes).
 * Client sekarang mengirim PIN plaintext lewat HTTPS ke API route yang
 * melakukan hashing & pencocokan di server (lihat src/app/api/auth/*),
 * bukan lagi di-hash di browser lalu dicocokkan lewat query Supabase
 * langsung dari client seperti versi awal.
 */
export function hashPinSyncNode(pin: string): string {
  return createHash("sha256").update(pin.trim()).digest("hex");
}
