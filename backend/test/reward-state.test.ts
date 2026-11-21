import { beforeEach, describe, expect, it, vi } from "vitest";
import { GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({
    niarimUserId: "NfromGoogleSub",
    googleSub: "12345",
    membershipTier: "free",
  })),
}));

import { getMyRewardState } from "../src/api/routes/rewardState";

const event = {
  headers: { authorization: "Bearer validated-in-auth-mock" },
  queryStringParameters: { niarimUserId: "Nattacker" },
} as unknown as APIGatewayProxyEventV2;

beforeEach(() => {
  process.env.TABLE_NAME = "test-table";
  send.mockReset();
});

describe("authenticated reward state", () => {
  it("reads wallet and entitlements from Google-verified NIARIM ID only", async () => {
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof GetCommand) {
        return { Item: {
          itemType: "COIN_WALLET",
          balanceCoins: 248,
        }};
      }
      if (command instanceof QueryCommand) {
        return { Items: [
          {
            itemType: "REWARD_ENTITLEMENT",
            entitlement: "communityPostQuota",
            status: "active",
            expiresAtEpochMs: Date.now() + 3600_000,
          },
          {
            itemType: "REWARD_ENTITLEMENT",
            entitlement: "toneCurve",
            status: "paused",
            expiresAtEpochMs: 1,
            pausedRemainingSeconds: 1800,
          },
          {
            itemType: "REWARD_ENTITLEMENT",
            entitlement: "watermark",
            status: "active",
            expiresAtEpochMs: Date.now() - 60_000,
          },
        ]};
      }
      return {};
    });
    const result = await getMyRewardState(event);
    expect(result.statusCode).toBe(200);
    const body = JSON.parse(result.body ?? "{}");
    expect(body.niarimUserId).toBe("NfromGoogleSub");
    expect(body.balanceCoins).toBe(248);
    expect(body.entitlements).toHaveLength(2);
    expect(body.rewardEarningEnabled).toBe(false);
    expect(body.redemptionEnabled).toBe(false);
    expect(send).toHaveBeenCalledTimes(2);
    const keys = send.mock.calls.map(([c]) =>
      c instanceof GetCommand
        ? c.input.Key?.pk
        : c.input.ExpressionAttributeValues?.[":owner"]);
    expect(keys).toEqual(["USER#NfromGoogleSub", "USER#NfromGoogleSub"]);
    expect(keys).not.toContain("USER#Nattacker");
  });

  it("empty wallet is zero and never grants coins on a read", async () => {
    send.mockResolvedValue({});
    const result = await getMyRewardState(event);
    const body = JSON.parse(result.body ?? "{}");
    expect(body.balanceCoins).toBe(0);
    expect(body.entitlements).toEqual([]);
  });

  it("returns active owned rights only; expired, malformed and paused are not active", async () => {
    const now = Date.now();
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof GetCommand) {
        return { Item: { itemType: "COIN_WALLET", balanceCoins: 900 } };
      }
      if (command instanceof QueryCommand) {
        return { Items: [
          { itemType: "REWARD_ENTITLEMENT", entitlement: "fullPremium",
            status: "active", expiresAtEpochMs: now + 3600_000 },
          { itemType: "REWARD_ENTITLEMENT", entitlement: "toneCurve",
            status: "active", expiresAtEpochMs: now + 3600_000 },
          { itemType: "REWARD_ENTITLEMENT", entitlement: "watermark",
            status: "active", expiresAtEpochMs: now - 1 },
          { itemType: "REWARD_ENTITLEMENT", entitlement: "canvasAds",
            status: "paused", expiresAtEpochMs: now + 3600_000,
            pausedRemainingSeconds: 120 },
          { itemType: "REWARD_ENTITLEMENT", entitlement: "allAds",
            status: "active", expiresAtEpochMs: "never" },
          { itemType: "OTHER", entitlement: "projectListAds",
            status: "active", expiresAtEpochMs: now + 3600_000 },
        ] };
      }
      return {};
    });
    const response = await getMyRewardState(event);
    const body = JSON.parse(response.body ?? "{}");
    expect(body.balanceCoins).toBe(900);
    expect(body.entitlements).toEqual(expect.arrayContaining([
      { feature: "fullPremium", status: "active",
        expiresAtEpochMs: now + 3600_000, pausedRemainingSeconds: null },
      { feature: "toneCurve", status: "active",
        expiresAtEpochMs: now + 3600_000, pausedRemainingSeconds: null },
      { feature: "canvasAds", status: "paused",
        expiresAtEpochMs: now + 3600_000, pausedRemainingSeconds: 120 },
    ]));
    expect(body.entitlements).toHaveLength(3);
    const query = send.mock.calls
      .map(([cmd]) => cmd)
      .find((cmd) => cmd instanceof QueryCommand) as QueryCommand;
    expect(query.input.ExpressionAttributeValues?.[":owner"])
      .toBe("USER#NfromGoogleSub");
    expect(query.input.ConsistentRead).toBe(true);
  });

});
