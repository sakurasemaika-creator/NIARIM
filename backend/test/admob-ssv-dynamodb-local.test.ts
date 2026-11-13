import { createSign, generateKeyPairSync, randomBytes } from "node:crypto";
import { beforeAll, afterAll, describe, expect, it, vi } from "vitest";
import {
  CreateTableCommand, DeleteTableCommand, DynamoDBClient, waitUntilTableExists,
} from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient, GetCommand, QueryCommand,
} from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

// Real ECDSA validation + real DynamoDB Local condition/transact writes.
// This test never obtains live AWS credentials or mints spendable coins.
const { publicKeys } = vi.hoisted(() => ({ publicKeys: vi.fn() }));
const owner = "N" + "a".repeat(32);
const other = "N" + "b".repeat(32);
const options = {
  endpoint: "http://127.0.0.1:8000",
  region: "ap-northeast-1",
  credentials: { accessKeyId: "localonly", secretAccessKey: "localonly" },
};
const rawClient = new DynamoDBClient(options);
const db = DynamoDBDocumentClient.from(rawClient, {
  marshallOptions: { removeUndefinedValues: true },
});
const table = "niarim-ad-local-" + Date.now();
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async (authorization?: string) => ({
    niarimUserId: authorization === "Bearer other"
      ? "N" + "b".repeat(32) : "N" + "a".repeat(32),
    googleSub: "test-only", membershipTier: "free",
  })),
}));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: DynamoDBDocumentClient.from(new DynamoDBClient({
    endpoint: "http://127.0.0.1:8000",
    region: "ap-northeast-1",
    credentials: { accessKeyId: "localonly", secretAccessKey: "localonly" },
  }), { marshallOptions: { removeUndefinedValues: true } }),
}));
vi.mock("../src/lib/admobSsv", async (original) => ({
  ...(await original<typeof import("../src/lib/admobSsv")>()),
  admobPublicKeys: publicKeys,
}));
import { Keys } from "../src/lib/dynamo";
import {
  startRewardedAdSession, receiveRewardedAdSsv, getRewardedAdStatus,
} from "../src/api/routes/rewardedAd";
import { getMyRewardState } from "../src/api/routes/rewardState";

const pair = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const keyId = 913251;
const unit = "ca-app-pub-1111111111111111/2222222222";
const request = (user: "owner" | "other" = "owner") => ({
  headers: { authorization: user === "owner" ? "Bearer owner" : "Bearer other" },
}) as unknown as APIGatewayProxyEventV2;
const parse = (value: { body?: string | null }) => JSON.parse(value.body ?? "{}");
function signedCallback(customData: string, transactionId: string, amount = 10) {
  const original = [
    "ad_network=12345",
    "ad_unit=2222222222",
    "custom_data=" + encodeURIComponent(customData),
    "reward_amount=" + amount,
    "reward_item=coins",
    "timestamp=" + Date.now(),
    "transaction_id=" + transactionId,
  ].join("&");
  const sign = createSign("SHA256");
  sign.update(original, "utf8");
  sign.end();
  return original + "&signature=" +
    sign.sign(pair.privateKey).toString("base64url") +
    "&key_id=" + keyId;
}
async function read(key: { pk: string; sk: string }) {
  return (await db.send(new GetCommand({
    TableName: table, Key: key, ConsistentRead: true,
  }))).Item;
}

describe.skipIf(process.env.NIARIM_DYNAMODB_LOCAL_TESTS !== "1")(
  "Google-signed AdMob callback against disposable DynamoDB Local", () => {
    beforeAll(async () => {
      process.env.TABLE_NAME = table;
      process.env.ADMOB_REWARDED_AD_UNIT_ID = unit;
      process.env.REWARDED_AD_SSV_ENABLED = "true";
      process.env.REWARDED_AD_REVIEW_APPROVED = "true";
      process.env.REWARDED_AD_DAILY_LIMIT = "2";
      publicKeys.mockResolvedValue(new Map([[
        keyId, pair.publicKey.export({ type: "spki", format: "pem" }).toString(),
      ]]));
      await rawClient.send(new CreateTableCommand({
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
      await waitUntilTableExists({ client: rawClient, maxWaitTime: 30 },
        { TableName: table });
    }, 45000);
    afterAll(async () => {
      try {
        await rawClient.send(new DeleteTableCommand({ TableName: table }));
      } finally {
        rawClient.destroy();
        db.destroy();
      }
    });

    it("exactly once credits ten signed coins and five durable records", async () => {
      const start = parse(await startRewardedAdSession(request()));
      expect(start.rewardCoins).toBe(10);
      expect(start.customData).toMatch(/^v1\.N[a-f0-9]{32}\.[a-f0-9-]{36}$/);
      const receiptId = randomBytes(16).toString("hex");
      const signed = signedCallback(start.customData, receiptId);
      const event = { ...request(), rawQueryString: signed };
      const success = parse(await receiveRewardedAdSsv(event));
      expect(success).toMatchObject({ credited: true });
      expect((await read(Keys.coinWallet(owner)))?.balanceCoins).toBe(10);
      expect((await read(Keys.coinWallet(owner)))?.rewardedEarnedCoins).toBe(10);
      expect((await read(Keys.admobReceipt(receiptId)))?.niarimUserId).toBe(owner);
      expect((await read(Keys.rewardedAdSession(owner)))?.consumedAtMs)
        .toBeGreaterThan(0);
      const day = new Date().toISOString().slice(0, 10).replaceAll("-", "");
      expect((await read(Keys.rewardAdDailyCount(owner, day)))?.consumed).toBe(1);
      const history = await db.send(new QueryCommand({
        TableName: table,
        KeyConditionExpression: "pk = :owner AND begins_with(sk, :history)",
        ExpressionAttributeValues: {
          ":owner": "USER#" + owner, ":history": "COIN_HISTORY#",
        },
        ConsistentRead: true,
      }));
      expect(history.Items).toHaveLength(1);
      expect(history.Items?.[0]?.deltaCoins).toBe(10);
      expect(parse(await getRewardedAdStatus({
        ...request(), queryStringParameters: {
          nonce: start.customData.split(".")[2],
        },
      }))).toMatchObject({ status: "credited", credited: true });

      // Google's retransmission cannot generate a second wallet credit.
      expect(parse(await receiveRewardedAdSsv(event)))
        .toMatchObject({ credited: true, duplicate: true });
      expect((await read(Keys.coinWallet(owner)))?.balanceCoins).toBe(10);
      expect((await read(Keys.rewardAdDailyCount(owner, day)))?.consumed).toBe(1);
      expect((await db.send(new QueryCommand({
        TableName: table,
        KeyConditionExpression: "pk = :owner AND begins_with(sk, :history)",
        ExpressionAttributeValues: {
          ":owner": "USER#" + owner, ":history": "COIN_HISTORY#",
        },
        ConsistentRead: true,
      }))).Items).toHaveLength(1);
      expect(parse(await getRewardedAdStatus({
        ...request("other"), queryStringParameters: {
          nonce: start.customData.split(".")[2],
        },
      }))).toMatchObject({ status: "not_found", credited: false });
      expect(parse(await getMyRewardState(request("other"))).balanceCoins).toBe(0);
    }, 35000);

    it("a changed reward amount is rejected before any new ledger writes", async () => {
      const start = parse(await startRewardedAdSession(request("other")));
      const raw = signedCallback(start.customData,
        randomBytes(16).toString("hex"), 1000);
      await expect(receiveRewardedAdSsv({
        ...request("other"), rawQueryString: raw,
      })).rejects.toMatchObject({ code: "INVALID_SSV" });
      expect(await read(Keys.coinWallet(other))).toBeUndefined();
      expect((await read(Keys.rewardedAdSession(other)))?.consumedAtMs)
        .toBeUndefined();
    }, 15000);
  },
);
