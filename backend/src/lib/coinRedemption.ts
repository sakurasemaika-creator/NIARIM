import { PREMIUM_MONTHLY_REFERENCE_COINS } from "./coinEconomyScale";
import { FINAL_ALL_INDIVIDUAL_MONTHLY_COINS,
  FINAL_PREMIUM_MONTHLY_COINS, FINAL_PREMIUM_YEARLY_COINS,
  finalBenefitCostCoins,
  COIN_BENEFIT_PRICE_VERSION } from "./coinBenefitProposal";

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
  months: 1 | 12;
  priceCoins: number | null;
  priceVersion: string | null;
}

export function premiumRedemptionOffer(): PremiumRedemptionOffer {
  const raw = process.env.COIN_FULL_PREMIUM_MONTH_COINS ?? "";
  const amount = Number(raw);
  const version = process.env.COIN_PRICE_VERSION ?? "";
  const enabled = process.env.COIN_REDEMPTION_ENABLED === "true" &&
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

/**
 * Annual redemption has the same atomic entitlement semantics as monthly,
 * but must be explicitly enabled separately after review. A disabled
 * offer never discloses a spendable price to the application.
 */
export function premiumAnnualRedemptionOffer(): PremiumRedemptionOffer & {
  months: 12;
} {
  const base = premiumRedemptionOffer();
  const raw = process.env.COIN_FULL_PREMIUM_YEAR_COINS ?? "";
  const amount = Number(raw);
  const enabled = base.enabled &&
    process.env.COIN_PREMIUM_ANNUAL_REDEMPTION_ENABLED === "true" &&
    /^[1-9][0-9]{0,8}$/.test(raw) &&
    Number.isSafeInteger(amount) &&
    amount === FINAL_PREMIUM_YEARLY_COINS &&
    amount < FINAL_PREMIUM_MONTHLY_COINS * 12;
  return {
    enabled, target: "fullPremium", months: 12,
    priceCoins: enabled ? amount : null,
    priceVersion: enabled ? COIN_BENEFIT_PRICE_VERSION : null,
  };
}

/** Exactly 12 calendar months, preserving the starting day if possible. */
export function addOneCalendarYearUtc(epochMs: number): number {
  if (!Number.isSafeInteger(epochMs) || epochMs < 0 ||
      epochMs > Date.UTC(9990, 0, 1)) {
    throw new Error("Invalid entitlement expiry timestamp");
  }
  const base = new Date(epochMs);
  const year = base.getUTCFullYear() + 1;
  const month = base.getUTCMonth();
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return Date.UTC(year, month, Math.min(base.getUTCDate(),lastDay),
    base.getUTCHours(),base.getUTCMinutes(),
    base.getUTCSeconds(),base.getUTCMilliseconds());
}

/** General Full Premium durations, including the short trial-sized periods. */
export function premiumFlexibleOffer(
  duration: import("./coinBenefitProposal").BenefitDuration,
  quantity: number,
) {
  const fullMonth = premiumRedemptionOffer();
  const annual = premiumAnnualRedemptionOffer();
  const needsAnnualDiscount = duration === "month" && quantity >= 12;
  const enabled = fullMonth.enabled && (!needsAnnualDiscount || annual.enabled);
  const coins = finalBenefitCostCoins("fullPremium",duration,quantity);
  return {
    enabled, target:"fullPremium" as const, duration, quantity,
    ...(duration==="month"?{months:quantity}:{}),
    catalogPriceCoins:coins,
    priceCoins:enabled?coins:null,
    priceVersion:enabled?COIN_BENEFIT_PRICE_VERSION:null,
  };
}

/** Add a checked amount of UTC hours, days, weeks or calendar months. */
export function premiumExpiryForDuration(
  start:number, duration:import("./coinBenefitProposal").BenefitDuration,
  quantity:number,
):number {
  if(!Number.isSafeInteger(start)||start<0||
     !Number.isSafeInteger(quantity)||quantity<1||quantity>120) {
    throw new Error("Invalid Premium period");
  }
  if(duration!=="month") {
    const millis = duration==="hour" ? 3_600_000
      : duration==="day" ? 86_400_000
      : duration==="week" ? 604_800_000 : 0;
    if(!millis)throw new Error("Invalid Premium period");
    const out=start+quantity*millis;
    if(!Number.isSafeInteger(out))throw new Error("Invalid Premium expiry");
    return out;
  }
  const date=new Date(start);
  const base=date.getUTCFullYear()*12+date.getUTCMonth()+quantity;
  const year=Math.floor(base/12),month=base%12;
  const lastDay=new Date(Date.UTC(year,month+1,0)).getUTCDate();
  const out=Date.UTC(year,month,Math.min(date.getUTCDate(),lastDay),
    date.getUTCHours(),date.getUTCMinutes(),
    date.getUTCSeconds(),date.getUTCMilliseconds());
  if(!Number.isSafeInteger(out))throw new Error("Invalid Premium expiry");
  return out;
}
