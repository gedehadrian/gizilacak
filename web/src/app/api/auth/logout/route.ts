import { NextRequest, NextResponse } from "next/server";
import { clearSessionCookie, type Role } from "@/lib/session";

export async function POST(req: NextRequest) {
  const body = (await req.json().catch(() => null)) as { role?: Role } | null;
  const role = body?.role;
  if (role === "dapur" || role === "sekolah" || role === "admin") {
    await clearSessionCookie(role);
  }
  return NextResponse.json({ ok: true });
}
