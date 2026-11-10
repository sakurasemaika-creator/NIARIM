import { PREMIUM_MONTHLY_REFERENCE_COINS } from "./coinEconomyScale";
import { PROPOSED_ALL_INDIVIDUAL_MONTHLY_COINS } from "./coinBenefitProposal";

/**
 * Deliberately narrow first version: full Premium for ONE calendar month.
 * The 55,000-coin reference is a FLOOR, not an automatically activated price.
 * Operators must separately configure, version and approve the actual offer.
 */
export interface PremiumRedemptionOffer {
  enabled: boolean;
  target: "fullPremium";
  months: 1;
  priceCoins: number | null;
  priceVersion: string | null;
}

export function premiumRedemptionOffer(): PremiumRedemptionOffer {
  const raw = process.env.COIN_FULL_PREMIUM_MONTH_COINS ?? "";
  const amount = Number(raw);
  const version = process.env.COIN_PRICE_VERSION ?? "";
  const approved = process.env.COIN_REDEMPTION_REVIEW_APPROVED === "true";
  const enabled = process.env.COIN_REDEMPTION_ENABLED === "true" &&
    approved &&
    /^[1-9][0-9]{0,8}$/.test(raw) &&
    Number.isSafeInteger(amount) &&
    amount % 10 === 0 &&
    amount >= PREMIUM_MONTHLY_REFERENCE_COINS &&
    amount < PROPOSED_ALL_INDIVIDUAL_MONTHLY_COINS &&
    /^v[1-9][0-9]*-[a-z0-9-]{2,40}$/.test(version);
  return {
    enabled,
    target: "fullPremium",
    months: 1,
    priceCoins: enabled ? amount : null,
    priceVersion: enabled ? version : null,
  };
}

/** Calendar-month arithmetic, UTC and leap-day safe. No 30-day assumption. */
export function addOneCalendarMonthUtc(epochMs: number): number {
  if (!Number.isSafeInteger(epochMs) || epochMs < 0 ||
      epochMs > Date.UTC(9990, 0, 1)) {
    throw new Error("Invalid entitlement expiry timestamp");
  }
  const base = new Date(epochMs);
  // Clamp 31st into shorter months instead of overflowing into the next.
  const nextYear = base.getUTCFullYear() +
    (base.getUTCMonth() === 11 ? 1 : 0);
  const nextMonth = (base.getUTCMonth() + 1) % 12;
  const monthEnd = new Date(Date.UTC(nextYear, nextMonth + 1, 0))
    .getUTCDate();
  return Date.UTC(nextYear, nextMonth,
    Math.min(base.getUTCDate(), monthEnd),
    base.getUTCHours(), base.getUTCMinutes(),
    base.getUTCSeconds(), base.getUTCMilliseconds());
}
