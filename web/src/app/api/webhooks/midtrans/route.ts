import { processMidtransWebhook } from "@/modules/billing/webhook";
import { isMidtransConfigured } from "@/modules/billing/midtrans";
import { jsonError, jsonOk } from "@/lib/http";

export async function POST(req: Request) {
  if (!isMidtransConfigured()) {
    return jsonError(503, "midtrans_unconfigured", "Webhook diterima tetapi MIDTRANS_SERVER_KEY belum diisi.");
  }
  const body = (await req.json().catch(() => null)) as Record<string, string> | null;
  if (!body) return jsonError(400, "invalid", "Body webhook tidak valid.");
  const result = await processMidtransWebhook(body);
  if (!result.ok) return jsonError(result.status, "webhook", result.message || "Webhook ditolak.");
  return jsonOk({ received: true, duplicate: "duplicate" in result ? result.duplicate : false });
}
