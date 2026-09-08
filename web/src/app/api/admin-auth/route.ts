import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  const body = (await req.json().catch(() => null)) as { pin?: string } | null;
  const pin = body?.pin?.trim() ?? "";
  const expected = process.env.ADMIN_PIN?.trim() ?? "2468";

  if (!pin || pin !== expected) {
    return NextResponse.json({ ok: false, error: "PIN admin salah" }, { status: 401 });
  }

  return NextResponse.json({ ok: true });
}
