import { createHash } from "node:crypto";
import type { DynamoDBBatchResponse, DynamoDBRecord } from "aws-lambda";
import { ConditionalCheckFailedException, TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { GetCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "./dynamo";
import { sendPushToUser } from "./push";
import { TABLE_ITEM_TYPE } from "./types";

export const communityActivityType = "COMMUNITY_ACTIVITY_V1";
export const missionActivityType = "MISSION_ACTIVITY_V1";
export const notificationStreamMaxAgeMs = 15 * 60_000;
export const communityKinds = ["newFollower", "newBookmark", "newRepost", "scheduledRelease"] as const;
type Kind = typeof communityKinds[number];
const day = 86_400_000;

// Use the same user-owned chronological index as the mission bell. Only this
// allowlist ever reaches the inbox or push; relationship rows stay private.
const inbox = "/community/notifications";
const userId = (value?: string): value is string =>
  value !== undefined && /^N[0-9a-f]{32}$/.test(value);
const workId = (value?: string): value is string =>
  value !== undefined && /^[A-Za-z0-9_-]{11}$/.test(value);
const publicWork = (item?: Record<string, unknown>) =>
  item?.itemType === TABLE_ITEM_TYPE.Work && item.isNiarimPublished === true &&
  (item.youtubePrivacyStatus === "public" || item.youtubePrivacyStatus === "unlisted");
const digest = (...parts: string[]) =>
  createHash("sha256").update(JSON.stringify(parts)).digest("hex").slice(0, 32);
type Image = NonNullable<DynamoDBRecord["dynamodb"]>["NewImage"];
const str = (image: Image, key: string) => image?.[key]?.S;

const content: Record<Kind | "mission_achievement", { body: string; key: string }> = {
  newFollower: { body: "新しいフォロワーが増えました", key: "push_new_follower" },
  newBookmark: { body: "作品がブックマークされました", key: "push_new_bookmark" },
  newRepost: { body: "作品がリポストされました", key: "push_new_repost" },
  scheduledRelease: { body: "予約していた作品が公開されました", key: "push_scheduled_release" },
  mission_achievement: { body: "新しいミッション達成通知があります", key: "push_mission_achievement" },
};

export function isCommunityKind(kind: unknown): kind is Kind {
  return typeof kind === "string" && communityKinds.some((known) => known === kind);
}

/** Recheck the current work before exposing a detail link. The inbox is safe
 * even if a work has since been deleted or made private. */
export function communityTarget(kind: Kind, id?: string): string {
  return kind !== "newFollower" && workId(id) ? `/community/work/${id}` : inbox;
}

interface Activity {
  kind: Kind;
  owner: string;
  actor?: string;
  work?: string;
  occurredAt: string;
  source?: { pk: string; sk: string; timeField: string };
}

async function recentActivity(record: DynamoDBRecord): Promise<Activity | undefined> {
  const image = record.dynamodb?.NewImage;
  const type = str(image, "itemType");
  if (type === TABLE_ITEM_TYPE.Work && record.eventName === "MODIFY") {
    const old = record.dynamodb?.OldImage;
    const occurrence = str(image, "scheduledReleaseConfirmedAt");
    const owner = str(image, "authorId");
    const work = str(image, "workId");
    if (str(old, "youtubePrivacyStatus") === "private" &&
        str(image, "youtubePrivacyStatus") === "public" &&
        image?.isNiarimPublished?.BOOL === true && occurrence &&
        occurrence !== str(old, "scheduledReleaseConfirmedAt") &&
        userId(owner) && workId(work)) {
      return { kind: "scheduledRelease", owner, work, occurredAt: occurrence };
    }
    return;
  }
  if (record.eventName !== "INSERT") return;
  if (type === TABLE_ITEM_TYPE.FollowerRecord) {
    const actor = str(image, "followerId");
    const owner = str(image, "targetId");
    const occurredAt = str(image, "followedAt");
    if (userId(actor) && userId(owner) && occurredAt && actor !== owner) {
      return { kind: "newFollower", owner, actor, occurredAt, source: {
        ...Keys.followerRecord(owner, actor), timeField: "followedAt",
      } };
    }
    return;
  }
  const bookmark = type === TABLE_ITEM_TYPE.Bookmark;
  if (!bookmark && type !== TABLE_ITEM_TYPE.Repost) return;
  const actor = str(image, "niarimUserId");
  const work = str(image, "workId");
  const timeField = bookmark ? "bookmarkedAt" : "repostedAt";
  const occurredAt = str(image, timeField);
  if (!userId(actor) || !workId(work) || !occurredAt) return;
  const { Item } = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.work(work), ConsistentRead: true,
  }));
  const owner = Item?.authorId;
  if (!publicWork(Item) || !userId(owner) || owner === actor) return;
  return {
    kind: bookmark ? "newBookmark" : "newRepost",
    owner, actor, work, occurredAt,
    source: { ...(bookmark ? Keys.bookmark(actor, work) : Keys.repost(actor, work)), timeField },
  };
}

async function storeActivity(activity: Activity): Promise<void> {
  const { kind, owner, actor, work, occurredAt, source } = activity;
  const when = Date.parse(occurredAt);
  const now = Date.now();
  if (!Number.isFinite(when) || when > now + 60_000 ||
      when < now - notificationStreamMaxAgeMs) return;
  const currentTable = tableName();
  const marker = {
    pk: `USER#${owner}`,
    sk: `COMMUNITY_NOTICE_KEY#${digest(kind, actor ?? "", work ?? "")}`,
  };
  // Event IDs use the actual occurrence, and never contain the actor.
  const eventId = `community_${digest(marker.sk, occurredAt, owner)}`;
  const checks = [
    ...(source ? [{ ConditionCheck: {
      TableName: currentTable, Key: { pk: source.pk, sk: source.sk },
      ConditionExpression: "#when = :when",
      ExpressionAttributeNames: { "#when": source.timeField },
      ExpressionAttributeValues: { ":when": occurredAt },
    } }] : []),
    ...(actor ? [Keys.block(actor, owner), Keys.block(owner, actor)].map((Key) => ({
      ConditionCheck: { TableName: currentTable, Key, ConditionExpression: "attribute_not_exists(pk)" },
    })) : []),
    ...(work ? [{ ConditionCheck: {
      TableName: currentTable, Key: Keys.work(work),
      ConditionExpression: "itemType = :work AND authorId = :owner AND isNiarimPublished = :on AND youtubePrivacyStatus IN (:public, :unlisted)",
      ExpressionAttributeValues: {
        ":work": TABLE_ITEM_TYPE.Work, ":owner": owner, ":on": true,
        ":public": "public", ":unlisted": "unlisted",
      },
    } }] : []),
  ];
  try {
    await ddb.send(new TransactWriteCommand({ TransactItems: [
      ...checks,
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
          itemType: communityActivityType, kind, eventId, occurredAt,
          ...(work ? { workId: work } : {}),
          ttl: Math.ceil((when + 30 * day) / 1000),
          pushPending: true,
        },
        ConditionExpression: "attribute_not_exists(pk)",
      } },
    ] }));
  } catch (error) {
    // A block/removal/privacy change or an unexpired marker is a normal no-op.
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
  let route = isMission ? "/creator-missions" : inbox;
  if (type !== "mission_achievement" && workId(id)) {
    const { Item } = await ddb.send(new GetCommand({
      TableName: tableName(), Key: Keys.work(id), ConsistentRead: true,
    }));
    if (!publicWork(Item) || Item?.authorId !== owner) return;
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
  await sendPushToUser(owner, {
    title: "NIARIM", body: message.body, androidBodyLocKey: message.key,
    data: { targetRoute: route, type },
  });
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
        const activity = await recentActivity(record);
        if (activity) await storeActivity(activity);
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
