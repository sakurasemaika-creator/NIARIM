import { beforeEach, describe, expect, it, vi } from "vitest";
import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({
    niarimUserId: "Nverified-account",
    googleSub: "verified-google-sub",
    membershipTier: "free",
  })),
}));
import { getMyCoinHistory } from "../src/api/routes/rewardState";
const request = (params: Record<string, string> = {}) => ({
  headers: { authorization: "Bearer verified-token" },
  queryStringParameters: { niarimUserId: "Nattacker", ...params },
}) as unknown as APIGatewayProxyEventV2;
beforeEach(() => {
  process.env.TABLE_NAME = "test-table";
  send.mockReset();
  send.mockResolvedValue({});
});
describe("server-issued immutable coin history", () => {
  it("queries only authenticated owner in newest-first key order", async () => {
    const sk = "COIN_HISTORY#8234567890123#admob-abc";
    send.mockResolvedValueOnce({
      Items: [{
        itemType: "COIN_HISTORY", source: "rewarded-ad",
        deltaCoins: 10, occurredAtEpochMs: 1760000000000,
      }],
      LastEvaluatedKey: { pk: "USER#Nverified-account", sk },
    });
    const response = await getMyCoinHistory(request());
    const body = JSON.parse(response.body ?? "{}");
    expect(body.entries).toEqual([{
      source: "rewarded-ad", deltaCoins: 10,
      occurredAtEpochMs: 1760000000000,
      missionId: null, workId: null, target: null,
    }]);
    expect(body.nextCursor).toBe(Buffer.from(sk).toString("base64url"));
    const cmd = send.mock.calls[0][0] as QueryCommand;
    expect(cmd).toBeInstanceOf(QueryCommand);
    expect(cmd.input.ExpressionAttributeValues?.[":owner"])
      .toBe("USER#Nverified-account");
    expect(cmd.input.ConsistentRead).toBe(true);
    expect(cmd.input.ScanIndexForward).toBe(true);
    expect(cmd.input.Limit).toBe(20);
  });
  it("rejects invalid cursors and oversized pages before querying", async () => {
    await expect(getMyCoinHistory(request({ limit: "100" })))
      .rejects.toMatchObject({ code: "COIN_HISTORY_INVALID_LIMIT" });
    await expect(getMyCoinHistory(request({
      cursor: Buffer.from("COIN_TX#attacker").toString("base64url"),
    }))).rejects.toMatchObject({ code: "COIN_HISTORY_INVALID_CURSOR" });
    expect(send).not.toHaveBeenCalled();
  });
  it("scopes valid cursors to the signed-in user", async () => {
    const sk = "COIN_HISTORY#8234567890123#admob-abc";
    await getMyCoinHistory(request({
      cursor: Buffer.from(sk).toString("base64url"), limit: "5",
    }));
    const cmd = send.mock.calls[0][0] as QueryCommand;
    expect(cmd.input.ExclusiveStartKey).toEqual({
      pk: "USER#Nverified-account", sk,
    });
    expect(cmd.input.Limit).toBe(5);
  });
});
