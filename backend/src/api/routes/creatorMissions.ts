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
import { workCountMissionById } from "../../lib/workCountMissionGrid";
import { claimWorkCountMission } from "./creatorWorkCountClaim";
import { getAllTimePublicWorks } from "./ranking";
import { editTimeVerificationEnabled } from "../../lib/editSessionPolicy";
import {
  CREATOR_MISSIONS,
  MAX_CREATOR_MISSION_COINS,
  MISSION_CATALOG_VERSION,
  missionRewardCoins,
  rankingMissionEligible, rankingMissionUnmetConditions,
  rankingEffectiveRankLimit, RANKING_MIN_BOOKMARKS,
  MIN_RANK_MISSION_PUBLIC_WORKS,
  missionClaimed,
  claimMissionInMask,
  type MissionDefinition,
} from "../../lib/missionCatalog";

/**
 * Claims OFF pending payout economics, moderation and wallet integrity review.
 * Initial community policy permits multiple accounts and reciprocal bookmarks;
 * this is separate from preventing the SAME account/work/goal from receiving
 * duplicate coins. A disabled flag cannot produce new wallet credits.
 */
function enabled(): boolean {
  return process.env.CREATOR_MISSION_CLAIMS_ENABLED === "true" &&
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED === "true";
}

const SOCIAL_HOLD_SECONDS = 48 * 60 * 60;
const QUERY_WORK_PAGE_SIZE = 25;
const MAX_OWN_WORK_PAGES = 20; // Prevent unbounded DynamoDB reads.
type MissionStateRecord = {
  itemType: "CREATOR_MISSIONS_V1" | "CREATOR_WORK_MISSIONS_V1";
  claimedMask: number;
  revision: number;
  verifiedEditSeconds: number;
  candidateEditSeconds: number;
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
  const candidateEditSeconds = typeof raw?.candidateEditSeconds === "number" &&
    Number.isSafeInteger(raw.candidateEditSeconds) &&
    raw.candidateEditSeconds >= 0 ? raw.candidateEditSeconds : 0;
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
    candidateEditSeconds,
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
): Promise<{ count: number; authoritative: boolean; bookmarks?: number }> {
  switch (mission.kind) {
    case "verifiedEditSeconds": {
      // No client-provided totalWorkSeconds or duration is accepted.
      // Only authenticated, nonce/sequence checked, server-clock-bounded
      // checkpoint receipts are eligible after separate operator approval.
      if(!editTimeVerificationEnabled()) return {count:0,authoritative:false};
      const recorded=await ddb.send(new GetCommand({
        TableName:tableName(),Key:Keys.creatorMissionState(userId),
        ConsistentRead:true,
      }));
      const item=recorded.Item;
      const seconds=item?.itemType==="CREATOR_MISSIONS_V1" &&
        Number.isSafeInteger(item?.verifiedEditSeconds) &&
        item!.verifiedEditSeconds>=0 ? item!.verifiedEditSeconds as number : 0;
      return {count:seconds,authoritative:true};
    }

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
      if (!workId || !/^[A-Za-z0-9_-]{11}$/.test(workId)) {
        badRequest("作品IDを指定してください", "MISSION_WORK_ID_REQUIRED");
      }
      // Use exactly the same public-visible ranking order as GET /ranking.
      // A raw GSI slot may belong to deleted/private works and is NOT a rank.
      const ranking=await getAllTimePublicWorks();
      const index=ranking.findIndex(w=>w.workId===workId &&
        w.authorId===userId);
      return {
        count:index<0?51:index+1, authoritative:true,
        bookmarks:index<0?0:ranking[index].bookmarkCount,
      };
    }
  }
}

export async function getMyCreatorMissions(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const selectedWorkId = event.queryStringParameters?.workId;
  if (selectedWorkId && !/^[A-Za-z0-9_-]{11}$/.test(selectedWorkId)) {
    badRequest("作品IDが不正です", "MISSION_INVALID_WORK_ID");
  }
  const [user, state, rankData] = await Promise.all([
    getUser(auth.niarimUserId),
    loadMissionState(auth.niarimUserId),
    ddb.send(new GetCommand({ TableName: tableName(), Key: Keys.batchState() })),
  ]);
  const rawCount = rankData.Item?.publishedWorkCount;
  const publishedWorkCount = typeof rawCount === "number" &&
    Number.isSafeInteger(rawCount) && rawCount >= 0 ? rawCount : 0;
  let workState: MissionStateRecord | undefined;
  let selectedWork: WorkItem | undefined;
  let selectedRanking: {count:number;bookmarks?:number}|undefined;
  if (selectedWorkId) {
    const work = await ddb.send(new GetCommand({
      TableName: tableName(), Key: Keys.work(selectedWorkId), ConsistentRead: true,
    }));
    selectedWork = work.Item as WorkItem | undefined;
    if (selectedWork?.authorId !== auth.niarimUserId) {
      forbidden("この作品のミッションは参照できません", "MISSION_NOT_YOUR_WORK");
    }
    workState = await loadMissionState(auth.niarimUserId, selectedWorkId);
    if(publishedWorkCount>=MIN_RANK_MISSION_PUBLIC_WORKS &&
       isPublicWork(selectedWork,auth.niarimUserId)) {
      // One authoritative live ranking read for ALL four milestones of
      // the selected work. Never fabricate positions from the client UI.
      selectedRanking=await measuredProgress(
        auth.niarimUserId,
        CREATOR_MISSIONS.find(m=>m.id==="bookmark_rank_1")!,
        selectedWorkId,
      );
    }
  }
  return ok({
    catalogVersion: MISSION_CATALOG_VERSION,
    enabled: enabled(),
    claimedMask: state.claimedMask,
    verifiedEditSeconds: state.verifiedEditSeconds,
    candidateEditSeconds: state.candidateEditSeconds,
    editTimeVerificationReady: editTimeVerificationEnabled(),
    editSessionPilotEnabled:
      process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED === "true",
    followerCount: user?.followerCount ?? 0,
    totalMissionCoins: state.totalMissionCoins,
    maximumLifetimeCreatorCoins: MAX_CREATOR_MISSION_COINS,
    perWorkRewardsAreUncapped: true,
    selectedWorkId: selectedWorkId ?? null,
    selectedWorkTitle: selectedWork?.title ?? null,
    publishedWorkCount,
    missions: CREATOR_MISSIONS.map((mission) => {
      const current = mission.perWork ? workState : state;
      const key = String(mission.bit);
      const eligible = mission.kind === "followers"
        ? (user?.followerCount ?? 0) >= mission.required
        : mission.kind === "workBookmarks" && selectedWorkId
          ? isPublicWork(selectedWork, auth.niarimUserId) &&
            Number.isSafeInteger(selectedWork!.bookmarkCount) &&
            selectedWork!.bookmarkCount >= mission.required
          : mission.kind === "verifiedEditSeconds"
            ? editTimeVerificationEnabled() &&
              state.verifiedEditSeconds>=mission.required
          : mission.kind === "niarimBookmarkRanking" && selectedWorkId
            ? selectedRanking!==undefined && rankingMissionEligible({
                goalRank:mission.required,
                liveRank:selectedRanking.count,
                publishedWorkCount,
                workBookmarks:selectedRanking.bookmarks??0,
              })
          : null;
      const pendingAt = current?.firstQualifiedAt[key];
      return {
        ...mission,
        eligible,
        readyForClaim: eligible === true &&
          (pendingAt === undefined ||
            (Math.floor(Date.now() / 1000) - pendingAt) >= SOCIAL_HOLD_SECONDS),
        claimed: current ? missionClaimed(current.claimedMask, mission.bit) : null,
        claimedAt: current?.claimedAt[key] ?? null,
        pendingSince: current?.firstQualifiedAt[key] ?? null,
        coins: current?.pendingCoins[key] ??
          missionRewardCoins(mission, publishedWorkCount),
        progress: mission.kind === "followers"
          ? user?.followerCount ?? 0
          : mission.kind === "verifiedEditSeconds" ? state.verifiedEditSeconds
          : mission.kind === "workBookmarks" && selectedWorkId
            ? selectedWork?.bookmarkCount ?? 0
          : mission.kind === "niarimBookmarkRanking" && selectedWorkId
            ? selectedRanking?.count??null : null,
        rankingUnmetConditions: mission.kind==="niarimBookmarkRanking"
          ? rankingMissionUnmetConditions({
              goalRank:mission.required,
              liveRank:selectedRanking?.count??null,
              publishedWorkCount,
              workBookmarks:Number.isSafeInteger(selectedWork?.bookmarkCount)
                ? selectedWork!.bookmarkCount : 0,
              workSelected:selectedWorkId!==undefined &&
                isPublicWork(selectedWork,auth.niarimUserId),
            })
          : null,
        rankingWorkBookmarks: mission.kind==="niarimBookmarkRanking" &&
          selectedWorkId ? (selectedWork?.bookmarkCount??0) : null,
        rankingMinPublishedWorks: mission.kind==="niarimBookmarkRanking"
          ? MIN_RANK_MISSION_PUBLIC_WORKS : null,
        rankingMinBookmarks: mission.kind==="niarimBookmarkRanking"
          ? RANKING_MIN_BOOKMARKS[mission.required] : null,
        rankingEffectiveRankLimit: mission.kind==="niarimBookmarkRanking"
          ? rankingEffectiveRankLimit(mission.required,publishedWorkCount)
          : null,
        rewardEnabled: enabled() &&
          (mission.kind !== "verifiedEditSeconds" ||
            editTimeVerificationEnabled()) &&
          !(mission.kind === "qualifiedWorks" &&
            mission.required > MAX_OWN_WORK_PAGES * QUERY_WORK_PAGE_SIZE),
      };
    }),
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
  if (!mission) {
    const gridMission=workCountMissionById(id);
    if (gridMission) return claimWorkCountMission(auth.niarimUserId,gridMission);
    badRequest("不明なミッションです", "INVALID_MISSION_ID");
  }

  const workId = mission.perWork ? body.workId : undefined;
  if (mission.perWork) {
    if (typeof workId !== "string" || !/^[A-Za-z0-9_-]{11}$/.test(workId)) {
      badRequest("作品ごとのミッションは作品IDが必要です", "MISSION_WORK_ID_REQUIRED");
    }
    const work = await ddb.send(new GetCommand({
      TableName: tableName(),
      Key: Keys.work(workId),
      ConsistentRead: true,
    }));
    if (!isPublicWork(work.Item as WorkItem | undefined, auth.niarimUserId)) {
      forbidden("公開中の自分の作品に限ります", "MISSION_WORK_NOT_ELIGIBLE");
    }
  }

  const itemWorkId = mission.perWork ? workId as string : undefined;
  const state = await loadMissionState(auth.niarimUserId, itemWorkId);
  if (missionClaimed(state.claimedMask, mission.bit)) {
    return ok({ missionId: id, workId: itemWorkId ?? null,
      claimed: true, awardedCoins: 0 });
  }

  // A daily statistics snapshot may lag live ranking. Never assume a
  // missing/invalid population count means an easy early reward.
  let publishedWorkCount:number|null=null;
  if (mission.kind==="niarimBookmarkRanking") {
    const count=await ddb.send(new GetCommand({
      TableName:tableName(),Key:Keys.batchState(),ConsistentRead:true,
    }));
    const n=count.Item?.publishedWorkCount;
    if(typeof n==="number" && Number.isSafeInteger(n) && n>=0)
      publishedWorkCount=n;
  }
  const progress = mission.kind==="niarimBookmarkRanking" &&
    (publishedWorkCount===null ||
      publishedWorkCount<MIN_RANK_MISSION_PUBLIC_WORKS)
    ? {count:51,authoritative:true,bookmarks:0}
    : await measuredProgress(auth.niarimUserId,mission,itemWorkId);
  if (!progress.authoritative) {
    forbidden("このミッションの安全な計測は準備中です", "MISSION_VERIFICATION_PENDING");
  }
  const eligible = mission.kind === "niarimBookmarkRanking"
    ? rankingMissionEligible({
        goalRank:mission.required,liveRank:progress.count,
        publishedWorkCount:publishedWorkCount ?? 0,
        workBookmarks:progress.bookmarks ?? 0,
      })
    : progress.count >= mission.required;
  const bitKey = String(mission.bit);
  if (!eligible) {
    // A mission that lost its requirement must restart the 48-hour hold.
    // Never retain an old qualifying timestamp for a later temporary spike.
    if (state.firstQualifiedAt[bitKey]) {
      const firstQualifiedAt = { ...state.firstQualifiedAt };
      const pendingCoins = { ...state.pendingCoins };
      delete firstQualifiedAt[bitKey];
      delete pendingCoins[bitKey];
      try {
        await ddb.send(new UpdateCommand({
          TableName: tableName(),
          Key: missionKey(auth.niarimUserId, itemWorkId),
          UpdateExpression:
            "SET firstQualifiedAt = :first, pendingCoins = :coins ADD revision :one",
          ConditionExpression:
            "revision = :rev AND claimedMask = :mask AND itemType = :type",
          ExpressionAttributeValues: {
            ":first": firstQualifiedAt,
            ":coins": pendingCoins,
            ":one": 1, ":rev": state.revision,
            ":mask": state.claimedMask, ":type": state.itemType,
          },
        }));
      } catch (error) {
        if (error instanceof ConditionalCheckFailedException ||
            error instanceof TransactionCanceledException) {
          conflict("進捗が更新されました。再確認してください", "MISSION_STATE_CHANGED");
        }
        throw error;
      }
    }
    conflict("ミッションの達成条件を確認できません", "MISSION_NOT_YET_COMPLETE");
  }

  const nowSec = Math.floor(Date.now() / 1000);
  const first = state.firstQualifiedAt[bitKey];
  let coins = state.pendingCoins[bitKey];
  if (!first || first > nowSec) {
    coins = missionRewardCoins(mission,publishedWorkCount ?? 0);
    const firstQualifiedAt = { ...state.firstQualifiedAt, [bitKey]: nowSec };
    const pendingCoins = { ...state.pendingCoins, [bitKey]: coins };
    try {
      await ddb.send(new UpdateCommand({
        TableName: tableName(),
        Key: missionKey(auth.niarimUserId, itemWorkId),
        UpdateExpression:
          "SET itemType = :type, firstQualifiedAt = :first, pendingCoins = :coins, " +
          "claimedMask = if_not_exists(claimedMask, :zero), " +
          "totalMissionCoins = if_not_exists(totalMissionCoins, :zero) " +
          "ADD revision :one",
        ConditionExpression:
          "attribute_not_exists(revision) OR revision = :revision",
        ExpressionAttributeValues: {
          ":type": state.itemType,
          ":first": firstQualifiedAt,
          ":coins": pendingCoins,
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
    return ok({ missionId: id, workId: itemWorkId ?? null,
      claimed: false, pending: true,
      readyAt: (nowSec + SOCIAL_HOLD_SECONDS) * 1000,
      offeredCoins: coins, awardedCoins: 0 });
  }
  if (nowSec - first < SOCIAL_HOLD_SECONDS) {
    return ok({ missionId: id, workId: itemWorkId ?? null,
      claimed: false, pending: true,
      readyAt: (first + SOCIAL_HOLD_SECONDS) * 1000,
      offeredCoins: coins ?? 0, awardedCoins: 0 });
  }

  // An already-present, versioned offer is immutable. Never pay a new rate
  // after the 48h hold. No forged client-side amounts are accepted.
  if (!Number.isSafeInteger(coins) || coins <= 0) {
    forbidden("報酬額の再検証が必要です", "MISSION_OFFER_MISSING");
  }
  const nextMask = claimMissionInMask(state.claimedMask, mission.bit);
  const nextTotal = state.totalMissionCoins + coins;
  if (!Number.isSafeInteger(nextTotal) || nextTotal < 0 ||
      (!mission.perWork && nextTotal > MAX_CREATOR_MISSION_COINS)) {
    forbidden("ミッションの獲得上限を超えています", "MISSION_REWARD_BUDGET");
  }
  const awardedAtMs = Date.now();
  const claimedAt = { ...state.claimedAt, [bitKey]: nowSec };
  const pending = { ...state.firstQualifiedAt };
  const pendingCoins = { ...state.pendingCoins };
  delete pending[bitKey];
  delete pendingCoins[bitKey];

  // Revalidate the live source in the SAME transaction as the wallet.
  // A GET alone would allow a simultaneous unpublish, unfollow or bookmark
  // removal to race with payout. Rankings are rechecked at BOTH the start
  // and end of the 48-hour hold; a transient live rank never pays instantly.
  // Anti-sybil/social manipulation still requires operational review.
  const sourceCondition = mission.perWork ? {
    ConditionCheck: {
      TableName: tableName(),
      Key: Keys.work(itemWorkId!),
      ConditionExpression:
        "itemType = :workType AND authorId = :author " +
        "AND isNiarimPublished = :published " +
        "AND youtubePrivacyStatus <> :private " +
        "AND youtubePrivacyStatus <> :deleted " +
        "AND gsi2pk = :bookmarkRank" +
        (mission.kind === "workBookmarks" ? " AND bookmarkCount >= :required" : ""),
      ExpressionAttributeValues: {
        ":workType": "WORK",
        ":author": auth.niarimUserId,
        ":published": true,
        ":private": "private",
        ":deleted": "deleted",
        ":bookmarkRank": "BOOKMARK_RANKING",
        ...(mission.kind === "workBookmarks" ? { ":required": mission.required } : {}),
      },
    },
  } : mission.kind === "followers" ? {
    ConditionCheck: {
      TableName: tableName(),
      Key: Keys.user(auth.niarimUserId),
      ConditionExpression:
        "itemType = :type AND followerCount >= :minimum",
      ExpressionAttributeValues: { ":type": "USER", ":minimum": mission.required },
    },
  } : null;

  // Exactly one atomic transaction: the SAME mission cannot credit twice
  // even if two clients race, the user switches devices or a request retries.
  try {
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {
          Update: {
            TableName: tableName(),
            Key: missionKey(auth.niarimUserId, itemWorkId),
            UpdateExpression:
              "SET claimedMask = :newMask, totalMissionCoins = :total, " +
              "claimedAt = :claimedAt, firstQualifiedAt = :pending, " +
              "pendingCoins = :pendingCoins ADD revision :one",
            ConditionExpression: "revision = :rev AND claimedMask = :oldMask",
            ExpressionAttributeValues: {
              ":newMask": nextMask,
              ":oldMask": state.claimedMask,
              ":total": nextTotal,
              ":claimedAt": claimedAt,
              ":pending": pending,
              ":pendingCoins": pendingCoins,
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
              "(attribute_not_exists(itemType) OR itemType = :walletType) " +
              "AND (attribute_not_exists(balanceCoins) OR " +
              "balanceCoins BETWEEN :zero AND :maxBefore)",
            ExpressionAttributeValues: {
              ":walletType": "COIN_WALLET",
              ":reward": coins,
              ":zero": 0,
              ":maxBefore": Number.MAX_SAFE_INTEGER - coins,
            },
          },
        },
        {
          Put: {
            TableName: tableName(),
            Item: {
              ...Keys.coinHistory(auth.niarimUserId, awardedAtMs,
                `mission-${id}-${itemWorkId ?? "account"}`),
              itemType: "COIN_HISTORY", source: "creator-mission",
              deltaCoins: coins, occurredAtEpochMs: awardedAtMs,
              missionId: id, workId: itemWorkId ?? null,
            },
            ConditionExpression: "attribute_not_exists(pk)",
          },
        },
        ...(sourceCondition ? [sourceCondition] : []),
      ],
    }));
  } catch (error) {
    if (error instanceof TransactionCanceledException ||
        error instanceof ConditionalCheckFailedException) {
      conflict("達成状況が更新されました。再読み込みしてください", "MISSION_STATE_CHANGED");
    }
    throw error;
  }

  return ok({ missionId: id, workId: itemWorkId ?? null,
    claimed: true, awardedCoins: coins });
}
