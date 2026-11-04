import { createHash } from "node:crypto";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { ApiError, badRequest, conflict, forbidden, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import {
  PLAY_PACKAGE_NAME, PLAY_SUBSCRIPTION_PRODUCTS, evaluatePlaySubscription,
  queryGooglePlaySubscription, type PlayProductId,
} from "../../lib/playVerification";

const VALIDATION_LEASE_MS = 15 * 60_000;
/** The production purchase-verification path is disabled by default. */
export function playVerificationEnabled(): boolean {
  return process.env.PLAY_PURCHASE_VERIFICATION_ENABLED === "true" &&
    process.env.PLAY_ANDROID_PACKAGE_NAME === PLAY_PACKAGE_NAME;
}

/** A purchase must never open Billing when backend verification is off. */
export async function getPlayPurchaseAvailability(event: APIGatewayProxyEventV2) {
  await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  return ok({
    enabled: playVerificationEnabled(),
    products: playVerificationEnabled() ? PLAY_SUBSCRIPTION_PRODUCTS : [],
  });
}

export async function verifyMyPlayPremium(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (!playVerificationEnabled()) {
    forbidden("Google Play購入検証は準備中です", "PLAY_VERIFICATION_DISABLED");
  }
  const body = parseJsonObject(event.body);
  if (typeof body.productId !== "string" ||
      !PLAY_SUBSCRIPTION_PRODUCTS.includes(body.productId as PlayProductId)) {
    badRequest("購入商品IDが不正です", "PLAY_INVALID_PRODUCT");
  }
  const productId = body.productId as PlayProductId;
  const token = body.purchaseToken;
  if (typeof token !== "string" || token.length < 16 || token.length > 2048 ||
      !/^[A-Za-z0-9._:=-]+$/.test(token)) {
    badRequest("購入トークンが不正です", "PLAY_INVALID_TOKEN");
  }
  let purchase: unknown;
  try {
    purchase = await queryGooglePlaySubscription(PLAY_PACKAGE_NAME, token);
  } catch {
    throw new ApiError(503, "Google Playで購入状態を確認できません",
      "PLAY_VERIFICATION_UNAVAILABLE");
  }
  const now = Date.now();
  const inspected = evaluatePlaySubscription(purchase, productId, now);
  const expiry = inspected.active ? inspected.expiresAtEpochMs! : 0;
  const validatedUntil = inspected.active
    ? Math.min(expiry, now + VALIDATION_LEASE_MS) : 0;
  const hash = createHash("sha256").update(token, "utf8").digest("hex");
  try {
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {
          Update: {
            TableName: tableName(),
            Key: Keys.playPurchaseToken(hash),
            UpdateExpression:
              "SET itemType = if_not_exists(itemType,:type), " +
              "niarimUserId = if_not_exists(niarimUserId,:owner), " +
              "verifiedAtMs = :now",
            ConditionExpression:
              "(attribute_not_exists(itemType) OR itemType = :type) AND " +
              "(attribute_not_exists(niarimUserId) OR niarimUserId = :owner)",
            ExpressionAttributeValues: {
              ":type": "PLAY_PURCHASE_TOKEN",
              ":owner": auth.niarimUserId,
              ":now": now,
            },
          },
        },
        {
          Update: {
            TableName: tableName(),
            Key: Keys.user(auth.niarimUserId),
            UpdateExpression:
              "SET playPremiumTokenHash = :hash, " +
              "playPremiumProductId = :product, " +
              "playPremiumExpiresAtEpochMs = :expires, " +
              "playPremiumVerifiedUntilEpochMs = :until, " +
              "playPremiumCheckedAtMs = :now",
            ConditionExpression:
              "itemType = :user AND " +
              "(attribute_not_exists(playPremiumCheckedAtMs) OR " +
              "playPremiumCheckedAtMs <= :now)" +
              (inspected.active ? "" :
                " AND (attribute_not_exists(playPremiumTokenHash) OR " +
                "playPremiumTokenHash = :hash)"),
            ExpressionAttributeValues: {
              ":user": "USER", ":hash": hash, ":product": productId,
              ":expires": expiry, ":until": validatedUntil, ":now": now,
            },
          },
        },
      ],
    }));
  } catch (error) {
    if (error instanceof TransactionCanceledException) {
      conflict("購入トークンの所有者または購入状態を確認できません",
        "PLAY_PURCHASE_CONFLICT");
    }
    throw error;
  }
  return ok({
    verified: inspected.active, productId,
    expiresAtEpochMs: inspected.active ? expiry : null,
    verifiedUntilEpochMs: inspected.active ? validatedUntil : null,
  });
}
