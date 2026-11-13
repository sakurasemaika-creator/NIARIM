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
/**
 * Owner-approved fixed launch reward: one VERIFIED voluntary rewarded
 * ad completion = 10 coins. Actual issuer must still validate AdMob's
 * signed SSV callback, account binding, quota and non-replay.
 * Keep AdMob reward_amount and server offer version aligned.
 */
export const FINAL_COIN_ECONOMY_VERSION = "economy-v2-min10-repriced-20261113" as const;
export const INITIAL_REWARDED_COINS_PER_COMPLETION = 10 as const;
export const INITIAL_REWARD_OFFER_VERSION = "launch-v1-10-coins" as const;
export const REFERENCE_COINS_PER_YEN = 100 as const;
export const PREMIUM_MONTHLY_LIST_PRICE_YEN = 550 as const;
export const PREMIUM_YEARLY_LIST_PRICE_YEN = 5_500 as const;
export const PREMIUM_MONTHLY_REFERENCE_COINS =
  PREMIUM_MONTHLY_LIST_PRICE_YEN * REFERENCE_COINS_PER_YEN;
export const PREMIUM_YEARLY_REFERENCE_COINS =
  PREMIUM_YEARLY_LIST_PRICE_YEN * REFERENCE_COINS_PER_YEN;
