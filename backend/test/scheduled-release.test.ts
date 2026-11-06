import { beforeEach, describe, expect, it, vi } from "vitest";
import { QueryCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import type { WorkItem } from "../src/lib/types";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
import { handler } from "../src/batch/scheduledRelease";

const scheduled: WorkItem = {
  itemType: "WORK", pk: "WORK#abcdefghijk", sk: "META",
  workId: "abcdefghijk", youtubeVideoId: "abcdefghijk",
  authorId: "author", youtubeChannelId: "channel",
  channelName: "Channel", channelAvatarUrl: "",
  channelInfoCachedAt: "2026-11-01T00:00:00Z",
  title: "Scheduled work",
  postedAt: "2026-11-01T00:00:00Z",
  createdAt: "2026-11-01T00:00:00Z",
  youtubeUrl: "https://www.youtube.com/watch?v=abcdefghijk",
  thumbnailUrl: "",
  viewCount: 0, likeCount: 0, commentCount: 0,
  lastFetchedAt: "2026-11-01T00:00:00Z",
  bookmarkCount: 0, repostCount: 0,
  isNiarimPublished: true,
  youtubePrivacyStatus: "private",
  scheduledPublishAt: "2026-11-01T12:00:00.000Z",
  isShort: false, tags: [], lockedTags: [],
  gsi3AllPk: "AUTHOR#author", gsi3AllSk: "2026-11-01T00:00:00Z",
  gsi6pk: "SCHEDULED", gsi6sk: "2026-11-01T12:00:00.000Z",
};

const updates = () => send.mock.calls.map(([cmd]) => cmd)
  .filter((cmd) => cmd instanceof UpdateCommand)
  .map((cmd) => cmd.input);

beforeEach(() => {
  send.mockReset();
  vi.unstubAllGlobals();
  process.env.TABLE_NAME = "test-table";
  process.env.YOUTUBE_API_KEY = "test-key";
});

describe("scheduled release private-safety", () => {
  it("queries only the due scheduled index, never scans all works", async () => {
    send.mockResolvedValue({ Items: [] });
    await handler();
    const input = send.mock.calls[0][0].input;
    expect(send.mock.calls[0][0]).toBeInstanceOf(QueryCommand);
    expect(input.IndexName).toBe("GSI6Scheduled");
    expect(input.KeyConditionExpression).toContain("gsi6sk <= :now");
    expect(globalThis.fetch).not.toHaveBeenCalled();
  });

  it("publishes only after YouTube returns public", async () => {
    send.mockImplementation(async (command) =>
      command instanceof QueryCommand ? { Items: [scheduled] } : {},
    );
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(
      JSON.stringify({
        items: [{ id: scheduled.youtubeVideoId,
          status: { privacyStatus: "public" } }],
      }),
      { status: 200 },
    )));
    await handler();
    const input = updates()[0];
    expect(input.UpdateExpression).toContain("youtubePrivacyStatus = :public");
    expect(input.UpdateExpression).toContain("gsi4pk = :latestPk");
    expect(input.UpdateExpression).toContain("REMOVE gsi6pk, gsi6sk");
    expect(input.ExpressionAttributeValues?.[":releasedAt"])
      .toBe(scheduled.scheduledPublishAt);
    expect(input.ConditionExpression).toContain("isNiarimPublished = :published");
  });

  it("retains private work and backs off when YouTube has not released it", async () => {
    send.mockImplementation(async (command) =>
      command instanceof QueryCommand ? { Items: [scheduled] } : {},
    );
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(
      JSON.stringify({ items: [] }), { status: 200 },
    )));
    await handler();
    expect(updates()).toHaveLength(1);
    expect(updates()[0].UpdateExpression).toBe("SET gsi6sk = :next");
    expect(updates()[0].ExpressionAttributeValues?.[":private"]).toBe("private");
  });

  it("never adds public indexes if the NIARIM owner set hidden", async () => {
    send.mockImplementation(async (command) =>
      command instanceof QueryCommand
        ? { Items: [{ ...scheduled, isNiarimPublished: false }] } : {},
    );
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(
      JSON.stringify({
        items: [{ id: scheduled.youtubeVideoId,
          status: { privacyStatus: "public" } }],
      }), { status: 200 },
    )));
    await handler();
    expect(updates()[0].UpdateExpression).not.toContain("gsi4pk = :latestPk");
    expect(updates()[0].UpdateExpression).toContain("REMOVE gsi6pk, gsi6sk");
  });
});
