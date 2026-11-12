import { badRequest } from "./response";
import {
  COIN_BENEFIT_PRICE_VERSION,
  finalBenefitCostCoins,
  finalBenefitCoins,
  type BenefitDuration,
  type BenefitPriceTarget,
} from "./coinBenefitProposal";

/**
 * Authenticated, read-only catalog previews.
 * These figures are not spendable offers. The only current redeemable
 * route remains fullPremium/month/1 after independent approval.
 */
const targets = new Set<BenefitPriceTarget>([
  "endCardEdit", "watermark", "toneCurve", "levelAdjustment",
  "unlimitedDuration", "customAutomation", "projectListAds",
  "canvasAds", "timelineAds", "processingAds", "allAds", "fullPremium",
]);
const durations = new Set<BenefitDuration>(["hour","day","week","month"]);

export interface CatalogRedemptionQuote {
  target: BenefitPriceTarget;
  duration: BenefitDuration;
  quantity: number;
  catalogPriceCoins: number;
  priceVersion: typeof COIN_BENEFIT_PRICE_VERSION;
  enabled: false;
  priceCoins: null;
  reason: "REDEMPTION_NOT_IMPLEMENTED";
}

export function catalogRedemptionQuote(
  query: Record<string,string | undefined>,
): CatalogRedemptionQuote {
  const requestedTarget = query.target ?? "fullPremium";
  const requestedDuration = query.duration ??
    (query.months !== undefined ? "month" : "month");
  // Compatibility with the original quote endpoint's ?months=1.
  // Multiple competing duration fields are rejected, never guessed.
  if (query.months !== undefined && query.duration !== undefined &&
      query.duration !== "month") {
    badRequest("期間指定が矛盾しています","REDEMPTION_INVALID_DURATION");
  }
  const rawQuantity = query.quantity ?? query.months ?? "1";
  if (!targets.has(requestedTarget as BenefitPriceTarget)) {
    badRequest("交換対象が不正です","REDEMPTION_INVALID_TARGET");
  }
  if (!durations.has(requestedDuration as BenefitDuration)) {
    badRequest("交換期間が不正です","REDEMPTION_INVALID_DURATION");
  }
  if (!/^(?:[1-9]|[1-9][0-9]|1[01][0-9]|120)$/.test(rawQuantity)) {
    badRequest("数量は1～120の整数を指定してください",
      "REDEMPTION_INVALID_QUANTITY");
  }
  const target = requestedTarget as BenefitPriceTarget;
  const duration = requestedDuration as BenefitDuration;
  const quantity = Number(rawQuantity);
  // Pricing derives exclusively from the owner-approved server catalog.
  const unit = finalBenefitCoins(target,duration);
  const total = finalBenefitCostCoins(target,duration,quantity);
  if (!Number.isSafeInteger(unit) || unit <= 0 ||
      !Number.isSafeInteger(total) || total <= 0) {
    throw new Error("Invalid server catalog price");
  }
  return {
    target, duration, quantity, catalogPriceCoins: total,
    priceVersion: COIN_BENEFIT_PRICE_VERSION,
    enabled: false, priceCoins: null,
    reason: "REDEMPTION_NOT_IMPLEMENTED",
  };
}
