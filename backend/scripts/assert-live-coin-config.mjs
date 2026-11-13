import { readFileSync } from "node:fs";
import { join } from "node:path";

// Run with a read-only AWS role before any future CDK deployment.
// The Lambda environment file contains production secrets; NEVER print it.
// A missing flag is equivalent to "false" only for default-off switches.
const [deployedEnvPath] = process.argv.slice(2);
if (!deployedEnvPath) {
  console.error("Missing protected read-only Lambda environment input.");
  process.exit(2);
}
const context = JSON.parse(
  readFileSync(join(process.cwd(), "cdk.json"), "utf8"),
).context;
const deployed = JSON.parse(readFileSync(deployedEnvPath, "utf8"));
if (deployed === null || typeof deployed !== "object" ||
    Array.isArray(deployed)) {
  console.error(
    "BLOCKED: read-only AWS role cannot inspect Lambda environment. " +
    "Do not perform a full CDK deploy without a verified live configuration.",
  );
  process.exit(1);
}

const booleanFlags = {
  COIN_REDEMPTION_ENABLED: "coinRedemptionEnabled",
  COIN_REDEMPTION_REVIEW_APPROVED: "coinRedemptionReviewApproved",
  COIN_INDIVIDUAL_REDEMPTION_ENABLED: "coinIndividualRedemptionEnabled",
  COIN_INDIVIDUAL_REDEMPTION_REVIEW_APPROVED: "coinIndividualRedemptionReviewApproved",
  COIN_INDIVIDUAL_RIGHTS_CONSUMERS_APPROVED: "coinIndividualRightsConsumersApproved",
  COIN_PREMIUM_ANNUAL_REDEMPTION_ENABLED: "coinPremiumAnnualRedemptionEnabled",
  CREATOR_MISSION_CLAIMS_ENABLED: "creatorMissionClaimsEnabled",
  CREATOR_MISSION_CLAIMS_REVIEW_APPROVED: "creatorMissionClaimsReviewApproved",
  CREATOR_QUALIFIED_WORK_SCAN_ENABLED: "creatorQualifiedWorkScanEnabled",
  CREATOR_RANKING_REWARDS_REVIEW_APPROVED: "creatorRankingRewardsReviewApproved",
  CREATOR_EDIT_SESSION_PILOT_ENABLED: "creatorEditSessionPilotEnabled",
  LOGIN_BONUS_CLAIMS_ENABLED: "loginBonusClaimsEnabled",
  LOGIN_BONUS_REWARDS_REVIEW_APPROVED: "loginBonusRewardsReviewApproved",
  CREATOR_GRID_PAYOUTS_ENABLED: "creatorGridPayoutsEnabled",
  CREATOR_GRID_REWARDS_REVIEW_APPROVED: "creatorGridRewardsReviewApproved",
  RECURRING_MISSION_PAYOUTS_ENABLED: "recurringMissionPayoutsEnabled",
  PLAZA_MISSION_PAYOUTS_ENABLED: "plazaMissionPayoutsEnabled",
  REWARDED_AD_SSV_ENABLED: "rewardedAdSsvEnabled",
  REWARDED_AD_REVIEW_APPROVED: "rewardedAdReviewApproved",
  PLAY_PURCHASE_VERIFICATION_ENABLED: "playPurchaseVerificationEnabled",
};
const exactValues = {
  COIN_FULL_PREMIUM_MONTH_COINS: "coinFullPremiumMonthCoins",
  COIN_FULL_PREMIUM_YEAR_COINS: "coinFullPremiumYearCoins",
  COIN_PRICE_VERSION: "coinPriceVersion",
  REWARDED_AD_DAILY_LIMIT: "rewardedAdDailyLimit",
  ADMOB_REWARDED_AD_UNIT_ID: "admobRewardedAdUnitId",
};
const conflicts = [];
for (const [env, key] of Object.entries(booleanFlags)) {
  const expected = context[key] === "true" ? "true" : "false";
  const current = deployed[env] ?? "false";
  if (current !== expected) conflicts.push(env);
}
for (const [env, key] of Object.entries(exactValues)) {
  const expected = String(context[key] ?? "");
  if (deployed[env] !== expected) conflicts.push(env);
}
if (conflicts.length) {
  console.error(
    "BLOCKED: CDK would overwrite current production coin/reward settings: " +
      conflicts.join(", "),
  );
  process.exit(1);
}
console.log(
  "PASS: CDK context matches all " +
  (Object.keys(booleanFlags).length + Object.keys(exactValues).length) +
  " protected live coin/reward settings (no secret values logged).",
);
