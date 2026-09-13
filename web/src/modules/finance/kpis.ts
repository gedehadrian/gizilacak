import { contributionMargin } from "@/lib/money";

export function platformKpis(input: {
  cashIn: number;
  refunds: number;
  feesKnown: number | null;
  variableCosts: number;
  mrr: number;
  openReceivables: number;
  activeSubscribers: number;
}) {
  const margin = contributionMargin({
    cashIn: input.cashIn,
    refunds: input.refunds,
    feesKnown: input.feesKnown,
    variableCosts: input.variableCosts,
  });
  return {
    ...input,
    contribution: margin.value,
    contributionPartial: margin.partial,
  };
}

export function costPerAcceptedPortion(allocatedCostRp: number, acceptedPortions: number) {
  if (acceptedPortions <= 0) return null;
  return allocatedCostRp / acceptedPortions;
}
