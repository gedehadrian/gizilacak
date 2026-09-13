import { isAdminConfigured } from "@/lib/supabase/admin";
import { jsonError, jsonOk } from "@/lib/http";
import { loadPublicScan, recordScanEvent } from "@/modules/delivery/public-scan";

export const dynamic = "force-dynamic";

export async function GET(_req: Request, ctx: { params: Promise<{ token: string }> }) {
  if (!isAdminConfigured()) return jsonError(503, "config", "Lookup publik belum dikonfigurasi.");
  const { token } = await ctx.params;
  const dto = await loadPublicScan(token);
  return jsonOk(dto);
}

export async function POST(req: Request, ctx: { params: Promise<{ token: string }> }) {
  if (!isAdminConfigured()) return jsonError(503, "config", "Lookup publik belum dikonfigurasi.");
  const { token } = await ctx.params;
  const body = (await req.json().catch(() => ({}))) as { event_key?: string };
  const eventKey = body.event_key || `${token}:${Date.now()}`;
  await recordScanEvent(token, eventKey, "public");
  return jsonOk({ recorded: true });
}
