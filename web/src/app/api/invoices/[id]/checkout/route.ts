import { mapPgError, requireTenantFlexible } from "@/lib/auth/require";
import { jsonError, jsonOk, assertSameOrigin } from "@/lib/http";
import { createSnapTransaction, isMidtransConfigured, snapHost } from "@/modules/billing/midtrans";
import { midtransEnv } from "@/lib/supabase/env";

/** Header CORS supaya app Flutter di web bisa memanggil endpoint ini. */
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, content-type, x-gzl-tenant",
  "Access-Control-Max-Age": "86400",
};

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders });
}

function withCors(res: Response) {
  for (const [k, v] of Object.entries(corsHeaders)) res.headers.set(k, v);
  return res;
}

export async function POST(req: Request, ctxp: { params: Promise<{ id: string }> }) {
  // Permintaan bearer datang dari app dan tidak membawa cookie, jadi tidak ada
  // risiko CSRF di sana. Cek same-origin hanya berlaku untuk pemanggilan cookie.
  const viaBearer = (req.headers.get("authorization") ?? "").toLowerCase().startsWith("bearer ");
  if (!viaBearer && !assertSameOrigin(req)) {
    return jsonError(403, "csrf", "Asal permintaan ditolak.");
  }
  const ctx = await requireTenantFlexible(req, ["owner", "finance"]);
  if (!ctx.ok) return withCors(ctx.error);
  const { id } = await ctxp.params;
  if (!isMidtransConfigured()) {
    return withCors(jsonError(
      503,
      "midtrans_unconfigured",
      "Pembayaran belum dapat diproses. Hubungi pengelola GiziLacak."
    ));
  }

  const { data: invoice } = await ctx.supabase
    .from("invoices")
    .select("id, number, status, total_rp, tenant_id")
    .eq("id", id)
    .eq("tenant_id", ctx.membership.tenant_id)
    .maybeSingle();
  if (!invoice) return withCors(jsonError(404, "not_found", "Invoice tidak ditemukan."));
  if (invoice.status === "paid") return withCors(jsonError(409, "conflict", "Invoice sudah lunas."));
  if (!["open", "draft"].includes(invoice.status)) return withCors(jsonError(409, "conflict", "Invoice tidak dapat dibayar."));

  const { data: existing } = await ctx.supabase
    .from("payments")
    .select("id, checkout_url, status, expires_at, order_id")
    .eq("invoice_id", id)
    .in("status", ["created", "pending"])
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (existing?.checkout_url && (!existing.expires_at || new Date(existing.expires_at) > new Date())) {
    return withCors(jsonOk({ redirectUrl: existing.checkout_url, orderId: existing.order_id, reused: true }));
  }

  const orderId = `${invoice.number}-${crypto.randomUUID().slice(0, 8)}`;
  const { data: tenant } = await ctx.supabase.from("tenants").select("name, billing_email").eq("id", invoice.tenant_id).single();
  const snap = await createSnapTransaction({
    orderId,
    amountRp: Number(invoice.total_rp),
    customerName: tenant?.name || "SPPG",
    customerEmail: tenant?.billing_email || "billing@invalid.local",
    itemName: `GiziLacak ${invoice.number}`,
  });

  const { error } = await ctx.supabase.from("payments").insert({
    tenant_id: invoice.tenant_id,
    invoice_id: invoice.id,
    provider: "midtrans",
    environment: midtransEnv(),
    order_id: orderId,
    status: "pending",
    amount_rp: invoice.total_rp,
    checkout_url: snap.redirectUrl,
    expires_at: new Date(Date.now() + 24 * 3600_000).toISOString(),
  });
  if (error) return withCors(mapPgError(error.message));
  return withCors(jsonOk({ redirectUrl: snap.redirectUrl, token: snap.token, host: snapHost() }));
}
