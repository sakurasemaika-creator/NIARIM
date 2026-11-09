import { beforeEach, describe, expect, it, vi } from "vitest";
import { BatchGetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
import { getLatestWorks } from "../src/api/routes/worksLatest";

const a = "aaaaaaaaaaa", b = "bbbbbbbbbbb", c = "ccccccccccc";
const work = (id: string, status: "public" | "unlisted" | "private", published = true) => ({
  pk: "WORK#" + id, sk: "META", itemType: "WORK", workId: id,
  title: "Current title " + id, channelName: "Creator", authorId: "author",
  postedAt: "2026-11-09T12:00:00.000Z", tags: [], lockedTags: [],
  bookmarkCount: 2, isNiarimPublished: published,
  youtubePrivacyStatus: status,
  thumbnailUrl: "private-img:" + id,
});
const event = (q = "") => ({
  queryStringParameters: q ? { q } : {},
}) as unknown as APIGatewayProxyEventV2;
const body = (result: { body?: string }) => JSON.parse(result.body ?? "{}");

beforeEach(() => {
  process.env.TABLE_NAME = "test";
  send.mockReset();
  send.mockImplementation(async (cmd: unknown) => {
    if (cmd instanceof QueryCommand) {
      // Stale GSI4 has all three works published, and old metadata.
      return { Items: [
        { ...work(a, "public"), title: "Stale title a" },
        { ...work(b, "public"), title: "Stale title b" },
        { ...work(c, "public"), title: "Stale title c" },
      ] };
    }
    if (cmd instanceof BatchGetCommand) {
      const ids = (cmd.input.RequestItems?.test?.Keys ?? []).map((k: any) => k.pk);
      return { Responses: { test: [
        work(a, "public"),
        work(b, "private"),
        work(c, "unlisted"),
      ].filter(w => ids.includes(w.pk)) } };
    }
    throw Error("Unexpected DynamoDB command");
  });
});

describe("latest/search public metadata privacy", () => {
  it("does not disclose a newly private work from stale GSI4 metadata", async () => {
    const result = body(await getLatestWorks(event()));
    expect(result.works.map((w: any) => w.workId)).toEqual([a, c]);
    expect(result.works.map((w: any) => w.title)).toEqual([
      "Current title " + a, "Current title " + c,
    ]);
    expect(JSON.stringify(result)).not.toContain("Stale title");
    expect(JSON.stringify(result)).not.toContain("private-img:" + b);
    const batch = send.mock.calls.find(([cmd]) => cmd instanceof BatchGetCommand)?.[0];
    expect(batch?.input.RequestItems?.test?.ConsistentRead).toBe(true);
  });

  it("matches search against current work metadata, not stale indexed title", async () => {
    const result = body(await getLatestWorks(event("Current title")));
    expect(result.works.map((w: any) => w.workId)).toEqual([a, c]);
    const stale = body(await getLatestWorks(event("Stale title")));
    expect(stale.works).toEqual([]);
  });
});
