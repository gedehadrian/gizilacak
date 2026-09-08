import { NextRequest, NextResponse } from "next/server";
import { getSession, type Role } from "@/lib/session";

export async function GET(req: NextRequest) {
  const role = req.nextUrl.searchParams.get("role") as Role | null;
  if (role !== "dapur" && role !== "sekolah" && role !== "admin") {
    return NextResponse.json({ ok: false, error: "Parameter role tidak valid." }, { status: 400 });
  }

  const session = await getSession(role);
  if (!session) {
    return NextResponse.json({ ok: true, loggedIn: false });
  }
  return NextResponse.json({ ok: true, loggedIn: true, session });
}
