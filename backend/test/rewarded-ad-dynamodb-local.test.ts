import { createSign, generateKeyPairSync, randomUUID } from "node:crypto";
import { beforeAll, afterAll, describe, expect, it, vi } from "vitest";
import {
  CreateTableCommand, DeleteTableCommand, DynamoDBClient,
  waitUntilTableExists,
} from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient, GetCommand, PutCommand, QueryCommand,
} from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

/**
 * Real DynamoDB transaction execution against a LOCAL, throwaway service.
 * Requires NIARIM_DYNAMODB_LOCAL_TESTS=1 and localhost:8000. Normal backend
 * CI and AWS Lambda do not run this integration test or create any records.
 * The local user, key, signature, reward session, wallet and table are
 * synthetic. Nothing interacts with production AdMob or AWS.
 */
const { loadGoogleKeys, requestAdMobReport } = vi.hoisted(() => ({
  loadGoogleKeys: vi.fn(),
  requestAdMobReport: vi.fn(),
}));
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
vi.mock("maxmind", () => ({
  open: vi.fn(async () => ({ get: () => ({ country: { iso_code: "JP" } }) })),
}));
vi.mock("@aws-sdk/client-secrets-manager", () => ({
  GetSecretValueCommand: class {},
  SecretsManagerClient: class {
    async send() {
      return { SecretString: JSON.stringify({
        client_id: "local-report-client",
        client_secret: "local-report-secret",
        refresh_token: "local-report-token",
      }) };
    }
  },
}));
vi.mock("google-auth-library", () => ({
  OAuth2Client: class {
    setCredentials() {}
    request = requestAdMobReport;
  },
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
import { handler as refreshAdRates } from "../src/batch/rewardAdRevenue";
import { Keys } from "../src/lib/dynamo";
import { authenticate } from "../src/lib/auth";
import { rewardReportDay } from "../src/lib/rewardAdRates";

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
function signedCallback(customData: string, transactionId: string, unit = "2222222222", amount = 10, timestamp = Date.now()) {
  const raw = [
    "ad_network=12345", "ad_unit=" + unit,
    "custom_data=" + encodeURIComponent(customData),
    "reward_amount=" + amount, "reward_item=coins",
    "timestamp=" + timestamp,
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
      const session = await row(Keys.rewardedAdSession(owner, nonce));
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
      const updatedSession = await row(Keys.rewardedAdSession(owner, nonce));
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
      await ddb.send(new PutCommand({
        TableName: table,
        Item: {
          ...Keys.rewardedAdSession(owner), itemType: "REWARDED_AD_SESSION", nonce: secondNonce,
          issuedAtMs: now - 1000, expiresAtMs: now + 300000,
          offerVersion: offer.offerVersion, rewardCoins: 10,
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

    it("accepts consecutive ads and settles delayed callbacks without an account-wide slot", async () => {
      const previousLimit = process.env.REWARDED_AD_DAILY_LIMIT;
      process.env.REWARDED_AD_DAILY_LIMIT = "unlimited";
      const start = async () => {
        vi.mocked(authenticate).mockResolvedValueOnce({
          niarimUserId: other, membershipTier: "free", googleSub: "local-test-unlimited",
        });
        return JSON.parse((await startRewardedAdSession(bearer)).body!);
      };
      try {
        const abandoned = await start();
        const first = await start();
        const second = await start();
        expect(new Set([abandoned.customData, first.customData, second.customData]).size).toBe(3);
        expect(first.dailyRewardLimit).toBeNull();
        const eventForSecond = ssvEvent(signedCallback(second.customData, "18fa792de1bca816048293fc71035640"));
        const eventForFirst = ssvEvent(signedCallback(first.customData, "18fa792de1bca816048293fc71035641"));
        expect((await receiveRewardedAdSsv(eventForSecond)).statusCode).toBe(200);
        expect((await receiveRewardedAdSsv(eventForFirst)).statusCode).toBe(200);
        expect(JSON.parse((await receiveRewardedAdSsv(eventForSecond)).body!))
          .toEqual({ credited: true, duplicate: true });
        expect((await row(Keys.coinWallet(other)))?.balanceCoins).toBe(20);
        expect(await row(Keys.rewardAdDailyCount(other, new Date().toISOString().slice(0, 10).replaceAll("-", ""))))
          .toBeUndefined();
      } finally {
        process.env.REWARDED_AD_DAILY_LIMIT = previousLimit;
      }
    });

    it("publishes a regional rate from the daily report and settles it once", async () => {
      const regionalOwner = `N${"c".repeat(32)}`;
      const tierUnit = "ca-app-pub-1111111111111111/3333333333";
      process.env.REWARDED_AD_COUNTRY_DB = "/opt/GeoLite2-Country.mmdb";
      process.env.REWARDED_AD_AUTO_RATES_ENABLED = "true";
      process.env.REWARDED_AD_UNIT_TIERS = JSON.stringify({ 20: tierUnit });
      process.env.ADMOB_REPORT_OAUTH_SECRET_ARN = "local-report-secret";
      try {
        const reportToday = rewardReportDay(Date.now());
        const today = Date.parse(reportToday.replace(/^(\d{4})(\d{2})(\d{2})$/, "$1-$2-$3"));
        const day = 86_400_000;
        for (let offset = 2; offset <= 8; offset++) {
          const date = new Date(today - offset * day).toISOString().slice(0, 10).replaceAll("-", "");
          await ddb.send(new PutCommand({
            TableName: table,
            Item: { ...Keys.rewardAdCountryDay(date, "JP"), completions: 17 },
          }));
        }
        requestAdMobReport.mockResolvedValueOnce({ data: [
          { header: { localizationSettings: { currencyCode: "JPY" } } },
          { row: {
            dimensionValues: { COUNTRY: { value: "JP" }, AD_UNIT: { value: adUnit } },
            metricValues: { IMPRESSIONS: { integerValue: "120" }, ESTIMATED_EARNINGS: { microsValue: "60000000" } },
          } },
          { footer: { matchingRowCount: "1" } },
        ] });
        await refreshAdRates();
        expect(requestAdMobReport).toHaveBeenCalledWith(expect.objectContaining({
          url: "https://admob.googleapis.com/v1/accounts/pub-1111111111111111/networkReport:generate",
          data: { reportSpec: expect.objectContaining({
            dimensionFilters: [{ dimension: "AD_UNIT", matchesAny: { values: [adUnit, tierUnit] } }],
          }) },
        }));
        const rates = await row(Keys.rewardAdRateSnapshot());
        const revenue = await row(Keys.rewardAdRevenueSnapshot());
        expect(rates?.rates).toEqual({ JP: 20 });
        expect(revenue?.countries).toEqual({
          JP: { impressions: 120, earningsMicros: "60000000", completions: 119 },
        });
        requestAdMobReport.mockRejectedValueOnce(new Error("Unreachable report service"));
        await expect(refreshAdRates()).rejects.toThrow("AdMob network report request failed");
        expect(await row(Keys.rewardAdRateSnapshot())).toEqual(rates);
        expect(await row(Keys.rewardAdRevenueSnapshot())).toEqual(revenue);
        vi.mocked(authenticate).mockResolvedValueOnce({
          niarimUserId: regionalOwner, membershipTier: "free", googleSub: "local-test-regional",
        });
        const invitation = JSON.parse((await startRewardedAdSession({
          ...bearer, requestContext: { http: { sourceIp: "203.0.113.20" } },
          body: JSON.stringify({ rewardCoins: 20, offerVersion: "regional-v1-20-3333333333" }),
        } as APIGatewayProxyEventV2)).body!);
        expect(invitation.adUnitId).toBe(tierUnit);
        const tx = "18fa792de1bca816048293fc71035642";
        const timestamp = Date.now();
        const event = ssvEvent(signedCallback(invitation.customData, tx, "3333333333", 20, timestamp));
        expect(JSON.parse((await receiveRewardedAdSsv(event)).body!)).toEqual({ credited: true });
        expect(JSON.parse((await receiveRewardedAdSsv(event)).body!))
          .toEqual({ credited: true, duplicate: true });
        expect((await row(Keys.coinWallet(regionalOwner)))?.balanceCoins).toBe(20);
        expect((await row(Keys.rewardAdCountryDay(rewardReportDay(timestamp), "JP")))?.completions).toBe(1);
      } finally {
        delete process.env.REWARDED_AD_COUNTRY_DB;
        delete process.env.REWARDED_AD_AUTO_RATES_ENABLED;
        delete process.env.REWARDED_AD_UNIT_TIERS;
        delete process.env.ADMOB_REPORT_OAUTH_SECRET_ARN;
      }
    });
  },
);
