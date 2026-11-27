import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { randomUUID } from "node:crypto";
import {
  ConditionalCheckFailedException, TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import { BatchGetCommand, GetCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate, type AuthenticatedUser } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { parseJsonObject } from "../../lib/request";
import { ApiError, badRequest, conflict, forbidden, ok } from "../../lib/response";
import {
  accountIneligibility, COUPON_ATTEMPTS_ITEM_TYPE, COUPON_ATTEMPTS_PER_HOUR, COUPON_ITEM_TYPE,
  COUPON_REDEMPTION_ITEM_TYPE, couponAttemptWindowId, displayCouponCode, epochMsOf,
  isPresentId, normalizeCouponCode, PRESENT_CLAIM_ITEM_TYPE, PRESENT_ITEM_TYPE,
  storedAccountFilter, storedIndexEntries, storedTranslations,
} from "../../lib/opalGifts";

/**
 * Opal coupons and presents for signed-in accounts. The account comes only
 * from the Google ID token; every credit is one DynamoDB transaction that
 * also writes a once-per-account marker, so a retry can never credit twice.
 */

async function owner(event: APIGatewayProxyEventV2): Promise<AuthenticatedUser> {
  return authenticate(event.headers?.["authorization"] ?? event.headers?.["Authorization"]);
}

function walletUpdate(userId: string, coins: number) {
  return {
    Update: {
      TableName: tableName(),
      Key: Keys.coinWallet(userId),
      UpdateExpression: "SET itemType = :walletType ADD balanceCoins :award, giftEarnedCoins :award",
      ConditionExpression:
        "(attribute_not_exists(itemType) OR itemType = :walletType) AND " +
        "(attribute_not_exists(balanceCoins) OR (balanceCoins >= :zero AND balanceCoins <= :limit))",
      ExpressionAttributeValues: {
        ":walletType": "COIN_WALLET", ":award": coins, ":zero": 0,
        ":limit": Number.MAX_SAFE_INTEGER - coins,
      },
    },
  };
}

function historyPut(userId: string, coins: number, now: number, source: string,
  extra: Record<string, string>) {
  return {
    Put: {
      TableName: tableName(),
      Item: {
        ...Keys.coinHistory(userId, now, `${source}-${randomUUID()}`),
        itemType: "COIN_HISTORY", source, deltaCoins: coins, occurredAtEpochMs: now, ...extra,
      },
      ConditionExpression: "attribute_not_exists(pk)",
    },
  };
}

function cancellationCodes(error: unknown): string[] {
  return error instanceof TransactionCanceledException
    ? (error.CancellationReasons ?? []).map((reason) => reason.Code ?? "None")
    : [];
}

function createdAtOf(auth: AuthenticatedUser): number | null {
  return epochMsOf(auth.accountCreatedAt);
}

function localizedMessage(row: Record<string, unknown>) {
  return {
    title: typeof row.title === "string" ? row.title : "",
    body: typeof row.body === "string" ? row.body : "",
    translations: storedTranslations(row.translations) ?? {},
  };
}

// --- Inbox ---------------------------------------------------------------

/**
 * GET /me/gifts: the presents this account can see now (claimed ones stay
 * listed as claimed until they expire) and how old the account is.
 */
export async function getMyGifts(event: APIGatewayProxyEventV2) {
  const auth = await owner(event);
  const now = Date.now();
  const createdAt = createdAtOf(auth);
  const index = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.opalPresentIndex(),
  }));
  const candidates = storedIndexEntries(index.Item).filter((entry) =>
    entry.visibleFromEpochMs <= now && entry.claimUntilEpochMs > now &&
    accountIneligibility(entry.eligibility,
      { userId: auth.niarimUserId, createdAtEpochMs: createdAt }, now) === null);

  const presents: Record<string, unknown>[] = [];
  if (candidates.length > 0) {
    const table = tableName();
    const keys = candidates.flatMap((entry) => [
      Keys.opalPresent(entry.id), Keys.opalPresentClaim(auth.niarimUserId, entry.id),
    ]);
    const page = await ddb.send(new BatchGetCommand({
      RequestItems: { [table]: { Keys: keys } },
    }));
    if ((page.UnprocessedKeys?.[table]?.Keys?.length ?? 0) > 0) {
      throw new Error("Unprocessed present reads");
    }
    const rows = page.Responses?.[table] ?? [];
    const find = (key: { pk: string; sk: string }) =>
      rows.find((row) => row.pk === key.pk && row.sk === key.sk);
    for (const entry of candidates) {
      const present = find(Keys.opalPresent(entry.id));
      if (present?.itemType !== PRESENT_ITEM_TYPE || present.active !== true ||
          !Number.isSafeInteger(present.coins)) continue;
      const filter = storedAccountFilter(present);
      if (accountIneligibility(filter,
        { userId: auth.niarimUserId, createdAtEpochMs: createdAt }, now) !== null) continue;
      const claim = find(Keys.opalPresentClaim(auth.niarimUserId, entry.id));
      const claimed = claim?.itemType === PRESENT_CLAIM_ITEM_TYPE;
      presents.push({
        id: entry.id,
        coins: present.coins,
        ...localizedMessage(present),
        visibleFromEpochMs: present.visibleFromEpochMs,
        claimUntilEpochMs: present.claimUntilEpochMs,
        claimed,
        claimedAtEpochMs: claimed && Number.isSafeInteger(claim.claimedAtEpochMs)
          ? claim.claimedAtEpochMs : null,
      });
    }
  }
  presents.sort((a, b) =>
    Number(a.claimed) - Number(b.claimed) ||
    (a.claimUntilEpochMs as number) - (b.claimUntilEpochMs as number));
  return ok({
    niarimUserId: auth.niarimUserId,
    serverNowEpochMs: now,
    accountCreatedAtEpochMs: createdAt,
    accountAgeSeconds: createdAt === null ? null : Math.max(0, Math.floor((now - createdAt) / 1000)),
    presents,
    unclaimedCount: presents.filter((present) => present.claimed === false).length,
  });
}

// --- Presents ------------------------------------------------------------

/** POST /me/gifts/presents/{id}/claim */
export async function claimMyPresent(event: APIGatewayProxyEventV2, presentId: string) {
  if (!isPresentId(presentId)) presentNotFound();
  const auth = await owner(event);
  const userId = auth.niarimUserId;
  const now = Date.now();
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.opalPresent(presentId), ConsistentRead: true,
  }));
  const present = result.Item;
  if (present?.itemType !== PRESENT_ITEM_TYPE || !Number.isSafeInteger(present.coins)) {
    presentNotFound();
  }
  const coins = present.coins as number;
  const already = await readPresentClaim(userId, presentId);
  if (already) return ok(already);
  if (present.active !== true) {
    conflict("このプレゼントは受け取れなくなりました", "PRESENT_ENDED");
  }
  if ((present.visibleFromEpochMs as number) > now) presentNotFound();
  if ((present.claimUntilEpochMs as number) <= now) {
    conflict("受け取りの期限が過ぎています", "PRESENT_EXPIRED");
  }
  if (accountIneligibility(storedAccountFilter(present),
    { userId, createdAtEpochMs: createdAtOf(auth) }, now) !== null) {
    presentNotFound();
  }
  try {
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {
          ConditionCheck: {
            TableName: tableName(), Key: Keys.opalPresent(presentId),
            ConditionExpression:
              "itemType = :type AND active = :yes AND coins = :coins AND " +
              "visibleFromEpochMs <= :now AND claimUntilEpochMs > :now",
            ExpressionAttributeValues: {
              ":type": PRESENT_ITEM_TYPE, ":yes": true, ":coins": coins, ":now": now,
            },
          },
        },
        {
          Put: {
            TableName: tableName(),
            Item: {
              ...Keys.opalPresentClaim(userId, presentId),
              itemType: PRESENT_CLAIM_ITEM_TYPE, presentId, coins, claimedAtEpochMs: now,
            },
            ConditionExpression: "attribute_not_exists(pk)",
          },
        },
        walletUpdate(userId, coins),
        historyPut(userId, coins, now, "present", { presentId }),
      ],
    }));
  } catch (error) {
    const codes = cancellationCodes(error);
    if (codes.length === 0) throw error;
    if (codes[1] === "ConditionalCheckFailed") {
      const replay = await readPresentClaim(userId, presentId);
      if (replay) return ok(replay);
    }
    if (codes[0] === "ConditionalCheckFailed") {
      conflict("このプレゼントは受け取れなくなりました", "PRESENT_ENDED");
    }
    if (codes[2] === "ConditionalCheckFailed") {
      conflict("オパールの残高を確認できません", "GIFT_WALLET_INVALID");
    }
    conflict("受け取りが混み合っています。もう一度お試しください", "GIFT_RETRY");
  }
  return ok({ claimed: true, alreadyClaimed: false, presentId, awardedCoins: coins });
}

function presentNotFound(): never {
  throw new ApiError(404, "プレゼントが見つかりません", "PRESENT_NOT_FOUND");
}

async function readPresentClaim(userId: string, presentId: string) {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.opalPresentClaim(userId, presentId), ConsistentRead: true,
  }));
  const claim = result.Item;
  if (claim?.itemType !== PRESENT_CLAIM_ITEM_TYPE) return null;
  return {
    claimed: true, alreadyClaimed: true, presentId,
    awardedCoins: Number.isSafeInteger(claim.coins) ? claim.coins as number : 0,
  };
}

// --- Coupons -------------------------------------------------------------

async function reserveCouponAttempt(userId: string, now: number) {
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: Keys.opalCouponAttempts(userId, couponAttemptWindowId(now)),
      UpdateExpression: "SET itemType = :type, #ttl = :ttl ADD attempts :one",
      ConditionExpression: "attribute_not_exists(attempts) OR attempts < :limit",
      ExpressionAttributeNames: { "#ttl": "ttl" },
      ExpressionAttributeValues: {
        ":type": COUPON_ATTEMPTS_ITEM_TYPE, ":one": 1, ":limit": COUPON_ATTEMPTS_PER_HOUR,
        ":ttl": Math.floor(now / 1000) + 2 * 60 * 60,
      },
    }));
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) {
      throw new ApiError(429, "クーポンコードの入力が続いています。しばらくしてからお試しください",
        "COUPON_RATE_LIMITED");
    }
    throw error;
  }
}

function couponTimes(coupon: Record<string, unknown>) {
  return {
    validFromEpochMs: coupon.validFromEpochMs as number,
    validUntilEpochMs: coupon.validUntilEpochMs as number,
  };
}

/**
 * POST /me/gifts/coupons/redeem `{code, requestId}`. Sending the same
 * request again after a lost response answers with the first result; another
 * request for an already used code is refused.
 */
export async function redeemMyCoupon(event: APIGatewayProxyEventV2) {
  const auth = await owner(event);
  const userId = auth.niarimUserId;
  const body = parseJsonObject(event.body);
  const requestId = body.requestId;
  if (typeof requestId !== "string" || !/^[A-Za-z0-9-]{8,64}$/.test(requestId)) {
    badRequest("requestIdが不正です", "COUPON_INVALID_REQUEST");
  }
  const code = normalizeCouponCode(body.code);
  if (code === null) {
    badRequest("クーポンコードの形が正しくありません", "COUPON_INVALID_CODE");
  }
  const now = Date.now();

  const replay = await readCouponRedemption(userId, code, requestId);
  if (replay) return ok(replay);

  await reserveCouponAttempt(userId, now);
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.opalCoupon(code), ConsistentRead: true,
  }));
  const coupon = result.Item;
  if (coupon?.itemType !== COUPON_ITEM_TYPE || !Number.isSafeInteger(coupon.coins)) {
    throw new ApiError(404, "このクーポンコードは見つかりません", "COUPON_NOT_FOUND");
  }
  const coins = coupon.coins as number;
  const times = couponTimes(coupon);
  if (coupon.active !== true) conflict("このクーポンは終了しました", "COUPON_ENDED");
  if (times.validFromEpochMs > now) {
    throw new ApiError(409, "このクーポンはまだ使えません", "COUPON_NOT_YET_VALID");
  }
  if (times.validUntilEpochMs <= now) conflict("このクーポンの有効期限が過ぎています", "COUPON_EXPIRED");
  if (Number.isSafeInteger(coupon.maxRedemptions) &&
      (coupon.redeemedCount as number ?? 0) >= (coupon.maxRedemptions as number)) {
    conflict("このクーポンは配布数の上限に達しました", "COUPON_LIMIT_REACHED");
  }
  const reason = accountIneligibility(storedAccountFilter(coupon),
    { userId, createdAtEpochMs: createdAtOf(auth) }, now);
  if (reason !== null) {
    forbidden(reason === "newAccountsOnly"
      ? "このクーポンは新しく登録したアカウント向けです"
      : "このアカウントではこのクーポンを使えません",
    reason === "newAccountsOnly" ? "COUPON_NEW_ACCOUNTS_ONLY" : "COUPON_NOT_ELIGIBLE");
  }

  try {
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {
          Update: {
            TableName: tableName(), Key: Keys.opalCoupon(code),
            UpdateExpression: "ADD redeemedCount :one",
            ConditionExpression:
              "itemType = :type AND active = :yes AND coins = :coins AND " +
              "validFromEpochMs <= :now AND validUntilEpochMs > :now AND " +
              "(attribute_not_exists(maxRedemptions) OR redeemedCount < maxRedemptions)",
            ExpressionAttributeValues: {
              ":type": COUPON_ITEM_TYPE, ":yes": true, ":coins": coins, ":now": now, ":one": 1,
            },
          },
        },
        {
          Put: {
            TableName: tableName(),
            Item: {
              ...Keys.opalCouponRedemption(userId, code),
              itemType: COUPON_REDEMPTION_ITEM_TYPE, code, coins, requestId,
              redeemedAtEpochMs: now,
            },
            ConditionExpression: "attribute_not_exists(pk)",
          },
        },
        walletUpdate(userId, coins),
        historyPut(userId, coins, now, "coupon", { couponCode: code }),
      ],
    }));
  } catch (error) {
    const codes = cancellationCodes(error);
    if (codes.length === 0) throw error;
    if (codes[1] === "ConditionalCheckFailed") {
      const again = await readCouponRedemption(userId, code, requestId);
      if (again) return ok(again);
      conflict("このクーポンはすでに使っています", "COUPON_ALREADY_REDEEMED");
    }
    if (codes[0] === "ConditionalCheckFailed") {
      const latest = await ddb.send(new GetCommand({
        TableName: tableName(), Key: Keys.opalCoupon(code), ConsistentRead: true,
      }));
      const row = latest.Item;
      if (row && Number.isSafeInteger(row.maxRedemptions) &&
          (row.redeemedCount as number ?? 0) >= (row.maxRedemptions as number)) {
        conflict("このクーポンは配布数の上限に達しました", "COUPON_LIMIT_REACHED");
      }
      conflict("このクーポンは終了しました", "COUPON_ENDED");
    }
    if (codes[2] === "ConditionalCheckFailed") {
      conflict("オパールの残高を確認できません", "GIFT_WALLET_INVALID");
    }
    conflict("受け取りが混み合っています。もう一度お試しください", "GIFT_RETRY");
  }
  return ok({
    redeemed: true, alreadyRedeemed: false, code: displayCouponCode(code), awardedCoins: coins,
  });
}

/**
 * The account's earlier redemption of this code: the same answer for the
 * same request, a refusal for a different one, nothing when never used.
 */
async function readCouponRedemption(userId: string, code: string, requestId: string) {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.opalCouponRedemption(userId, code), ConsistentRead: true,
  }));
  const row = result.Item;
  if (row?.itemType !== COUPON_REDEMPTION_ITEM_TYPE) return null;
  if (row.requestId !== requestId) {
    conflict("このクーポンはすでに使っています", "COUPON_ALREADY_REDEEMED");
  }
  return {
    redeemed: true, alreadyRedeemed: true, code: displayCouponCode(code),
    awardedCoins: Number.isSafeInteger(row.coins) ? row.coins as number : 0,
  };
}
