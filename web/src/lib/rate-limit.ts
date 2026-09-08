// Rate limiter in-memory sederhana per instance server.
//
// CATATAN JUJUR: ini bukan rate limiter terdistribusi (tidak akan konsisten
// kalau Vercel menjalankan banyak instance serverless paralel). Untuk
// produksi sungguhan, ganti dengan Upstash Redis / Vercel KV. Untuk MVP
// lomba dengan deadline ketat, ini tetap jauh lebih baik daripada tanpa
// proteksi sama sekali terhadap percobaan brute-force PIN 4 digit.

const buckets = new Map<string, { count: number; resetAt: number }>();

export function checkRateLimit(
  key: string,
  limit: number,
  windowMs: number
): boolean {
  const now = Date.now();
  const bucket = buckets.get(key);
  if (!bucket || now > bucket.resetAt) {
    buckets.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (bucket.count >= limit) return false;
  bucket.count += 1;
  return true;
}

export function clientIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for");
  return fwd?.split(",")[0]?.trim() || "unknown";
}
