import { NextRequest, NextResponse } from "next/server";
import { setSessionCookie } from "@/lib/session";
import { checkRateLimit, clientIp } from "@/lib/rate-limit";

export async function POST(req: NextRequest) {
  const expected = process.env.ADMIN_PIN?.trim();
  if (!expected) {
    // SENGAJA tidak pakai PIN default fallback (mis. "2468") — kalau env var
    // belum diisi, login harus gagal jelas, bukan diam-diam pakai PIN yang
    // sudah tertulis di dokumen publik proyek ini.
    return NextResponse.json(
      { ok: false, error: "ADMIN_PIN belum dikonfigurasi di server." },
      { status: 500 }
    );
  }

  if (!checkRateLimit(`auth:admin:${clientIp(req)}`, 8, 5 * 60 * 1000)) {
    return NextResponse.json(
      { ok: false, error: "Terlalu banyak percobaan. Coba lagi beberapa menit lagi." },
      { status: 429 }
    );
  }

  const body = (await req.json().catch(() => null)) as { pin?: string } | null;
  const pin = body?.pin?.trim() ?? "";

  if (!pin || pin !== expected) {
    return NextResponse.json({ ok: false, error: "PIN admin salah." }, { status: 401 });
  }

  await setSessionCookie("admin", {});
  return NextResponse.json({ ok: true });
}
