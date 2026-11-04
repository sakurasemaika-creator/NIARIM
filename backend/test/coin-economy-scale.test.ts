import { describe, expect, it } from "vitest";
import {
  INITIAL_REWARDED_COINS_PER_COMPLETION,
  INITIAL_REWARD_OFFER_VERSION,
  REFERENCE_COINS_PER_YEN,
  PREMIUM_MONTHLY_REFERENCE_COINS,
  PREMIUM_YEARLY_REFERENCE_COINS,
} from "../src/lib/coinEconomyScale";

describe("launch rewarded coin design constants", () => {
  it("starts with ten whole coins per rewarded ad", () => {
    expect(INITIAL_REWARDED_COINS_PER_COMPLETION).toBe(10);
    expect(INITIAL_REWARD_OFFER_VERSION).toBe("launch-v1-10-coins");
  });
  it("retains the non-cash display reference of 100 coins per yen", () => {
    expect(REFERENCE_COINS_PER_YEN).toBe(100);
    expect(PREMIUM_MONTHLY_REFERENCE_COINS).toBe(55000);
    expect(PREMIUM_YEARLY_REFERENCE_COINS).toBe(550000);
  });
});
