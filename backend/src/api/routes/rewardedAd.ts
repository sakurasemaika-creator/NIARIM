import { randomUUID } from "node:crypto";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  ConditionalCheckFailedException, TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import {
  GetCommand, PutCommand, TransactWriteCommand,
} from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { ApiError, badRequest, conflict, forbidden, json, ok } from "../../lib/response";
import {
  admobPublicKeys, SsvVerificationError,
  signedRewardSession, validateAdmobOffer, verifyAdmobSsv,
} from "../../lib/admobSsv";
import { INITIAL_REWARDED_COINS_PER_COMPLETION,
  INITIAL_REWARD_OFFER_VERSION } from "../../lib/coinEconomyScale";
import {
  dailyRewardLimit, remainingRewardedGrants, rewardAdUtcDay,
} from "../../lib/rewardAdQuota";
import { parseJsonObject } from "../../lib/request";
import { regionalRewardAdOffer, rewardAdTiers, rewardCountryPattern, rewardReportDay } from "../../lib/rewardAdRates";

/**
 * Explicit kill switch. No ad grants, sessions or SSV key downloads until the
 * owner enters a production rewarded-ad unit and deliberately enables it.
 * This endpoint is NOT a general coin deposit API.
 */
export function rewardedAdConfiguration() {
  const adUnit = process.env.ADMOB_REWARDED_AD_UNIT_ID ?? "";
  const rawCap = process.env.REWARDED_AD_DAILY_LIMIT ?? "";
  const capIsValid = rawCap === "unlimited" || dailyRewardLimit() !== null;
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
const RECEIPT_LIFETIME_SECONDS = 30 * 24 * 3600;

async function findRewardedAdSession(userId: string, nonce: string) {
  const table = tableName();
  const key = Keys.rewardedAdSession(userId, nonce);
  const { Item } = await ddb.send(new GetCommand({ TableName: table, Key: key, ConsistentRead: true }));
  if (Item) return { key, item: Item };
  // Earlier app requests used one record per account. In-flight watches can
  // still settle against that record after new requests start using nonce keys.
  const legacyKey = Keys.rewardedAdSession(userId);
  const { Item: legacy } = await ddb.send(new GetCommand({
    TableName: table, Key: legacyKey, ConsistentRead: true,
  }));
  return { key: legacyKey, item: legacy };
}

export async function startRewardedAdSession(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const now = Date.now();
  const config = await regionalRewardAdOffer(
    rewardedAdConfiguration(), event.requestContext?.http?.sourceIp, now,
  );
  if (!config.enabled) forbidden("報酬広告は準備中です", "REWARDED_AD_DISABLED");
  const quote = event.body ? parseJsonObject(event.body) : {};
  if ((quote.offerVersion !== undefined || config.version !== INITIAL_REWARD_OFFER_VERSION) &&
      (quote.offerVersion !== config.version || quote.rewardCoins !== config.amount)) {
    conflict("広告報酬が変わりました。もう一度確認してください", "REWARDED_AD_OFFER_CHANGED");
  }
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
  const expiresAtMs = now + SESSION_LIFETIME_MS;
  await ddb.send(new PutCommand({
    TableName: tableName(),
    Item: {
      ...Keys.rewardedAdSession(auth.niarimUserId, nonce),
      itemType: "REWARDED_AD_SESSION", nonce, issuedAtMs: now, expiresAtMs,
      offerVersion: config.version, rewardCoins: config.amount, adUnitId: config.adUnitId,
      rewardCountry: config.country ?? null,
      ttl: Math.floor(expiresAtMs / 1000) + 8 * 24 * 3600,
    },
    ConditionExpression: "attribute_not_exists(pk)",
  }));
  return ok({
    adUnitId: config.adUnitId,
    rewardCoins: config.amount,
    offerVersion: config.version,
    customData: `${config.country ? "v2" : "v1"}.${auth.niarimUserId}.${nonce}`,
    dailyRewardLimit: limit,
    dailyRewardRemaining: remainingToday,
    expiresAtEpochMs: expiresAtMs,
  });
}

/**
 * Read-only, owner-bound receipt status. Session consumption and wallet credit
 * occur in the SAME DynamoDB transaction, so consumedAtMs is a server-side
 * proof. A Flutter callback alone cannot mark an ad as paid.
 */
export async function getRewardedAdStatus(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const nonce = event.queryStringParameters?.nonce;
  if (!nonce || !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(nonce)) {
    badRequest("広告セッションIDが不正です", "REWARDED_AD_INVALID_NONCE");
  }
  const { item: session } = await findRewardedAdSession(auth.niarimUserId, nonce);
  if (session?.itemType !== "REWARDED_AD_SESSION" ||
      session.nonce !== nonce) {
    return ok({credited: false, status: "not_found"});
  }
  if (typeof session.consumedAtMs === "number" &&
      Number.isSafeInteger(session.consumedAtMs) &&
      session.consumedAtMs > 0) {
    return ok({credited: true, status: "credited"});
  }
  if (typeof session.expiresAtMs === "number" &&
      Number.isSafeInteger(session.expiresAtMs) &&
      session.expiresAtMs < Date.now()) {
    return ok({credited: false, status: "expired"});
  }
  return ok({credited: false, status: "pending"});
}

/**
 * Google calls GET /admob/ssv without a user bearer token. Every supplied
 * field is cryptographically signed with a rotating AdMob ECDSA key.
 * The signed customData MUST match a server-issued, unconsumed session.
 */
export async function receiveRewardedAdSsv(event: APIGatewayProxyEventV2) {
  const config = rewardedAdConfiguration();
  const now = Date.now();
  let settledOffer: { adUnitId: string; amount: number; version: string; country?: string } = config;
  let regional = false;
  let reward;
  let identity;
  let sessionKey: ReturnType<typeof Keys.rewardedAdSession>;
  try {
    // Always verify Google's ECDSA signature BEFORE acknowledging a
    // callback, even if issuance is disabled. AdMob's URL verification
    // sends a real signed callback without an app-issued custom_data value.
    reward = await verifyAdmobSsv(event.rawQueryString ?? "", admobPublicKeys);
    if (!reward.customData) {
      let configuredAmount = reward.rewardAmount === config.amount;
      if (!configuredAmount && process.env.REWARDED_AD_UNIT_TIERS) {
        const unit = rewardAdTiers(process.env.REWARDED_AD_UNIT_TIERS, config.adUnitId)
          .get(reward.rewardAmount);
        configuredAmount = unit?.split("/")[1] === reward.adUnit;
      }
      // Google's AdMob "Verify URL" tool signs a test callback using
      // an ad_unit that may differ from the production unit. Accept only
      // signed, unbound connectivity checks, which NEVER reach DynamoDB.
      // User-bound rewards still require the exact production ad unit in
      // validateAdmobOffer and the server-issued session transaction.
      if (!reward.adUnit || reward.adUnit.length > 128 ||
          reward.rewardItem !== "coins" ||
          !configuredAmount ||
          reward.timestampMs > now + 5 * 60_000 ||
          now - reward.timestampMs > 60 * 60_000) {
        throw new SsvVerificationError("Unbound AdMob verification mismatch");
      }
      // Nothing is written to DynamoDB and no coins can be granted.
      // This is a signed connectivity acknowledgment, NOT a reward.
      return ok({ verified: true, credited: false });
    }
    if (!config.enabled) forbidden("広告報酬は無効です", "REWARDED_AD_DISABLED");
    regional = reward.customData.startsWith("v2.");
    identity = regional
      ? signedRewardSession(reward.customData)
      : validateAdmobOffer(reward, { adUnitId: config.adUnitId, amount: config.amount, nowMs: now });
    if (reward.rewardItem !== "coins" || reward.timestampMs > now + 5 * 60_000 ||
        now - reward.timestampMs > 7 * 86_400_000) {
      throw new SsvVerificationError("Reward or timestamp mismatch");
    }
    const found = await findRewardedAdSession(identity.userId, identity.nonce);
    sessionKey = found.key;
    const { item: Item } = found;
    if (Item?.itemType !== "REWARDED_AD_SESSION" || Item.nonce !== identity.nonce) {
      const { Item: receipt } = await ddb.send(new GetCommand({
        TableName: tableName(),
        Key: Keys.admobReceipt(reward.transactionId.toLowerCase()),
        ConsistentRead: true,
      }));
      if (receipt?.itemType === "REWARDED_AD_RECEIPT" &&
          receipt.niarimUserId === identity.userId && receipt.sessionNonce === identity.nonce &&
          receipt.adUnitSuffix === reward.adUnit && receipt.earnedCoins === reward.rewardAmount) {
        return ok({ credited: true, duplicate: true });
      }
      conflict("報酬セッションを確認できません", "SSV_SESSION_CONFLICT");
    }
    if (regional) {
      if (typeof Item.adUnitId !== "string" || typeof Item.offerVersion !== "string" ||
          !Number.isSafeInteger(Item.rewardCoins) || Item.rewardCoins < 1 || Item.rewardCoins > 100 ||
          typeof Item.rewardCountry !== "string" || !rewardCountryPattern.test(Item.rewardCountry)) {
        throw new SsvVerificationError("Invalid stored regional reward offer");
      }
      settledOffer = {
        adUnitId: Item.adUnitId, amount: Item.rewardCoins,
        version: Item.offerVersion, country: Item.rewardCountry,
      };
      validateAdmobOffer(reward, {
        adUnitId: settledOffer.adUnitId, amount: settledOffer.amount, nowMs: now,
      });
    }
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
  const dailyCap = dailyRewardLimit();
  const watchedDayUtc = rewardAdUtcDay(reward.timestampMs);
  try {
    // The receipt and session prevent duplicate payments in the same write
    // as the balance. A cap counter is included only if a cap is configured.
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
              offerVersion: settledOffer.version,
              earnedCoins: settledOffer.amount,
              sessionNonce: nonce,
              adUnitSuffix: reward.adUnit,
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
              "AND attribute_not_exists(consumedAtMs)" +
              (regional ? " AND adUnitId = :unit AND rewardCountry = :country" : ""),
            ExpressionAttributeValues: {
              ":type": "REWARDED_AD_SESSION",
              ":nonce": nonce,
              ":now": now,
              ":adTimestamp": reward.timestampMs,
              ":version": settledOffer.version,
              ":amount": settledOffer.amount,
              ...(regional ? { ":unit": settledOffer.adUnitId, ":country": settledOffer.country } : {}),
            },
          },
        },
        ...(dailyCap === null ? [] : [{
          Update: {
            TableName: tableName(),
            Key: Keys.rewardAdDailyCount(userId, watchedDayUtc),
            UpdateExpression:
              "SET itemType = :type, #ttl = :ttl ADD #consumed :one",
            ExpressionAttributeNames: {
              "#ttl": "ttl",
              "#consumed": "consumed",
            },
            ConditionExpression:
              "attribute_not_exists(#consumed) OR #consumed < :limit",
            ExpressionAttributeValues: {
              ":type": "REWARDED_AD_DAY",
              ":ttl": Math.floor(now / 1000) + RECEIPT_LIFETIME_SECONDS,
              ":one": 1,
              ":limit": dailyCap,
            },
          },
        }]),
        ...(settledOffer.country ? [{
          Update: {
            TableName: tableName(),
            Key: Keys.rewardAdCountryDay(rewardReportDay(reward.timestampMs), settledOffer.country),
            UpdateExpression: "SET #ttl = :ttl ADD completions :one",
            ExpressionAttributeNames: { "#ttl": "ttl" },
            ExpressionAttributeValues: {
              ":ttl": Math.floor(now / 1000) + 40 * 24 * 3600,
              ":one": 1,
            },
          },
        }] : []),
        {
          Put: {
            TableName: tableName(),
            Item: {
              ...Keys.coinHistory(userId, reward.timestampMs, `admob-${transactionId}`),
              itemType: "COIN_HISTORY", source: "rewarded-ad",
              deltaCoins: settledOffer.amount, occurredAtEpochMs: reward.timestampMs,
              transactionId,
            },
            ConditionExpression: "attribute_not_exists(pk)",
          },
        },
        {
          Update: {
            TableName: tableName(),
            Key: Keys.coinWallet(userId),
            UpdateExpression:
              "SET itemType = :type, updatedAtEpochMs = :now " +
              "ADD balanceCoins :reward, rewardedEarnedCoins :reward",
            ConditionExpression:
              "(attribute_not_exists(itemType) OR itemType = :type) " +
              "AND (attribute_not_exists(balanceCoins) OR " +
              "balanceCoins BETWEEN :zero AND :limit)",
            ExpressionAttributeValues: {
              ":type": "COIN_WALLET",
              ":now": now,
              ":reward": settledOffer.amount,
              ":zero": 0,
              ":limit": Number.MAX_SAFE_INTEGER - settledOffer.amount,
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
          existing.Item.earnedCoins === settledOffer.amount &&
          (!regional || (existing.Item.sessionNonce === nonce &&
            existing.Item.adUnitSuffix === reward.adUnit))) {
        return ok({ credited: true, duplicate: true });
      }
      conflict("報酬セッションを確認できません", "SSV_SESSION_CONFLICT");
    }
    throw error;
  }
  return ok({ credited: true });
}
