import { describe, expect, it } from "vitest";
import {
  hitungStatusKonsumsiKomponen,
  statusPalingMendesak,
} from "@/lib/status";

describe("status konsumsi", () => {
  const now = new Date("2026-09-11T12:00:00.000Z");

  it("dalam batas sebelum warning", () => {
    const cooked = new Date("2026-09-11T08:00:00.000Z");
    const consumeBy = new Date("2026-09-11T16:00:00.000Z");
    const r = hitungStatusKonsumsiKomponen(cooked, consumeBy, 60, now);
    expect(r.status).toBe("dalam-batas");
    expect(r.label).toMatch(/Masih dalam batas/);
    expect(r.label.toLowerCase()).not.toContain("aman");
  });

  it("mendekati saat warning", () => {
    const consumeBy = new Date("2026-09-11T12:30:00.000Z");
    const r = hitungStatusKonsumsiKomponen(now, consumeBy, 60, now);
    expect(r.status).toBe("mendekati-batas");
  });

  it("lewat batas", () => {
    const consumeBy = new Date("2026-09-11T11:00:00.000Z");
    const r = hitungStatusKonsumsiKomponen(new Date("2026-09-11T08:00:00.000Z"), consumeBy, 60, now);
    expect(r.status).toBe("lewat-batas");
  });

  it("unknown jika data tidak lengkap", () => {
    const r = hitungStatusKonsumsiKomponen(null, null, null, now);
    expect(r.status).toBe("belum-terverifikasi");
  });

  it("satu unknown membuat keseluruhan belum terverifikasi", () => {
    const a = hitungStatusKonsumsiKomponen(new Date("2026-09-11T08:00:00Z"), new Date("2026-09-11T18:00:00Z"), 60, now);
    const b = hitungStatusKonsumsiKomponen(null, null, null, now);
    expect(statusPalingMendesak([a, b]).status).toBe("belum-terverifikasi");
  });
});
