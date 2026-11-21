import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "./dynamo";
import type { MembershipTier } from "./types";

/**
 * The same NIARIM User ID used by works, follow and bookmark records owns
 * reward entitlements. Clients must never be allowed to write these rows.
 * Only a future verified SSV+wallet transaction may create/extend them.
 */
export type RewardEntitlementName = "communityPostQuota" | "fullPremium";

interface RewardEntitlementRecord {
  itemType: "REWARD_ENTITLEMENT";
  entitlement: RewardEntitlementName;
  status: "active" | "paused";
  expiresAtEpochMs: number;
  // Stored separately for subscription pause/resume; paused must never unlock.
  pausedRemainingSeconds?: number;
}

export function isActiveRewardEntitlement(
  record: unknown,
  target: RewardEntitlementName,
  now: Date,
): boolean {
  if (!record || typeof record !== "object") return false;
  const item = record as Partial<RewardEntitlementRecord>;
  return (
    item.itemType === "REWARD_ENTITLEMENT" &&
    item.entitlement === target &&
    item.status === "active" &&
    typeof item.expiresAtEpochMs === "number" &&
    Number.isSafeInteger(item.expiresAtEpochMs) &&
    item.expiresAtEpochMs > now.getTime()
  );
}

/**
 * Resolves extra posting quota only from the **server-side** membership tier
 * or time-bounded reward entitlements. No query/body flag is accepted.
 *
 * NOTE: membershipTier must be synchronized through VERIFIED Play Billing.
 * Today new backend users default to "free" until that integration exists.
 */
export async function resolvePostMembershipTier(
  niarimUserId: string,
  membershipTier: MembershipTier,
  now: Date = new Date(),
): Promise<MembershipTier> {
  if (membershipTier === "premium") return "premium";

  const targets: RewardEntitlementName[] = [
    "communityPostQuota",
    "fullPremium",
  ];
  const records = await Promise.all(
    targets.map(async (target) => {
      const response = await ddb.send(
        new GetCommand({
          TableName: tableName(),
          Key: Keys.rewardEntitlement(niarimUserId, target),
          ConsistentRead: true,
        }),
      );
      return { target, record: response.Item };
    }),
  );
  return records.some(({ target, record }) =>
    isActiveRewardEntitlement(record, target, now)
  )
    ? "premium"
    : "free";
}
