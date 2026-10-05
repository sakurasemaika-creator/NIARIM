import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { PutCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({ niarimUserId: "Nauthor" })),
  getUser: vi.fn(async () => ({
    niarimUserId: "Nauthor",
    membershipTier: "free",
    youtubeChannelId: "channel",
  })),
  cacheChannelInfo: vi.fn(async () => {}),
}));
vi.mock("../src/lib/quota", () => ({
  reservePostQuota: vi.fn(async () => {}),
  releasePostQuota: vi.fn(async () => {}),
}));
vi.mock("../src/lib/youtube", () => ({
  getOwnChannelInfo: vi.fn(async () => ({
    channelId: "channel",
    channelName: "Channel",
    channelAvatarUrl: "",
  })),
  getVideoSnippet: vi.fn(async () => ({
    id: "abcdefghijk",
    channelId: "channel",
    publishedAt: "2026-09-01T00:00:00Z",
    title: "Work",
    thumbnailUrl: "",
    privacyStatus: "public",
  })),
  verifyVideoOwnership: vi.fn(() => ({ ok: true })),
}));
import { createWork } from "../src/api/routes/worksCreate";

const source = readFileSync(
  resolve(__dirname, "../src/api/routes/worksCreate.ts"),
  "utf8",
);

describe("work registration idempotency contract", () => {
  it("treats the YouTube video id as the NIARIM work idempotency key", () => {
    expect(source).toContain("workId: body.youtubeVideoId");
    expect(source).toContain("youtubeVideoId: body.youtubeVideoId");
    expect(source).toContain("Key: Keys.work(body.youtubeVideoId)");
  });

  it("returns an existing work unchanged for a duplicate POST by the same author", () => {
    expect(source).toContain("if (existing) {");
    expect(source).toContain("existing.authorId !== auth.niarimUserId");
    expect(source).toContain(
      "return created({ work: toPublicWork(existing) })",
    );
    expect(source).not.toContain("new UpdateCommand");
  });

  it("does not reserve post quota before the duplicate-POST early return", () => {
    const duplicateReturn = source.indexOf(
      "return created({ work: toPublicWork(existing) })",
    );
    const quotaReservation = source.indexOf("await reservePostQuota");
    expect(duplicateReturn).toBeGreaterThan(-1);
    expect(quotaReservation).toBeGreaterThan(duplicateReturn);
  });

  it("applies the recent-upload ownership check only to a new work", () => {
    const duplicateReturn = source.indexOf(
      "return created({ work: toPublicWork(existing) })",
    );
    const ownershipCheck = source.indexOf(
      "const verification = verifyVideoOwnership(",
    );
    expect(ownershipCheck).toBeGreaterThan(duplicateReturn);
  });

  it("keeps publish-state changes outside POST /works", () => {
    expect(source).not.toContain("existing.isNiarimPublished");
    expect(source).not.toContain("hasPublicIndexes");
    expect(source).not.toContain("new UpdateCommand");
  });

  it("protects first registration from concurrent overwrite", () => {
    expect(source).toContain('ConditionExpression: "attribute_not_exists(pk)"');
    expect(source).toContain("ConditionalCheckFailedException");
    expect(source).toContain('"VIDEO_REGISTRATION_CONFLICT"');
  });

  it("never revives a deleted work id", () => {
    expect(source).toContain('existingRaw?.itemType === "WORK_TOMBSTONE"');
    expect(source).toContain('"WORK_DELETED"');
  });
});

describe("work registration AI image/video disclosure", () => {
  const post = (extra: object) =>
    createWork({
      headers: {},
      body: JSON.stringify({
        youtubeVideoId: "abcdefghijk",
        youtubeAccessToken: "token",
        ...extra,
      }),
    } as APIGatewayProxyEventV2);
  const storedWork = () =>
    send.mock.calls
      .map(([c]) => c)
      .filter((c) => c instanceof PutCommand)
      .map((c) => c.input.Item)[0];

  beforeEach(() => {
    send.mockReset();
    send.mockResolvedValue({});
    process.env.TABLE_NAME = "test-table";
  });

  it("stores the flag as false when the poster omits it", async () => {
    const result = await post({});
    expect(result.statusCode).toBe(201);
    expect(storedWork()?.containsGenerativeAiImageOrVideo).toBe(false);
    expect(
      JSON.parse(result.body ?? "{}").work.containsGenerativeAiImageOrVideo,
    ).toBe(false);
  });

  it("stores the flag when the poster declares AI images or video", async () => {
    const result = await post({ containsGenerativeAiImageOrVideo: true });
    expect(result.statusCode).toBe(201);
    expect(storedWork()?.containsGenerativeAiImageOrVideo).toBe(true);
    expect(
      JSON.parse(result.body ?? "{}").work.containsGenerativeAiImageOrVideo,
    ).toBe(true);
  });
});
