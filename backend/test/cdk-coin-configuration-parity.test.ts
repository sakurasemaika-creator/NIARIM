import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  COIN_BENEFIT_PRICE_VERSION,
  FINAL_PREMIUM_MONTHLY_COINS,
  FINAL_PREMIUM_YEARLY_COINS,
} from "../src/lib/coinBenefitProposal";

const cdkContext = JSON.parse(
  readFileSync("cdk.json", "utf8"),
).context as Record<string, unknown>;
const cdkStack = readFileSync("lib/niarim-backend-stack.ts", "utf8");

describe("CDK must not silently roll back active coin and reward configuration", () => {
  it("bundles the same immutable price catalog version as the app/backend", () => {
    expect(cdkContext.coinPriceVersion).toBe(COIN_BENEFIT_PRICE_VERSION);
    expect(cdkContext.coinFullPremiumMonthCoins)
      .toBe(String(FINAL_PREMIUM_MONTHLY_COINS));
    expect(cdkContext.coinFullPremiumYearCoins)
      .toBe(String(FINAL_PREMIUM_YEARLY_COINS));
  });

  it("requires independent rights-consumer and transaction review switches", () => {
    expect(cdkStack).toContain("COIN_INDIVIDUAL_REDEMPTION_REVIEW_APPROVED:");
    expect(cdkStack).toContain("COIN_INDIVIDUAL_RIGHTS_CONSUMERS_APPROVED:");
    expect(cdkStack).toContain("COIN_PREMIUM_ANNUAL_REDEMPTION_ENABLED:");
    for (const key of [
      "coinIndividualRedemptionReviewApproved",
      "coinIndividualRightsConsumersApproved",
      "coinPremiumAnnualRedemptionEnabled",
      "coinRedemptionReviewApproved",
    ]) {
      expect(["true", "false"]).toContain(cdkContext[key]);
    }
  });

  it("keeps recurring and plaza payout switches under CDK management", () => {
    expect(cdkStack).toContain("RECURRING_MISSION_PAYOUTS_ENABLED:");
    expect(cdkStack).toContain("PLAZA_MISSION_PAYOUTS_ENABLED:");
    expect(["true", "false"]).toContain(
      cdkContext.recurringMissionPayoutsEnabled,
    );
    expect(["true", "false"]).toContain(
      cdkContext.plazaMissionPayoutsEnabled,
    );
  });
});
