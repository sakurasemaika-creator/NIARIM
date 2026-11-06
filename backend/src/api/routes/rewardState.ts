import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { badRequest, ok } from "../../lib/response";
import { rewardedAdConfiguration } from "./rewardedAd";
import { premiumRedemptionOffer } from "../../lib/coinRedemption";
import { remainingRewardedGrants, rewardAdDailyQuota } from "../../lib/rewardAdQuota";

/**
 * Read-only reward wallet endpoint. Google ID token -> NIARIM user ID is
 * verified server-side. Never accept an arbitrary user ID from the caller.
 * Real coin issuance/exchange remains disabled until SSV + atomic ledger exist.
 */
export async function getMyRewardState(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const now = Date.now();
  const adConfig = rewardedAdConfiguration();
  const adQuota = rewardAdDailyQuota(now);
  const [wallet, entitlementPage, adCount] = await Promise.all([
    ddb.send(
      new GetCommand({
        TableName: tableName(),
        Key: Keys.coinWallet(auth.niarimUserId),
        ConsistentRead: true,
      }),
    ),
    ddb.send(
      new QueryCommand({
        TableName: tableName(),
        KeyConditionExpression: "pk = :owner AND begins_with(sk, :prefix)",
        ExpressionAttributeValues: {
          ":owner": `USER#${auth.niarimUserId}`,
          ":prefix": "ENTITLEMENT#",
        },
        ConsistentRead: true,
        Limit: 100,
      }),
    ),
    adConfig.enabled && adQuota.limit !== null
      ? ddb.send(new GetCommand({
          TableName: tableName(),
          Key: Keys.rewardAdDailyCount(auth.niarimUserId, adQuota.dayUtc),
          ConsistentRead: true,
        }))
      : Promise.resolve(null),
  ]);

  const coin = wallet.Item;
  // This row is only written by the future verified SSV wallet service.
  // Missing wallet means zero verified spendable coins, never an error.
  const balanceCoins =
    coin?.itemType === "COIN_WALLET" &&
    typeof coin.balanceCoins === "number" &&
    Number.isSafeInteger(coin.balanceCoins) &&
    coin.balanceCoins >= 0
      ? coin.balanceCoins as number
      : 0;
  const entitlements = (entitlementPage.Items ?? [])
    .filter((row) =>
      row.itemType === "REWARD_ENTITLEMENT" &&
      typeof row.entitlement === "string" &&
      (row.status === "active" || row.status === "paused") &&
      Number.isSafeInteger(row.expiresAtEpochMs)
    )
    .map((row) => ({
      feature: row.entitlement as string,
      status: row.status as string,
      expiresAtEpochMs: row.expiresAtEpochMs as number,
      pausedRemainingSeconds: row.status === "paused" &&
        Number.isSafeInteger(row.pausedRemainingSeconds) &&
        row.pausedRemainingSeconds >= 0
          ? row.pausedRemainingSeconds as number
          : null,
    }))
    .filter((row) => row.status === "paused" ||
      row.expiresAtEpochMs > now);

  return ok({
    niarimUserId: auth.niarimUserId,
    balanceCoins,
    entitlements,
    membershipTier: auth.membershipTier,
    // Actual ad availability remains dependent on AdMob inventory and
    // AdMob's independently configured frequency caps. This counter only
    // tracks NIARIM-verifiable COIN GRANTS on a UTC day.
    rewardEarningEnabled: adConfig.enabled,
    rewardedOfferVersion: adConfig.version,
    rewardedCoinsPerCompletion: adConfig.amount,
    rewardedDailyLimit: adConfig.enabled ? adQuota.limit : null,
    rewardedDailyRemaining: adConfig.enabled
      ? remainingRewardedGrants(adQuota.limit, adCount?.Item?.consumed)
      : null,
    rewardedDailyResetAtEpochMs: adConfig.enabled && adQuota.limit !== null
      ? adQuota.resetsAtEpochMs : null,
    redemptionEnabled: premiumRedemptionOffer().enabled,
  });
}

// Read-only, authenticated chronological journal. No client writes.
export async function getMyCoinHistory(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const requestedLimit = event.queryStringParameters?.limit ?? "20";
  if (!/^[1-9][0-9]?$/.test(requestedLimit) ||
      Number(requestedLimit) > 50) {
    badRequest("履歴の取得件数が不正です", "COIN_HISTORY_INVALID_LIMIT");
  }
  const limit = Number(requestedLimit);
  const token = event.queryStringParameters?.cursor;
  let exclusiveStartKey: { pk: string; sk: string } | undefined;
  if (token !== undefined) {
    if (!/^[A-Za-z0-9_-]{1,512}$/.test(token)) {
      badRequest("履歴のカーソルが不正です", "COIN_HISTORY_INVALID_CURSOR");
    }
    const sk = Buffer.from(token, "base64url").toString("utf8");
    if (!/^COIN_HISTORY#[0-9]{13}#[A-Za-z0-9_-]{1,160}$/.test(sk)) {
      badRequest("履歴のカーソルが不正です", "COIN_HISTORY_INVALID_CURSOR");
    }
    // A cursor never sets user identity; only the bearer token may do so.
    exclusiveStartKey = { pk: `USER#${auth.niarimUserId}`, sk };
  }
  const page = await ddb.send(new QueryCommand({
    TableName: tableName(),
    KeyConditionExpression: "pk = :owner AND begins_with(sk, :prefix)",
    ExpressionAttributeValues: {
      ":owner": `USER#${auth.niarimUserId}`,
      ":prefix": "COIN_HISTORY#",
    },
    ExclusiveStartKey: exclusiveStartKey,
    ScanIndexForward: true,
    ConsistentRead: true,
    Limit: limit,
  }));
  const entries = (page.Items ?? [])
    .filter((row) =>
      row.itemType === "COIN_HISTORY" &&
      typeof row.source === "string" &&
      Number.isSafeInteger(row.deltaCoins) &&
      Number.isSafeInteger(row.occurredAtEpochMs))
    .map((row) => ({
      source: row.source as string,
      deltaCoins: row.deltaCoins as number,
      occurredAtEpochMs: row.occurredAtEpochMs as number,
      missionId: typeof row.missionId === "string" ? row.missionId : null,
      workId: typeof row.workId === "string" ? row.workId : null,
      target: typeof row.target === "string" ? row.target : null,
    }));
  const lastSk = page.LastEvaluatedKey?.sk;
  return ok({
    entries,
    nextCursor: typeof lastSk === "string"
      ? Buffer.from(lastSk, "utf8").toString("base64url") : null,
  });
}
