import { createSign, generateKeyPairSync, randomUUID } from "node:crypto";
import { beforeAll, afterAll, describe, expect, it, vi } from "vitest";
import {
  CreateTableCommand, DeleteTableCommand, DynamoDBClient,
  waitUntilTableExists,
} from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient, GetCommand, QueryCommand, UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

/**
 * Real DynamoDB transaction execution against a LOCAL, throwaway service.
 * Requires NIARIM_DYNAMODB_LOCAL_TESTS=1 and localhost:8000. Normal backend
 * CI and AWS Lambda do not run this integration test or create any records.
 * The local user, key, signature, reward session, wallet and table are
 * synthetic. Nothing interacts with production AdMob or AWS.
 */
const { loadGoogleKeys } = vi.hoisted(() => ({ loadGoogleKeys: vi.fn() }));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({
    niarimUserId: `N${"a".repeat(32)}`,
    googleSub: "isolated-local-test-user",
    membershipTier: "free",
  })),
}));
vi.mock("../src/lib/admobSsv", async (importOriginal) => ({
  ...(await importOriginal<typeof import("../src/lib/admobSsv")>()),
  admobPublicKeys: loadGoogleKeys,
}));
vi.mock("../src/lib/dynamo", async (importOriginal) => {
  const original = await importOriginal<typeof import("../src/lib/dynamo")>();
  const { DynamoDBClient: Client } = await import("@aws-sdk/client-dynamodb");
  const { DynamoDBDocumentClient: Doc } = await import("@aws-sdk/lib-dynamodb");
  const client = new Client({
    endpoint: "http://127.0.0.1:8000",
    region: "ap-northeast-1",
    credentials: { accessKeyId: "localonly", secretAccessKey: "localonly" },
  });
  return {
    ...original,
    ddb: Doc.from(client, {
      marshallOptions: { removeUndefinedValues: true },
    }),
  };
});

import {
  getRewardedAdStatus, receiveRewardedAdSsv, startRewardedAdSession,
} from "../src/api/routes/rewardedAd";
import { Keys } from "../src/lib/dynamo";

const localOptions = {
  endpoint: "http://127.0.0.1:8000",
  region: "ap-northeast-1",
  credentials: { accessKeyId: "localonly", secretAccessKey: "localonly" },
};
const client = new DynamoDBClient(localOptions);
const ddb = DynamoDBDocumentClient.from(client);
const keys = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const keyId = 222334455;
const owner = `N${"a".repeat(32)}`;
const other = `N${"b".repeat(32)}`;
const adUnit = "ca-app-pub-1111111111111111/2222222222";
const table = `niarim-ssv-local-${Date.now()}`;
const bearer = {
  headers: { authorization: "Bearer fake-local-auth" },
} as unknown as APIGatewayProxyEventV2;
function signedCallback(customData: string, transactionId: string, unit = "2222222222") {
  const raw = [
    "ad_network=12345", "ad_unit=" + unit,
    "custom_data=" + encodeURIComponent(customData),
    "reward_amount=10", "reward_item=coins",
    "timestamp=" + Date.now(),
    "transaction_id=" + transactionId,
  ].join("&");
  const signer = createSign("SHA256");
  signer.update(raw, "utf8");
  signer.end();
  return raw + "&signature=" +
    signer.sign(keys.privateKey).toString("base64url") +
    "&key_id=" + keyId;
}
function ssvEvent(raw: string) {
  return { ...bearer, rawQueryString: raw } as APIGatewayProxyEventV2;
}
async function row(key: {pk: string; sk: string}) {
  const result = await ddb.send(new GetCommand({
    TableName: table, Key: key, ConsistentRead: true,
  }));
  return result.Item;
}

describe.skipIf(process.env.NIARIM_DYNAMODB_LOCAL_TESTS !== "1")(
  "SSV full signed reward against disposable DynamoDB Local", () => {
    beforeAll(async () => {
      process.env.TABLE_NAME = table;
      process.env.ADMOB_REWARDED_AD_UNIT_ID = adUnit;
      process.env.REWARDED_AD_SSV_ENABLED = "true";
      process.env.REWARDED_AD_REVIEW_APPROVED = "true";
      process.env.REWARDED_AD_DAILY_LIMIT = "1"; // Test fixture: one grant/day.
      loadGoogleKeys.mockResolvedValue(new Map([[
        keyId, keys.publicKey.export({ type: "spki", format: "pem" }).toString(),
      ]]));
      await client.send(new CreateTableCommand({
        TableName: table,
        BillingMode: "PAY_PER_REQUEST",
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
    }, 45_000);

    afterAll(async () => {
      try {
        await client.send(new DeleteTableCommand({ TableName: table }));
      } finally {
        client.destroy();
        ddb.destroy();
      }
    });

    it("atomic +10, immutable history, replay dedupe and cap failure all hold in actual DynamoDB", async () => {
      const invite = await startRewardedAdSession(bearer);
      const offer = JSON.parse(invite.body ?? "{}");
      expect(offer.rewardCoins).toBe(10);
      expect(offer.customData).toMatch(/^v1\.N[a-f0-9]{32}\.[0-9a-f-]{36}$/);
      const nonce = offer.customData.split(".")[2] as string;
      const session = await row(Keys.rewardedAdSession(owner));
      expect(session?.itemType).toBe("REWARDED_AD_SESSION");
      expect(session?.nonce).toBe(nonce);
      const pending = await getRewardedAdStatus({
        ...bearer, queryStringParameters: { nonce },
      } as APIGatewayProxyEventV2);
      expect(JSON.parse(pending.body ?? "{}")).toMatchObject({
        status: "pending", credited: false,
      });

      const transactionId = "18fa792de1bca816048293fc71035638";
      const signed = signedCallback(offer.customData, transactionId);
      const result = await receiveRewardedAdSsv(ssvEvent(signed));
      expect(JSON.parse(result.body ?? "{}")).toMatchObject({ credited: true });
      const wallet = await row(Keys.coinWallet(owner));
      expect(wallet?.balanceCoins).toBe(10);
      expect(wallet?.rewardedEarnedCoins).toBe(10);
      const receipt = await row(Keys.admobReceipt(transactionId));
      expect(receipt?.earnedCoins).toBe(10);
      expect(receipt?.niarimUserId).toBe(owner);
      const updatedSession = await row(Keys.rewardedAdSession(owner));
      expect(updatedSession?.consumedAtMs).toBeGreaterThan(0);
      const status = await getRewardedAdStatus({
        ...bearer, queryStringParameters: { nonce },
      } as APIGatewayProxyEventV2);
      expect(JSON.parse(status.body ?? "{}")).toMatchObject({
        status: "credited", credited: true,
      });

      const replay = await receiveRewardedAdSsv(ssvEvent(signed));
      expect(JSON.parse(replay.body ?? "{}")).toMatchObject({
        credited: true, duplicate: true,
      });
      expect((await row(Keys.coinWallet(owner)))?.balanceCoins).toBe(10);

      // An otherwise signed message cannot impersonate someone else's
      // receipt or mint coins for a non-existent user session.
      await expect(receiveRewardedAdSsv(ssvEvent(signedCallback(
        `v1.${other}.${nonce}`, transactionId,
      )))).rejects.toMatchObject({ code: "SSV_SESSION_CONFLICT" });
      expect(await row(Keys.coinWallet(other))).toBeUndefined();

      // Exhaustion of today's limit is checked before another session is
      // issued; a maliciously supplied different session still cannot
      // bypass the transaction's atomic daily-cap condition.
      await expect(startRewardedAdSession(bearer))
        .rejects.toMatchObject({ code: "REWARDED_AD_DAILY_LIMIT" });
      const secondNonce = randomUUID();
      const now = Date.now();
      await ddb.send(new UpdateCommand({
        TableName: table, Key: Keys.rewardedAdSession(owner),
        UpdateExpression: "SET nonce = :nonce, issuedAtMs = :start, " +
          "expiresAtMs = :expiry, offerVersion = :version, " +
          "rewardCoins = :amount REMOVE consumedAtMs",
        ExpressionAttributeValues: {
          ":nonce": secondNonce, ":start": now - 1000,
          ":expiry": now + 300000,
          ":version": offer.offerVersion, ":amount": 10,
        },
      }));
      const tx2 = "18fa792de1bca816048293fc71035639";
      await expect(receiveRewardedAdSsv(ssvEvent(signedCallback(
        `v1.${owner}.${secondNonce}`, tx2,
      )))).rejects.toMatchObject({ code: "SSV_SESSION_CONFLICT" });
      expect(await row(Keys.admobReceipt(tx2))).toBeUndefined();
      expect((await row(Keys.coinWallet(owner)))?.balanceCoins).toBe(10);

      const history = await ddb.send(new QueryCommand({
        TableName: table,
        KeyConditionExpression: "pk = :pk AND begins_with(sk, :sk)",
        ExpressionAttributeValues: {
          ":pk": `USER#${owner}`, ":sk": "COIN_HISTORY#",
        },
      }));
      expect(history.Count).toBe(1);
      expect(history.Items?.[0]?.deltaCoins).toBe(10);
      expect(history.Items?.[0]?.transactionId).toBe(transactionId);
    }, 90_000);
  },
);
