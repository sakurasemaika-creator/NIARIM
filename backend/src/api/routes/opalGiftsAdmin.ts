import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  ConditionalCheckFailedException, TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import { GetCommand, PutCommand, QueryCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { authenticateAdmin } from "../../lib/adminAuth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import {
  COUPON_ITEM_TYPE, displayCouponCode, generateCouponCode, generatePresentId, isPresentId,
  MAX_ACTIVE_PRESENTS, MAX_NOTE_CHARS, MAX_PRESENT_BODY_CHARS, MAX_PRESENT_TITLE_CHARS,
  MAX_REDEMPTIONS_LIMIT, normalizeCouponCode, parseAccountFilter, parseCoins, parseText,
  parseTranslations, parseWindow, PRESENT_INDEX_ITEM_TYPE, PRESENT_ITEM_TYPE,
  storedAccountFilter, storedIndexEntries, storedTranslations, type PresentIndexEntry,
} from "../../lib/opalGifts";
import { decodePageCursor, encodePageCursor } from "../../lib/pagination";
import { parseJsonObject } from "../../lib/request";
import { badRequest, conflict, notFound, ok } from "../../lib/response";

/**
 * Operator API for opal coupons and presents (admin page). Same admin
 * authentication and CORS as the moderation admin API.
 */

function pageLimit(raw: string | undefined): number {
  if (raw === undefined) return 50;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > 50) {
    badRequest("limitは1〜50です", "INVALID_PAGE_SIZE");
  }
  return value;
}

function iso(epochMs: unknown): string | null {
  return Number.isSafeInteger(epochMs) ? new Date(epochMs as number).toISOString() : null;
}

function eligibilityView(row: Record<string, unknown>) {
  const filter = storedAccountFilter(row);
  return {
    newAccountWithinDays: filter.newAccountWithinDays ?? null,
    accountCreatedFrom: iso(filter.accountCreatedFromEpochMs),
    accountCreatedUntil: iso(filter.accountCreatedUntilEpochMs),
    accountIds: filter.accountIds ?? null,
  };
}

function couponView(row: Record<string, unknown>) {
  const code = String(row.code ?? "");
  return {
    code,
    displayCode: displayCouponCode(code),
    coins: row.coins,
    active: row.active === true,
    validFrom: iso(row.validFromEpochMs),
    validUntil: iso(row.validUntilEpochMs),
    maxRedemptions: Number.isSafeInteger(row.maxRedemptions) ? row.maxRedemptions : null,
    redeemedCount: Number.isSafeInteger(row.redeemedCount) ? row.redeemedCount : 0,
    eligibility: eligibilityView(row),
    note: typeof row.note === "string" ? row.note : "",
    createdAt: row.createdAt ?? null,
    createdBy: row.createdBy ?? null,
    deactivatedAt: row.deactivatedAt ?? null,
    deactivatedBy: row.deactivatedBy ?? null,
  };
}

function presentView(row: Record<string, unknown>) {
  return {
    id: row.presentId,
    coins: row.coins,
    title: row.title,
    body: row.body ?? "",
    translations: storedTranslations(row.translations) ?? {},
    active: row.active === true,
    visibleFrom: iso(row.visibleFromEpochMs),
    claimUntil: iso(row.claimUntilEpochMs),
    eligibility: eligibilityView(row),
    note: typeof row.note === "string" ? row.note : "",
    createdAt: row.createdAt ?? null,
    createdBy: row.createdBy ?? null,
    deactivatedAt: row.deactivatedAt ?? null,
    deactivatedBy: row.deactivatedBy ?? null,
  };
}

// --- Coupons -------------------------------------------------------------

/** GET /admin/gifts/coupons?limit=&cursor= (in code order). */
export async function listAdminCoupons(event: APIGatewayProxyEventV2) {
  await authenticateAdmin(event);
  const qp = event.queryStringParameters ?? {};
  const scope = "admin-coupons";
  const page = await ddb.send(new QueryCommand({
    TableName: tableName(),
    KeyConditionExpression: "pk = :pk AND begins_with(sk, :prefix)",
    ExpressionAttributeValues: { ":pk": "OPAL_COUPON", ":prefix": "CODE#" },
    ConsistentRead: true,
    Limit: pageLimit(qp.limit),
    ExclusiveStartKey: decodePageCursor(qp.cursor, scope),
  }));
  return ok({
    coupons: (page.Items ?? []).filter((row) => row.itemType === COUPON_ITEM_TYPE).map(couponView),
    nextCursor: encodePageCursor(page.LastEvaluatedKey, scope),
  });
}

/**
 * POST /admin/gifts/coupons
 * `{code?, coins, validFrom?, validUntil, maxRedemptions?, eligibility?, note?}`.
 * Without `code` a 12-character code of unambiguous characters is made.
 */
export async function createAdminCoupon(event: APIGatewayProxyEventV2) {
  const admin = await authenticateAdmin(event);
  const body = parseJsonObject(event.body);
  const now = Date.now();
  const coins = parseCoins(body.coins);
  const window = parseWindow(body.validFrom, body.validUntil, ["validFrom", "validUntil"], now);
  let maxRedemptions: number | undefined;
  if (body.maxRedemptions !== undefined && body.maxRedemptions !== null) {
    const value = body.maxRedemptions;
    if (typeof value !== "number" || !Number.isSafeInteger(value) ||
        value < 1 || value > MAX_REDEMPTIONS_LIMIT) {
      badRequest(`maxRedemptionsは1〜${MAX_REDEMPTIONS_LIMIT}の整数です`, "GIFT_INVALID_LIMIT");
    }
    maxRedemptions = value;
  }
  const { accountIds: _none, ...eligibility } =
    parseAccountFilter(body.eligibility, { allowAccountIds: false });
  const note = parseText(body.note, "note", MAX_NOTE_CHARS, { required: false });
  let custom: string | null = null;
  if (body.code !== undefined && body.code !== null && body.code !== "") {
    custom = normalizeCouponCode(body.code);
    if (custom === null) {
      badRequest("codeは英数字4〜32文字です（空白・ハイフンは除いて数えます）", "COUPON_INVALID_CODE");
    }
  }
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = custom ?? generateCouponCode();
    const item = {
      ...Keys.opalCoupon(code),
      itemType: COUPON_ITEM_TYPE,
      code,
      coins,
      active: true,
      validFromEpochMs: window.from,
      validUntilEpochMs: window.until,
      ...(maxRedemptions !== undefined ? { maxRedemptions } : {}),
      redeemedCount: 0,
      eligibility,
      ...(note ? { note } : {}),
      createdAt: new Date(now).toISOString(),
      createdBy: admin.email,
    };
    try {
      await ddb.send(new PutCommand({
        TableName: tableName(), Item: item, ConditionExpression: "attribute_not_exists(pk)",
      }));
      return ok({ ok: true, coupon: couponView(item) });
    } catch (error) {
      if (!(error instanceof ConditionalCheckFailedException)) throw error;
      if (custom !== null) conflict("このコードはすでにあります", "COUPON_CODE_TAKEN");
    }
  }
  throw new Error("Could not generate a unique coupon code");
}

/** POST /admin/gifts/coupons/{code}/deactivate */
export async function deactivateAdminCoupon(event: APIGatewayProxyEventV2, rawCode: string) {
  const admin = await authenticateAdmin(event);
  const code = normalizeCouponCode(rawCode);
  if (code === null) notFound("クーポンが見つかりません");
  try {
    const result = await ddb.send(new UpdateCommand({
      TableName: tableName(), Key: Keys.opalCoupon(code),
      UpdateExpression: "SET active = :no, deactivatedAt = :at, deactivatedBy = :by",
      ConditionExpression: "itemType = :type AND active = :yes",
      ExpressionAttributeValues: {
        ":no": false, ":yes": true, ":type": COUPON_ITEM_TYPE,
        ":at": new Date().toISOString(), ":by": admin.email,
      },
      ReturnValues: "ALL_NEW",
    }));
    return ok({ ok: true, coupon: couponView(result.Attributes ?? {}) });
  } catch (error) {
    if (!(error instanceof ConditionalCheckFailedException)) throw error;
    const current = await ddb.send(new GetCommand({
      TableName: tableName(), Key: Keys.opalCoupon(code), ConsistentRead: true,
    }));
    if (current.Item?.itemType !== COUPON_ITEM_TYPE) notFound("クーポンが見つかりません");
    return ok({ ok: true, coupon: couponView(current.Item) });
  }
}

// --- Presents ------------------------------------------------------------

/** GET /admin/gifts/presents?limit=&cursor= (newest first). */
export async function listAdminPresents(event: APIGatewayProxyEventV2) {
  await authenticateAdmin(event);
  const qp = event.queryStringParameters ?? {};
  const scope = "admin-presents";
  const page = await ddb.send(new QueryCommand({
    TableName: tableName(),
    KeyConditionExpression: "pk = :pk AND begins_with(sk, :prefix)",
    ExpressionAttributeValues: { ":pk": "OPAL_PRESENT", ":prefix": "PRESENT#" },
    ScanIndexForward: false,
    ConsistentRead: true,
    Limit: pageLimit(qp.limit),
    ExclusiveStartKey: decodePageCursor(qp.cursor, scope),
  }));
  return ok({
    presents: (page.Items ?? []).filter((row) => row.itemType === PRESENT_ITEM_TYPE).map(presentView),
    nextCursor: encodePageCursor(page.LastEvaluatedKey, scope),
  });
}

async function readIndex(): Promise<{ entries: PresentIndexEntry[]; revision: number | null }> {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.opalPresentIndex(), ConsistentRead: true,
  }));
  const row = result.Item;
  return {
    entries: storedIndexEntries(row),
    revision: row?.itemType === PRESENT_INDEX_ITEM_TYPE && Number.isSafeInteger(row.revision)
      ? row.revision as number : null,
  };
}

function indexPut(entries: PresentIndexEntry[], revision: number | null) {
  return {
    Put: {
      TableName: tableName(),
      Item: {
        ...Keys.opalPresentIndex(),
        itemType: PRESENT_INDEX_ITEM_TYPE,
        revision: (revision ?? 0) + 1,
        entries,
        updatedAt: new Date().toISOString(),
      },
      ConditionExpression: revision === null
        ? "attribute_not_exists(pk) OR attribute_not_exists(revision)"
        : "revision = :revision",
      ...(revision === null ? {} : { ExpressionAttributeValues: { ":revision": revision } }),
    },
  };
}

/** Index writes race only with other admin writes; three tries are plenty. */
async function withIndex<T>(write: (entries: PresentIndexEntry[], revision: number | null) => Promise<T>) {
  for (let attempt = 0; ; attempt++) {
    const { entries, revision } = await readIndex();
    try {
      return await write(entries, revision);
    } catch (error) {
      const indexLost = error instanceof TransactionCanceledException &&
        (error.CancellationReasons ?? []).at(-1)?.Code === "ConditionalCheckFailed";
      if (!indexLost || attempt >= 2) throw error;
    }
  }
}

/**
 * POST /admin/gifts/presents
 * `{coins, title, body?, translations?, visibleFrom?, claimUntil, eligibility?, note?}`.
 * `eligibility` may list `accountIds` (at most 100 NIARIM User IDs).
 */
export async function createAdminPresent(event: APIGatewayProxyEventV2) {
  const admin = await authenticateAdmin(event);
  const body = parseJsonObject(event.body);
  const now = Date.now();
  const coins = parseCoins(body.coins);
  const title = parseText(body.title, "title", MAX_PRESENT_TITLE_CHARS, { required: true })!;
  const message = parseText(body.body, "body", MAX_PRESENT_BODY_CHARS, { required: false }) ?? "";
  const translations = parseTranslations(body.translations);
  const window = parseWindow(body.visibleFrom, body.claimUntil, ["visibleFrom", "claimUntil"], now);
  const eligibility = parseAccountFilter(body.eligibility, { allowAccountIds: true });
  const note = parseText(body.note, "note", MAX_NOTE_CHARS, { required: false });
  const presentId = generatePresentId(now);
  const { accountIds, ...shared } = eligibility;
  const item = {
    ...Keys.opalPresent(presentId),
    itemType: PRESENT_ITEM_TYPE,
    presentId,
    coins,
    title,
    body: message,
    ...(translations ? { translations } : {}),
    active: true,
    visibleFromEpochMs: window.from,
    claimUntilEpochMs: window.until,
    eligibility,
    ...(note ? { note } : {}),
    createdAt: new Date(now).toISOString(),
    createdBy: admin.email,
  };
  const entry: PresentIndexEntry = {
    id: presentId,
    visibleFromEpochMs: window.from,
    claimUntilEpochMs: window.until,
    eligibility: shared,
    targeted: accountIds !== undefined,
  };
  await withIndex(async (entries, revision) => {
    const live = entries.filter((e) => e.claimUntilEpochMs > now);
    if (live.length >= MAX_ACTIVE_PRESENTS) {
      conflict(`同時に配れるプレゼントは${MAX_ACTIVE_PRESENTS}件までです。終わったものを止めてください`,
        "PRESENT_LIMIT_REACHED");
    }
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {
          Put: {
            TableName: tableName(), Item: item, ConditionExpression: "attribute_not_exists(pk)",
          },
        },
        indexPut([...live, entry], revision),
      ],
    }));
  });
  return ok({ ok: true, present: presentView(item) });
}

/** POST /admin/gifts/presents/{id}/deactivate */
export async function deactivateAdminPresent(event: APIGatewayProxyEventV2, presentId: string) {
  const admin = await authenticateAdmin(event);
  if (!isPresentId(presentId)) notFound("プレゼントが見つかりません");
  const now = Date.now();
  const at = new Date(now).toISOString();
  const current = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.opalPresent(presentId), ConsistentRead: true,
  }));
  if (current.Item?.itemType !== PRESENT_ITEM_TYPE) notFound("プレゼントが見つかりません");
  await withIndex(async (entries, revision) => {
    const live = entries.filter((e) => e.claimUntilEpochMs > now && e.id !== presentId);
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {
          Update: {
            TableName: tableName(), Key: Keys.opalPresent(presentId),
            UpdateExpression: current.Item!.active === true
              ? "SET active = :no, deactivatedAt = :at, deactivatedBy = :by"
              : "SET active = :no",
            ConditionExpression: "itemType = :type",
            ExpressionAttributeValues: {
              ":no": false, ":type": PRESENT_ITEM_TYPE,
              ...(current.Item!.active === true ? { ":at": at, ":by": admin.email } : {}),
            },
          },
        },
        indexPut(live, revision),
      ],
    }));
  });
  const after = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.opalPresent(presentId), ConsistentRead: true,
  }));
  return ok({ ok: true, present: presentView(after.Item ?? {}) });
}
