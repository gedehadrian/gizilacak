import { describe, expect, it } from "vitest";
import { addCalendarMonth, contributionMargin, neutralizeCsv, toCsv, bepSimulation } from "@/lib/money";

describe("finance formulas", () => {
  it("margin 200000 - 5000 fee - 20000 variable = 175000", () => {
    const r = contributionMargin({ cashIn: 200_000, refunds: 0, feesKnown: 5_000, variableCosts: 20_000 });
    expect(r.value).toBe(175_000);
    expect(r.partial).toBe(false);
  });

  it("refund 50000 menurunkan margin menjadi 125000", () => {
    const r = contributionMargin({ cashIn: 200_000, refunds: 50_000, feesKnown: 5_000, variableCosts: 20_000 });
    expect(r.value).toBe(125_000);
  });

  it("fee null menandai parsial dan tidak memaksa nol", () => {
    const r = contributionMargin({ cashIn: 200_000, refunds: 0, feesKnown: null, variableCosts: 20_000 });
    expect(r.partial).toBe(true);
    expect(r.value).toBe(180_000);
  });

  it("BEP tidak tercapai jika kontribusi <= 0", () => {
    expect(bepSimulation(1_000_000, 100_000, 100_000)).toBe("tidak tercapai dengan asumsi ini");
  });
});

describe("csv injection", () => {
  it("prefix rumus", () => {
    expect(neutralizeCsv("=1+1")).toBe("'=1+1");
    expect(toCsv([["ok", "+cmd"]])).toContain("'+cmd");
  });
});

describe("addCalendarMonth", () => {
  it("31 Jan + 1 bulan tidak overflow ke Maret", () => {
    const d = addCalendarMonth(new Date("2026-01-31T00:00:00.000Z"), 1);
    expect(d.getUTCMonth()).toBe(1);
  });
});
