import { createHash, createHmac, randomBytes } from "node:crypto";
import type { DynamoDBBatchResponse, DynamoDBRecord } from "aws-lambda";
import { ConditionalCheckFailedException, TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { GetCommand, PutCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "./dynamo";
import { sendPushToUser } from "./push";
import { TABLE_ITEM_TYPE } from "./types";

export const communityActivityType = "COMMUNITY_ACTIVITY_V1";
export const missionActivityType = "MISSION_ACTIVITY_V1";
export const notificationStreamMaxAgeMs = 15 * 60_000;
export const communityKinds = ["newFollower", "newBookmark", "newRepost", "scheduledRelease", "workPosted", "workPublicationConfirmed"] as const;
type Kind = typeof communityKinds[number];
const day = 86_400_000;

// Use the same user-owned chronological index as the mission bell. Only this
// allowlist ever reaches the inbox or push; relationship rows stay private.
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
  newFollower: { body: "新しいフォロワーが増えました", key: "push_new_follower" },
  newBookmark: { body: "作品がブックマークされました", key: "push_new_bookmark" },
  newRepost: { body: "作品がリポストされました", key: "push_new_repost" },
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
  return kind !== "newFollower" && kind !== "workPosted" && workId(id)
    ? `/community/work/${id}` : myWorks;
}

interface Activity {
  kind: Kind;
  owner: string;
  actor?: string;
  work?: string;
  occurredAt: string;
  isPost?: boolean;
  source?: { pk: string; sk: string; timeField: string };
}

async function recentActivity(record: DynamoDBRecord): Promise<Activity | undefined> {
  const image = record.dynamodb?.NewImage;
  const type = str(image, "itemType");
  if (type === TABLE_ITEM_TYPE.Work) {
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

let fingerprintSecret: Promise<string> | undefined;

// One server-only key, not one row per relationship. A keyed digest prevents
// a recipient from testing another person's public ID against a notice.
async function loadFingerprintSecret(): Promise<string> {
  const Key = { pk: "SYSTEM#COMMUNITY_NOTICE_FINGERPRINT", sk: "V1" };
  const read = async () => (await ddb.send(new GetCommand({
    TableName: tableName(), Key, ConsistentRead: true,
  }))).Item?.secret;
  const existing = await read();
  if (typeof existing === "string" && /^[a-f0-9]{64}$/.test(existing)) return existing;
  const secret = randomBytes(32).toString("hex");
  try {
    await ddb.send(new PutCommand({
      TableName: tableName(), Item: { ...Key, secret, itemType: "INTERNAL_CONFIG" },
      ConditionExpression: "attribute_not_exists(pk)",
    }));
    return secret;
  } catch (error) {
    if (!(error instanceof ConditionalCheckFailedException)) throw error;
    const winner = await read();
    if (typeof winner !== "string" || !/^[a-f0-9]{64}$/.test(winner)) {
      throw new Error("Missing notification fingerprint key");
    }
    return winner;
  }
}

async function fingerprint(owner: string, kind: Kind, actor: string, work?: string) {
  fingerprintSecret ??= loadFingerprintSecret().catch((error: unknown) => {
    fingerprintSecret = undefined;
    throw error;
  });
  return createHmac("sha256", await fingerprintSecret)
    .update(JSON.stringify([owner, kind, actor, work ?? ""])).digest("hex");
}

async function storeActivity(activity: Activity): Promise<void> {
  const { kind, owner, actor, work, occurredAt, source, isPost } = activity;
  const when = Date.parse(occurredAt);
  const now = Date.now();
  if (!Number.isFinite(when) || when > now + 60_000 ||
      when < now - notificationStreamMaxAgeMs) return;
  const currentTable = tableName();
  const marker = {
    pk: `USER#${owner}`,
    sk: `COMMUNITY_NOTICE_KEY#${digest(kind, actor ?? occurredAt, work ?? "")}`,
  };
  // Event IDs use the actual occurrence, and never contain the actor.
  const eventId = `community_${digest(marker.sk, occurredAt, owner)}`;
  const firstKey = actor ? await fingerprint(owner, kind, actor, work) : undefined;
  const displayKey = isPost && work ? `post:${work}` : eventId;
  const requiresListing = kind !== "workPosted" && kind !== "scheduledRelease";
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
      ConditionExpression: "itemType = :work AND authorId = :owner" +
        (requiresListing
          ? " AND isNiarimPublished = :on AND youtubePrivacyStatus IN (:public, :unlisted)"
          : kind === "scheduledRelease" ? " AND youtubePrivacyStatus = :public" : ""),
      ExpressionAttributeValues: {
        ":work": TABLE_ITEM_TYPE.Work, ":owner": owner,
        ...(requiresListing ? { ":on": true, ":public": "public", ":unlisted": "unlisted" }
          : kind === "scheduledRelease" ? { ":public": "public" } : {}),
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
          itemType: communityActivityType, kind, eventId, occurredAt, displayKey,
          ...(firstKey ? { firstKey } : {}),
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
  let route = isMission ? "/creator-missions" : myWorks;
  if (type !== "mission_achievement" && workId(id) && type !== "newFollower") {
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
  const firstKey = str(image, "firstKey");
  const displayKey = str(image, "displayKey") ?? eventId;
  await sendPushToUser(owner, {
    title: "NIARIM", body: message.body, androidBodyLocKey: message.key,
    deviceHandled: true,
    allowLegacy: isMission,
    data: {
      targetRoute: route, type, owner, eventId, occurredAt, displayKey,
      niarimNoticeVersion: "1", ...(firstKey ? { firstKey } : {}),
    },
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
