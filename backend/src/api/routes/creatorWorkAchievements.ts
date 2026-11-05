import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { BatchGetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { badRequest, ok } from "../../lib/response";
import { PER_WORK_MISSIONS, missionClaimed } from "../../lib/missionCatalog";
import type { WorkItem } from "../../lib/types";

/**
 * Read-only, paginated list of *achieved* per-work bookmark milestones.
 * Claimed bits remain in USER#<id>/MISSION_WORK#<workId> forever, and
 * POST /me/missions/claim does the atomic claim + balance update.
 *
 * Never award coins here. GSI3 is eventually consistent: each candidate is
 * rechecked against the strongly consistent work item by the claim handler.
 * A single call reads <=25 public works and <=25 claim bitmask records.
 */
const PAGE_SIZE = 25;
const HOLD_SECONDS = 48 * 3600;
const MAX_CURSOR_CHARS = 1024;
function decodeCursor(value: string | undefined, userId: string) {
  if (value === undefined) return undefined;
  if (value.length < 1 || value.length > MAX_CURSOR_CHARS ||
      !/^[a-zA-Z0-9_-]+$/.test(value)) {
    badRequest("カーソルが不正です", "WORK_MISSION_CURSOR_INVALID");
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(Buffer.from(value, "base64url").toString("utf8"));
  } catch {
    badRequest("カーソルが不正です", "WORK_MISSION_CURSOR_INVALID");
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    badRequest("カーソルが不正です", "WORK_MISSION_CURSOR_INVALID");
  }
  const row = parsed as Record<string, unknown>;
  if (typeof row.pk !== "string" ||
      !/^WORK#[A-Za-z0-9_-]{11}$/.test(row.pk) ||
      row.sk !== "META" || row.gsi3pk !== `AUTHOR#${userId}` ||
      typeof row.gsi3sk !== "string" ||
      row.gsi3sk.length < 10 || row.gsi3sk.length > 60) {
    badRequest("カーソルが不正です", "WORK_MISSION_CURSOR_INVALID");
  }
  return {pk: row.pk, sk: row.sk, gsi3pk: row.gsi3pk, gsi3sk: row.gsi3sk};
}
export async function getMyWorkMissionAchievements(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const table = tableName();
  const cursor = decodeCursor(event.queryStringParameters?.cursor, auth.niarimUserId);
  const page = await ddb.send(new QueryCommand({
    TableName: table, IndexName: "GSI3",
    KeyConditionExpression: "gsi3pk = :author",
    ExpressionAttributeValues: {":author": `AUTHOR#${auth.niarimUserId}`},
    ScanIndexForward: false, Limit: PAGE_SIZE, ExclusiveStartKey: cursor,
  }));
  const qualifying = (page.Items ?? []).filter((raw) => {
    const work = raw as WorkItem;
    return work.itemType === "WORK" && work.authorId === auth.niarimUserId &&
      work.isNiarimPublished === true &&
      work.youtubePrivacyStatus !== "private" &&
      work.youtubePrivacyStatus !== "deleted" &&
      work.gsi2pk === "BOOKMARK_RANKING" &&
      typeof work.workId === "string" &&
      /^[A-Za-z0-9_-]{11}$/.test(work.workId) &&
      Number.isSafeInteger(work.bookmarkCount) &&
      work.bookmarkCount >= 0;
  }) as WorkItem[];
  // Only one BatchGet on the primary table (GSI reads aren't strongly
  // consistent). Missing state is treated as unclaimed, not as proof.
  const stateKeys = qualifying.map(w =>
    Keys.creatorWorkMissionState(auth.niarimUserId, w.workId));
  const stateResult = stateKeys.length
    ? await ddb.send(new BatchGetCommand({
      RequestItems: {[table]: {Keys: stateKeys, ConsistentRead: true}},
    })) : undefined;
  if ((stateResult?.UnprocessedKeys?.[table]?.Keys?.length ?? 0) > 0) {
    // Never show an incorrect claimed flag when a DynamoDB read was throttled.
    throw new Error("Unprocessed mission claim records");
  }
  const states = new Map<string, Record<string, unknown>>();
  for (const raw of stateResult?.Responses?.[table] ?? []) {
    if (raw.itemType === "CREATOR_WORK_MISSIONS_V1" &&
        typeof raw.pk === "string" && raw.pk === `USER#${auth.niarimUserId}` &&
        typeof raw.sk === "string" && /^MISSION_WORK#[A-Za-z0-9_-]{11}$/.test(raw.sk)) {
      states.set(raw.sk.slice("MISSION_WORK#".length), raw);
    }
  }
  const nowSec = Math.floor(Date.now() / 1000);
  const items = qualifying.flatMap(work => {
    const state = states.get(work.workId);
    const mask = Number.isSafeInteger(state?.claimedMask) &&
      (state?.claimedMask as number) >= 0 ? state!.claimedMask as number : 0;
    const since = state?.firstQualifiedAt;
    const held = since && typeof since === "object" && !Array.isArray(since)
      ? since as Record<string, unknown> : {};
    const coinQuotes = state?.pendingCoins && typeof state.pendingCoins === "object" &&
      !Array.isArray(state.pendingCoins)
        ? state.pendingCoins as Record<string, unknown> : {};
    return PER_WORK_MISSIONS
      .filter(m => m.kind === "workBookmarks" && work.bookmarkCount >= m.required)
      .map(m => {
        const key = String(m.bit);
        const claimed = missionClaimed(mask, m.bit);
        const pendingSince = typeof held[key] === "number" &&
          Number.isSafeInteger(held[key]) && (held[key] as number) > 0
            ? held[key] as number : null;
        const quoted = coinQuotes[key];
        return {
          missionId: m.id,
          workId: work.workId,
          workTitle: work.title,
          workPostedAt: work.postedAt,
          kind: m.kind,
          required: m.required,
          bookmarkCount: work.bookmarkCount,
          coins: Number.isSafeInteger(quoted) && (quoted as number) > 0
            ? quoted : m.coins,
          claimed,
          claimedAt: (state?.claimedAt as Record<string, unknown> | undefined)?.[key] ?? null,
          pendingSince,
          readyForClaim: !claimed &&
            (pendingSince === null || nowSec - pendingSince >= HOLD_SECONDS),
        };
      });
  });
  const nextCursor = page.LastEvaluatedKey
    ? Buffer.from(JSON.stringify(page.LastEvaluatedKey)).toString("base64url")
    : null;
  return ok({
    items,
    nextCursor,
    rewardEnabled: process.env.CREATOR_MISSION_CLAIMS_ENABLED === "true" &&
      process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED === "true",
    // Rank missions need a separate live rank check; no guesses here.
    includedKinds: ["workBookmarks"],
  });
}
