import { randomUUID } from "node:crypto";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  ConditionalCheckFailedException, TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import {
  GetCommand, TransactWriteCommand, UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { ApiError, conflict, forbidden, json, ok } from "../../lib/response";
import {
  admobPublicKeys, SsvVerificationError,
  validateAdmobOffer, verifyAdmobSsv,
} from "../../lib/admobSsv";
import { INITIAL_REWARDED_COINS_PER_COMPLETION,
  INITIAL_REWARD_OFFER_VERSION } from "../../lib/coinEconomyScale";
import {
  dailyRewardLimit, remainingRewardedGrants, rewardAdUtcDay,
} from "../../lib/rewardAdQuota";

/**
 * Explicit kill switch. No ad grants, sessions or SSV key downloads until the
 * owner enters a production rewarded-ad unit and deliberately enables it.
 * This endpoint is NOT a general coin deposit API.
 */
export function rewardedAdConfiguration() {
  const adUnit = process.env.ADMOB_REWARDED_AD_UNIT_ID ?? "";
  const rawCap = process.env.REWARDED_AD_DAILY_LIMIT ?? "";
  // A typo in the production cap must DISABLE grants, never silently
  // convert a limited offer into unlimited rewards.
  const capIsValid = rawCap === "" || dailyRewardLimit() !== null;
  const enabled = capIsValid &&
    process.env.REWARDED_AD_SSV_ENABLED === "true" &&
    /^ca-app-pub-[0-9]{16}\/[0-9]{10}$/.test(adUnit) &&
    !adUnit.startsWith("ca-app-pub-3940256099942544/") &&
    process.env.REWARDED_AD_REVIEW_APPROVED === "true";
  return {
    enabled, adUnitId: adUnit,
    amount: INITIAL_REWARDED_COINS_PER_COMPLETION,
    version: INITIAL_REWARD_OFFER_VERSION,
  };
}
const SESSION_LIFETIME_MS = 30 * 60_000;
const SESSION_COOLDOWN_MS = 30_000;
const RECEIPT_LIFETIME_SECONDS = 30 * 24 * 3600;

export async function startRewardedAdSession(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const config = rewardedAdConfiguration();
  if (!config.enabled) forbidden("報酬広告は準備中です", "REWARDED_AD_DISABLED");

  const now = Date.now();
  const limit = dailyRewardLimit();
  let remainingToday: number | null = null;
  if (limit !== null) {
    const day = rewardAdUtcDay(now);
    const counter = await ddb.send(new GetCommand({
      TableName: tableName(),
      Key: Keys.rewardAdDailyCount(auth.niarimUserId, day),
      ConsistentRead: true,
    }));
    remainingToday = remainingRewardedGrants(limit, counter.Item?.consumed);
    if (remainingToday === 0) {
      forbidden("本日の広告コイン獲得上限に達しました",
        "REWARDED_AD_DAILY_LIMIT");
    }
  }
  const nonce = randomUUID();
  const key = Keys.rewardedAdSession(auth.niarimUserId);
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: key,
      UpdateExpression:
        "SET itemType = :type, nonce = :nonce, issuedAtMs = :issued, " +
        "expiresAtMs = :expires, offerVersion = :version, " +
        "rewardCoins = :amount REMOVE consumedAtMs",
      ConditionExpression:
        "attribute_not_exists(issuedAtMs) OR issuedAtMs <= :cooldown",
      ExpressionAttributeValues: {
        ":type": "REWARDED_AD_SESSION",
        ":nonce": nonce,
        ":issued": now,
        ":expires": now + SESSION_LIFETIME_MS,
        ":version": config.version,
        ":amount": config.amount,
        ":cooldown": now - SESSION_COOLDOWN_MS,
      },
    }));
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) {
      conflict("次の広告まで少し時間を空けてください", "REWARD_AD_COOLDOWN");
    }
    throw error;
  }
  return ok({
    adUnitId: config.adUnitId,
    rewardCoins: config.amount,
    offerVersion: config.version,
    customData: `v1.${auth.niarimUserId}.${nonce}`,
    dailyRewardLimit: limit,
    dailyRewardRemaining: remainingToday,
    expiresAtEpochMs: now + SESSION_LIFETIME_MS,
  });
}

/**
 * Google calls GET /admob/ssv without a user bearer token. Every supplied
 * field is cryptographically signed with a rotating AdMob ECDSA key.
 * The signed customData MUST match a server-issued, unconsumed session.
 */
export async function receiveRewardedAdSsv(event: APIGatewayProxyEventV2) {
  const config = rewardedAdConfiguration();
  if (!config.enabled) forbidden("広告報酬は無効です", "REWARDED_AD_DISABLED");
  let reward;
  let identity;
  try {
    reward = await verifyAdmobSsv(event.rawQueryString ?? "", admobPublicKeys);
    identity = validateAdmobOffer(reward, {
      adUnitId: config.adUnitId,
      amount: config.amount,
      nowMs: Date.now(),
    });
  } catch (error) {
    if (error instanceof SsvVerificationError) {
      throw new ApiError(
        error.temporary ? 503 : 403,
        error.temporary ? "検証鍵を取得できません" : "不正な広告報酬通知",
        error.temporary ? "SSV_KEY_TEMPORARY" : "INVALID_SSV",
      );
    }
    throw error;
  }
  const { userId, nonce } = identity;
  const transactionId = reward.transactionId.toLowerCase();
  const receiptKey = Keys.admobReceipt(transactionId);
  const sessionKey = Keys.rewardedAdSession(userId);
  const now = Date.now();
  const dailyCap = dailyRewardLimit();
  const watchedDayUtc = rewardAdUtcDay(reward.timestampMs);
  try {
    // One indivisible transaction: global receipt prevents replay across
    // accounts, and an optional 4th item enforces the daily coin-grant cap.
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {
          Put: {
            TableName: tableName(),
            Item: {
              ...receiptKey,
              itemType: "REWARDED_AD_RECEIPT",
              niarimUserId: userId,
              transactionId,
              offerVersion: config.version,
              earnedCoins: config.amount,
              receivedAtMs: now,
              // TTL is a storage optimisation; a 7-day signed timestamp
              // boundary prevents old callbacks from becoming valid again.
              ttl: Math.floor(now / 1000) + RECEIPT_LIFETIME_SECONDS,
            },
            ConditionExpression: "attribute_not_exists(pk)",
          },
        },
        {
          Update: {
            TableName: tableName(),
            Key: sessionKey,
            UpdateExpression: "SET consumedAtMs = :now",
            ConditionExpression:
              "itemType = :type AND nonce = :nonce AND " +
              "issuedAtMs <= :adTimestamp AND expiresAtMs >= :adTimestamp " +
              "AND offerVersion = :version AND rewardCoins = :amount " +
              "AND attribute_not_exists(consumedAtMs)",
            ExpressionAttributeValues: {
              ":type": "REWARDED_AD_SESSION",
              ":nonce": nonce,
              ":now": now,
              ":adTimestamp": reward.timestampMs,
              ":version": config.version,
              ":amount": config.amount,
            },
          },
        },
        ...(dailyCap === null ? [] : [{
          Update: {
            TableName: tableName(),
            Key: Keys.rewardAdDailyCount(userId, watchedDayUtc),
            UpdateExpression:
              "SET itemType = :type, ttl = :ttl ADD consumed :one",
            ConditionExpression:
              "attribute_not_exists(consumed) OR consumed < :limit",
            ExpressionAttributeValues: {
              ":type": "REWARDED_AD_DAY",
              ":ttl": Math.floor(now / 1000) + RECEIPT_LIFETIME_SECONDS,
              ":one": 1,
              ":limit": dailyCap,
            },
          },
        }]),
        {
          Update: {
            TableName: tableName(),
            Key: Keys.coinWallet(userId),
            UpdateExpression:
              "SET itemType = :type, updatedAtEpochMs = :now " +
              "ADD balanceCoins :reward, rewardedEarnedCoins :reward",
            ConditionExpression:
              "(attribute_not_exists(itemType) OR itemType = :type) " +
              "AND (attribute_not_exists(balanceCoins) OR balanceCoins < :limit)",
            ExpressionAttributeValues: {
              ":type": "COIN_WALLET",
              ":now": now,
              ":reward": config.amount,
              ":limit": Number.MAX_SAFE_INTEGER - config.amount,
            },
          },
        },
      ],
    }));
  } catch (error) {
    if (error instanceof TransactionCanceledException ||
        error instanceof ConditionalCheckFailedException) {
      // Google retries lost acknowledgments. A duplicate receipt for the
      // SAME account/event is already settled; return 200, never credit twice.
      const existing = await ddb.send(new GetCommand({
        TableName: tableName(), Key: receiptKey, ConsistentRead: true,
      }));
      if (existing.Item?.itemType === "REWARDED_AD_RECEIPT" &&
          existing.Item.niarimUserId === userId &&
          existing.Item.earnedCoins === config.amount) {
        return ok({ credited: true, duplicate: true });
      }
      conflict("報酬セッションを確認できません", "SSV_SESSION_CONFLICT");
    }
    throw error;
  }
  return ok({ credited: true });
}
