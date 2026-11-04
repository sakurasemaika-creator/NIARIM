import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  ConditionalCheckFailedException,
  TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import {
  GetCommand,
  QueryCommand,
  TransactWriteCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import { authenticate, getUser } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { badRequest, conflict, forbidden, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import type { WorkItem } from "../../lib/types";
import {
  CREATOR_MISSIONS,
  MAX_CREATOR_MISSION_COINS,
  MISSION_CATALOG_VERSION,
  missionRewardCoins,
  missionClaimed,
  claimMissionInMask,
  type MissionDefinition,
} from "../../lib/missionCatalog";

/**
 * Claims OFF by default until anti-sybil / age / moderation / wallet review.
 * No AWS write or reward issuance occurs when the feature flag is absent.
 */
function enabled(): boolean {
  return process.env.CREATOR_MISSION_CLAIMS_ENABLED === "true";
}

const SOCIAL_HOLD_SECONDS = 48 * 60 * 60;
const QUERY_WORK_PAGE_SIZE = 25;
const MAX_OWN_WORK_PAGES = 20; // Prevent unbounded DynamoDB reads.
type MissionStateRecord = {
  itemType: "CREATOR_MISSIONS_V1" | "CREATOR_WORK_MISSIONS_V1";
  claimedMask: number;
  revision: number;
  verifiedEditSeconds: number;
  totalMissionCoins: number;
  firstQualifiedAt: Record<string, number>;
  claimedAt: Record<string, number>;
  pendingCoins: Record<string, number>;
};
const missionKey = (userId: string, workId?: string) =>
  workId === undefined ? Keys.creatorMissionState(userId) :
    Keys.creatorWorkMissionState(userId, workId);

function normalizeState(
  raw: Record<string, unknown> | undefined, perWork = false,
): MissionStateRecord {
  const type = perWork ? "CREATOR_WORK_MISSIONS_V1" as const :
    "CREATOR_MISSIONS_V1" as const;
  const claimedMask = raw?.itemType === type &&
    typeof raw.claimedMask === "number" &&
    Number.isSafeInteger(raw.claimedMask) && raw.claimedMask >= 0
      ? raw.claimedMask
      : 0;
  const revision = typeof raw?.revision === "number" &&
    Number.isSafeInteger(raw.revision) && raw.revision >= 0
      ? raw.revision
      : 0;
  const verifiedEditSeconds = typeof raw?.verifiedEditSeconds === "number" &&
    Number.isSafeInteger(raw.verifiedEditSeconds) &&
    raw.verifiedEditSeconds >= 0 ? raw.verifiedEditSeconds : 0;
  const totalMissionCoins = typeof raw?.totalMissionCoins === "number" &&
    Number.isSafeInteger(raw.totalMissionCoins) &&
    raw.totalMissionCoins >= 0 ? raw.totalMissionCoins : 0;

  const parseDates = (data: unknown): Record<string, number> => {
    if (!data || typeof data !== "object" || Array.isArray(data)) return {};
    const clean: Record<string, number> = {};
    for (const m of CREATOR_MISSIONS) {
      const val = (data as Record<string, unknown>)[String(m.bit)];
      if (typeof val === "number" && Number.isSafeInteger(val) && val > 0) {
        clean[String(m.bit)] = val;
      }
    }
    return clean;
  };
  return {
    itemType: type,
    claimedMask,
    revision,
    verifiedEditSeconds,
    totalMissionCoins,
    firstQualifiedAt: parseDates(raw?.firstQualifiedAt),
    claimedAt: parseDates(raw?.claimedAt),
    pendingCoins: parseDates(raw?.pendingCoins),
  };
}

async function loadMissionState(
  userId: string, workId?: string,
): Promise<MissionStateRecord> {
  const record = await ddb.send(new GetCommand({
    TableName: tableName(),
    Key: missionKey(userId, workId),
    ConsistentRead: true,
  }));
  return normalizeState(record.Item, workId !== undefined);
}

function isPublicWork(work: WorkItem | undefined, ownerId: string): boolean {
  return Boolean(
    work?.itemType === "WORK" && work.authorId === ownerId &&
    work.isNiarimPublished &&
    work.youtubePrivacyStatus !== "private" &&
    work.youtubePrivacyStatus !== "deleted" &&
    work.gsi2pk === "BOOKMARK_RANKING",
  );
}

/** Only existing NIARIM-native data; NEVER reward YouTube engagement. */
async function measuredProgress(
  userId: string,
  mission: MissionDefinition,
  workId?: string,
): Promise<{ count: number; authoritative: boolean }> {
  switch (mission.kind) {
    case "verifiedEditSeconds":
      // local Project.totalWorkSeconds is NOT trusted; sender can edit it.
      // Requires separate validated, bounded activity sessions to enable.
      return { count: 0, authoritative: false };

    case "followers": {
      const user = await getUser(userId);
      return { count: user?.followerCount ?? 0, authoritative: true };
    }

    case "workBookmarks": {
      if (!workId || !/^[A-Za-z0-9_-]{11}$/.test(workId)) {
        badRequest("作品IDを指定してください", "MISSION_WORK_ID_REQUIRED");
      }
      const work = await ddb.send(new GetCommand({
        TableName: tableName(),
        Key: Keys.work(workId),
        ConsistentRead: true,
      }));
      const item = work.Item as WorkItem | undefined;
      return {
        count: isPublicWork(item, userId) ? item!.bookmarkCount : 0,
        authoritative: true,
      };
    }

    case "qualifiedWorks": {
      let matching = 0;
      let cursor: Record<string, any> | undefined;
      let exhausted = false;
      // Query the already-existing public author GSI; do not add a new index
      // or copy all works to a mission-only per-work table.
      for (let page = 0; page < MAX_OWN_WORK_PAGES; page++) {
        const result = await ddb.send(new QueryCommand({
          TableName: tableName(),
          IndexName: "GSI3",
          KeyConditionExpression: "gsi3pk = :author",
          ExpressionAttributeValues: { ":author": `AUTHOR#${userId}` },
          Limit: QUERY_WORK_PAGE_SIZE,
          ExclusiveStartKey: cursor,
        }));
        for (const raw of result.Items ?? []) {
          const w = raw as WorkItem;
          if (isPublicWork(w, userId) &&
              w.bookmarkCount >= (mission.eachWorkBookmarks ?? Infinity)) {
            matching += 1;
          }
          if (matching >= mission.required) {
            return { count: matching, authoritative: true };
          }
        }
        cursor = result.LastEvaluatedKey;
        if (!cursor) { exhausted = true; break; }
      }
      // A bounded scan cannot prove nonachievement for users with >500 works.
      if (!exhausted) return { count: matching, authoritative: false };
      return { count: matching, authoritative: true };
    }

    case "niarimBookmarkRanking": {
      // The app's existing 'all' ranking is based on YouTube statistics and
      // MUST NOT be used to reward user-generated YouTube engagement.
      const ranking = await ddb.send(new QueryCommand({
        TableName: tableName(),
        IndexName: "GSI2",
        KeyConditionExpression: "gsi2pk = :rank",
        ExpressionAttributeValues: { ":rank": "BOOKMARK_RANKING" },
        ScanIndexForward: false,
        Limit: 50,
      }));
      const list = ranking.Items ?? [];
      const index = list.findIndex((w) =>
        w.itemType === "WORK" && w.authorId === userId &&
        w.isNiarimPublished === true);
      return {
        count: index < 0 ? 51 : index + 1,
        authoritative: true,
      };
    }
  }
}

export async function getMyCreatorMissions(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  // Two point reads, no work scan and no additional GSIs.
  const [user, state] = await Promise.all([
    getUser(auth.niarimUserId),
    loadMissionState(auth.niarimUserId),
  ]);
  return ok({
    catalogVersion: MISSION_CATALOG_VERSION,
    enabled: enabled(),
    claimedMask: state.claimedMask,
    verifiedEditSeconds: state.verifiedEditSeconds,
    editTimeVerificationReady: false,
    followerCount: user?.followerCount ?? 0,
    totalMissionCoins: state.totalMissionCoins,
    maximumLifetimeCreatorCoins: MAX_CREATOR_MISSION_COINS,
    missions: CREATOR_MISSIONS.map((mission) => ({
      ...mission,
      claimed: missionClaimed(state.claimedMask, mission.bit),
      claimedAt: state.claimedAt?.[String(mission.bit)] ?? null,
      pendingSince: state.firstQualifiedAt?.[String(mission.bit)] ?? null,
      // Work/ranking progress is fetched only on intentional claim attempts
      // rather than scanning and charging every time this page opens.
      progress: mission.kind === "followers"
        ? user?.followerCount ?? 0
        : null,
      rewardEnabled: enabled() && mission.kind !== "verifiedEditSeconds",
    })),
  });
}

export async function claimCreatorMission(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (!enabled()) {
    forbidden("ミッション報酬は公開準備中です", "CREATOR_MISSIONS_DISABLED");
  }
  const body = parseJsonObject(event.body);
  const id = body.missionId;
  if (typeof id !== "string" || id.length > 64) {
    badRequest("ミッションIDが不正です", "INVALID_MISSION_ID");
  }
  const mission = CREATOR_MISSIONS.find((m) => m.id === id);
  if (!mission) badRequest("不明なミッションです", "INVALID_MISSION_ID");

  const workId = typeof body.workId === "string" ? body.workId : undefined;
  const state = await loadMissionState(auth.niarimUserId);
  if (missionClaimed(state.claimedMask, mission.bit)) {
    return ok({ missionId: id, claimed: true, awardedCoins: 0 });
  }

  const progress = await measuredProgress(auth.niarimUserId, mission, workId);
  if (!progress.authoritative) {
    forbidden("このミッションの安全な計測は準備中です", "MISSION_VERIFICATION_PENDING");
  }
  const eligible = mission.kind === "niarimBookmarkRanking"
    ? progress.count <= mission.required
    : progress.count >= mission.required;
  if (!eligible) {
    conflict("ミッションの達成条件を確認できません", "MISSION_NOT_YET_COMPLETE");
  }

  const nowSec = Math.floor(Date.now() / 1000);
  const bitKey = String(mission.bit);
  const first = state.firstQualifiedAt?.[bitKey];

  // First successful verification only starts a mandatory dwell timer.
  // Reacting to an immediate self-created bookmark/follow is not enough.
  if (!first || first > nowSec) {
    const firstQualifiedAt = { ...state.firstQualifiedAt, [bitKey]: nowSec };
    try {
      await ddb.send(new UpdateCommand({
        TableName: tableName(),
        Key: missionKey(auth.niarimUserId),
        UpdateExpression:
          "SET itemType = :type, firstQualifiedAt = :first, " +
          "claimedMask = if_not_exists(claimedMask, :zero), " +
          "verifiedEditSeconds = if_not_exists(verifiedEditSeconds, :zero), " +
          "totalMissionCoins = if_not_exists(totalMissionCoins, :zero) " +
          "ADD revision :one",
        ConditionExpression:
          "attribute_not_exists(revision) OR revision = :revision",
        ExpressionAttributeValues: {
          ":type": "CREATOR_MISSIONS_V1",
          ":first": firstQualifiedAt,
          ":zero": 0,
          ":one": 1,
          ":revision": state.revision,
        },
      }));
    } catch (error) {
      if (error instanceof TransactionCanceledException ||
          error instanceof ConditionalCheckFailedException) {
        conflict("進捗が更新されました。再試行してください", "MISSION_STATE_CHANGED");
      }
      throw error;
    }
    return ok({
      missionId: id,
      claimed: false,
      pending: true,
      readyAt: (nowSec + SOCIAL_HOLD_SECONDS) * 1000,
      awardedCoins: 0,
    });
  }
  if (nowSec - first < SOCIAL_HOLD_SECONDS) {
    return ok({
      missionId: id,
      claimed: false,
      pending: true,
      readyAt: (first + SOCIAL_HOLD_SECONDS) * 1000,
      awardedCoins: 0,
    });
  }

  const nextMask = claimMissionInMask(state.claimedMask, mission.bit);
  const nextTotal = state.totalMissionCoins + mission.coins;
  if (!Number.isSafeInteger(nextTotal) ||
      nextTotal > MAX_CREATOR_MISSION_COINS) {
    forbidden("ミッションの獲得上限を超えています", "MISSION_REWARD_BUDGET");
  }
  const claimedAt = { ...state.claimedAt, [bitKey]: nowSec };
  const pending = { ...state.firstQualifiedAt };
  delete pending[bitKey];
  // One user mission row + the existing coin wallet, atomically updated.
  // The revision and claimedMask preconditions make retries/races idempotent.
  try {
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {
          Update: {
            TableName: tableName(),
            Key: missionKey(auth.niarimUserId),
            UpdateExpression:
              "SET claimedMask = :newMask, totalMissionCoins = :total, " +
              "claimedAt = :claimedAt, firstQualifiedAt = :pending " +
              "ADD revision :one",
            ConditionExpression: "revision = :rev AND claimedMask = :oldMask",
            ExpressionAttributeValues: {
              ":newMask": nextMask,
              ":oldMask": state.claimedMask,
              ":total": nextTotal,
              ":claimedAt": claimedAt,
              ":pending": pending,
              ":rev": state.revision,
              ":one": 1,
            },
          },
        },
        {
          Update: {
            TableName: tableName(),
            Key: Keys.coinWallet(auth.niarimUserId),
            UpdateExpression:
              "SET itemType = :walletType ADD balanceCoins :reward, " +
              "missionEarnedCoins :reward",
            ConditionExpression:
              "attribute_not_exists(itemType) OR itemType = :walletType",
            ExpressionAttributeValues: {
              ":walletType": "COIN_WALLET",
              ":reward": mission.coins,
            },
          },
        },
      ],
    }));
  } catch (error) {
    if (error instanceof TransactionCanceledException) {
      // A simultaneous claim might have succeeded. Never award twice:
      // caller can refresh the read-only status and retry if unclaimed.
      conflict("達成状況が更新されました。再読み込みしてください", "MISSION_STATE_CHANGED");
    }
    throw error;
  }

  return ok({
    missionId: id,
    claimed: true,
    awardedCoins: mission.coins,
  });
}
