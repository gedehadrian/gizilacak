// @vitest-environment node
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));
import { verifyMidtransSignature } from "@/modules/billing/midtrans";

// Independent Python hashlib.sha512 fixture for the documented concatenation.
const signature = "7464c2ef6f924148aa8e4684079ddb4da46dd771e8f038191099c605a7bbb80b0a8d616f5ed44d98b040f3da1e65e2c182b2a2f7a734d72095c194241e4e8474";
const payload = {
  orderId: "test-order-1",
  statusCode: "200",
  grossAmount: "10000.00",
  signatureKey: signature,
};

describe("Midtrans notification signature", () => {
  beforeEach(() => vi.stubEnv("MIDTRANS_SERVER_KEY", "test-server-key"));
  afterEach(() => vi.unstubAllEnvs());

  it("accepts SHA512(order_id + status_code + gross_amount + ServerKey)", () => {
    expect(verifyMidtransSignature(payload)).toBe(true);
  });

  it("accepts equivalent uppercase hexadecimal", () => {
    expect(verifyMidtransSignature({ ...payload, signatureKey: signature.toUpperCase() })).toBe(true);
  });

  it("rejects the old HMAC calculation", () => {
    expect(verifyMidtransSignature({ ...payload, signatureKey:
      "125571e9769fd906bb7a3ce8b904f191d4d8cf657263c72eb7fffbda838ad3451ae62bb9ba1546881509dad57c680eb8e4ad48750476db63fd5865ed4468051d",
    })).toBe(false);
  });

  it.each([
    { orderId: "another-order" },
    { statusCode: "201" },
    { grossAmount: "10001.00" },
    { grossAmount: "10000" },
  ])("rejects changed signed fields: %j", (change) => {
    expect(verifyMidtransSignature({ ...payload, ...change })).toBe(false);
  });

  it("rejects a signature generated with a different server key", () => {
    vi.stubEnv("MIDTRANS_SERVER_KEY", "another-server-key");
    expect(verifyMidtransSignature(payload)).toBe(false);
  });

  it.each(["", "00", "g".repeat(128), "0".repeat(128), signature.slice(0, -1),
    signature + "g", signature + "00", signature + "\n", " " + signature,
  ])("rejects malformed or incorrect signature %j", (signatureKey) => {
    expect(verifyMidtransSignature({ ...payload, signatureKey })).toBe(false);
  });

  it("fails closed when the server key is missing", () => {
    vi.stubEnv("MIDTRANS_SERVER_KEY", "");
    expect(() => verifyMidtransSignature(payload)).toThrow("Pembayaran belum dikonfigurasi.");
  });
});
