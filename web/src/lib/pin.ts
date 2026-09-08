/** Hash PIN dengan SHA-256 (hex). Cukup untuk demo, bukan auth produksi. */
export async function hashPin(pin: string): Promise<string> {
  const data = new TextEncoder().encode(pin.trim());
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function hashPinSyncNode(pin: string): string {
  // Hanya dipakai di server (API route)
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { createHash } = require("crypto") as typeof import("crypto");
  return createHash("sha256").update(pin.trim()).digest("hex");
}
