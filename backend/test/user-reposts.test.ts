import { beforeEach, describe, expect, it, vi } from "vitest";
import { GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import type { RepostItem, WorkItem } from "../src/lib/types";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
import { getUserReposts } from "../src/api/routes/reposts";
import { handler } from "../src/api/handler";

const baseWork: WorkItem = {
  itemType: "WORK",
  pk: "WORK#aaaaaaaaaaa",
  sk: "META",
  workId: "aaaaaaaaaaa",
  youtubeVideoId: "aaaaaaaaaaa",
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
  viewCount: 1,
  likeCount: 1,
  commentCount: 0,
  lastFetchedAt: "2026-09-01T00:00:00Z",
  bookmarkCount: 0,
  repostCount: 1,
  isNiarimPublished: true,
  youtubePrivacyStatus: "public",
  isShort: false,
  tags: [],
  lockedTags: [],
  gsi3AllPk: "AUTHOR#Nauthor",
  gsi3AllSk: "2026-09-01T00:00:00Z",
};
const work = (id: string, extra: Partial<WorkItem> = {}): WorkItem => ({
  ...baseWork,
  pk: `WORK#${id}`,
  workId: id,
  youtubeVideoId: id,
  ...extra,
});
const repost = (workId: string, repostedAt: string): RepostItem => ({
  itemType: "REPOST",
  pk: "USER#Nfan",
  sk: `REPOST#${workId}`,
  niarimUserId: "Nfan",
  workId,
  repostedAt,
});

const works: Record<string, WorkItem> = {
  older0000aa: work("older0000aa"),
  newer0000bb: work("newer0000bb", { containsGenerativeAiImageOrVideo: true }),
  hidden000cc: work("hidden000cc", { isNiarimPublished: false }),
  ytprivatedd: work("ytprivatedd", { youtubePrivacyStatus: "private" }),
};

beforeEach(() => {
  send.mockReset();
  process.env.TABLE_NAME = "test-table";
  send.mockImplementation(async (c) => {
    if (c instanceof QueryCommand) {
      return {
        Items: [
          repost("older0000aa", "2026-09-02T00:00:00Z"),
          repost("hidden000cc", "2026-09-05T00:00:00Z"),
          repost("newer0000bb", "2026-09-04T00:00:00Z"),
          repost("ytprivatedd", "2026-09-06T00:00:00Z"),
          repost("gone0000000", "2026-09-07T00:00:00Z"),
        ],
      };
    }
    if (c instanceof GetCommand) {
      const id = String(c.input.Key?.pk).replace("WORK#", "");
      return { Item: works[id] };
    }
    throw new Error("unexpected command");
  });
});

const body = (res: { body?: string }) => JSON.parse(res.body ?? "{}");

describe("GET /users/{id}/reposts", () => {
  it("lists the user's public reposts newest first with the work", async () => {
    const res = await getUserReposts(
      { headers: {} } as APIGatewayProxyEventV2,
      "Nfan",
    );
    const json = body(res);
    expect(json.userId).toBe("Nfan");
    expect(
      json.reposts.map((r: { work: { workId: string } }) => r.work.workId),
    ).toEqual(["newer0000bb", "older0000aa"]);
    expect(json.reposts[0].repostedAt).toBe("2026-09-04T00:00:00Z");
    // The public shape carries the poster's AI declaration so the app's
    // filters apply to reposted works too.
    expect(json.reposts[0].work.containsGenerativeAiImageOrVideo).toBe(true);
    const query = send.mock.calls
      .map(([c]) => c)
      .find((c) => c instanceof QueryCommand)!;
    expect(query.input.KeyConditionExpression).toBe(
      "pk = :pk AND begins_with(sk, :prefix)",
    );
    expect(query.input.ExpressionAttributeValues).toEqual({
      ":pk": "USER#Nfan",
      ":prefix": "REPOST#",
    });
    expect(query.input.IndexName).toBeUndefined();
  });

  it("is routed without sign-in", async () => {
    const res = await handler({
      requestContext: { http: { method: "GET", path: "/users/Nfan/reposts" } },
      headers: {},
    } as unknown as APIGatewayProxyEventV2);
    expect(res.statusCode).toBe(200);
    expect(body(res).reposts).toHaveLength(2);
  });
});
