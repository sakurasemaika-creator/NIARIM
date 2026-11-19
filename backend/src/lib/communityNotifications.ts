import { createHash } from "node:crypto";
import type { DynamoDBBatchResponse, DynamoDBRecord } from "aws-lambda";
import { ConditionalCheckFailedException, TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { GetCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "./dynamo";
import { sendPushToUser } from "./push";
import { ACCOUNT_MISSIONS, PER_WORK_MISSIONS, REPOST_MISSIONS } from "./missionCatalog";
import { recordMissionAchievement } from "./missionNotifications";
import { TABLE_ITEM_TYPE } from "./types";

export const communityActivityType = "COMMUNITY_ACTIVITY_V1";
export const missionActivityType = "MISSION_ACTIVITY_V1";
export const notificationStreamMaxAgeMs = 15 * 60_000;
export const communityKinds = ["scheduledRelease", "workPosted", "workPublicationConfirmed"] as const;
type Kind = typeof communityKinds[number];
const day = 86_400_000;

// Publication notices use the same user-owned index as mission activity.
const myWorks = "/community/my-works";
const userId = (value?: string): value is string =>
  value !== undefined && /^N[0-9a-f]{32}$/.test(value);
const workId = (value?: string): value is string =>
  value !== undefined && /^[A-Za-z0-9_-]{11}$/.test(value);
const youtubeVisible = (status: unknown) => status === "public" || status === "unlisted";
const publicWork = (item?: Record<string, unknown>) =>
  item?.itemType === TABLE_ITEM_TYPE.Work && item.isNiarimPublished === true &&
  youtubeVisible(item.youtubePrivacyStatus);
const digest = (...parts: string[]) =>
  createHash("sha256").update(JSON.stringify(parts)).digest("hex").slice(0, 32);
type Image = NonNullable<DynamoDBRecord["dynamodb"]>["NewImage"];
const str = (image: Image, key: string) => image?.[key]?.S;

const content: Record<Kind | "mission_achievement", { body: string; key: string }> = {
  scheduledRelease: { body: "予約していた作品が公開されました", key: "push_scheduled_release" },
  workPosted: { body: "作品の投稿が完了しました", key: "push_work_posted" },
  workPublicationConfirmed: { body: "作品が公開されました", key: "push_work_published" },
  mission_achievement: { body: "新しいミッション達成通知があります", key: "push_mission_achievement" },
};

export function isCommunityKind(kind: unknown): kind is Kind {
  return typeof kind === "string" && communityKinds.some((known) => known === kind);
}

/** Recheck the current work before exposing a detail link. The inbox is safe
 * even if a work has since been deleted or made private. */
export function communityTarget(kind: Kind, id?: string): string {
  return kind !== "workPosted" && workId(id)
    ? `/community/work/${id}` : myWorks;
}

interface Activity {
  kind: Kind;
  owner: string;
  work: string;
  occurredAt: string;
  isPost?: boolean;
}

function recentActivity(record: DynamoDBRecord): Activity | undefined {
  const image = record.dynamodb?.NewImage;
  if (str(image, "itemType") !== TABLE_ITEM_TYPE.Work) return;
  const old = record.dynamodb?.OldImage;
  const owner = str(image, "authorId");
  const work = str(image, "workId");
  if (!userId(owner) || !workId(work)) return;
  const visible = image?.isNiarimPublished?.BOOL === true &&
    ["public", "unlisted"].includes(str(image, "youtubePrivacyStatus") ?? "");
  const scheduledAt = str(image, "scheduledPublishAt");
  if (record.eventName === "INSERT") {
    // A reservation is not a successful publication.
    if (scheduledAt && !visible) return;
    const occurredAt = str(image, "createdAt");
    if (occurredAt) return {
      kind: visible ? "workPublicationConfirmed" : "workPosted", owner, work, occurredAt, isPost: true,
    };
    return;
  }
  if (record.eventName !== "MODIFY") return;
  const previouslyVisible = old?.isNiarimPublished?.BOOL === true &&
    ["public", "unlisted"].includes(str(old, "youtubePrivacyStatus") ?? "");
  const confirmedAt = str(image, "scheduledReleaseConfirmedAt");
  if (str(old, "youtubePrivacyStatus") === "private" &&
      str(image, "youtubePrivacyStatus") === "public" && confirmedAt &&
      confirmedAt !== str(old, "scheduledReleaseConfirmedAt")) {
    return { kind: "scheduledRelease", owner, work, occurredAt: confirmedAt };
  }
  if (!visible || previouslyVisible) return;
  // An owner can publish a previously hidden but already verified video.
  // Conditions in the producer ensure this marker is written only with that transition.
  const publishedAt = str(image, "plazaPublicationConfirmedAt");
  if (publishedAt && publishedAt !== str(old, "plazaPublicationConfirmedAt")) {
    return { kind: "workPublicationConfirmed", owner, work, occurredAt: publishedAt };
  }
  return;
}

async function storeActivity(activity: Activity): Promise<void> {
  const { kind, owner, work, occurredAt, isPost } = activity;
  const when = Date.parse(occurredAt);
  const now = Date.now();
  if (!Number.isFinite(when) || when > now + 60_000 ||
      when < now - notificationStreamMaxAgeMs) return;
  const currentTable = tableName();
  const marker = {
    pk: `USER#${owner}`,
    sk: `COMMUNITY_NOTICE_KEY#${digest(kind, occurredAt, work)}`,
  };
  const eventId = `community_${digest(marker.sk, occurredAt, owner)}`;
  const displayKey = isPost ? `post:${work}` : eventId;
  const requiresListing = kind !== "workPosted" && kind !== "scheduledRelease";
  const workCheck = { ConditionCheck: {
      TableName: currentTable, Key: Keys.work(work),
      ConditionExpression: "itemType = :work AND authorId = :owner" +
        (requiresListing
          ? " AND isNiarimPublished = :on AND youtubePrivacyStatus IN (:public, :unlisted)"
          : kind === "scheduledRelease" ? " AND youtubePrivacyStatus = :public" : ""),
      ExpressionAttributeValues: {
        ":work": TABLE_ITEM_TYPE.Work, ":owner": owner,
        ...(requiresListing ? { ":on": true, ":public": "public", ":unlisted": "unlisted" }
          : kind === "scheduledRelease" ? { ":public": "public" } : {}),
      },
  } };
  try {
    await ddb.send(new TransactWriteCommand({ TransactItems: [
      workCheck,
      { Put: {
        TableName: currentTable,
        Item: { ...marker, itemType: "COMMUNITY_NOTICE_DEDUPE_V1", when,
          ttl: Math.ceil((when + day) / 1000) },
        ConditionExpression: "attribute_not_exists(pk) OR #when <= :cutoff",
        ExpressionAttributeNames: { "#when": "when" },
        ExpressionAttributeValues: { ":cutoff": when - day },
      } },
      { Put: {
        TableName: currentTable,
        Item: {
          ...Keys.missionActivity(owner, when, eventId),
          itemType: communityActivityType, kind, eventId, occurredAt, displayKey,
          workId: work,
          ttl: Math.ceil((when + 30 * day) / 1000),
          pushPending: true,
        },
        ConditionExpression: "attribute_not_exists(pk)",
      } },
      { ConditionCheck: {
        TableName: currentTable, Key: Keys.user(owner),
        ConditionExpression: "itemType = :user AND attribute_not_exists(erasureReceipt)",
        ExpressionAttributeValues: { ":user": TABLE_ITEM_TYPE.User },
      } },
    ] }));
  } catch (error) {
    // A removal/privacy change or an unexpired marker is a normal no-op.
    // Throttling and concurrent transactions must remain retryable.
    if (error instanceof TransactionCanceledException &&
        error.CancellationReasons?.some((reason) => reason.Code === "ConditionalCheckFailed")) return;
    throw error;
  }
}

async function deliver(record: DynamoDBRecord): Promise<void> {
  const image = record.dynamodb?.NewImage;
  const pk = str(image, "pk");
  const sk = str(image, "sk");
  const owner = pk?.startsWith("USER#") ? pk.slice(5) : undefined;
  if (!pk || !sk?.startsWith("MISSION_ACTIVITY#") || !userId(owner) ||
      image?.pushPending?.BOOL !== true) return;
  const isMission = str(image, "itemType") === missionActivityType;
  const kind = str(image, "kind");
  if (!isMission && !isCommunityKind(kind)) return;
  const type = isMission ? "mission_achievement" : kind as Kind;
  const id = str(image, "workId");
  let route = isMission ? "/creator-missions" : myWorks;
  if (type !== "mission_achievement" && workId(id)) {
    const { Item } = await ddb.send(new GetCommand({
      TableName: tableName(), Key: Keys.work(id), ConsistentRead: true,
    }));
    if (Item?.itemType !== TABLE_ITEM_TYPE.Work || Item.authorId !== owner) return;
    if (type === "scheduledRelease" ? !youtubeVisible(Item.youtubePrivacyStatus)
      : type !== "workPosted" && !publicWork(Item)) return;
    route = communityTarget(type, id);
  }
  // Claim once before the external request. FCM can accept a message even
  // when the client times out, so resending that event could double notify.
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(), Key: { pk, sk },
      ConditionExpression: "pushPending = :pending",
      UpdateExpression: "SET pushAttemptedAt = :now REMOVE pushPending",
      ExpressionAttributeValues: { ":pending": true, ":now": new Date().toISOString() },
    }));
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) return;
    throw error;
  }
  const message = content[type];
  const eventId = str(image, "eventId");
  const when = Date.parse(str(image, "occurredAt") ?? "");
  if (!eventId || !Number.isFinite(when)) return;
  const occurredAt = new Date(when).toISOString();
  const displayKey = str(image, "displayKey") ?? eventId;
  await sendPushToUser(owner, {
    title: "NIARIM", body: message.body, androidBodyLocKey: message.key,
    deviceHandled: true,
    allowLegacy: isMission,
    data: {
      targetRoute: route, type, owner, eventId, occurredAt, displayKey,
      niarimNoticeVersion: "1",
    },
  });
}

const followerMissions = ACCOUNT_MISSIONS.filter(m => m.kind === "followers");
const bookmarkMissions = PER_WORK_MISSIONS.filter(m =>
  m.kind === "workBookmarks" && m.required > 0,
);

function imageCount(image: Image, key: string): number {
  const raw = image?.[key]?.N;
  if (raw === undefined) return 0;
  const count = Number(raw);
  return Number.isSafeInteger(count) && count >= 0 ? count : NaN;
}

async function recordReachedMilestones(record: DynamoDBRecord): Promise<void> {
  if (record.eventName !== "MODIFY") return;
  const old = record.dynamodb?.OldImage;
  const image = record.dynamodb?.NewImage;
  const timestamp = record.dynamodb?.ApproximateCreationDateTime;
  if (!old || !image || !timestamp) return;
  const when = timestamp * 1000;
  const now = Date.now();
  if (!Number.isFinite(when) || when < now - notificationStreamMaxAgeMs ||
      when > now + 60_000) return;
  const occurredAt = new Date(when).toISOString();
  const type = str(image, "itemType");
  if (type !== str(old, "itemType")) return;
  const crossed = (attribute: string, required: number) =>
    imageCount(old, attribute) < required && imageCount(image, attribute) >= required;
  if (type === TABLE_ITEM_TYPE.User) {
    const owner = str(image, "niarimUserId");
    if (!userId(owner) || str(image, "pk") !== `USER#${owner}`) return;
    for (const m of followerMissions) {
      if (crossed("followerCount", m.required)) {
        await recordMissionAchievement(owner, {
          kind: "followers", missionId: m.id, required: m.required, occurredAt,
        });
      }
    }
    return;
  }
  if (type !== TABLE_ITEM_TYPE.Work || image.isNiarimPublished?.BOOL !== true ||
      !youtubeVisible(str(image, "youtubePrivacyStatus")) ||
      str(image, "gsi2pk") !== "BOOKMARK_RANKING") return;
  const owner = str(image, "authorId");
  const id = str(image, "workId");
  if (!userId(owner) || !workId(id)) return;
  for (const [kind, countAttribute, missions] of [
    ["workBookmarks", "bookmarkCount", bookmarkMissions],
    ["workReposts", "repostCount", REPOST_MISSIONS],
  ] as const) {
    for (const m of missions) {
      if (crossed(countAttribute, m.required)) {
        await recordMissionAchievement(owner, {
          kind, missionId: m.id, required: m.required, occurredAt,
          workId: id, workTitle: str(image, "title"),
        });
      }
    }
  }
}

export async function handleNotificationStream(records: DynamoDBRecord[]): Promise<DynamoDBBatchResponse> {
  const failures = await Promise.all(records.map(async (record): Promise<{itemIdentifier: string} | undefined> => {
    if (record.eventSource !== "aws:dynamodb") return undefined;
    const image = record.dynamodb?.NewImage;
    const type = str(image, "itemType");
    try {
      if (record.eventName === "INSERT" &&
          (type === communityActivityType || type === missionActivityType)) {
        await deliver(record);
      } else {
        const activity = recentActivity(record);
        if (activity) await storeActivity(activity);
        await recordReachedMilestones(record);
      }
    } catch (error) {
      console.error("Notification stream record failed", error instanceof Error ? error.name : "UnknownError");
      const id = record.dynamodb?.SequenceNumber;
      if (id) return { itemIdentifier: id };
      throw error;
    }
    return undefined;
  }));
  return { batchItemFailures: failures.flatMap((failure) => failure ? [failure] : []) };
}
