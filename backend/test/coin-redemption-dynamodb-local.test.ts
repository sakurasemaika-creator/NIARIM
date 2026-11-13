import { randomUUID } from "node:crypto";
import { beforeAll, afterAll, describe, expect, it, vi } from "vitest";
import {
  CreateTableCommand, DeleteTableCommand, DynamoDBClient,
  waitUntilTableExists,
} from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient, GetCommand, PutCommand, QueryCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

// Real conditional transactions, but ONLY against a disposable localhost table.
// No AWS production identity, real tokens, or real spendable coins are used.
const owner = "N" + "a".repeat(32);
const other = "N" + "b".repeat(32);
const localOptions = {
  endpoint: "http://127.0.0.1:8000",
  region: "ap-northeast-1",
  credentials: { accessKeyId: "localonly", secretAccessKey: "localonly" },
};
const client = new DynamoDBClient(localOptions);
const localDdb = DynamoDBDocumentClient.from(client, {
  marshallOptions: { removeUndefinedValues: true },
});
const table = "niarim-coin-local-" + Date.now();
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async (authorization?: string) => ({
    niarimUserId: authorization === "Bearer other"
      ? "N" + "b".repeat(32) : "N" + "a".repeat(32),
    googleSub: "synthetic-test-only",
    membershipTier: "free",
  })),
  getUser: vi.fn(async () => ({
    itemType: "USER",
    membershipTier: "free",
  })),
}));
vi.mock("../src/lib/dynamo", async (original) => {
  const source = await original<typeof import("../src/lib/dynamo")>();
  const { DynamoDBClient: Client } = await import("@aws-sdk/client-dynamodb");
  const { DynamoDBDocumentClient: Doc } = await import("@aws-sdk/lib-dynamodb");
  const local = new Client({
    endpoint: "http://127.0.0.1:8000",
    region: "ap-northeast-1",
    credentials: { accessKeyId: "localonly", secretAccessKey: "localonly" },
  });
  return {
    ...source,
    ddb: Doc.from(local, {
      marshallOptions: { removeUndefinedValues: true },
    }),
  };
});
import { Keys } from "../src/lib/dynamo";
import { COIN_BENEFIT_PRICE_VERSION } from "../src/lib/coinBenefitProposal";
import { redeemIndividualCoins } from "../src/lib/individualCoinRedemption";
import { redeemCoins } from "../src/api/routes/coinRedemption";
import { getMyRewardState } from "../src/api/routes/rewardState";

function event(account: "owner" | "other", body?: object) {
  return {
    headers: { authorization: account === "owner" ? "Bearer owner" : "Bearer other" },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  } as unknown as APIGatewayProxyEventV2;
}
async function get(key: { pk: string; sk: string }) {
  const response = await localDdb.send(new GetCommand({
    TableName: table, Key: key, ConsistentRead: true,
  }));
  return response.Item;
}
function individualInput(requestId: string, targets = ["toneCurve", "levelAdjustment"]) {
  return {
    targets, duration: "week", quantity: 1,
    priceVersion: COIN_BENEFIT_PRICE_VERSION, requestId,
  };
}

describe.skipIf(process.env.NIARIM_DYNAMODB_LOCAL_TESTS !== "1")(
  "real coin redemption transactions on disposable DynamoDB Local", () => {
    beforeAll(async () => {
      process.env.TABLE_NAME = table;
      process.env.COIN_PRICE_VERSION = COIN_BENEFIT_PRICE_VERSION;
      process.env.COIN_INDIVIDUAL_REDEMPTION_ENABLED = "true";
      process.env.COIN_INDIVIDUAL_REDEMPTION_REVIEW_APPROVED = "true";
      process.env.COIN_INDIVIDUAL_RIGHTS_CONSUMERS_APPROVED = "true";
      process.env.COIN_REDEMPTION_ENABLED = "true";
      process.env.COIN_REDEMPTION_REVIEW_APPROVED = "true";
      process.env.COIN_FULL_PREMIUM_MONTH_COINS = "55000";
      process.env.COIN_FULL_PREMIUM_YEAR_COINS = "550000";
      process.env.COIN_PREMIUM_ANNUAL_REDEMPTION_ENABLED = "true";
      await client.send(new CreateTableCommand({
        TableName: table, BillingMode: "PAY_PER_REQUEST",
        AttributeDefinitions: [
          { AttributeName: "pk", AttributeType: "S" },
          { AttributeName: "sk", AttributeType: "S" },
        ],
        KeySchema: [
          { AttributeName: "pk", KeyType: "HASH" },
          { AttributeName: "sk", KeyType: "RANGE" },
        ],
      }));
      await waitUntilTableExists({ client, maxWaitTime: 30 }, { TableName: table });
      for (const [id, coins] of [[owner, 10000], [other, 200000]] as const) {
        await localDdb.send(new PutCommand({
          TableName: table,
          Item: { ...Keys.user(id), itemType: "USER", membershipTier: "free" },
        }));
        await localDdb.send(new PutCommand({
          TableName: table,
          Item: {
            ...Keys.coinWallet(id), itemType: "COIN_WALLET",
            balanceCoins: coins, redeemedCoins: 0,
          },
        }));
      }
    }, 45_000);

    afterAll(async () => {
      try {
        await client.send(new DeleteTableCommand({ TableName: table }));
      } finally {
        client.destroy();
        localDdb.destroy();
      }
    });

    it("atomically debits the exact server price, grants two owned rights, and deduplicates retries", async () => {
      const requestId = randomUUID();
      const reply = await redeemIndividualCoins(owner, {
        ...individualInput(requestId),
        costCoins: 1,
        accountId: other,
      });
      expect(JSON.parse(reply.body ?? "{}")).toMatchObject({
        redeemed: true, duplicate: false, costCoins: 6230,
      });
      expect((await get(Keys.coinWallet(owner)))?.balanceCoins).toBe(3770);
      expect((await get(Keys.coinWallet(other)))?.balanceCoins).toBe(200000);
      for (const feature of ["toneCurve", "levelAdjustment"]) {
        const right = await get(Keys.rewardEntitlement(owner, feature));
        expect(right?.status).toBe("active");
        expect(right?.entitlement).toBe(feature);
        expect(right?.expiresAtEpochMs).toBeGreaterThan(Date.now());
        expect(await get(Keys.rewardEntitlement(other, feature))).toBeUndefined();
      }
      const retry = await redeemIndividualCoins(owner, individualInput(requestId));
      expect(JSON.parse(retry.body ?? "{}")).toMatchObject({
        redeemed: true, duplicate: true, costCoins: 6230,
      });
      expect((await get(Keys.coinWallet(owner)))?.balanceCoins).toBe(3770);
      const history = await localDdb.send(new QueryCommand({
        TableName: table,
        KeyConditionExpression: "pk = :owner AND begins_with(sk, :prefix)",
        ExpressionAttributeValues: {
          ":owner": "USER#" + owner, ":prefix": "COIN_HISTORY#",
        },
        ConsistentRead: true,
      }));
      expect(history.Count).toBe(1);
      expect(history.Items?.[0]?.deltaCoins).toBe(-6230);
    }, 30_000);

    it("insufficient funds leaves no receipt, debit, or partial entitlement", async () => {
      const requestId = randomUUID();
      await expect(redeemIndividualCoins(
        owner, individualInput(requestId, ["watermark"]),
      )).rejects.toMatchObject({ code: "REDEMPTION_STATE_CHANGED" });
      expect(await get(Keys.coinTransaction(owner, "redeem-" + requestId)))
        .toBeUndefined();
      expect(await get(Keys.rewardEntitlement(owner, "watermark")))
        .toBeUndefined();
      expect((await get(Keys.coinWallet(owner)))?.balanceCoins).toBe(3770);
    }, 30_000);

    it("expired or paused rights are not returned as active rights", async () => {
      await localDdb.send(new UpdateCommand({
        TableName: table, Key: Keys.rewardEntitlement(owner, "toneCurve"),
        UpdateExpression: "SET expiresAtEpochMs = :expired",
        ExpressionAttributeValues: { ":expired": Date.now() - 1000 },
      }));
      await localDdb.send(new UpdateCommand({
        TableName: table, Key: Keys.rewardEntitlement(owner, "levelAdjustment"),
        UpdateExpression: "SET #s = :paused, pausedRemainingSeconds = :remaining",
        ExpressionAttributeNames: { "#s": "status" },
        ExpressionAttributeValues: { ":paused": "paused", ":remaining": 7200 },
      }));
      const reply = await getMyRewardState(event("owner"));
      const state = JSON.parse(reply.body ?? "{}");
      expect(state.entitlements.some((x: { feature: string }) =>
        x.feature === "toneCurve")).toBe(false);
      expect(state.entitlements).toEqual(expect.arrayContaining([
        expect.objectContaining({
          feature: "levelAdjustment", status: "paused",
          pausedRemainingSeconds: 7200,
        }),
      ]));
      expect((await get(Keys.coinWallet(other)))?.balanceCoins).toBe(200000);
    }, 30_000);

    it("full Premium monthly debits only the other user and cannot double debit", async () => {
      const requestId = randomUUID();
      const body = {
        target: "fullPremium", duration: "month", quantity: 1,
        priceVersion: COIN_BENEFIT_PRICE_VERSION, requestId,
      };
      const reply = await redeemCoins(event("other", body));
      const result = JSON.parse(reply.body ?? "{}");
      expect(result).toMatchObject({
        redeemed: true, duplicate: false, costCoins: 55000,
      });
      expect(result.expiresAtEpochMs).toBeGreaterThan(Date.now());
      expect((await get(Keys.coinWallet(other)))?.balanceCoins).toBe(145000);
      expect((await get(Keys.coinWallet(owner)))?.balanceCoins).toBe(3770);
      expect((await get(Keys.rewardEntitlement(other, "fullPremium")))?.expiresAtEpochMs)
        .toBe(result.expiresAtEpochMs);
      expect((await get(Keys.user(other)))?.coinPremiumExpiresAtEpochMs)
        .toBe(result.expiresAtEpochMs);
      const retry = await redeemCoins(event("other", body));
      expect(JSON.parse(retry.body ?? "{}")).toMatchObject({
        redeemed: true, duplicate: true, costCoins: 55000,
      });
      expect((await get(Keys.coinWallet(other)))?.balanceCoins).toBe(145000);
      const reward = await getMyRewardState(event("other"));
      expect(JSON.parse(reward.body ?? "{}").entitlements).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            feature: "fullPremium", status: "active",
            expiresAtEpochMs: result.expiresAtEpochMs,
          }),
        ]),
      );
    }, 30_000);
  },
);
