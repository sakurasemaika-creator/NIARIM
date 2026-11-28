// The daily post limit was only checked by POST /works, after the app had
// already uploaded the video to YouTube: a second post on the same day left a
// video on YouTube that could never be registered (found by walking the app
// against a local copy of the backend, 2026-11-28). GET /me/post-quota lets
// the app look before it uploads, with the same counters and tier rules.
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { send, items } = vi.hoisted(() => {
  const items = new Map<string, Record<string, unknown>>();
  const send = vi.fn();
  return { send, items };
});
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", async (original) => ({
  ...(await original<typeof import("../src/lib/auth")>()),
  authenticate: vi.fn(async () => ({
    niarimUserId: "Nposter",
    googleSub: "sub",
    membershipTier: "free",
  })),
}));

import { handler } from "../src/api/handler";
import { GLOBAL_COUNTER_USER_ID, Keys, todayYyyymmdd } from "../src/lib/dynamo";
import {
  DAILY_POST_LIMIT_GLOBAL,
  readPostQuota,
} from "../src/lib/quota";

const keyOf = (key: { pk: string; sk: string }) => `${key.pk}|${key.sk}`;
const put = (key: { pk: string; sk: string }, item: Record<string, unknown>) =>
  items.set(keyOf(key), { ...key, ...item });
const today = () => todayYyyymmdd(new Date());

function request(): APIGatewayProxyEventV2 {
  return {
    version: "2.0",
    routeKey: "$default",
    rawPath: "/me/post-quota",
    rawQueryString: "",
    headers: { authorization: "Bearer checked-by-auth-mock" },
    requestContext: {
      accountId: "anonymous",
      apiId: "test",
      domainName: "example.test",
      domainPrefix: "example",
      http: {
        method: "GET",
        path: "/me/post-quota",
        protocol: "HTTP/1.1",
        sourceIp: "127.0.0.1",
        userAgent: "test",
      },
      requestId: "test",
      routeKey: "$default",
      stage: "$default",
      time: "01/Jan/2026:00:00:00 +0000",
      timeEpoch: 0,
    },
    isBase64Encoded: false,
  };
}

async function quota() {
  const result = await handler(request());
  return { status: result.statusCode, body: JSON.parse(result.body ?? "{}") };
}

beforeEach(() => {
  process.env.TABLE_NAME = "test-table";
  items.clear();
  send.mockReset();
  send.mockImplementation(async (command: unknown) => {
    if (!(command instanceof GetCommand)) {
      throw new Error(`GET /me/post-quota must only read: ${String(command)}`);
    }
    const key = command.input.Key as { pk: string; sk: string };
    return { Item: items.get(keyOf(key)) };
  });
  put(Keys.user("Nposter"), {
    itemType: "USER",
    niarimUserId: "Nposter",
    membershipTier: "free",
  });
});

describe("GET /me/post-quota", () => {
  it("gives a free member one post a day, and none after it is used", async () => {
    expect(await quota()).toEqual({
      status: 200,
      body: { limit: 1, used: 0, remaining: 1 },
    });
    put(Keys.dailyCounter("Nposter", today()), { count: 1 });
    expect(await quota()).toEqual({
      status: 200,
      body: { limit: 1, used: 1, remaining: 0 },
    });
  });

  it("counts a post-quota reward as three a day, like the reservation", async () => {
    put(Keys.rewardEntitlement("Nposter", "communityPostQuota"), {
      itemType: "REWARD_ENTITLEMENT",
      entitlement: "communityPostQuota",
      status: "active",
      expiresAtEpochMs: Date.now() + 3_600_000,
    });
    put(Keys.dailyCounter("Nposter", today()), { count: 2 });
    expect((await quota()).body).toEqual({ limit: 3, used: 2, remaining: 1 });
  });

  it("uses the stored membership tier, as POST /works does", async () => {
    put(Keys.user("Nposter"), {
      itemType: "USER",
      niarimUserId: "Nposter",
      membershipTier: "premium",
    });
    put(Keys.dailyCounter("Nposter", today()), { count: 1 });
    expect((await quota()).body).toEqual({ limit: 3, used: 1, remaining: 2 });
  });

  it("has nothing left when NIARIM as a whole is full for the day", async () => {
    put(Keys.dailyCounter(GLOBAL_COUNTER_USER_ID, today()), {
      count: DAILY_POST_LIMIT_GLOBAL,
    });
    expect((await quota()).body).toEqual({ limit: 1, used: 0, remaining: 0 });
  });

  it("counts only today's (UTC) counter, like the reservation", async () => {
    const now = new Date("2027-01-01T00:30:00.000Z");
    put(Keys.dailyCounter("Nposter", "20261231"), { count: 1 });
    expect(await readPostQuota("Nposter", "free", now)).toEqual({
      limit: 1,
      used: 0,
      remaining: 1,
    });
  });

  it("refuses a suspended account with POSTING_SUSPENDED before any upload", async () => {
    put(Keys.user("Nposter"), {
      itemType: "USER",
      niarimUserId: "Nposter",
      membershipTier: "free",
      postingSuspended: true,
    });
    const { status, body } = await quota();
    expect(status).toBe(403);
    expect(body.code).toBe("POSTING_SUSPENDED");
  });

  it("is read-only", async () => {
    await quota();
    for (const [command] of send.mock.calls) {
      expect(command).toBeInstanceOf(GetCommand);
      expect(command.input.ConsistentRead).toBe(true);
    }
  });
});
