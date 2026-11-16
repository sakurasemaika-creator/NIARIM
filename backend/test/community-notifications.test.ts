import type { DynamoDBRecord } from "aws-lambda";
import { ConditionalCheckFailedException, TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { GetCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const { send, push, authenticate } = vi.hoisted(() => ({
  send: vi.fn(), push: vi.fn(), authenticate: vi.fn(),
}));
vi.mock("../src/lib/dynamo", async (base) => ({
  ...(await base<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/push", () => ({ sendPushToUser: push }));
vi.mock("../src/lib/auth", () => ({ authenticate }));

import { handleNotificationStream } from "../src/lib/communityNotifications";
import { getMyMissionActivity } from "../src/api/routes/creatorMissionActivity";
import { recordMissionAchievement } from "../src/lib/missionNotifications";

const owner = "N" + "a".repeat(32);
const actor = "N" + "b".repeat(32);
const work = "Ab_12345678";
const now = "2026-11-16T04:20:00.000Z";
const publicWork = { itemType: "WORK", authorId: owner, workId: work,
  youtubePrivacyStatus: "public", isNiarimPublished: true };
const image = (values: Record<string, unknown>) =>
  Object.fromEntries(Object.entries(values).map(([k, v]) => [k,
    typeof v === "boolean" ? { BOOL: v } : { S: String(v) }]));
function record(values: Record<string, unknown>, eventName: DynamoDBRecord["eventName"] = "INSERT",
  old?: Record<string, unknown>): DynamoDBRecord {
  return { eventSource: "aws:dynamodb", eventName, dynamodb: {
    SequenceNumber: "1234", NewImage: image(values), ...(old ? { OldImage: image(old) } : {}),
  } };
}
const follow = () => record({
  itemType: "FOLLOWER_RECORD", followerId: actor, targetId: owner, followedAt: now,
});
const bookmark = () => record({
  itemType: "BOOKMARK", niarimUserId: actor, workId: work, bookmarkedAt: now,
});

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date(now));
  vi.stubEnv("TABLE_NAME", "test");
  send.mockReset();
  send.mockImplementation(async (command) => command instanceof GetCommand
    ? { Item: publicWork } : {});
  push.mockReset().mockResolvedValue(undefined);
  authenticate.mockReset().mockResolvedValue({ niarimUserId: owner });
});
afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

function lastStored() {
  const write = send.mock.calls.find(([cmd]) => cmd instanceof TransactWriteCommand);
  expect(write).toBeDefined();
  const items = (write![0] as TransactWriteCommand).input.TransactItems!;
  return { items, marker: items.at(-2)!.Put!, event: items.at(-1)!.Put!.Item! };
}

describe("committed activity to private history", () => {
  it.each([
    ["newFollower", follow()],
    ["newBookmark", bookmark()],
    ["newRepost", record({ itemType: "REPOST", niarimUserId: actor,
      workId: work, repostedAt: now })],
  ])("records %s anonymously and checks current relationship and both blocks", async (kind, change) => {
    expect(await handleNotificationStream([change])).toEqual({ batchItemFailures: [] });
    const { items, marker, event } = lastStored();
    expect(event).toMatchObject({ pk: "USER#" + owner, kind, occurredAt: now, pushPending: true });
    expect(JSON.stringify(event)).not.toContain(actor);
    expect(marker.ConditionExpression).toContain("#when <= :cutoff");
    expect(marker.ExpressionAttributeValues![":cutoff"]).toBe(Date.parse(now) - 86_400_000);
    expect(items.map((i) => i.ConditionCheck?.Key?.sk)).toEqual(expect.arrayContaining([
      "BLOCK#" + actor, "BLOCK#" + owner,
    ]));
    expect(push).not.toHaveBeenCalled();
  });

  it("suppresses self-actions, removals, stale records and nonpublic work", async () => {
    await handleNotificationStream([
      { ...follow(), eventName: "REMOVE" },
      record({ itemType: "FOLLOWER_RECORD", followerId: owner, targetId: owner, followedAt: now }),
      record({ itemType: "FOLLOWER_RECORD", followerId: actor, targetId: owner, followedAt: "2026-11-15T04:00:00Z" }),
    ]);
    expect(send).not.toHaveBeenCalled();
    send.mockResolvedValueOnce({ Item: { ...publicWork, youtubePrivacyStatus: "private" } });
    await handleNotificationStream([bookmark()]);
    expect(send.mock.calls.map(([c]) => c.constructor.name)).toEqual(["GetCommand"]);
  });

  it("dedupes a replay or a new toggle within 24 hours without retrying a block denial", async () => {
    send.mockRejectedValueOnce(new TransactionCanceledException({
      $metadata: {}, message: "Expected condition failure", CancellationReasons: [{ Code: "ConditionalCheckFailed" }],
    }));
    expect(await handleNotificationStream([follow()])).toEqual({ batchItemFailures: [] });
    expect(push).not.toHaveBeenCalled();
    send.mockRejectedValueOnce(new Error("temporary throttle"));
    expect(await handleNotificationStream([follow()])).toEqual({
      batchItemFailures: [{ itemIdentifier: "1234" }],
    });
  });

  it("records only a verified scheduled release transition for a visible work", async () => {
    const transition = { ...publicWork, scheduledReleaseConfirmedAt: now };
    await handleNotificationStream([
      record(publicWork, "MODIFY", { youtubePrivacyStatus: "private" }),
      record({ ...transition, isNiarimPublished: false }, "MODIFY", { youtubePrivacyStatus: "private" }),
      record(transition, "MODIFY", { youtubePrivacyStatus: "public" }),
    ]);
    expect(send).not.toHaveBeenCalled();
    await handleNotificationStream([record(transition, "MODIFY", { youtubePrivacyStatus: "private" })]);
    expect(lastStored().event).toMatchObject({ kind: "scheduledRelease", workId: work });
  });
});

describe("delivery from stored activity", () => {
  it("claims once and sends safe data, without double sending on replay", async () => {
    await handleNotificationStream([bookmark()]);
    const activity = record(lastStored().event);
    expect(await handleNotificationStream([activity])).toEqual({ batchItemFailures: [] });
    expect(push).toHaveBeenCalledWith(owner, expect.objectContaining({
      androidBodyLocKey: "push_new_bookmark",
      data: { targetRoute: "/community/work/" + work, type: "newBookmark" },
    }));
    expect(send.mock.calls.some(([cmd]) => cmd instanceof UpdateCommand &&
      cmd.input.ConditionExpression === "pushPending = :pending")).toBe(true);
    send.mockResolvedValueOnce({ Item: publicWork }).mockRejectedValueOnce(
      new ConditionalCheckFailedException({ $metadata: {}, message: "Already attempted" }));
    await handleNotificationStream([activity]);
    expect(push).toHaveBeenCalledTimes(1);
  });

  it("skips a private/deleted work at delivery, including after recording", async () => {
    await handleNotificationStream([bookmark()]);
    send.mockResolvedValueOnce({});
    await handleNotificationStream([record(lastStored().event)]);
    expect(push).not.toHaveBeenCalled();
  });

  it("does not send mission achievements inline when the stream is active", async () => {
    vi.stubEnv("NOTIFICATION_STREAM_ENABLED", "true");
    await recordMissionAchievement(owner, { kind: "followers", missionId: "follow_1",
      occurredAt: now, required: 1 });
    const event = lastStored().event;
    expect(push).not.toHaveBeenCalled();
    expect(event.pushPending).toBe(true);
    await handleNotificationStream([record(event)]);
    expect(push).toHaveBeenCalledWith(owner, expect.objectContaining({
      data: { targetRoute: "/creator-missions", type: "mission_achievement" },
    }));
  });

  it("keeps existing mission responses and exposes only allowlisted community data on opt-in", async () => {
    const entries = [
      { itemType: "COMMUNITY_ACTIVITY_V1", eventId: "safe", occurredAt: now,
        ttl: Date.parse(now) / 1000 + 100, workId: work, actorId: actor, kind: "newBookmark" },
      { itemType: "COMMUNITY_ACTIVITY_V1", eventId: "expired", occurredAt: now,
        ttl: Date.parse(now) / 1000 - 100, kind: "newFollower" },
      { itemType: "MISSION_ACTIVITY_V1", eventId: "mission", kind: "followers",
        required: 1, occurredAt: now },
    ];
    send.mockResolvedValue({ Items: entries });
    const legacy = await getMyMissionActivity({ headers: {} } as unknown as Parameters<typeof getMyMissionActivity>[0]);
    expect(JSON.parse(legacy.body!).events).toHaveLength(1);
    const mixed = await getMyMissionActivity({ headers: {}, queryStringParameters: { includeCommunity: "true" } } as unknown as Parameters<typeof getMyMissionActivity>[0]);
    const events = JSON.parse(mixed.body!).events;
    expect(events).toHaveLength(2);
    expect(events[0]).toEqual({ eventId: "safe", occurredAt: now,
      kind: "newBookmark", targetRoute: "/community/work/" + work });
    expect(JSON.stringify(events)).not.toContain(actor);
  });
});
