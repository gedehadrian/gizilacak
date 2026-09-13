import "server-only";
import { createHash, timingSafeEqual } from "crypto";
import { appUrl, midtransEnv } from "@/lib/supabase/env";

export function isMidtransConfigured() {
  return Boolean(process.env.MIDTRANS_SERVER_KEY);
}

function serverKey() {
  const k = process.env.MIDTRANS_SERVER_KEY;
  if (!k) throw new Error("Pembayaran belum dikonfigurasi.");
  return k;
}

export function snapHost() {
  return midtransEnv() === "production"
    ? "https://app.midtrans.com"
    : "https://app.sandbox.midtrans.com";
}

export function verifyMidtransSignature(params: {
  orderId: string;
  statusCode: string;
  grossAmount: string;
  signatureKey: string;
}): boolean {
  // Buffer.from(hex) silently truncates invalid suffixes; validate the entire digest.
  if (!/^[0-9a-f]{128}$/i.test(params.signatureKey)) return false;
  const raw = params.orderId + params.statusCode + params.grossAmount + serverKey();
  const expected = createHash("sha512").update(raw).digest("hex");
  try {
    const a = Buffer.from(expected, "hex");
    const b = Buffer.from(params.signatureKey, "hex");
    return a.length === b.length && timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

export async function createSnapTransaction(input: {
  orderId: string;
  amountRp: number;
  customerName: string;
  customerEmail: string;
  itemName: string;
}) {
  const auth = Buffer.from(`${serverKey()}:`).toString("base64");
  const res = await fetch(`${snapHost()}/snap/v1/transactions`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      transaction_details: {
        order_id: input.orderId,
        gross_amount: input.amountRp,
      },
      item_details: [
        { id: "plan", price: input.amountRp, quantity: 1, name: input.itemName.slice(0, 50) },
      ],
      customer_details: {
        first_name: input.customerName.slice(0, 50),
        email: input.customerEmail,
      },
      credit_card: { secure: true },
      // Tanpa ini Midtrans memakai alamat bawaan di dashboard-nya, yang secara
      // default mengarah ke example.com. Ditentukan per transaksi supaya ikut
      // lingkungan tempat aplikasi berjalan, bukan bergantung pada setelan
      // dashboard yang tak terlihat dari kode.
      callbacks: { finish: `${appUrl()}/bayar/selesai` },
    }),
  });
  const json = (await res.json()) as { token?: string; redirect_url?: string; error_messages?: string[] };
  if (!res.ok || !json.redirect_url) {
    throw new Error(json.error_messages?.join(", ") || "Gagal membuat checkout Midtrans.");
  }
  return { token: json.token, redirectUrl: json.redirect_url };
}

export function mapTransactionStatus(status: string, fraud?: string): "paid" | "pending" | "failed" | "expired" | "refunded" {
  if (status === "settlement") return "paid";
  if (status === "capture" && (fraud === "accept" || !fraud)) return "paid";
  if (status === "pending" || status === "authorize") return "pending";
  if (status === "expire") return "expired";
  if (status === "refund" || status === "partial_refund") return "refunded";
  return "failed";
}
