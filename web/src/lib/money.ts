export function formatRp(amount: number | bigint | null | undefined): string {
  if (amount == null) return "belum lengkap";
  const n = Number(amount);
  return new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", maximumFractionDigits: 0 }).format(n);
}

export function contributionMargin(params: {
  cashIn: number;
  refunds: number;
  feesKnown: number | null;
  variableCosts: number;
}): { value: number | null; partial: boolean } {
  if (params.feesKnown == null) {
    return { value: params.cashIn - params.refunds - params.variableCosts, partial: true };
  }
  return {
    value: params.cashIn - params.refunds - params.feesKnown - params.variableCosts,
    partial: false,
  };
}

export function bepSimulation(fixedMonthly: number, price: number, variablePerSppg: number): string | number {
  const contrib = price - variablePerSppg;
  if (contrib <= 0) return "tidak tercapai dengan asumsi ini";
  return Math.ceil(fixedMonthly / contrib);
}

export function neutralizeCsv(value: string): string {
  const v = value.replace(/"/g, '""');
  if (/^[=+\-@]/.test(v)) return `'${v}`;
  return v;
}

export function toCsv(rows: string[][]): string {
  return rows
    .map((r) => r.map((c) => `"${neutralizeCsv(String(c ?? ""))}"`).join(","))
    .join("\n");
}

export function addCalendarMonth(from: Date, months = 1): Date {
  const d = new Date(from.getTime());
  const day = d.getUTCDate();
  d.setUTCMonth(d.getUTCMonth() + months);
  if (d.getUTCDate() < day) d.setUTCDate(0);
  return d;
}
