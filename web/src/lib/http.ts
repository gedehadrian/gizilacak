import { NextResponse } from "next/server";
import { appUrl } from "@/lib/supabase/env";

export function assertSameOrigin(req: Request): boolean {
  const origin = req.headers.get("origin");
  if (!origin) return true;
  try {
    const allowed = new URL(appUrl()).host;
    return new URL(origin).host === allowed || new URL(origin).host === req.headers.get("host");
  } catch {
    return false;
  }
}

export function jsonError(
  status: number,
  code: string,
  message: string,
  fieldErrors?: Record<string, string>
) {
  const requestId = crypto.randomUUID();
  return NextResponse.json(
    { error: { code, message, fieldErrors, requestId } },
    { status }
  );
}

export function jsonOk(data: unknown, status = 200) {
  return NextResponse.json(data, { status });
}
