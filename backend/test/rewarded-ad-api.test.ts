import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  GetCommand, TransactWriteCommand, UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({
    niarimUserId: `N${"a".repeat(32)}`,
    googleSub: "verified-google-sub",
    membershipTier: "free",
  })),
}));
vi.mock("../src/lib/admobSsv", async (original) => ({
  ...(await original<typeof import("../src/lib/admobSsv")>()),
  verifyAdmobSsv: vi.fn(async () => ({
    adUnit: "2222222222",
    rewardAmount: 10,
    rewardItem: "coins",
    transactionId: "18fa792de1bca816048293fc71035638",
    timestampMs: Date.now(),
    customData: `v1.N${"a".repeat(32)}.123e4567-e89b-12d3-a456-426614174000`,
  })),
}));
import {
  receiveRewardedAdSsv, rewardedAdConfiguration, startRewardedAdSession,
} from "../src/api/routes/rewardedAd";

const request = {
  headers: { authorization: "Bearer verified-in-mock" },
  rawQueryString: "original=google-signed-raw-query",
} as unknown as APIGatewayProxyEventV2;

beforeEach(() => {
  send.mockReset();
  send.mockResolvedValue({});
  process.env.TABLE_NAME = "unit-test-table";
  delete process.env.ADMOB_REWARDED_AD_UNIT_ID;
  delete process.env.REWARDED_AD_SSV_ENABLED;
  delete process.env.REWARDED_AD_REVIEW_APPROVED;
});

function enable() {
  process.env.ADMOB_REWARDED_AD_UNIT_ID =
    "ca-app-pub-1111111111111111/2222222222";
  process.env.REWARDED_AD_SSV_ENABLED = "true";
  process.env.REWARDED_AD_REVIEW_APPROVED = "true";
}

describe("rewarded ad SSV + exactly-once wallet", () => {
  it("is fully disabled by default and rejects Google's test ad unit", async () => {
    expect(rewardedAdConfiguration().enabled).toBe(false);
    await expect(startRewardedAdSession(request)).rejects.toMatchObject({
      code: "REWARDED_AD_DISABLED",
    });
    await expect(receiveRewardedAdSsv(request)).rejects.toMatchObject({
      code: "REWARDED_AD_DISABLED",
    });
    expect(send).not.toHaveBeenCalled();
    enable();
    process.env.ADMOB_REWARDED_AD_UNIT_ID =
      "ca-app-pub-3940256099942544/5224354917";
    expect(rewardedAdConfiguration().enabled).toBe(false);
  });

  it("mints an unguessable user-bound ad invitation, not coins", async () => {
    enable();
    const response = await startRewardedAdSession(request);
    const body = JSON.parse(response.body ?? "{}");
    expect(body.customData).toMatch(/^v1\.N[a-f0-9]{32}\.[0-9a-f-]{36}$/);
    expect(body.rewardCoins).toBe(10);
    expect(body.adUnitId).toContain("2222222222");
    expect(send).toHaveBeenCalledTimes(1);
    const command = send.mock.calls[0][0];
    expect(command).toBeInstanceOf(UpdateCommand);
    expect(command.input.Key.pk).toBe(`USER#N${"a".repeat(32)}`);
    expect(command.input.ConditionExpression).toContain("issuedAtMs");
    expect(send.mock.calls.some(([c]) => c instanceof TransactWriteCommand))
      .toBe(false);
  });

  it("credits signed event once in three-item atomic transaction", async () => {
    enable();
    const response = await receiveRewardedAdSsv(request);
    expect(response.statusCode).toBe(200);
    const tx = send.mock.calls[0][0] as TransactWriteCommand;
    expect(tx).toBeInstanceOf(TransactWriteCommand);
    expect(tx.input.TransactItems).toHaveLength(3);
    const rows = tx.input.TransactItems!;
    expect(rows[0].Put?.Item?.pk).toMatch(/^ADMOB_TX#/);
    expect(rows[0].Put?.ConditionExpression).toContain("attribute_not_exists");
    expect(rows[0].Put?.Item?.ttl).toBeGreaterThan(Date.now() / 1000);
    expect(rows[1].Update?.ConditionExpression).toContain("attribute_not_exists(consumedAtMs)");
    expect(rows[1].Update?.Key?.sk).toBe("REWARDED_AD_SESSION");
    expect(rows[2].Update?.Key?.sk).toBe("COIN_WALLET");
    expect(rows[2].Update?.ExpressionAttributeValues?.[":reward"]).toBe(10);
  });

  it("lost acknowledgment does not mint another ten coins", async () => {
    enable();
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof TransactWriteCommand) {
        throw new TransactionCanceledException({
          $metadata: {}, message: "Condition failed",
        });
      }
      if (command instanceof GetCommand) {
        return { Item: {
          itemType: "REWARDED_AD_RECEIPT",
          niarimUserId: `N${"a".repeat(32)}`,
          earnedCoins: 10,
        }};
      }
      return {};
    });
    const response = await receiveRewardedAdSsv(request);
    expect(JSON.parse(response.body ?? "{}")).toMatchObject({
      credited: true, duplicate: true,
    });
    expect(send.mock.calls.filter(([c]) => c instanceof TransactWriteCommand))
      .toHaveLength(1);
  });

  it("never treats an unrelated failed transaction as successful", async () => {
    enable();
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof TransactWriteCommand) {
        throw new TransactionCanceledException({
          $metadata: {}, message: "Condition failed",
        });
      }
      return {};
    });
    await expect(receiveRewardedAdSsv(request)).rejects.toMatchObject({
      code: "SSV_SESSION_CONFLICT",
    });
  });
});
