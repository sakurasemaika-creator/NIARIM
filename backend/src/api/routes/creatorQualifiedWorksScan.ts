import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { GetCommand, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { badRequest, conflict, forbidden, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import type { WorkItem } from "../../lib/types";

/**
 * Candidate-only scanner for the 1,000-10,000 qualified works missions.
 * DynamoDB GSI3 is eventually consistent: no scan can prove a stable snapshot
 * while bookmarks or publication change. Consequently it MUST NEVER grant
 * reward coins or be treated as verified proof by the claim endpoint.
 *
 * A Lambda invocation is limited to 10 seconds. Scanning <= 8x25 existing
 * author-index rows per call avoids the previous 500-work hard ceiling without
 * an unbounded request, a new index, per-work storage or client-trusted cursors.
 */
const MAX_PAGES_PER_REQUEST = 8;
const PAGE_SIZE = 25;
const SCAN_VALIDITY_MS = 24 * 60 * 60_000;
const MAX_WORKS_PER_SCAN = 1_000_000;
type ScanRecord = {
  pk: string;
  sk: string;
  itemType: "MISSION_QUALIFIED_WORK_SCAN_V1";
  revision: number;
  startedAtEpochMs: number;
  updatedAtEpochMs: number;
  processedWorks: number;
  worksWith10Bookmarks: number;
  worksWith20Bookmarks: number;
  cursor?: Record<string, unknown>;
  scanComplete: boolean;
  // TTL is opportunistic; explicit age checks always enforce freshness.
  expiresAtEpochSeconds: number;
};
function validScan(value: Record<string, unknown> | undefined): value is ScanRecord {
  if (value?.itemType !== "MISSION_QUALIFIED_WORK_SCAN_V1") return false;
  for (const name of ["revision", "startedAtEpochMs", "updatedAtEpochMs",
    "processedWorks", "worksWith10Bookmarks", "worksWith20Bookmarks"]) {
    const n = value[name];
    if (typeof n !== "number" || !Number.isSafeInteger(n) || n < 0) return false;
  }
  if (value.scanComplete !== true && value.scanComplete !== false) return false;
  if (value.cursor !== undefined &&
      (value.cursor === null || typeof value.cursor !== "object" ||
       Array.isArray(value.cursor))) return false;
  return (value.worksWith10Bookmarks as number) <= (value.processedWorks as number) &&
    (value.worksWith20Bookmarks as number) <= (value.worksWith10Bookmarks as number);
}

function snapshot(scan: ScanRecord, unchanged: boolean) {
  return {
    provisional: true,
    authoritativeForRewards: false,
    scanComplete: scan.scanComplete,
    processedWorks: scan.processedWorks,
    worksWith10Bookmarks: scan.worksWith10Bookmarks,
    worksWith20Bookmarks: scan.worksWith20Bookmarks,
    startedAtEpochMs: scan.startedAtEpochMs,
    updatedAtEpochMs: scan.updatedAtEpochMs,
    morePages: !scan.scanComplete,
    unchanged,
  };
}

export async function scanMyQualifiedWorks(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (process.env.CREATOR_QUALIFIED_WORK_SCAN_ENABLED !== "true") {
    forbidden("大量作品の進捗計測は準備中です", "MISSION_SCAN_DISABLED");
  }
  const body = parseJsonObject(event.body, { allowEmpty: true });
  if (body.restart !== undefined && typeof body.restart !== "boolean") {
    badRequest("restartは真偽値で指定してください", "MISSION_SCAN_INVALID_RESTART");
  }
  const now = Date.now();
  const key = Keys.creatorQualifiedWorksScan(auth.niarimUserId);
  const previous = await ddb.send(new GetCommand({
    TableName: tableName(), Key: key, ConsistentRead: true,
  }));
  const raw = previous.Item as Record<string, unknown> | undefined;
  // A damaged persisted scan cannot quietly produce trusted counters.
  if (raw && !validScan(raw)) {
    conflict("進捗データを再検証してください", "MISSION_SCAN_INVALID_STATE");
  }
  const existing = validScan(raw) ? raw : undefined;
  const expired = !existing ||
    now - existing.startedAtEpochMs >= SCAN_VALIDITY_MS ||
    existing.startedAtEpochMs > now;
  const reset = body.restart === true || expired;
  if (existing?.scanComplete && !reset) return ok(snapshot(existing, true));

  const priorRevision = existing?.revision ?? 0;
  const started = reset ? now : existing!.startedAtEpochMs;
  let cursor: Record<string, unknown> | undefined =
    reset ? undefined : existing!.cursor;
  let processed = reset ? 0 : existing!.processedWorks;
  let matching10 = reset ? 0 : existing!.worksWith10Bookmarks;
  let matching20 = reset ? 0 : existing!.worksWith20Bookmarks;
  let complete = false;
  let pagesScanned = 0;
  for (let page = 0; page < MAX_PAGES_PER_REQUEST; page++) {
    const query = await ddb.send(new QueryCommand({
      TableName: tableName(),
      IndexName: "GSI3",
      KeyConditionExpression: "gsi3pk = :author",
      ExpressionAttributeValues: { ":author": `AUTHOR#${auth.niarimUserId}` },
      Limit: PAGE_SIZE,
      ExclusiveStartKey: cursor,
    }));
    pagesScanned += 1;
    const items = query.Items ?? [];
    if (items.length > PAGE_SIZE) throw new Error("Invalid index page size");
    processed += items.length;
    for (const rawWork of items) {
      const work = rawWork as WorkItem;
      if (work.itemType !== "WORK" || work.authorId !== auth.niarimUserId ||
          !work.isNiarimPublished ||
          work.youtubePrivacyStatus === "private" ||
          work.youtubePrivacyStatus === "deleted" ||
          work.gsi2pk !== "BOOKMARK_RANKING" ||
          !Number.isSafeInteger(work.bookmarkCount) ||
          work.bookmarkCount < 0) continue;
      if (work.bookmarkCount >= 10) matching10 += 1;
      if (work.bookmarkCount >= 20) matching20 += 1;
    }
    cursor = query.LastEvaluatedKey;
    if (!cursor) { complete = true; break; }
    if (processed >= MAX_WORKS_PER_SCAN) break;
  }
  const next: ScanRecord = {
    ...key,
    itemType: "MISSION_QUALIFIED_WORK_SCAN_V1",
    revision: priorRevision + 1,
    startedAtEpochMs: started,
    updatedAtEpochMs: now,
    processedWorks: processed,
    worksWith10Bookmarks: matching10,
    worksWith20Bookmarks: matching20,
    ...(complete ? {} : { cursor }),
    scanComplete: complete,
    expiresAtEpochSeconds: Math.floor((started + SCAN_VALIDITY_MS) / 1000),
  };
  try {
    await ddb.send(new PutCommand({
      TableName: tableName(),
      Item: next,
      ConditionExpression: existing
        ? "itemType = :type AND revision = :revision"
        : "attribute_not_exists(pk)",
      ...(existing ? {ExpressionAttributeValues: {
        ":type": "MISSION_QUALIFIED_WORK_SCAN_V1",
        ":revision": priorRevision,
      }} : {}),
    }));
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) {
      conflict("別の端末で計測が進みました。再読み込みしてください",
        "MISSION_SCAN_CONCURRENT_CHANGE");
    }
    throw error;
  }
  return ok({ ...snapshot(next, false), pagesScanned });
}
