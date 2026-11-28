// A video uploaded more than 15 minutes before its registration is refused
// (no reuse of old videos). The refusal used to carry the generic FORBIDDEN
// code, so the app said "you don't have permission" and offered a retry that
// could never succeed (found by walking the app against a local copy of the
// backend, 2026-11-28). It now carries VIDEO_NOT_RECENT, still with 403.
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { beforeEach, describe, expect, it, vi } from "vitest";

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
const { publishedAt } = vi.hoisted(() => ({ publishedAt: { value: "" } }));
vi.mock("../src/lib/youtube", async (original) => ({
  ...(await original<typeof import("../src/lib/youtube")>()),
  getOwnChannelInfo: vi.fn(),
  getVideoSnippet: vi.fn(async () => ({
    id: "abcdefghijk",
    channelId: "channel",
    publishedAt: publishedAt.value,
    title: "Work",
    thumbnailUrl: "",
    privacyStatus: "unlisted",
  })),
}));

import { createWork } from "../src/api/routes/worksCreate";
import { reservePostQuota } from "../src/lib/quota";

const event = {
  headers: { authorization: "Bearer checked-by-auth-mock" },
  body: JSON.stringify({
    youtubeVideoId: "abcdefghijk",
    youtubeAccessToken: "token",
    title: "Work",
  }),
} as unknown as APIGatewayProxyEventV2;

beforeEach(() => {
  process.env.TABLE_NAME = "test-table";
  send.mockReset();
  send.mockResolvedValue({});
  vi.mocked(reservePostQuota).mockClear();
});

describe("POST /works with a video uploaded long before", () => {
  it("is refused with 403 VIDEO_NOT_RECENT, before any post is counted", async () => {
    publishedAt.value = new Date(Date.now() - 16 * 60_000).toISOString();
    await expect(createWork(event)).rejects.toMatchObject({
      statusCode: 403,
      code: "VIDEO_NOT_RECENT",
    });
    expect(reservePostQuota).not.toHaveBeenCalled();
  });

  it("goes on to count the post when the video was just uploaded", async () => {
    publishedAt.value = new Date(Date.now() - 60_000).toISOString();
    await createWork(event);
    expect(reservePostQuota).toHaveBeenCalledTimes(1);
  });
});
