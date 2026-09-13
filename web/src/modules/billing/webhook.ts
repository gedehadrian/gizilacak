import "server-only";
import { createSupabaseAdmin } from "@/lib/supabase/admin";
import { midtransEnv } from "@/lib/supabase/env";
import { mapTransactionStatus, verifyMidtransSignature } from "./midtrans";

type MidtransBody = {
  order_id?: string;
  status_code?: string;
  gross_amount?: string;
  signature_key?: string;
  transaction_status?: string;
  fraud_status?: string;
  transaction_id?: string;
  payment_type?: string;
};

function amountEquals(gross: string, amountRp: number) {
  const n = Number.parseFloat(gross);
  return Number.isFinite(n) && Math.round(n) === Math.round(amountRp);
}

export async function processMidtransWebhook(body: MidtransBody) {
  const orderId = body.order_id ?? "";
  const statusCode = body.status_code ?? "";
  const grossAmount = body.gross_amount ?? "";
  const signatureKey = body.signature_key ?? "";
  if (!orderId || !signatureKey) {
    return { ok: false, status: 400, message: "Payload webhook tidak lengkap." };
  }
  if (!verifyMidtransSignature({ orderId, statusCode, grossAmount, signatureKey })) {
    return { ok: false, status: 403, message: "Tanda tangan webhook ditolak." };
  }

  const env = midtransEnv();
  const admin = createSupabaseAdmin();
  const dedupe = `${env}:${orderId}:${body.transaction_id ?? ""}:${body.transaction_status ?? ""}:${statusCode}`;

  const { data: existing } = await admin
    .from("payment_events")
    .select("id, status, processed_at")
    .eq("provider", "midtrans")
    .eq("environment", env)
    .eq("dedupe_key", dedupe)
    .maybeSingle();

  if (existing?.processed_at) {
    return { ok: true, status: 200, duplicate: true };
  }

  const { data: event, error: evErr } = existing
    ? { data: existing, error: null }
    : await admin
        .from("payment_events")
        .insert({
          provider: "midtrans",
          environment: env,
          dedupe_key: dedupe,
          payload_redacted: {
            order_id: orderId,
            transaction_status: body.transaction_status,
            status_code: statusCode,
            gross_amount: grossAmount,
            transaction_id: body.transaction_id,
            payment_type: body.payment_type,
          },
          status: "received",
          verified_at: new Date().toISOString(),
        })
        .select("id")
        .single();

  if (evErr && evErr.code !== "23505") {
    return { ok: false, status: 500, message: "Gagal menyimpan event pembayaran." };
  }

  const { data: payment } = await admin
    .from("payments")
    .select("id, invoice_id, tenant_id, amount_rp, status, refunded_rp, environment")
    .eq("order_id", orderId)
    .eq("environment", env)
    .maybeSingle();

  if (!payment) {
    await admin.from("payment_events").update({ status: "ignored", error_code: "order_unknown" }).eq("dedupe_key", dedupe);
    return { ok: true, status: 200, ignored: true };
  }

  if (!amountEquals(grossAmount, Number(payment.amount_rp))) {
    await admin
      .from("payment_events")
      .update({ status: "failed", error_code: "amount_mismatch" })
      .eq("dedupe_key", dedupe);
    return { ok: false, status: 409, message: "Nominal webhook tidak cocok dengan invoice." };
  }

  const mapped = mapTransactionStatus(body.transaction_status ?? "", body.fraud_status);

  if (mapped === "paid") {
    const { error } = await admin.rpc("activate_paid_invoice", {
      _invoice_id: payment.invoice_id,
      _payment_id: payment.id,
    });
    if (error) {
      await admin
        .from("payment_events")
        .update({ status: "failed", error_code: error.message, retry_count: 1 })
        .eq("dedupe_key", dedupe);
      return { ok: false, status: 500, message: "Aktivasi langganan gagal; event tersimpan untuk retry." };
    }
  } else if (mapped === "refunded") {
    const refunded = Number(payment.amount_rp);
    await admin
      .from("payments")
      .update({ status: "refunded", refunded_rp: refunded })
      .eq("id", payment.id)
      .neq("status", "refunded");
  } else if (mapped === "expired" || mapped === "failed") {
    await admin.from("payments").update({ status: mapped }).eq("id", payment.id).in("status", ["created", "pending"]);
  } else if (mapped === "pending") {
    await admin.from("payments").update({ status: "pending" }).eq("id", payment.id).eq("status", "created");
  }

  const eventId = event?.id ?? existing?.id;
  if (eventId) {
    await admin
      .from("payment_events")
      .update({ status: "processed", processed_at: new Date().toISOString(), payment_id: payment.id })
      .eq("id", eventId);
  }

  return { ok: true, status: 200 };
}
