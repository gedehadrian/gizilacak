import "server-only";
import { cookies } from "next/headers";
import { createHmac, timingSafeEqual } from "crypto";

// Session cookie ringan berbasis HMAC (self-signed), bukan library auth
// pihak ketiga — cukup untuk demo lomba dengan deadline ketat, tapi jauh
// lebih kredibel dibanding session hanya di sessionStorage (yang bisa
// dipalsukan langsung dari devtools tanpa perlu tahu PIN).
//
// PENTING (produksi sungguhan): ganti dengan library auth teruji
// (mis. NextAuth/Auth.js, Lucia, atau Supabase Auth) sebelum dipakai
// untuk skala nyata — ini tetap sebuah tanda tangan sederhana, bukan
// pengganti audit keamanan penuh.

export type Role = "dapur" | "sekolah" | "admin";

const COOKIE_NAMES: Record<Role, string> = {
  dapur: "gzl_dapur",
  sekolah: "gzl_sekolah",
  admin: "gzl_admin",
};

const MAX_AGE_SECONDS = 8 * 60 * 60; // 8 jam kerja

interface SessionPayload {
  role: Role;
  id?: string;
  nama?: string;
  kode?: string;
  iat: number;
}

function getSecret(): string {
  const secret = process.env.SESSION_SECRET;
  if (!secret || secret.length < 16) {
    throw new Error(
      "SESSION_SECRET belum diisi (atau terlalu pendek) di .env.local — wajib diisi string acak minimal 32 karakter."
    );
  }
  return secret;
}

function sign(payload: string): string {
  return createHmac("sha256", getSecret()).update(payload).digest("hex");
}

function encode(payload: SessionPayload): string {
  const json = JSON.stringify(payload);
  const b64 = Buffer.from(json, "utf8").toString("base64url");
  const sig = sign(b64);
  return `${b64}.${sig}`;
}

function decode(token: string, role: Role): SessionPayload | null {
  const [b64, sig] = token.split(".");
  if (!b64 || !sig) return null;

  const expected = sign(b64);
  try {
    const a = Buffer.from(sig, "hex");
    const b = Buffer.from(expected, "hex");
    if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  } catch {
    return null;
  }

  let payload: SessionPayload;
  try {
    payload = JSON.parse(Buffer.from(b64, "base64url").toString("utf8"));
  } catch {
    return null;
  }

  if (payload.role !== role) return null;
  if (Date.now() - payload.iat > MAX_AGE_SECONDS * 1000) return null;
  return payload;
}

export async function setSessionCookie(
  role: Role,
  data: Omit<SessionPayload, "role" | "iat">
): Promise<void> {
  const token = encode({ role, ...data, iat: Date.now() });
  const store = await cookies();
  store.set(COOKIE_NAMES[role], token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: MAX_AGE_SECONDS,
  });
}

export async function getSession(role: Role): Promise<SessionPayload | null> {
  const store = await cookies();
  const token = store.get(COOKIE_NAMES[role])?.value;
  if (!token) return null;
  return decode(token, role);
}

export async function clearSessionCookie(role: Role): Promise<void> {
  const store = await cookies();
  store.delete(COOKIE_NAMES[role]);
}
