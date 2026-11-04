/**
 * Coin denomination agreed for NIARIM on 2026-11-04.
 *
 * NON-CASH DISPLAY REFERENCE ONLY.
 * These are NOT effective redemption prices, ad reward amounts or a promise
 * of actual impression earnings. Reward coins cannot be cashed out.
 *
 * Actual ad-unit reward amounts are configured in AdMob. A verified SSV
 * transaction, stored offer version and NIARIM User ID will be required
 * before granting coins. No issuance is enabled by this module.
 */
export const REFERENCE_COINS_PER_YEN = 100 as const;
export const PREMIUM_MONTHLY_LIST_PRICE_YEN = 550 as const;
export const PREMIUM_YEARLY_LIST_PRICE_YEN = 5_500 as const;
export const PREMIUM_MONTHLY_REFERENCE_COINS =
  PREMIUM_MONTHLY_LIST_PRICE_YEN * REFERENCE_COINS_PER_YEN;
export const PREMIUM_YEARLY_REFERENCE_COINS =
  PREMIUM_YEARLY_LIST_PRICE_YEN * REFERENCE_COINS_PER_YEN;
