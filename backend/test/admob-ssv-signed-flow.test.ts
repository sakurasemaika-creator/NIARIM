import { createSign, generateKeyPairSync } from "node:crypto";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { GetCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

/**
 * Full signed callback integration against REAL NIARIM route + verifier.
 * Only the Google public-key download, identity and DynamoDB I/O are
 * substituted. NO coin is issued and NO AWS resource is modified.
 *
 * The separate rewarded-ad-api tests inspect atomic transaction semantics.
 * These tests specifically eliminate the verifier mock blind spot.
 */
const { send, loadGoogleKeys } = vi.hoisted(() => ({
  send: vi.fn(),
  loadGoogleKeys: vi.fn(),
}));
vi.mock("../src/lib/dynamo", async (importOriginal) => ({
  ...(await importOriginal<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({
    niarimUserId: `N${"a".repeat(32)}`,
    googleSub: "mock-authenticated-sub",
    membershipTier: "free",
  })),
}));
vi.mock("../src/lib/admobSsv", async (importOriginal) => ({
  ...(await importOriginal<typeof import("../src/lib/admobSsv")>()),
  admobPublicKeys: loadGoogleKeys,
}));
import {
  getRewardedAdStatus, receiveRewardedAdSsv, rewardedAdConfiguration,
  startRewardedAdSession,
} from "../src/api/routes/rewardedAd";

const keys = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const keyId = 812345;
const adUnit = "ca-app-pub-1111111111111111/2222222222";
const user = `N${"a".repeat(32)}`;
const signedTransactionId = "18fa792de1bca816048293fc71035638";
const req = {
  headers: { authorization: "Bearer fixture-authentication" },
} as APIGatewayProxyEventV2;

function signCallback({
  customData, unit = "2222222222", item = "coins", amount = 10,
  timestamp = Date.now(), transactionId = signedTransactionId,
}: {
  customData?: string | null; unit?: string; item?: string;
  amount?: number; timestamp?: number; transactionId?: string;
} = {}) {
  // Fields are in Google's alphabetical canonical order, preserving the
  // original exact signed bytes rather than reserializing after signing.
  const raw = [
    "ad_network=12345",
    "ad_unit=" + unit,
    ...(customData == null ? [] : ["custom_data=" + encodeURIComponent(customData)]),
    "reward_amount=" + amount,
    "reward_item=" + item,
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
function event(rawQueryString: string): APIGatewayProxyEventV2 {
  return { ...req, rawQueryString } as APIGatewayProxyEventV2;
}
function validConfig() {
  process.env.ADMOB_REWARDED_AD_UNIT_ID = adUnit;
  process.env.REWARDED_AD_SSV_ENABLED = "true";
  process.env.REWARDED_AD_REVIEW_APPROVED = "true";
  // Only an isolated test fixture; launch limit remains a product decision.
  process.env.REWARDED_AD_DAILY_LIMIT = "10";
}
beforeEach(() => {
  send.mockReset().mockResolvedValue({});
  loadGoogleKeys.mockReset().mockResolvedValue(new Map([[
    keyId, keys.publicKey.export({ type: "spki", format: "pem" }).toString(),
  ]]));
  process.env.TABLE_NAME = "signed-flow-test-only";
  for (const key of [
    "ADMOB_REWARDED_AD_UNIT_ID", "REWARDED_AD_SSV_ENABLED",
    "REWARDED_AD_REVIEW_APPROVED", "REWARDED_AD_DAILY_LIMIT",
  ]) delete process.env[key];
});

describe("real ECDSA-signed AdMob reward callback through NIARIM API", () => {
  it("starts owner-bound session, verifies signed completion, and requests atomic 10-coin write", async () => {
    validConfig();
    const started = await startRewardedAdSession(req);
    const invitation = JSON.parse(started.body ?? "{}");
    expect(started.statusCode).toBe(200);
    expect(invitation.adUnitId).toBe(adUnit);
    expect(invitation.rewardCoins).toBe(10);
    expect(invitation.customData).toMatch(/^v1\.N[a-f0-9]{32}\.[0-9a-f-]{36}$/);
    const signed = signCallback({ customData: invitation.customData });
    const result = await receiveRewardedAdSsv(event(signed));
    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body ?? "{}")).toMatchObject({ credited: true });
    const txs = send.mock.calls
      .map(([command]) => command)
      .filter((command) => command instanceof TransactWriteCommand);
    expect(txs).toHaveLength(1);
    const items = (txs[0] as TransactWriteCommand).input.TransactItems!;
    expect(items).toHaveLength(5);
    expect(items[0].Put?.Item?.transactionId).toBe(signedTransactionId);
    expect(items[0].Put?.ConditionExpression).toContain("attribute_not_exists");
    expect(items[1].Update?.ExpressionAttributeValues?.[":nonce"])
      .toBe(invitation.customData.split(".")[2]);
    expect(items[1].Update?.ConditionExpression)
      .toContain("attribute_not_exists(consumedAtMs)");
    expect(items[2].Update?.ExpressionAttributeValues?.[":limit"]).toBe(10);
    expect(items[3].Put?.Item?.deltaCoins).toBe(10);
    expect(items[4].Update?.ExpressionAttributeValues?.[":reward"]).toBe(10);
  });

  it("signed unbound AdMob URL check succeeds while coin issuance remains disabled", async () => {
    process.env.REWARDED_AD_SSV_ENABLED = "false";
    process.env.REWARDED_AD_REVIEW_APPROVED = "false";
    expect(rewardedAdConfiguration().enabled).toBe(false);
    const result = await receiveRewardedAdSsv(event(signCallback({
      unit: "0000000000",
    })));
    expect(result.statusCode).toBe(200);
    expect(JSON.parse(result.body ?? "{}")).toEqual({
      verified: true, credited: false,
    });
    expect(send).not.toHaveBeenCalled();
  });

  it("a signed user-bound callback NEVER credits if the owner switch is off", async () => {
    process.env.ADMOB_REWARDED_AD_UNIT_ID = adUnit;
    const raw = signCallback({
      customData: `v1.${user}.123e4567-e89b-12d3-a456-426614174000`,
    });
    await expect(receiveRewardedAdSsv(event(raw))).rejects.toMatchObject({
      code: "REWARDED_AD_DISABLED",
    });
    expect(send).not.toHaveBeenCalled();
  });

  it.each([
    ["modified amount", (s: string) => s.replace("reward_amount=10", "reward_amount=500")],
    ["modified signature", (s: string) => s.replace(/signature=[A-Za-z0-9_-]+/, "signature=fake")],
    ["duplicate signed field", (s: string) => s.replace("&reward_item=coins", "&reward_amount=1&reward_item=coins")],
    ["unsigned URL", (s: string) => s.split("&signature=")[0]],
  ])("rejects %s without even requesting DynamoDB writes", async (_, mutate) => {
    validConfig();
    const raw = signCallback({
      customData: `v1.${user}.123e4567-e89b-12d3-a456-426614174000`,
    });
    await expect(receiveRewardedAdSsv(event(mutate(raw))))
      .rejects.toMatchObject({ code: "INVALID_SSV" });
    expect(send).not.toHaveBeenCalled();
  });

  it.each([
    { unit: "0000000000" },
    { item: "diamonds" },
    { amount: 1000 },
    { timestamp: Date.now() - 8 * 24 * 3600_000 },
    { customData: "attacker-controlled-value" },
  ])("rejects valid signatures for invalid reward offers: %j", async (override) => {
    validConfig();
    const raw = signCallback({
      customData: `v1.${user}.123e4567-e89b-12d3-a456-426614174000`,
      ...override,
    });
    await expect(receiveRewardedAdSsv(event(raw)))
      .rejects.toMatchObject({ code: "INVALID_SSV" });
    expect(send).not.toHaveBeenCalled();
  });

  it("duplicate signed callbacks are acknowledged but never pay twice", async () => {
    validConfig();
    const raw = signCallback({
      customData: `v1.${user}.123e4567-e89b-12d3-a456-426614174000`,
    });
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof TransactWriteCommand) {
        throw new TransactionCanceledException({
          $metadata: {}, message: "transaction receipt already claimed",
        });
      }
      if (command instanceof GetCommand) {
        return { Item: {
          itemType: "REWARDED_AD_RECEIPT",
          niarimUserId: user,
          earnedCoins: 10,
        }};
      }
      return {};
    });
    const result = await receiveRewardedAdSsv(event(raw));
    expect(JSON.parse(result.body ?? "{}")).toEqual({
      credited: true, duplicate: true,
    });
    const attemptedWrites = send.mock.calls.filter(([cmd]) =>
      cmd instanceof TransactWriteCommand);
    expect(attemptedWrites).toHaveLength(1);
  });

  it("a conflicting receipt owned by another account is never treated as paid", async () => {
    validConfig();
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof TransactWriteCommand) {
        throw new TransactionCanceledException({
          $metadata: {}, message: "collision",
        });
      }
      if (command instanceof GetCommand) {
        return { Item: {
          itemType: "REWARDED_AD_RECEIPT",
          niarimUserId: `N${"b".repeat(32)}`,
          earnedCoins: 10,
        }};
      }
      return {};
    });
    const raw = signCallback({
      customData: `v1.${user}.123e4567-e89b-12d3-a456-426614174000`,
    });
    await expect(receiveRewardedAdSsv(event(raw)))
      .rejects.toMatchObject({ code: "SSV_SESSION_CONFLICT" });
  });

  it("no signed session may bypass the configured daily limit", async () => {
    validConfig();
    process.env.REWARDED_AD_DAILY_LIMIT = "0";
    expect(rewardedAdConfiguration().enabled).toBe(false);
    await expect(startRewardedAdSession(req))
      .rejects.toMatchObject({ code: "REWARDED_AD_DISABLED" });
    expect(send).not.toHaveBeenCalled();
  });
});
