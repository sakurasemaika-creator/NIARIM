import type { APIGatewayProxyEventV2, Context } from "aws-lambda";
import {
  CreateTableCommand, DeleteTableCommand, DynamoDBClient, waitUntilTableExists,
} from "@aws-sdk/client-dynamodb";
import { GetCommand, PutCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";

const fixture = vi.hoisted(() => ({
  owner: "N" + "a".repeat(32), other: "N" + "b".repeat(32),
  nonce: "a".repeat(64), sub: "fake-owner", otherSub: "fake-other",
}));
vi.mock("google-auth-library", () => ({
  OAuth2Client: class {
    async verifyIdToken({ idToken }: { idToken: string }) {
      return { getPayload: () => ({
        sub: idToken === "other" ? fixture.otherSub : fixture.sub,
        email: "audit@example.invalid", email_verified: idToken !== "unverified",
        iat: Math.floor(Date.now() / 1000) - (idToken === "old" ? 900 : 1),
        nonce: fixture.nonce,
      }) };
    }
  },
}));
vi.mock("../src/lib/dynamo", async (original) => {
  const source = await original<typeof import("../src/lib/dynamo")>();
  const { DynamoDBClient: Client } = await import("@aws-sdk/client-dynamodb");
  const { DynamoDBDocumentClient: Doc } = await import("@aws-sdk/lib-dynamodb");
  return { ...source, ddb: Doc.from(new Client({
    endpoint: "http://127.0.0.1:8000",
    region: "ap-northeast-1",
    credentials: { accessKeyId: "localonly", secretAccessKey: "localonly" },
  }), { marshallOptions: { removeUndefinedValues: true } }) };
});

import { ddb, Keys } from "../src/lib/dynamo";
import { authenticate } from "../src/lib/auth";
import { getAccountDeletionStatus, startAccountDeletion, verifyAccountDeletion } from "../src/api/routes/accountDeletion";
import { handler as erase } from "../src/batch/accountErasure";

const { owner, other, nonce, sub, otherSub } = fixture;
const local = new DynamoDBClient({
  endpoint: "http://127.0.0.1:8000", region: "ap-northeast-1",
  credentials: { accessKeyId: "localonly", secretAccessKey: "localonly" },
});
const TableName = "niarim-erasure-local-" + Date.now();
const context = { getRemainingTimeInMillis: () => 40000 } as Context;
const event = (body: object, token = "owner"): APIGatewayProxyEventV2 => ({
  version: "2.0", routeKey: "$default",
  rawPath: "/account-deletion", rawQueryString: "",
  requestContext: {
    accountId: "test", apiId: "test", domainName: "test", domainPrefix: "test",
    requestId: "test", routeKey: "$default", stage: "$default",
    time: "", timeEpoch: 0,
    http: { method: "POST", path: "/account-deletion", sourceIp: "127.0.0.1", protocol: "HTTP/1.1", userAgent: "test" },
  },
  isBase64Encoded: false,
  headers: { authorization: "Bearer " + token }, body: JSON.stringify(body),
});
const read = async (Key: { pk: string; sk: string }) => (await ddb.send(new GetCommand({
  TableName, Key, ConsistentRead: true,
}))).Item;
const put = (Item: Record<string, unknown>) => ddb.send(new PutCommand({ TableName, Item }));
const parse = (value: { body?: string }) => JSON.parse(value.body ?? "{}");

it("rejects expired, mismatched, and unverified identity without looking up accounts", async () => {
  vi.stubEnv("GOOGLE_CLIENT_ID", "test-only");
  try {
    await expect(verifyAccountDeletion(event({ nonce: "b".repeat(64) }))).rejects.toMatchObject({ statusCode: 401 });
    await expect(verifyAccountDeletion(event({ nonce }, "old"))).rejects.toMatchObject({ statusCode: 401 });
    await expect(verifyAccountDeletion(event({ nonce }, "unverified"))).rejects.toMatchObject({ statusCode: 401 });
    await expect(startAccountDeletion(event({ nonce }))).rejects.toMatchObject({ statusCode: 400 });
  } finally {
    vi.unstubAllEnvs();
  }
});

describe.skipIf(process.env.NIARIM_DYNAMODB_LOCAL_TESTS !== "1")("self-service account erasure in DynamoDB Local", () => {
  beforeAll(async () => {
    vi.stubEnv("TABLE_NAME", TableName);
    vi.stubEnv("GOOGLE_CLIENT_ID", "test-only");
    await local.send(new CreateTableCommand({
      TableName, BillingMode: "PAY_PER_REQUEST",
      AttributeDefinitions: [
        { AttributeName: "pk", AttributeType: "S" },
        { AttributeName: "sk", AttributeType: "S" },
      ],
      KeySchema: [
        { AttributeName: "pk", KeyType: "HASH" },
        { AttributeName: "sk", KeyType: "RANGE" },
      ],
    }));
    await waitUntilTableExists({ client: local, maxWaitTime: 30 }, { TableName });
  }, 45_000);

  afterAll(async () => {
    await local.send(new DeleteTableCommand({ TableName }));
    local.destroy();
    ddb.destroy();
    vi.unstubAllEnvs();
  });

  it("locks the principal, resumes cleanup, erases personal rows and keeps another account intact", async () => {
    const createdAt = new Date(Date.now() - 86_400_000).toISOString();
    const ownWork = "abcdefghijk";
    const otherWork = "xyzabcdefgh";
    const ownWallet = { ...Keys.coinWallet(owner), itemType: "COIN_WALLET", balanceCoins: 100 };
    const otherWallet = { ...Keys.coinWallet(other), itemType: "COIN_WALLET", balanceCoins: 50 };
    const ownerDevice = { ...Keys.deviceOwner("owner-token-hash"), itemType: "DEVICE_OWNER_V1", owner };
    const transferredDevice = { ...Keys.deviceOwner("rebound-hash"), itemType: "DEVICE_OWNER_V1", owner: other };
    const ownReport = { ...Keys.report(otherWork, owner, createdAt), itemType: "REPORT", reporterId: owner, reason: "test-only" };
    const playBinding = { ...Keys.playPurchaseToken("test-purchase"), itemType: "PLAY_PURCHASE_TOKEN", niarimUserId: owner };
    const rewardReceipt = {
      ...Keys.admobReceipt("test-ad"), itemType: "REWARDED_AD_RECEIPT",
      transactionId: "test-ad", niarimUserId: owner, sessionNonce: "test-only", ttl: 9999999999,
    };
    const profile = (id: string, subject: string) => ({
      ...Keys.user(id), itemType: "USER", niarimUserId: id, googleSub: subject,
      createdAt, membershipTier: "free", followerCount: 1, followingCount: 0,
    });
    const lookup = (id: string, subject: string) => ({
      ...Keys.googleSubLookup(subject), itemType: "GOOGLE_SUB_LOOKUP",
      niarimUserId: id, googleSub: subject,
    });
    const userRows = Array.from({ length: 27 }, (_, index) => ({
      ...Keys.coinTransaction(owner, String(index)), itemType: "COIN_TX",
    }));
    const rows = [
      profile(owner, sub), profile(other, otherSub), lookup(owner, sub), lookup(other, otherSub),
      ownWallet, otherWallet, ownerDevice, transferredDevice, ownReport, playBinding, rewardReceipt,
      { ...Keys.work(ownWork), workId: ownWork, authorId: owner, itemType: "WORK", title: "my title" },
      { ...Keys.workDetail(ownWork), authorId: owner, itemType: "WORK_DETAIL", description: "my details" },
      { ...Keys.work(otherWork), workId: otherWork, authorId: other, itemType: "WORK", bookmarkCount: 2, gsi2pk: "BOOKMARK_RANKING", gsi2sk: 2 },
      { ...Keys.bookmark(owner, otherWork), workId: otherWork, niarimUserId: owner, itemType: "BOOKMARK" },
      { ...Keys.followerRecord(other, owner), targetId: other, followerId: owner, itemType: "FOLLOWER_RECORD" },
      { ...Keys.followingRecord(owner, other), targetId: other, followerId: owner, itemType: "FOLLOWING_RECORD" },
      ...userRows,
    ];
    for (const row of rows) await put(row);

    expect(parse(await verifyAccountDeletion(event({ nonce })))).toEqual({
      email: "audit@example.invalid", state: "ready",
    });
    const start = await startAccountDeletion(event({ nonce, confirm: true, accountId: other }));
    expect(start.statusCode).toBe(202);
    const { receipt } = parse(start);
    expect(parse(await startAccountDeletion(event({ nonce, confirm: true })))).toEqual({ state: "pending", receipt });
    expect(parse(await getAccountDeletionStatus(event({ receipt })))).toEqual({ state: "pending" });
    await expect(authenticate("Bearer owner")).rejects.toMatchObject({ code: "ACCOUNT_ERASURE_PENDING" });
    expect(await authenticate("Bearer other")).toMatchObject({ niarimUserId: other });

    await erase({}, context);
    expect(await read(Keys.user(owner))).toBeDefined();
    const key = Keys.accountErasureJob(receipt);
    await ddb.send(new UpdateCommand({
      TableName, Key: key, UpdateExpression: "SET enqueuedAt = :past",
      ExpressionAttributeValues: { ":past": Date.now() - 60000 },
    }));
    // Stop after one scan page and resume from the saved cursor.
    let clockReads = 0;
    const spent = { getRemainingTimeInMillis: () => ++clockReads === 1 ? 7000 : 5000 } as Context;
    await erase({}, spent);
    expect((await read(key))?.leaseUntil).toBeGreaterThan(Date.now());
    expect((await read(key))?.cursor).toMatchObject({ pk: expect.any(String), sk: expect.any(String) });
    await ddb.send(new UpdateCommand({ TableName, Key: key, UpdateExpression: "REMOVE leaseUntil" }));
    await erase({}, context);

    expect(parse(await getAccountDeletionStatus(event({ receipt })))).toEqual({ state: "complete" });
    for (const item of [
      Keys.user(owner), Keys.googleSubLookup(sub), Keys.workDetail(ownWork),
      Keys.bookmark(owner, otherWork), Keys.followerRecord(other, owner),
      Keys.followingRecord(owner, other), ownWallet, ownerDevice, ownReport, playBinding, key,
      ...userRows,
    ]) {
      expect(await read({ pk: item.pk, sk: item.sk })).toBeUndefined();
    }
    expect(await read(Keys.work(ownWork))).toEqual({
      ...Keys.work(ownWork), workId: ownWork, itemType: "WORK_TOMBSTONE",
    });
    expect(await read(Keys.work(otherWork))).toMatchObject({ authorId: other, bookmarkCount: 1, gsi2sk: 1 });
    expect(await read(Keys.user(other))).toMatchObject({ followerCount: 0 });
    expect(await read(Keys.coinWallet(other))).toEqual(otherWallet);
    expect(await read(Keys.deviceOwner("rebound-hash"))).toEqual(transferredDevice);
    expect(await read(Keys.admobReceipt("test-ad"))).not.toHaveProperty("niarimUserId");
    expect(await read(Keys.accountErasureBoundary(sub))).toMatchObject({ ttl: expect.any(Number) });
    await expect(authenticate("Bearer owner")).rejects.toMatchObject({ statusCode: 401 });
    expect(parse(await verifyAccountDeletion(event({ nonce })))).toMatchObject({ state: "no-account" });
    await erase({}, context);
    expect((await read(Keys.work(otherWork)))?.bookmarkCount).toBe(1);
  }, 45_000);
});
