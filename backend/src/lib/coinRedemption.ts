import { PREMIUM_MONTHLY_REFERENCE_COINS } from "./coinEconomyScale";
import { FINAL_ALL_INDIVIDUAL_MONTHLY_COINS,
  FINAL_PREMIUM_MONTHLY_COINS, COIN_BENEFIT_PRICE_VERSION } from "./coinBenefitProposal";

/**
 * Initial implemented redemption route: full Premium for ONE calendar month.
 * The final monthly tariff is precisely 55,000 coins (550 yen x 100).
 * Annual Premium is a separate approved 550,000-coin catalog rate but
 * is NOT supported by this monthly-only redemption endpoint.
 * Incorrect operator configuration must FAIL CLOSED.
 * Pricing finalization does not itself authorize balance deductions.
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
    amount === FINAL_PREMIUM_MONTHLY_COINS &&
    amount >= PREMIUM_MONTHLY_REFERENCE_COINS &&
    amount < FINAL_ALL_INDIVIDUAL_MONTHLY_COINS &&
    version === COIN_BENEFIT_PRICE_VERSION;
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
