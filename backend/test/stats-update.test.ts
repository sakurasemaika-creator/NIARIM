import { beforeEach, describe, expect, it, vi } from "vitest";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import {
  GetCommand,
  PutCommand,
  ScanCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import type { WorkItem } from "../src/lib/types";

const { send, stats } = vi.hoisted(() => ({ send: vi.fn(), stats: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/youtube", () => ({ batchGetVideoStats: stats }));
import { handler } from "../src/batch/statsUpdate";

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
const updates = () =>
  send.mock.calls
    .map(([c]) => c)
    .filter((c) => c instanceof UpdateCommand && c.input.Key?.pk === work.pk);

beforeEach(() => {
  send.mockReset();
  stats.mockReset();
  process.env.TABLE_NAME = "test-table";
  process.env.YOUTUBE_API_KEY = "test-key";
  send.mockImplementation(async (c) =>
    c instanceof ScanCommand ? { Items: [work] } : {},
  );
});

describe("statistics batch data safety", () => {
  it("retains previous counters after a partial failure without changing the publication preference", async () => {
    stats.mockResolvedValue(
      new Map([[work.workId, { id: work.workId, privacyStatus: "public" }]]),
    );
    await handler();
    const input = updates()[0].input;
    expect(input.ExpressionAttributeValues).toMatchObject({
      ":view": 100,
      ":like": 5,
      ":comment": 2,
      ":status": "public",
    });
    expect(input.UpdateExpression).not.toContain("isNiarimPublished =");
  });

  it("hides an inaccessible video while preserving the owner's publication preference", async () => {
    stats.mockResolvedValue(
      new Map([[work.workId, { id: work.workId, privacyStatus: "private" }]]),
    );
    await handler();
    const input = updates()[0].input;
    expect(input.ExpressionAttributeValues[":status"]).toBe("private");
    expect(input.UpdateExpression).not.toContain("isNiarimPublished =");
    for (const key of [
      "gsi1pk",
      "gsi1sk",
      "gsi2pk",
      "gsi2sk",
      "gsi3pk",
      "gsi3sk",
      "gsi4pk",
      "gsi4sk",
    ]) {
      expect(input.UpdateExpression.split(" REMOVE ")[1]).toContain(key);
    }
  });

  it.each(["hidden", "tombstone"])(
    "does not republish a concurrent %s work",
    async (state) => {
      stats.mockResolvedValue(
        new Map([
          [
            work.workId,
            { id: work.workId, privacyStatus: "public", viewCount: 120 },
          ],
        ]),
      );
      let attempts = 0;
      send.mockImplementation(async (command) => {
        if (command instanceof ScanCommand) return { Items: [work] };
        if (command instanceof GetCommand) {
          expect(command.input.ConsistentRead).toBe(true);
          return {
            Item:
              state === "hidden"
                ? { ...work, isNiarimPublished: false }
                : { itemType: "WORK_TOMBSTONE" },
          };
        }
        if (
          command instanceof UpdateCommand &&
          command.input.Key?.pk === work.pk &&
          attempts++ === 0
        ) {
          throw new ConditionalCheckFailedException({
            message: "changed",
            $metadata: {},
          });
        }
        return {};
      });
      await handler();
      expect(updates()).toHaveLength(state === "hidden" ? 2 : 1);
      if (state === "hidden")
        expect(updates()[1].input.UpdateExpression).toContain(" REMOVE ");
      const snapshots = send.mock.calls
        .map(([c]) => c)
        .filter((c) => c instanceof PutCommand);
      expect(snapshots).toHaveLength(4);
      for (const snapshot of snapshots)
        expect(snapshot.input.Item?.entries).toEqual([]);
    },
  );
});
