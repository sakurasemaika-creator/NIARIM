/** Opal exchange prices anchored to the Japanese subscription list prices. */
export const COIN_BENEFIT_PRICE_VERSION = "v7-complete-pack-anchor-20261116" as const;

// Individual rates follow the existing weights with a monthly comparison total of 68,750 Opals.
const monthlyCoins = {
  endCardEdit: 5_390,
  watermark: 8_090,
  toneCurve: 8_090,
  levelAdjustment: 6_740,
  unlimitedDuration: 11_240,
  customAutomation: 11_240,
  projectListAds: 5_390,
  canvasAds: 8_990,
  timelineAds: 7_190,
  processingAds: 4_490,
  allAds: 17_960,
} as const;

type IndividualBenefit = keyof typeof monthlyCoins;
export type BenefitPriceTarget = IndividualBenefit | "fullPremium";
export type BenefitDuration = "hour" | "day" | "week" | "month";

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

function individualUnitCoins(
  target: IndividualBenefit, duration: BenefitDuration,
): number {
  const month = monthlyCoins[target];
  // Round each short-period tariff up to 10 Opals.
  switch (duration) {
    case "hour": return Math.ceil(month / 60) * 10;
    case "day": return Math.ceil(month / 30) * 10;
    case "week": return Math.ceil(month * 3 / 40) * 10;
    case "month": return month;
  }
}

export function comparableBenefitsUnitCoins(duration: BenefitDuration): number {
  return comparableBenefits.reduce(
    (sum, target) => sum + individualUnitCoins(target, duration), 0,
  );
}

export function finalBenefitCoins(
  target: BenefitPriceTarget, duration: BenefitDuration,
): number {
  if (target !== "fullPremium") return individualUnitCoins(target, duration);
  if (duration === "month") return 55_000;
  // Round down to a whole ten so the pack saves at least 20% of the individual total.
  return Math.floor(comparableBenefitsUnitCoins(duration) * 4 / 50) * 10;
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
