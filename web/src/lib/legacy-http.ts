import { jsonError, jsonOk } from "@/lib/http";

function gone() {
  return jsonError(410, "gone", "Endpoint PIN/seed demo dinonaktifkan di produksi. Gunakan akun email di /masuk.");
}

export function pinLegacyGuard() {
  if (process.env.NODE_ENV === "production") return gone();
  return null;
}

export function seedLegacyGuard() {
  if (process.env.NODE_ENV === "production") return gone();
  return null;
}

export { jsonOk };
