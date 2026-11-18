import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError } from "../src/lib/response";

const { authenticate, getUser, send } = vi.hoisted(() => ({
  authenticate: vi.fn(),
  getUser: vi.fn(),
  send: vi.fn(),
}));

vi.mock("../src/lib/auth", () => ({ authenticate, getUser }));
vi.mock("../src/lib/dynamo", async (load) => ({
  ...(await load<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
  tableName: () => "test-table",
}));

import { getFollowers, getSocialCounts } from "../src/api/routes/follows";
import { Keys } from "../src/lib/dynamo";

const owner = "N" + "a".repeat(32);
const follower = "N" + "b".repeat(32);
const removed = "N" + "c".repeat(32);
const request = (cursor?: string) => ({
  headers: { authorization: "Bearer owner" },
  queryStringParameters: cursor === undefined ? undefined : { cursor },
}) as unknown as APIGatewayProxyEventV2;

describe("follower directory access", () => {
  beforeEach(() => {
    vi.resetAllMocks();
    authenticate.mockResolvedValue({ niarimUserId: owner });
  });

  it("requires authentication and ownership before reading relationships", async () => {
    authenticate.mockRejectedValueOnce(new ApiError(401, "unauthenticated"));
    await expect(getFollowers(request(), owner)).rejects.toMatchObject({ statusCode: 401 });
    await expect(getFollowers(request(), follower)).rejects.toMatchObject({ statusCode: 403 });
    expect(send).not.toHaveBeenCalled();
    expect(getUser).not.toHaveBeenCalled();
  });

  it("returns only profile fields and scopes every page to the same owner", async () => {
    getUser.mockImplementation(async (id) => id === follower ? {
      niarimUserId: follower,
      channelName: "Alice",
      followerCount: 4,
      googleSub: "internal-id",
    } : undefined);
    send.mockResolvedValueOnce({
      Items: [{ followerId: follower }, { followerId: removed }],
      LastEvaluatedKey: Keys.followerRecord(owner, removed),
    }).mockResolvedValueOnce({});

    const first = await getFollowers(request(), owner);
    expect(first.headers?.["cache-control"]).toBe("no-store");
    expect(JSON.parse(first.body!)).toEqual({
      followers: [{ niarimUserId: follower, channelName: "Alice" }],
      nextCursor: removed,
    });
    const second = await getFollowers(request(removed), owner);
    const query = send.mock.calls[1][0] as QueryCommand;
    expect(query).toBeInstanceOf(QueryCommand);
    expect(query.input).toMatchObject({
      ExpressionAttributeValues: { ":pk": Keys.user(owner).pk, ":prefix": "FOLLOWER#" },
      ExclusiveStartKey: Keys.followerRecord(owner, removed),
      Limit: 25,
    });
    expect(JSON.parse(second.body!)).toEqual({ followers: [], nextCursor: null });
  });

  it("rejects invalid cursors and keeps public profile totals available", async () => {
    await expect(getFollowers(request("invalid"), owner)).rejects.toMatchObject({ statusCode: 400 });
    expect(send).not.toHaveBeenCalled();
    getUser.mockResolvedValue({ followerCount: 4, followingCount: 2 });
    const counts = await getSocialCounts(request(), owner);
    expect(JSON.parse(counts.body!)).toEqual({ followerCount: 4, followingCount: 2 });
  });
});
