/**
 * Reference-only price proposal, NOT an enabled coin offer.
 * Backend redemption remains gated by a separately approved server quote.
 *
 * Every target has a monotone time discount: 24 hours cost more than one day,
 * seven days cost more than one week, and 4 weeks cost more than one month.
 * Full Premium is strictly cheaper than buying each equivalent standalone
 * right for the same period.
 */
export const COIN_BENEFIT_PRICE_PROPOSAL_VERSION = "proposal-v1" as const;

const month = {
  endCardEdit: 8_000,
  watermark: 14_000,
  toneCurve: 13_000,
  levelAdjustment: 10_000,
  unlimitedDuration: 18_000,
  customAutomation: 20_000,
  projectListAds: 9_000,
  canvasAds: 15_000,
  timelineAds: 12_000,
  processingAds: 6_000,
  allAds: 36_000,
  fullPremium: 60_000,
} as const;

export type BenefitPriceTarget = keyof typeof month;
export type BenefitDuration = "hour" | "day" | "week" | "month";

export const INDIVIDUAL_BENEFITS: readonly BenefitPriceTarget[] = [
  "endCardEdit","watermark","toneCurve","levelAdjustment",
  "unlimitedDuration","customAutomation",
  "projectListAds","canvasAds","timelineAds","processingAds",
];

export function proposedBenefitCoins(
  target: BenefitPriceTarget, duration: BenefitDuration,
): number {
  const perMonth = month[target];
  if (duration === "month") return perMonth;
  // Full bundle is quoted at independently-approved rates and cannot be
  // activated from this proposed calculator.
  if (target === "fullPremium") {
    return {hour:500,day:2_500,week:18_000}[duration];
  }
  return {
    hour: Math.ceil(perMonth / 120),
    day: Math.ceil(perMonth / 28),
    week: Math.ceil(perMonth / 3.7),
  }[duration];
}

export const PROPOSED_PREMIUM_MONTHLY_COINS = month.fullPremium;
export const PROPOSED_ALL_INDIVIDUAL_MONTHLY_COINS = INDIVIDUAL_BENEFITS
  .reduce((sum,target)=>sum + month[target],0);

export function isBundledPremiumCheaperForAllDurations(): boolean {
  return (["hour","day","week","month"] as const).every(duration => {
    const standalone = INDIVIDUAL_BENEFITS.reduce(
      (sum,target)=>sum + proposedBenefitCoins(target,duration),0);
    const allAdSingles = (["projectListAds","canvasAds",
      "timelineAds","processingAds"] as const).reduce(
      (sum,target)=>sum + proposedBenefitCoins(target,duration),0);
    return proposedBenefitCoins("fullPremium",duration) < standalone &&
      proposedBenefitCoins("allAds",duration) < allAdSingles;
  });
}
