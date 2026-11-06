import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { BatchGetCommand, GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate, getUser } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { ok } from "../../lib/response";
import { ACCOUNT_MISSIONS, PER_WORK_MISSIONS, missionClaimed } from "../../lib/missionCatalog";
import {
  BOOKMARK_GOALS, WORK_COUNT_GOALS, WORK_COUNT_MISSIONS, LEGACY_GRID_BITS,
} from "../../lib/workCountMissionGrid";
import type { WorkItem } from "../../lib/types";

/**
 * Lightweight, read-only achieved-unclaimed signal for the Home drawer.
 * A marker is not a coin grant. GSI3 is eventually consistent, and POST claim
 * must independently verify any achievement before writing wallet entries.
 *
 * Stop at the first candidate instead of loading all 480 matrix rows and
 * every per-work achievement through the Flutter UI.
 */
const PAGE_SIZE = 25;
const MAX_PAGES = 20;
const BOOKMARK_MISSIONS = PER_WORK_MISSIONS.filter(m => m.kind === "workBookmarks");

function safeMask(value: unknown): number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0
    ? value : 0;
}
function isEligibleWork(value: WorkItem, userId: string): boolean {
  return value.itemType === "WORK" &&
    value.authorId === userId &&
    value.isNiarimPublished === true &&
    value.youtubePrivacyStatus !== "private" &&
    value.youtubePrivacyStatus !== "deleted" &&
    value.gsi2pk === "BOOKMARK_RANKING" &&
    typeof value.workId === "string" &&
    /^[A-Za-z0-9_-]{11}$/.test(value.workId) &&
    Number.isSafeInteger(value.bookmarkCount) &&
    value.bookmarkCount >= 0;
}

export async function getMyCreatorMissionAttention(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const table = tableName();
  const [user, legacy] = await Promise.all([
    getUser(auth.niarimUserId),
    ddb.send(new GetCommand({
      TableName: table, Key: Keys.creatorMissionState(auth.niarimUserId),
      ConsistentRead: true,
    })),
  ]);
  const oldMask = safeMask(legacy.Item?.claimedMask);
  for (const mission of ACCOUNT_MISSIONS) {
    if (mission.kind === "followers" &&
        (user?.followerCount ?? 0) >= mission.required &&
        !missionClaimed(oldMask, mission.bit)) {
      return ok({
        hasAchievedUnclaimed: true,
        source: "followers", provisional: false, complete: true,
      });
    }
  }

  const totals = new Map(BOOKMARK_GOALS.map(n => [n, 0]));
  let cursor: Record<string, any> | undefined;
  let complete = false;
  let scanned = 0;
  for (let pageNumber = 0; pageNumber < MAX_PAGES; pageNumber++) {
    const page = await ddb.send(new QueryCommand({
      TableName: table, IndexName: "GSI3",
      KeyConditionExpression: "gsi3pk = :author",
      ExpressionAttributeValues: { ":author": "AUTHOR#" + auth.niarimUserId },
      Limit: PAGE_SIZE, ExclusiveStartKey: cursor,
    }));
    const works = (page.Items ?? [])
      .filter((raw): raw is WorkItem =>
        isEligibleWork(raw as WorkItem, auth.niarimUserId));
    scanned += works.length;
    for (const work of works) {
      for (const threshold of BOOKMARK_GOALS) {
        if (work.bookmarkCount >= threshold) {
          totals.set(threshold, (totals.get(threshold) ?? 0) + 1);
        }
      }
    }
    if (works.length > 0) {
      const stateResult = await ddb.send(new BatchGetCommand({
        RequestItems: {
          [table]: {
            Keys: works.map(work =>
              Keys.creatorWorkMissionState(auth.niarimUserId, work.workId)),
            ConsistentRead: true,
          },
        },
      }));
      if ((stateResult.UnprocessedKeys?.[table]?.Keys?.length ?? 0) > 0) {
        throw new Error("Unprocessed work mission notification reads");
      }
      const masks = new Map<string, number>();
      for (const item of stateResult.Responses?.[table] ?? []) {
        if (item.pk === "USER#" + auth.niarimUserId &&
            item.itemType === "CREATOR_WORK_MISSIONS_V1" &&
            typeof item.sk === "string" &&
            /^MISSION_WORK#[A-Za-z0-9_-]{11}$/.test(item.sk)) {
          masks.set(item.sk.slice("MISSION_WORK#".length), safeMask(item.claimedMask));
        }
      }
      for (const work of works) {
        const mask = masks.get(work.workId) ?? 0;
        if (BOOKMARK_MISSIONS.some(mission =>
          work.bookmarkCount >= mission.required &&
          !missionClaimed(mask, mission.bit))) {
          return ok({
            hasAchievedUnclaimed: true,
            source: "work", provisional: true, complete: true,
          });
        }
      }
    }
    cursor = page.LastEvaluatedKey;
    if (!cursor) { complete = true; break; }
  }

  // Read the 20 account shards once (not one read per grid mission).
  const keys = WORK_COUNT_GOALS.map(goal =>
    Keys.creatorGridShard(auth.niarimUserId, goal));
  const result = await ddb.send(new BatchGetCommand({
    RequestItems: { [table]: { Keys: keys, ConsistentRead: true } },
  }));
  if ((result.UnprocessedKeys?.[table]?.Keys?.length ?? 0) > 0) {
    throw new Error("Unprocessed grid notification reads");
  }
  const masks = new Map<number, number>();
  for (const item of result.Responses?.[table] ?? []) {
    if (item.pk !== "USER#" + auth.niarimUserId ||
        item.itemType !== "CREATOR_GRID_V1" ||
        typeof item.sk !== "string") continue;
    const match = /^MISSION_GRID#(\d+)$/.exec(item.sk);
    if (!match) continue;
    const goal = Number(match[1]);
    if (WORK_COUNT_GOALS.includes(goal)) masks.set(goal, safeMask(item.claimedMask));
  }
  for (const mission of WORK_COUNT_MISSIONS) {
    if ((totals.get(mission.eachWorkBookmarks) ?? 0) < mission.required) {
      continue;
    }
    const legacyBit = LEGACY_GRID_BITS[mission.id];
    if (!missionClaimed(masks.get(mission.required) ?? 0, mission.bit) &&
        (legacyBit === undefined || !missionClaimed(oldMask, legacyBit))) {
      return ok({
        hasAchievedUnclaimed: true, source: "works",
        provisional: true, complete,
      });
    }
  }
  return ok({
    hasAchievedUnclaimed: false, source: "none",
    provisional: !complete, complete, scanned,
  });
}
