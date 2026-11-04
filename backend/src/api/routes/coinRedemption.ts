import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  ConditionalCheckFailedException, TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import { GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate, getUser } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { badRequest, conflict, forbidden, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import { addOneCalendarMonthUtc, premiumRedemptionOffer } from "../../lib/coinRedemption";

/** Read quote from the same server configuration used for spending. */
export async function getCoinRedemptionQuote(event: APIGatewayProxyEventV2) {
  await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const target = event.queryStringParameters?.target ?? "fullPremium";
  const months = event.queryStringParameters?.months ?? "1";
  if (target !== "fullPremium" || months !== "1") {
    badRequest("この特典・期間の交換は準備中です", "REDEMPTION_NOT_AVAILABLE");
  }
  return ok(premiumRedemptionOffer());
}

/**
 * NO CLIENT-SUPPLIED AMOUNTS. One confirmed, atomic transaction:
 * 1) immutable per-user receipt, 2) conditional wallet debit,
 * 3) conditional entitlement extension. Retried requestId returns only
 * the receipt, never charges a second time.
 */
export async function redeemCoins(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const offer = premiumRedemptionOffer();
  if (!offer.enabled || offer.priceCoins === null ||
      offer.priceVersion === null) {
    forbidden("コイン交換は準備中です", "REDEMPTION_DISABLED");
  }
  const body = parseJsonObject(event.body);
  if (body.target !== "fullPremium" || body.months !== 1) {
    badRequest("この交換内容は準備中です", "REDEMPTION_NOT_AVAILABLE");
  }
  const requestId = body.requestId;
  if (typeof requestId !== "string" ||
      !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(requestId)) {
    badRequest("リクエストIDが不正です", "REDEMPTION_REQUEST_ID_INVALID");
  }
  const receiptKey = Keys.coinTransaction(
    auth.niarimUserId, `redeem-${requestId}`);
  // A lost response may arrive after a price change. Retry the old,
  // authenticated receipt first; NEVER charge the same request again.
  const already = await ddb.send(new GetCommand({
    TableName: tableName(), Key: receiptKey, ConsistentRead: true,
  }));
  if (already.Item) {
    if (already.Item.itemType !== "COIN_REDEMPTION" ||
        already.Item.target !== "fullPremium" ||
        already.Item.months !== 1 ||
        already.Item.priceVersion !== body.priceVersion ||
        !Number.isSafeInteger(already.Item.costCoins) ||
        !Number.isSafeInteger(already.Item.expiresAtEpochMs)) {
      conflict("交換履歴が一致しません", "REDEMPTION_REQUEST_REUSED");
    }
    return ok({
      redeemed: true, duplicate: true,
      target: "fullPremium", costCoins: already.Item.costCoins,
      expiresAtEpochMs: already.Item.expiresAtEpochMs,
    });
  }
  if (body.priceVersion !== offer.priceVersion) {
    conflict("交換価格が変更されました。再確認してください",
      "REDEMPTION_PRICE_CHANGED");
  }
  const user = await getUser(auth.niarimUserId);
  const preflightNow = Date.now();
  // A stale 15-minute verification lease must NOT imply that the Play
  // subscription's paid term has ended. Fail closed until its known expiry
  // or an authoritative cancellation/revocation re-check clears it.
  const playTermNotExpired =
    typeof user?.playPremiumExpiresAtEpochMs === "number" &&
    Number.isSafeInteger(user.playPremiumExpiresAtEpochMs) &&
    user.playPremiumExpiresAtEpochMs > preflightNow;
  if (!user || user.itemType !== "USER" ||
      user.membershipTier !== "free" || playTermNotExpired) {
    // A coin-funded Premium membership is allowed to add another month.
    // An active Play subscription still requires separate pause/resume logic.
    forbidden("購入済み会員の交換延長は準備中です",
      "REDEMPTION_SUBSCRIPTION_CONFLICT");
  }

  const entitlementKey = Keys.rewardEntitlement(
    auth.niarimUserId, "fullPremium");
  const current = await ddb.send(new GetCommand({
    TableName: tableName(),
    Key: entitlementKey, ConsistentRead: true,
  }));
  const previous = current.Item as Record<string, unknown> | undefined;
  if (previous?.status === "paused") {
    conflict("一時停止中の特典の延長は準備中です",
      "REDEMPTION_PAUSED_ENTITLEMENT");
  }
  if (previous?.itemType &&
      previous.itemType !== "REWARD_ENTITLEMENT") {
    forbidden("特典データに不整合があります", "ENTITLEMENT_TYPE_CONFLICT");
  }
  const oldExpiry = previous?.expiresAtEpochMs;
  if (oldExpiry !== undefined &&
      (typeof oldExpiry !== "number" ||
        !Number.isSafeInteger(oldExpiry) || oldExpiry < 0)) {
    forbidden("特典期限の再検証が必要です", "ENTITLEMENT_INVALID");
  }
  const now = Date.now();
  const from = Math.max(now, typeof oldExpiry === "number" ? oldExpiry : 0);
  const expiresAtEpochMs = addOneCalendarMonthUtc(from);
  const oldExpiryCondition = oldExpiry === undefined
    ? "attribute_not_exists(expiresAtEpochMs)"
    : "expiresAtEpochMs = :oldExpiry";
  const amount = offer.priceCoins;

  try {
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {
          Put: {
            TableName: tableName(),
            Item: {
              ...receiptKey,
              itemType: "COIN_REDEMPTION",
              requestId,
              target: "fullPremium",
              months: 1,
              priceVersion: offer.priceVersion,
              costCoins: amount,
              redeemedAtMs: now,
              expiresAtEpochMs,
            },
            ConditionExpression: "attribute_not_exists(pk)",
          },
        },
        {
          Update: {
            TableName: tableName(),
            Key: Keys.coinWallet(auth.niarimUserId),
            UpdateExpression:
              "SET updatedAtEpochMs = :now ADD balanceCoins :minus, " +
              "redeemedCoins :price",
            ConditionExpression:
              "itemType = :wallet AND balanceCoins >= :price",
            ExpressionAttributeValues: {
              ":wallet": "COIN_WALLET",
              ":now": now,
              ":minus": -amount,
              ":price": amount,
            },
          },
        },
        {
          Update: {
            TableName: tableName(),
            Key: entitlementKey,
            UpdateExpression:
              "SET itemType = :type, entitlement = :entitlement, " +
              "#status = :active, expiresAtEpochMs = :expiry, " +
              "source = :source, lastRedemptionId = :requestId",
            ConditionExpression:
              "(attribute_not_exists(itemType) OR itemType = :type) " +
              "AND (attribute_not_exists(#status) OR #status = :active) " +
              `AND ${oldExpiryCondition}`,
            ExpressionAttributeNames: { "#status": "status" },
            ExpressionAttributeValues: {
              ":type": "REWARD_ENTITLEMENT",
              ":entitlement": "fullPremium",
              ":active": "active",
              ":expiry": expiresAtEpochMs,
              ":source": "coin-redemption",
              ":requestId": requestId,
              ...(oldExpiry === undefined ? {} : { ":oldExpiry": oldExpiry }),
            },
          },
        },
        {
          Update: {
            TableName: tableName(),
            Key: Keys.user(auth.niarimUserId),
            UpdateExpression: "SET coinPremiumExpiresAtEpochMs = :expires",
            ConditionExpression:
              "itemType = :user AND membershipTier = :free AND " +
              "(attribute_not_exists(playPremiumExpiresAtEpochMs) OR " +
              "playPremiumExpiresAtEpochMs <= :now) AND " +
              "(attribute_not_exists(coinPremiumExpiresAtEpochMs) OR " +
              "coinPremiumExpiresAtEpochMs <= :expires)",
            ExpressionAttributeValues: {
              ":user": "USER", ":free": "free",
              ":now": now, ":expires": expiresAtEpochMs,
            },
          },
        },
        {
          Put: {
            TableName: tableName(),
            Item: {
              ...Keys.coinHistory(auth.niarimUserId, now, `redeem-${requestId}`),
              itemType: "COIN_HISTORY", source: "coin-redemption",
              deltaCoins: -amount, occurredAtEpochMs: now,
              target: "fullPremium", requestId,
            },
            ConditionExpression: "attribute_not_exists(pk)",
          },
        },
      ],
    }));
  } catch (error) {
    if (error instanceof TransactionCanceledException ||
        error instanceof ConditionalCheckFailedException) {
      // A response can be lost after commit. The same UUID MUST NOT debit
      // again; return the original receipt's expiry and cost.
      const receipt = await ddb.send(new GetCommand({
        TableName: tableName(),
        Key: receiptKey, ConsistentRead: true,
      }));
      const old = receipt.Item;
      if (old?.itemType === "COIN_REDEMPTION" &&
          old.target === "fullPremium" &&
          old.months === 1 &&
          old.priceVersion === offer.priceVersion &&
          old.costCoins === amount &&
          Number.isSafeInteger(old.expiresAtEpochMs)) {
        return ok({
          redeemed: true, duplicate: true, costCoins: amount,
          target: "fullPremium", expiresAtEpochMs: old.expiresAtEpochMs,
        });
      }
      conflict("残高または特典状態が更新されました。再読み込みしてください",
        "REDEMPTION_STATE_CHANGED");
    }
    throw error;
  }
  return ok({
    redeemed: true, duplicate: false, costCoins: amount,
    target: "fullPremium", expiresAtEpochMs,
  });
}
