import { beforeEach, describe, expect, it, vi } from "vitest";
import { TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
const { send, googleLookup } = vi.hoisted(() => ({
  send: vi.fn(), googleLookup: vi.fn(),
}));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()), ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({
    niarimUserId: "Nverified-account", membershipTier: "free",
  })),
}));
vi.mock("../src/lib/playVerification", async (original) => ({
  ...(await original<typeof import("../src/lib/playVerification")>()),
  queryGooglePlaySubscription: googleLookup,
}));
import { verifyMyPlayPremium, getPlayPurchaseAvailability } from "../src/api/routes/playPremium";
import { evaluatePlaySubscription, playWorkloadIdentityConfig } from "../src/lib/playVerification";
const productId = "niarim_premium_monthly";
const purchaseToken = "long-google-play-token-1234567890";
const valid = {
  subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  lineItems: [{ productId, expiryTime: "2028-01-01T00:00:00Z" }],
};
const request = (body: object) => ({
  headers: { authorization: "Bearer test" },
  body: JSON.stringify(body),
}) as unknown as APIGatewayProxyEventV2;
beforeEach(() => {
  process.env.TABLE_NAME = "unit-test-table";
  process.env.PLAY_ANDROID_PACKAGE_NAME = "com.niarim.niarim";
  process.env.PLAY_WIF_AUDIENCE =
    "//iam.googleapis.com/projects/123456789/locations/global/workloadIdentityPools/play-tests/providers/aws-lambda";
  process.env.PLAY_VERIFIER_SERVICE_ACCOUNT =
    "niarim-play-test@play-ci.iam.gserviceaccount.com";
  delete process.env.PLAY_PURCHASE_VERIFICATION_ENABLED;
  send.mockReset(); send.mockResolvedValue({});
  googleLookup.mockReset(); googleLookup.mockResolvedValue(valid);
});
describe("Google Play purchase verification", () => {
  it("declines Billing preflight when backend verifier is off", async () => {
    const out = await getPlayPurchaseAvailability(request({}));
    expect(JSON.parse(out.body ?? "{}")).toEqual({enabled:false,products:[]});
    expect(send).not.toHaveBeenCalled();
    expect(googleLookup).not.toHaveBeenCalled();
  });
  it("never offers paid Billing when the Google Play WIF identity is absent", async () => {
    process.env.PLAY_PURCHASE_VERIFICATION_ENABLED = "true";
    delete process.env.PLAY_WIF_AUDIENCE;
    expect(playWorkloadIdentityConfig()).toBeNull();
    expect(JSON.parse((await getPlayPurchaseAvailability(request({}))).body ?? "{}"))
      .toMatchObject({ enabled: false, products: [] });
    await expect(verifyMyPlayPremium(request({ productId, purchaseToken })))
      .rejects.toMatchObject({ code: "PLAY_VERIFICATION_DISABLED" });
    expect(googleLookup).not.toHaveBeenCalled();
    expect(send).not.toHaveBeenCalled();
  });
  it("rejects malformed WIF identifiers and never falls back to FCM credentials", async () => {
    process.env.PLAY_PURCHASE_VERIFICATION_ENABLED = "true";
    process.env.PLAY_WIF_AUDIENCE = "https://example.invalid/redirect";
    process.env.FCM_WIF_AUDIENCE = "//iam.googleapis.com/projects/123456789/locations/global/workloadIdentityPools/fcm/providers/aws";
    process.env.FCM_SENDER_SERVICE_ACCOUNT = "fcm@test.iam.gserviceaccount.com";
    expect(playWorkloadIdentityConfig()).toBeNull();
    expect(JSON.parse((await getPlayPurchaseAvailability(request({}))).body ?? "{}"))
      .toMatchObject({ enabled: false, products: [] });
    expect(send).not.toHaveBeenCalled();
  });
  it("only reports server-side product IDs when enabled", async () => {
    process.env.PLAY_PURCHASE_VERIFICATION_ENABLED = "true";
    const out = await getPlayPurchaseAvailability(request({}));
    expect(JSON.parse(out.body ?? "{}")).toMatchObject({
      enabled: true, products: ["niarim_premium_monthly", "niarim_premium_yearly"],
    });
    expect(send).not.toHaveBeenCalled();
  });
  it("is fail-closed by default", async () => {
    await expect(verifyMyPlayPremium(request({productId,purchaseToken})))
      .rejects.toMatchObject({code: "PLAY_VERIFICATION_DISABLED"});
    expect(googleLookup).not.toHaveBeenCalled();
    expect(send).not.toHaveBeenCalled();
  });
  it("checks Google then binds hashed receipt once per user", async () => {
    process.env.PLAY_PURCHASE_VERIFICATION_ENABLED = "true";
    const result = await verifyMyPlayPremium(request({productId,purchaseToken}));
    const body = JSON.parse(result.body ?? "{}");
    expect(body.verified).toBe(true);
    expect(body.expiresAtEpochMs).toBe(Date.parse("2028-01-01T00:00:00Z"));
    expect(body.verifiedUntilEpochMs).toBeLessThan(Date.now()+16*60_000);
    const tx = send.mock.calls[0][0] as TransactWriteCommand;
    expect(tx).toBeInstanceOf(TransactWriteCommand);
    expect(tx.input.TransactItems).toHaveLength(2);
    const tokenUpdate = tx.input.TransactItems![0].Update;
    expect(tokenUpdate?.Key?.pk).toMatch(/^PLAY_PURCHASE#[a-f0-9]{64}$/);
    expect(tokenUpdate?.ConditionExpression).toContain("niarimUserId = :owner");
    expect(JSON.stringify(tx.input)).not.toContain(purchaseToken);
  });
  it("denies invalid IDs before Google", async () => {
    process.env.PLAY_PURCHASE_VERIFICATION_ENABLED = "true";
    await expect(verifyMyPlayPremium(request({
      productId:"fake",purchaseToken,
    }))).rejects.toMatchObject({code:"PLAY_INVALID_PRODUCT"});
    await expect(verifyMyPlayPremium(request({
      productId,purchaseToken:"bad",
    }))).rejects.toMatchObject({code:"PLAY_INVALID_TOKEN"});
    expect(googleLookup).not.toHaveBeenCalled();
  });
  it("accepts canceled-unexpired but rejects paused, hold, pending, expired", () => {
    const now=Date.parse("2027-01-01T00:00:00Z");
    for (const state of ["SUBSCRIPTION_STATE_PAUSED","SUBSCRIPTION_STATE_ON_HOLD",
      "SUBSCRIPTION_STATE_PENDING","SUBSCRIPTION_STATE_EXPIRED"]) {
      expect(evaluatePlaySubscription({...valid,subscriptionState:state},
        productId,now).active).toBe(false);
    }
    expect(evaluatePlaySubscription({...valid,
      subscriptionState:"SUBSCRIPTION_STATE_CANCELED"},productId,now).active)
      .toBe(true);
    expect(evaluatePlaySubscription({...valid,
      lineItems:[{productId:"other",expiryTime:"2028-01-01T00:00:00Z"}]},
      productId,now).active).toBe(false);
  });
});
