import { beforeEach, describe, expect, it, vi } from "vitest";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import type { WorkItem } from "../src/lib/types";
import { computeRankingScore } from "../src/lib/ranking";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({ niarimUserId: "Nauthor" })),
}));
import { updateWork } from "../src/api/routes/worksUpdate";

const work: WorkItem = {
  itemType: "WORK",
  pk: "WORK#abcdefghijk",
  sk: "META",
  workId: "abcdefghijk",
  youtubeVideoId: "abcdefghijk",
  authorId: "Nauthor",
  youtubeChannelId: "channel",
  channelName: "Channel",
  channelAvatarUrl: "",
  channelInfoCachedAt: "2026-09-01T00:00:00Z",
  title: "Work",
  postedAt: "2026-09-01T00:00:00Z",
  createdAt: "2026-09-01T00:00:00Z",
  youtubeUrl: "",
  thumbnailUrl: "",
  viewCount: 100,
  likeCount: 5,
  commentCount: 2,
  lastFetchedAt: "2026-09-01T00:00:00Z",
  bookmarkCount: 4,
  repostCount: 0,
  isNiarimPublished: true,
  youtubePrivacyStatus: "public",
  isShort: false,
  tags: [],
  lockedTags: [],
  gsi3AllPk: "AUTHOR#Nauthor",
  gsi3AllSk: "2026-09-01T00:00:00Z",
};
const event = (body: object) =>
  ({ headers: {}, body: JSON.stringify(body) }) as APIGatewayProxyEventV2;
const updates = () =>
  send.mock.calls.map(([c]) => c).filter((c) => c instanceof UpdateCommand);
const changed = () =>
  new ConditionalCheckFailedException({ message: "changed", $metadata: {} });

beforeEach(() => {
  send.mockReset();
  process.env.TABLE_NAME = "test-table";
  send.mockImplementation(async (c) =>
    c instanceof GetCommand
      ? { Item: { ...work } }
      : { Attributes: { ...work } },
  );
});

describe("work editing concurrency", () => {
  it("edits only the title without rewriting visibility or ranking indexes", async () => {
    await updateWork(event({ title: "  Renamed  " }), work.workId);
    const input = updates()[0].input;
    expect(input.UpdateExpression).toBe("SET title = :title");
    expect(input.ExpressionAttributeValues).toEqual({
      ":title": "Renamed",
      ":workType": "WORK",
      ":authorId": "Nauthor",
    });
    expect(input.ConditionExpression).toContain("authorId = :authorId");
  });

  it("re-reads a concurrent YouTube privacy change and keeps the work hidden", async () => {
    let reads = 0;
    send.mockImplementation(async (c) => {
      if (c instanceof GetCommand) {
        expect(c.input.ConsistentRead).toBe(true);
        return {
          Item: {
            ...work,
            youtubePrivacyStatus: reads++ === 0 ? "public" : "private",
          },
        };
      }
      if (updates().length === 1) throw changed();
      return { Attributes: { ...work, youtubePrivacyStatus: "private" } };
    });
    await updateWork(event({ isNiarimPublished: true }), work.workId);
    expect(updates()).toHaveLength(2);
    const [first, second] = updates().map((c) => c.input);
    expect(first.ConditionExpression).toContain(
      "youtubePrivacyStatus = :privacy",
    );
    expect(second.ExpressionAttributeValues?.[":privacy"]).toBe("private");
    expect(second.ExpressionAttributeValues?.[":pub"]).toBe(true);
    const removed = second.UpdateExpression?.split(" REMOVE ")[1]?.split(", ");
    expect(removed).toEqual(
      expect.arrayContaining([
        "rankingScore",
        "gsi1pk",
        "gsi1sk",
        "gsi2pk",
        "gsi2sk",
        "gsi3pk",
        "gsi3sk",
        "gsi4pk",
        "gsi4sk",
      ]),
    );
  });

  it("rebuilds rankings from current counters and retries if counters change", async () => {
    let reads = 0;
    send.mockImplementation(async (c) => {
      if (c instanceof GetCommand)
        return {
          Item: {
            ...work,
            isNiarimPublished: false,
            viewCount: reads++ ? 200 : 100,
          },
        };
      if (updates().length === 1) throw changed();
      return { Attributes: { ...work, viewCount: 200 } };
    });
    await updateWork(event({ isNiarimPublished: true }), work.workId);
    expect(updates()).toHaveLength(2);
    const input = updates()[1].input;
    expect(input.ExpressionAttributeValues?.[":score"]).toBe(
      computeRankingScore({ ...work, viewCount: 200 }),
    );
    expect(input.UpdateExpression).toContain("rankingScore = :score");
    for (const name of [
      "viewCount",
      "likeCount",
      "commentCount",
      "bookmarkCount",
    ]) {
      expect(input.ConditionExpression).toContain(`${name} = :${name}`);
    }
  });

  it("never recreates a work deleted between the read and update", async () => {
    let reads = 0;
    send.mockImplementation(async (c) => {
      if (c instanceof GetCommand)
        return { Item: reads++ ? { itemType: "WORK_TOMBSTONE" } : work };
      throw changed();
    });
    await expect(
      updateWork(event({ title: "Renamed" }), work.workId),
    ).rejects.toMatchObject({ statusCode: 404 });
    expect(updates()).toHaveLength(1);
  });

  it("leaves empty patches as reads without writing stale state", async () => {
    const result = await updateWork(event({}), work.workId);
    expect(result.statusCode).toBe(200);
    expect(updates()).toHaveLength(0);
  });

  it("bounds repeated conflicts without accepting an unsafe write", async () => {
    send.mockImplementation(async (c) => {
      if (c instanceof GetCommand) return { Item: work };
      throw changed();
    });
    await expect(
      updateWork(event({ isNiarimPublished: true }), work.workId),
    ).rejects.toMatchObject({ statusCode: 409, code: "WORK_CHANGED" });
    expect(updates()).toHaveLength(3);
  });
});
