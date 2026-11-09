import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  GetCommand, TransactWriteCommand, UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

const { send, verifySignedCallback } = vi.hoisted(() => ({
  send: vi.fn(), verifySignedCallback: vi.fn(),
}));
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
  verifyAdmobSsv: verifySignedCallback,
}));
import {
  receiveRewardedAdSsv, rewardedAdConfiguration, startRewardedAdSession,
  getRewardedAdStatus,
} from "../src/api/routes/rewardedAd";

const request = {
  headers: { authorization: "Bearer verified-in-mock" },
  rawQueryString: "original=google-signed-raw-query",
} as unknown as APIGatewayProxyEventV2;

beforeEach(() => {
  send.mockReset();
  send.mockResolvedValue({});
  verifySignedCallback.mockReset();
  verifySignedCallback.mockImplementation(async () => ({
    adUnit: "2222222222",
    rewardAmount: 10,
    rewardItem: "coins",
    transactionId: "18fa792de1bca816048293fc71035638",
    timestampMs: Date.now(),
    customData: `v1.N${"a".repeat(32)}.123e4567-e89b-12d3-a456-426614174000`,
  }));
  process.env.TABLE_NAME = "unit-test-table";
  delete process.env.ADMOB_REWARDED_AD_UNIT_ID;
  delete process.env.REWARDED_AD_SSV_ENABLED;
  delete process.env.REWARDED_AD_REVIEW_APPROVED;
  delete process.env.REWARDED_AD_DAILY_LIMIT;
});

function enable() {
  process.env.ADMOB_REWARDED_AD_UNIT_ID =
    "ca-app-pub-1111111111111111/2222222222";
  process.env.REWARDED_AD_SSV_ENABLED = "true";
  process.env.REWARDED_AD_REVIEW_APPROVED = "true";
  // Unit test fixture, not an invented launch quota.
  process.env.REWARDED_AD_DAILY_LIMIT = "10";
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
    delete process.env.REWARDED_AD_DAILY_LIMIT;
    expect(rewardedAdConfiguration().enabled).toBe(false);
    process.env.REWARDED_AD_DAILY_LIMIT = "9999";
    expect(rewardedAdConfiguration().enabled).toBe(false);
    process.env.REWARDED_AD_DAILY_LIMIT = "10";
    expect(rewardedAdConfiguration().enabled).toBe(true);
    process.env.ADMOB_REWARDED_AD_UNIT_ID =
      "ca-app-pub-3940256099942544/5224354917";
    expect(rewardedAdConfiguration().enabled).toBe(false);
  });

  it("acknowledges only a matching signed unbound URL check without issuing coins", async () => {
    process.env.ADMOB_REWARDED_AD_UNIT_ID =
      "ca-app-pub-1111111111111111/2222222222";
    verifySignedCallback.mockImplementationOnce(async () => ({
      adUnit: "2222222222",
      rewardAmount: 10,
      rewardItem: "coins",
      transactionId: "18fa792de1bca816048293fc71035638",
      timestampMs: Date.now(),
      customData: null,
    }));
    const response = await receiveRewardedAdSsv(request);
    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body ?? "{}")).toMatchObject({
      verified: true, credited: false,
    });
    expect(send).not.toHaveBeenCalled();
    expect(rewardedAdConfiguration().enabled).toBe(false);
  });

  it("accepts a signed unbound AdMob URL test using a different ad unit, with zero writes", async () => {
    process.env.ADMOB_REWARDED_AD_UNIT_ID =
      "ca-app-pub-1111111111111111/2222222222";
    verifySignedCallback.mockImplementationOnce(async () => ({
      adUnit: "0000000000",
      rewardAmount: 10,
      rewardItem: "coins",
      transactionId: "18fa792de1bca816048293fc71035638",
      timestampMs: Date.now(),
      customData: null,
    }));
    const response = await receiveRewardedAdSsv(request);
    expect(response.statusCode).toBe(200);
    expect(JSON.parse(response.body ?? "{}")).toEqual({
      verified: true, credited: false,
    });
    expect(send).not.toHaveBeenCalled();
  });

  it("rejects mismatching or unsigned verification callbacks", async () => {
    process.env.ADMOB_REWARDED_AD_UNIT_ID =
      "ca-app-pub-1111111111111111/2222222222";
    verifySignedCallback.mockImplementationOnce(async () => ({
      adUnit: "", rewardAmount: 10, rewardItem: "coins",
      transactionId: "18fa792de1bca816048293fc71035638",
      timestampMs: Date.now(), customData: null,
    }));
    await expect(receiveRewardedAdSsv(request)).rejects.toMatchObject({
      code: "INVALID_SSV",
    });
    verifySignedCallback.mockRejectedValueOnce(new Error("bad signature"));
    await expect(receiveRewardedAdSsv(request)).rejects.toThrow();
    expect(send).not.toHaveBeenCalled();
  });

  it("mints an unguessable user-bound ad invitation, not coins", async () => {
    enable();
    const response = await startRewardedAdSession(request);
    const body = JSON.parse(response.body ?? "{}");
    expect(body.customData).toMatch(/^v1\.N[a-f0-9]{32}\.[0-9a-f-]{36}$/);
    expect(body.rewardCoins).toBe(10);
    expect(body.adUnitId).toContain("2222222222");
    expect(send).toHaveBeenCalledTimes(2);
    expect(send.mock.calls[0][0]).toBeInstanceOf(GetCommand);
    const command = send.mock.calls[1][0];
    expect(command).toBeInstanceOf(UpdateCommand);
    expect(command.input.Key.pk).toBe(`USER#N${"a".repeat(32)}`);
    expect(command.input.ConditionExpression).toContain("issuedAtMs");
    expect(command.input.ConditionExpression).toContain("attribute_exists(consumedAtMs)");
    expect(command.input.ConditionExpression).toContain("expiresAtMs < :issued");
    expect(send.mock.calls.some(([c]) => c instanceof TransactWriteCommand))
      .toBe(false);
  });

  it("only reports ad coin grant after a server-consumed session", async () => {
    enable();
    const nonce = "123e4567-e89b-12d3-a456-426614174000";
    const checked = {...request, queryStringParameters: {nonce}};
    send.mockResolvedValueOnce({ Item: {
      itemType: "REWARDED_AD_SESSION", nonce,
      expiresAtMs: Date.now() + 300_000,
    }});
    const pending = await getRewardedAdStatus(checked);
    expect(JSON.parse(pending.body ?? "{}")).toEqual({
      credited:false,status:"pending",
    });
    send.mockResolvedValueOnce({ Item: {
      itemType:"REWARDED_AD_SESSION", nonce,
      consumedAtMs:Date.now(),
    }});
    const credited = await getRewardedAdStatus(checked);
    expect(JSON.parse(credited.body ?? "{}")).toEqual({
      credited:true,status:"credited",
    });
    expect(send.mock.calls.every(([command]) => command instanceof GetCommand)).toBe(true);
    expect(send.mock.calls[0][0].input.Key.pk)
      .toBe(`USER#N${"a".repeat(32)}`);
  });

  it("never leaks another account's ad result and rejects invalid nonces", async () => {
    enable();
    send.mockResolvedValueOnce({Item: {
      itemType:"REWARDED_AD_SESSION",
      nonce:"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      consumedAtMs:Date.now(),
    }});
    const status = await getRewardedAdStatus({
      ...request, queryStringParameters: {
        nonce:"123e4567-e89b-12d3-a456-426614174000",
      },
    });
    expect(JSON.parse(status.body ?? "{}")).toMatchObject({
      credited:false,status:"not_found",
    });
    await expect(getRewardedAdStatus({
      ...request,queryStringParameters:{nonce:"attacker"},
    })).rejects.toMatchObject({code:"REWARDED_AD_INVALID_NONCE"});
    expect(send).toHaveBeenCalledTimes(1);
  });

  it("credits signed event once with immutable coin history", async () => {
    enable();
    const response = await receiveRewardedAdSsv(request);
    expect(response.statusCode).toBe(200);
    const tx = send.mock.calls[0][0] as TransactWriteCommand;
    expect(tx).toBeInstanceOf(TransactWriteCommand);
    expect(tx.input.TransactItems).toHaveLength(5);
    const rows = tx.input.TransactItems!;
    expect(rows[0].Put?.Item?.pk).toMatch(/^ADMOB_TX#/);
    expect(rows[0].Put?.ConditionExpression).toContain("attribute_not_exists");
    expect(rows[0].Put?.Item?.ttl).toBeGreaterThan(Date.now() / 1000);
    expect(rows[1].Update?.ConditionExpression).toContain("attribute_not_exists(consumedAtMs)");
    expect(rows[1].Update?.Key?.sk).toBe("REWARDED_AD_SESSION");
    expect(rows[2].Update?.Key?.sk).toMatch(/^REWARDED_AD_DAY#/);
    expect(rows[2].Update?.ExpressionAttributeValues?.[":limit"]).toBe(10);
    expect(rows[3].Put?.Item?.sk).toMatch(/^COIN_HISTORY#/);
    expect(rows[3].Put?.Item?.deltaCoins).toBe(10);
    expect(rows[4].Update?.Key?.sk).toBe("COIN_WALLET");
    expect(rows[4].Update?.ExpressionAttributeValues?.[":reward"]).toBe(10);
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
