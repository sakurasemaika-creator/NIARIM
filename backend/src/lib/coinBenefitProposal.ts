/**
 * Owner-approved, FIXED launch coin exchange unit-price catalog.
 * Economics is final, NOT an automatic offer or entitlement grant.
 * Each currently unsupported redemption remains disabled until its
 * authenticated, atomic server redemption path has been implemented.
 * This table does not bypass independent safety and release gates.
 *
 * Multi-unit exchange pricing multiplies a rounded unit price by quantity,
 * EXCEPT full Premium: complete 12-month blocks use the Japanese annual
 * plan price of ¥5,500 × 100 = 550,000 coins, then remaining months use
 * the approved 55,000-coin monthly price. This does not enable annual
 * redemption before a server implementation and independent approval.
 * Discounted bundles remain cheaper than equivalent individual rights.
 */
import {
  PREMIUM_YEARLY_LIST_PRICE_YEN, REFERENCE_COINS_PER_YEN,
} from "./coinEconomyScale";

export const COIN_BENEFIT_PRICE_VERSION = "v3-final-annual550000" as const;

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
export const FINAL_PREMIUM_YEARLY_COINS =
  PREMIUM_YEARLY_LIST_PRICE_YEN * REFERENCE_COINS_PER_YEN;

/** Final-priced quantity, including the explicit 1-year discount.
 * This is only a PRICE calculation, never a spendable entitlement quote.
 */
export function finalBenefitCostCoins(
  target: BenefitPriceTarget, duration: BenefitDuration, quantity: number,
): number {
  if (!Number.isSafeInteger(quantity) || quantity < 1 ||
      quantity > 120) throw new RangeError("Invalid benefit duration quantity");
  if (target === "fullPremium" && duration === "month") {
    return Math.floor(quantity / 12) * FINAL_PREMIUM_YEARLY_COINS +
      (quantity % 12) * FINAL_PREMIUM_MONTHLY_COINS;
  }
  return finalBenefitCoins(target,duration) * quantity;
}
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
