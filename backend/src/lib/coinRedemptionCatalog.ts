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

/**
 * Canonical server-calculated comparison for multiple features, in one
 * shared duration. This is a non-spendable preview until each feature has
 * production entitlement enforcement and an independently reviewed debit.
 */
export function catalogSelectionQuote(query: Record<string,string|undefined>) {
  const raw = query.targets;
  if (!raw || raw.length > 320) {
    badRequest("交換対象を指定してください","REDEMPTION_INVALID_TARGET");
  }
  const selection = raw.split(",");
  if (selection.length < 1 || selection.length > 11 ||
      selection.some(target=>!targets.has(target as BenefitPriceTarget)) ||
      new Set(selection).size !== selection.length) {
    badRequest("特典の重複または不正な組み合わせです",
      "REDEMPTION_INVALID_SELECTION");
  }
  const chosen = selection as BenefitPriceTarget[];
  if (chosen.includes("fullPremium") && chosen.length > 1) {
    badRequest("フルPremiumと個別特典は同時に指定できません",
      "REDEMPTION_OVERLAPPING_BUNDLE");
  }
  if (chosen.includes("allAds") && chosen.some(target=>[
    "projectListAds","canvasAds","timelineAds","processingAds",
  ].includes(target))) {
    badRequest("全広告非表示と個別の広告非表示は重複できません",
      "REDEMPTION_OVERLAPPING_ADS");
  }
  const first = catalogRedemptionQuote({...query,target:chosen[0]});
  const items = chosen.map(target=>({
    target, catalogPriceCoins:finalBenefitCostCoins(
      target,first.duration,first.quantity,
    ),
  }));
  const totalCoins = items.reduce((sum,item)=>sum+item.catalogPriceCoins,0);
  if (!Number.isSafeInteger(totalCoins)||totalCoins<1) {
    throw new Error("Invalid catalog price total");
  }
  return {
    targets: chosen, duration:first.duration,quantity:first.quantity,
    items, catalogPriceCoins:totalCoins,
    priceVersion:COIN_BENEFIT_PRICE_VERSION,
    enabled:false,priceCoins:null,
    reason:"REDEMPTION_NOT_IMPLEMENTED" as const,
  };
}
