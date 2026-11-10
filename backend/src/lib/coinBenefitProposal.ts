/**
 * Owner-approved, FIXED launch coin exchange unit-price catalog.
 * Economics is final, NOT an automatic offer or entitlement grant.
 * Each currently unsupported redemption remains disabled until its
 * authenticated, atomic server redemption path has been implemented.
 * This table does not bypass independent safety and release gates.
 *
 * Multi-unit exchange pricing is the unit price multiplied by quantity;
 * the unit price is rounded upwards to a multiple of 10 coins.
 * Discounted bundles remain cheaper than equivalent individual rights.
 */
export const COIN_BENEFIT_PRICE_VERSION = "v2-final-55000" as const;

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
  fullPremium: 55_000,
} as const;

export type BenefitPriceTarget = keyof typeof month;
export type BenefitDuration = "hour" | "day" | "week" | "month";

export const INDIVIDUAL_BENEFITS: readonly BenefitPriceTarget[] = [
  "endCardEdit","watermark","toneCurve","levelAdjustment",
  "unlimitedDuration","customAutomation",
  "projectListAds","canvasAds","timelineAds","processingAds",
];

export function finalBenefitCoins(
  target: BenefitPriceTarget, duration: BenefitDuration,
): number {
  const perMonth = month[target];
  if (duration === "month") return perMonth;
  // Full bundle is fixed by the owner; redemption activation remains
  // separately gated by a server-signed, revisioned quote.
  if (target === "fullPremium") {
    return {hour:500,day:2_500,week:18_000}[duration];
  }
  // Round every unit price UP at the ones place to a multiple of 10.
  const raw = {
    hour: Math.ceil(perMonth / 120),
    day: Math.ceil(perMonth / 28),
    week: Math.ceil(perMonth / 3.7),
  }[duration];
  return Math.ceil(raw / 10) * 10;
}

export const FINAL_PREMIUM_MONTHLY_COINS = month.fullPremium;
export const FINAL_ALL_INDIVIDUAL_MONTHLY_COINS = INDIVIDUAL_BENEFITS
  .reduce((sum,target)=>sum + month[target],0);

export function isBundledPremiumCheaperForAllDurations(): boolean {
  return (["hour","day","week","month"] as const).every(duration => {
    const standalone = INDIVIDUAL_BENEFITS.reduce(
      (sum,target)=>sum + finalBenefitCoins(target,duration),0);
    const allAdSingles = (["projectListAds","canvasAds",
      "timelineAds","processingAds"] as const).reduce(
      (sum,target)=>sum + finalBenefitCoins(target,duration),0);
    return finalBenefitCoins("fullPremium",duration) < standalone &&
      finalBenefitCoins("allAds",duration) < allAdSingles;
  });
}
