/** Opal exchange prices anchored to the Japanese subscription list prices. */
export const COIN_BENEFIT_PRICE_VERSION = "v8-complete-pack-half-20261116" as const;

// Exchange prices in hour, day, week, and month order.
const unitPrices = {
  endCardEdit: [1_440, 2_880, 6_470, 8_620],
  watermark: [2_160, 4_320, 9_710, 12_940],
  toneCurve: [2_160, 4_320, 9_710, 12_940],
  levelAdjustment: [1_800, 3_600, 8_090, 10_780],
  unlimitedDuration: [3_000, 6_000, 13_490, 17_980],
  customAutomation: [3_000, 6_000, 13_490, 17_980],
  projectListAds: [1_440, 2_880, 6_470, 8_620],
  canvasAds: [2_400, 4_800, 10_790, 14_380],
  timelineAds: [1_920, 3_840, 8_630, 11_500],
  processingAds: [1_200, 2_400, 5_390, 7_180],
  allAds: [4_820, 9_580, 21_560, 28_760],
  fullPremium: [9_190, 18_350, 41_260, 55_000],
} as const;

export type BenefitPriceTarget = keyof typeof unitPrices;
type IndividualBenefit = Exclude<BenefitPriceTarget, "fullPremium">;
export type BenefitDuration = "hour" | "day" | "week" | "month";
const durationIndex = { hour: 0, day: 1, week: 2, month: 3 } as const;

const adPlacements = [
  "projectListAds", "canvasAds", "timelineAds", "processingAds",
] as const;

const productionBenefits = [
  "endCardEdit", "watermark", "toneCurve", "levelAdjustment",
  "unlimitedDuration", "customAutomation",
] as const;

// All Ads replaces the four overlapping placement options in the comparison.
const comparableBenefits = [...productionBenefits, "allAds"] as const;

export const INDIVIDUAL_BENEFITS: readonly IndividualBenefit[] = [
  ...productionBenefits, ...adPlacements,
];

export function comparableBenefitsUnitCoins(duration: BenefitDuration): number {
  return comparableBenefits.reduce(
    (sum, target) => sum + finalBenefitCoins(target, duration), 0,
  );
}

export function finalBenefitCoins(
  target: BenefitPriceTarget, duration: BenefitDuration,
): number {
  return unitPrices[target][durationIndex[duration]];
}

export const FINAL_PREMIUM_MONTHLY_COINS = finalBenefitCoins("fullPremium", "month");
export const FINAL_PREMIUM_YEARLY_COINS = 10 * FINAL_PREMIUM_MONTHLY_COINS;

/** Each complete 12-month block costs ten monthly units. */
export function finalBenefitCostCoins(
  target: BenefitPriceTarget, duration: BenefitDuration, quantity: number,
): number {
  if (!Number.isSafeInteger(quantity) || quantity < 1 || quantity > 120) {
    throw new RangeError("Invalid benefit duration quantity");
  }
  const units = duration === "month" ? quantity - 2 * Math.floor(quantity / 12) : quantity;
  return finalBenefitCoins(target, duration) * units;
}

export function isBundledPremiumCheaperForAllDurations(): boolean {
  return (["hour", "day", "week", "month"] as const).every(duration =>
    finalBenefitCoins("fullPremium", duration) < comparableBenefitsUnitCoins(duration) &&
    finalBenefitCoins("allAds", duration) < adPlacements.reduce(
      (sum, target) => sum + finalBenefitCoins(target, duration), 0,
    ),
  );
}
