import type { APIGatewayProxyEventV2, APIGatewayProxyStructuredResultV2 } from "aws-lambda";
import { TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { FakeDynamo } from "./helpers/fakeDynamo";

const mocks = vi.hoisted(() => ({
  authenticate: vi.fn(),
  verifyGoogleIdentity: vi.fn(),
  readSecureParameter: vi.fn(),
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: mocks.authenticate,
  verifyGoogleIdentity: mocks.verifyGoogleIdentity,
  tryAuthenticate: vi.fn(async () => null),
  getUser: vi.fn(async () => undefined),
  cacheChannelInfo: vi.fn(async () => {}),
}));
vi.mock("../src/lib/ssmParameters", () => ({ readSecureParameter: mocks.readSecureParameter }));

import { ddb } from "../src/lib/dynamo";
import { handler } from "../src/api/handler";
import {
  COUPON_CODE_ALPHABET, accountIneligibility, displayCouponCode, generateCouponCode,
  normalizeCouponCode,
} from "../src/lib/opalGifts";

const fake = new FakeDynamo();
vi.spyOn(ddb, "send").mockImplementation(fake.send as never);

const ADMIN_PARAM = "/niarim/moderation/admin-emails";
const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.parse("2026-12-01T03:00:00.000Z");
const alice = "N" + "a".repeat(32);
const bob = "N" + "b".repeat(32);
const created: Record<string, string> = {
  [alice]: new Date(NOW - 2 * DAY).toISOString(),
  [bob]: new Date(NOW - 400 * DAY).toISOString(),
};
let signedIn = alice;
let params: Record<string, string | undefined>;

function httpEvent(method: string, path: string, body?: unknown, query?: Record<string, string>) {
  return {
    requestContext: { http: { method, path } },
    headers: { authorization: "Bearer token" },
    body: body === undefined ? undefined : JSON.stringify(body),
    queryStringParameters: query,
  } as unknown as APIGatewayProxyEventV2;
}

async function call(method: string, path: string, body?: unknown, query?: Record<string, string>) {
  const response = await handler(httpEvent(method, path, body, query)) as APIGatewayProxyStructuredResultV2;
  return { status: response.statusCode, body: JSON.parse(response.body || "{}") };
}

function wallet(userId: string) {
  return fake.get(`USER#${userId}`, "COIN_WALLET")?.balanceCoins ?? 0;
}

function history(userId: string) {
  return [...fake.items.values()].filter((row) =>
    row.pk === `USER#${userId}` && String(row.sk).startsWith("COIN_HISTORY#"));
}

async function createCoupon(body: Record<string, unknown>) {
  const response = await call("POST", "/admin/gifts/coupons", {
    coins: 500, validUntil: new Date(NOW + 30 * DAY).toISOString(), ...body,
  });
  expect(response.status).toBe(200);
  return response.body.coupon as { code: string; displayCode: string };
}

async function createPresent(body: Record<string, unknown>) {
  const response = await call("POST", "/admin/gifts/presents", {
    coins: 300, title: "メンテナンスのお詫び", body: "ご不便をおかけしました。",
    claimUntil: new Date(NOW + 7 * DAY).toISOString(), ...body,
  });
  expect(response.status).toBe(200);
  return response.body.present as { id: string };
}

const redeem = (code: string, requestId = "req-00000001") =>
  call("POST", "/me/gifts/coupons/redeem", { code, requestId });

beforeEach(() => {
  fake.items.clear();
  fake.calls.length = 0;
  vi.clearAllMocks();
  vi.useFakeTimers({ toFake: ["Date"] });
  vi.setSystemTime(NOW);
  vi.stubEnv("TABLE_NAME", "gift-test");
  vi.stubEnv("MODERATION_ADMIN_EMAILS_PARAMETER", ADMIN_PARAM);
  params = { [ADMIN_PARAM]: "owner@example.com" };
  mocks.readSecureParameter.mockImplementation(async (name: string) => params[name]);
  mocks.verifyGoogleIdentity.mockResolvedValue({
    sub: "g", email: "owner@example.com", email_verified: true,
  });
  signedIn = alice;
  mocks.authenticate.mockImplementation(async () => ({
    niarimUserId: signedIn, googleSub: `g-${signedIn}`, membershipTier: "free",
    accountCreatedAt: created[signedIn],
  }));
});

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

describe("coupon codes", () => {
  it("normalises width, case, spaces and hyphens", () => {
    expect(normalizeCouponCode(" abcd-efgh ")).toBe("ABCDEFGH");
    expect(normalizeCouponCode("ＡＢＣＤ－２３４５")).toBe("ABCD2345");
    expect(normalizeCouponCode("abcd ー efgh")).toBe("ABCDEFGH");
    expect(normalizeCouponCode("ab")).toBeNull();
    expect(normalizeCouponCode("abcd!efgh")).toBeNull();
    expect(normalizeCouponCode(12345)).toBeNull();
  });

  it("generates unambiguous 12-character codes shown in groups of four", () => {
    for (const ch of "01ILO") expect(COUPON_CODE_ALPHABET).not.toContain(ch);
    const code = generateCouponCode();
    expect(code).toMatch(/^[A-Z2-9]{12}$/);
    expect([...code].every((c) => COUPON_CODE_ALPHABET.includes(c))).toBe(true);
    expect(displayCouponCode("ABCDEFGHJKMN")).toBe("ABCD-EFGH-JKMN");
    expect(displayCouponCode("WELCOME2027")).toBe("WELCOME2027");
  });

  it("judges new accounts from the server creation time", () => {
    const filter = { newAccountWithinDays: 7 };
    expect(accountIneligibility(filter, { userId: alice, createdAtEpochMs: NOW - 6 * DAY }, NOW)).toBeNull();
    expect(accountIneligibility(filter, { userId: alice, createdAtEpochMs: NOW - 8 * DAY }, NOW))
      .toBe("newAccountsOnly");
    expect(accountIneligibility(filter, { userId: alice, createdAtEpochMs: null }, NOW))
      .toBe("newAccountsOnly");
    expect(accountIneligibility({ accountCreatedUntilEpochMs: NOW - DAY },
      { userId: alice, createdAtEpochMs: NOW }, NOW)).toBe("accountTooNew");
    expect(accountIneligibility({ accountIds: [bob] },
      { userId: alice, createdAtEpochMs: NOW }, NOW)).toBe("accountNotListed");
  });
});

describe("coupon redemption", () => {
  it("credits the wallet once, writes history and counts the redemption", async () => {
    const coupon = await createCoupon({ code: "welcome-2027", note: "SNS" });
    expect(coupon.code).toBe("WELCOME2027");
    const response = await redeem(" welcome 2027 ");
    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({ redeemed: true, alreadyRedeemed: false, awardedCoins: 500 });
    expect(wallet(alice)).toBe(500);
    expect(history(alice)).toHaveLength(1);
    expect(history(alice)[0]).toMatchObject({ source: "coupon", deltaCoins: 500, couponCode: "WELCOME2027" });
    expect(fake.get("OPAL_COUPON", "CODE#WELCOME2027")?.redeemedCount).toBe(1);
  });

  it("answers a retried request with the first result and refuses another request", async () => {
    await createCoupon({ code: "RETRY234" });
    expect((await redeem("retry234", "req-same-0001")).status).toBe(200);
    const replay = await redeem("RETRY234", "req-same-0001");
    expect(replay.status).toBe(200);
    expect(replay.body).toMatchObject({ alreadyRedeemed: true, awardedCoins: 500 });
    const again = await redeem("RETRY234", "req-other-0002");
    expect(again.status).toBe(409);
    expect(again.body.code).toBe("COUPON_ALREADY_REDEEMED");
    expect(wallet(alice)).toBe(500);
    expect(history(alice)).toHaveLength(1);
  });

  it("never credits twice when two requests race", async () => {
    await createCoupon({ code: "RACE2345" });
    const [first, second] = await Promise.all([
      redeem("RACE2345", "req-race-0001"), redeem("RACE2345", "req-race-0002"),
    ]);
    expect([first.status, second.status].sort()).toEqual([200, 409]);
    expect(wallet(alice)).toBe(500);
    expect(fake.get("OPAL_COUPON", "CODE#RACE2345")?.redeemedCount).toBe(1);
  });

  it("refuses unknown, ended, expired and not yet valid codes", async () => {
    expect((await redeem("NOSUCH22")).body.code).toBe("COUPON_NOT_FOUND");
    expect((await redeem("NOSUCH22")).status).toBe(404);

    await createCoupon({ code: "ENDED234" });
    expect((await call("POST", "/admin/gifts/coupons/ended-234/deactivate")).status).toBe(200);
    expect((await redeem("ENDED234")).body.code).toBe("COUPON_ENDED");

    await createCoupon({ code: "LATER234", validFrom: new Date(NOW + DAY).toISOString() });
    expect((await redeem("LATER234")).body.code).toBe("COUPON_NOT_YET_VALID");

    await createCoupon({ code: "SHORT234", validUntil: new Date(NOW + 60_000).toISOString() });
    vi.setSystemTime(NOW + 60_000);
    expect((await redeem("SHORT234")).body.code).toBe("COUPON_EXPIRED");
    expect(wallet(alice)).toBe(0);
  });

  it("stops at the total redemption limit", async () => {
    await createCoupon({ code: "LIMIT234", maxRedemptions: 1 });
    expect((await redeem("LIMIT234")).status).toBe(200);
    signedIn = bob;
    const response = await redeem("LIMIT234");
    expect(response.status).toBe(409);
    expect(response.body.code).toBe("COUPON_LIMIT_REACHED");
    expect(wallet(bob)).toBe(0);
  });

  it("limits new-account coupons by the account creation time", async () => {
    await createCoupon({ code: "NEWBIE23", eligibility: { newAccountWithinDays: 7 } });
    signedIn = bob;
    const refused = await redeem("NEWBIE23");
    expect(refused.status).toBe(403);
    expect(refused.body.code).toBe("COUPON_NEW_ACCOUNTS_ONLY");
    signedIn = alice;
    expect((await redeem("NEWBIE23")).status).toBe(200);
  });

  it("limits apology coupons to accounts created on or before a date", async () => {
    await createCoupon({
      code: "SORRY234", eligibility: { accountCreatedUntil: new Date(NOW - 30 * DAY).toISOString() },
    });
    expect((await redeem("SORRY234")).body.code).toBe("COUPON_NOT_ELIGIBLE");
    signedIn = bob;
    expect((await redeem("SORRY234")).status).toBe(200);
  });

  it("refuses badly formed codes and request ids before touching the table", async () => {
    expect((await call("POST", "/me/gifts/coupons/redeem", { code: "!!", requestId: "req-00000001" }))
      .body.code).toBe("COUPON_INVALID_CODE");
    expect((await call("POST", "/me/gifts/coupons/redeem", { code: "ABCD2345", requestId: "x" }))
      .body.code).toBe("COUPON_INVALID_REQUEST");
  });

  it("rate limits guessing to ten attempts an hour", async () => {
    for (let i = 0; i < 10; i++) expect((await redeem(`GUESS${i}AA`)).status).toBe(404);
    const limited = await redeem("GUESS0AB");
    expect(limited.status).toBe(429);
    expect(limited.body.code).toBe("COUPON_RATE_LIMITED");
    vi.setSystemTime(NOW + 60 * 60 * 1000);
    expect((await redeem("GUESS0AB")).status).toBe(404);
  });
});

describe("presents", () => {
  it("lists visible presents with a badge count, claims once and keeps claimed ones listed", async () => {
    const present = await createPresent({});
    const inbox = await call("GET", "/me/gifts");
    expect(inbox.status).toBe(200);
    expect(inbox.body).toMatchObject({ unclaimedCount: 1, niarimUserId: alice });
    expect(inbox.body.accountAgeSeconds).toBe(2 * 24 * 60 * 60);
    expect(inbox.body.presents[0]).toMatchObject({
      id: present.id, coins: 300, title: "メンテナンスのお詫び", claimed: false,
      claimUntilEpochMs: NOW + 7 * DAY,
    });

    const claim = await call("POST", `/me/gifts/presents/${present.id}/claim`);
    expect(claim.body).toMatchObject({ claimed: true, alreadyClaimed: false, awardedCoins: 300 });
    const retry = await call("POST", `/me/gifts/presents/${present.id}/claim`);
    expect(retry.body).toMatchObject({ claimed: true, alreadyClaimed: true, awardedCoins: 300 });
    expect(wallet(alice)).toBe(300);
    expect(history(alice)).toHaveLength(1);
    expect(history(alice)[0]).toMatchObject({ source: "present", presentId: present.id });

    const after = await call("GET", "/me/gifts");
    expect(after.body.unclaimedCount).toBe(0);
    expect(after.body.presents[0]).toMatchObject({ claimed: true, claimedAtEpochMs: NOW });
  });

  it("never credits twice when two claims race", async () => {
    const present = await createPresent({});
    const results = await Promise.all([
      call("POST", `/me/gifts/presents/${present.id}/claim`),
      call("POST", `/me/gifts/presents/${present.id}/claim`),
    ]);
    expect(results.every((r) => r.status === 200)).toBe(true);
    expect(results.filter((r) => r.body.alreadyClaimed === false)).toHaveLength(1);
    expect(wallet(alice)).toBe(300);
  });

  it("hides expired presents and refuses to credit them", async () => {
    const present = await createPresent({ claimUntil: new Date(NOW + 60_000).toISOString() });
    vi.setSystemTime(NOW + 60_000);
    expect((await call("GET", "/me/gifts")).body.presents).toEqual([]);
    const claim = await call("POST", `/me/gifts/presents/${present.id}/claim`);
    expect(claim.status).toBe(409);
    expect(claim.body.code).toBe("PRESENT_EXPIRED");
    expect(wallet(alice)).toBe(0);
  });

  it("shows a present only from its visible time", async () => {
    const present = await createPresent({ visibleFrom: new Date(NOW + DAY).toISOString() });
    expect((await call("GET", "/me/gifts")).body.presents).toEqual([]);
    expect((await call("POST", `/me/gifts/presents/${present.id}/claim`)).status).toBe(404);
    vi.setSystemTime(NOW + DAY);
    expect((await call("GET", "/me/gifts")).body.unclaimedCount).toBe(1);
  });

  it("targets listed accounts and accounts created on or before a date", async () => {
    const listed = await createPresent({ eligibility: { accountIds: [bob] } });
    const apology = await createPresent({
      eligibility: { accountCreatedUntil: new Date(NOW - 30 * DAY).toISOString() },
    });
    expect((await call("GET", "/me/gifts")).body.presents).toEqual([]);
    expect((await call("POST", `/me/gifts/presents/${listed.id}/claim`)).status).toBe(404);
    expect((await call("POST", `/me/gifts/presents/${apology.id}/claim`)).status).toBe(404);
    signedIn = bob;
    expect((await call("GET", "/me/gifts")).body.unclaimedCount).toBe(2);
  });

  it("stops a deactivated present and removes it from the inbox", async () => {
    const present = await createPresent({});
    const stopped = await call("POST", `/admin/gifts/presents/${present.id}/deactivate`);
    expect(stopped.body.present.active).toBe(false);
    expect((await call("GET", "/me/gifts")).body.presents).toEqual([]);
    expect((await call("POST", `/me/gifts/presents/${present.id}/claim`)).body.code).toBe("PRESENT_ENDED");
    expect(fake.get("OPAL_PRESENT", "ACTIVE")?.entries).toEqual([]);
  });

  it("caps the active presents and prunes expired ones from the index", async () => {
    await createPresent({ claimUntil: new Date(NOW + 60_000).toISOString() });
    vi.setSystemTime(NOW + 60_000);
    for (let i = 0; i < 20; i++) await createPresent({});
    expect((fake.get("OPAL_PRESENT", "ACTIVE")?.entries as unknown[]).length).toBe(20);
    const full = await call("POST", "/admin/gifts/presents", {
      coins: 1, title: "t", claimUntil: new Date(NOW + 2 * DAY).toISOString(),
    });
    expect(full.body.code).toBe("PRESENT_LIMIT_REACHED");
  });

  it("keeps the index consistent when an admin write races", async () => {
    await createPresent({});
    const original = fake.send;
    let raced = false;
    vi.mocked(ddb.send).mockImplementation((async (command: unknown) => {
      if (!raced && command instanceof TransactWriteCommand) {
        raced = true;
        const index = fake.get("OPAL_PRESENT", "ACTIVE")!;
        fake.put({ ...index, revision: (index.revision as number) + 1 });
      }
      return original(command);
    }) as never);
    try {
      await createPresent({ title: "2件目" });
    } finally {
      vi.mocked(ddb.send).mockImplementation(fake.send as never);
    }
    expect((fake.get("OPAL_PRESENT", "ACTIVE")?.entries as unknown[]).length).toBe(2);
  });
});

describe("operator API", () => {
  it("requires the admin allowlist for every gift admin route", async () => {
    params[ADMIN_PARAM] = undefined;
    for (const [method, path] of [
      ["GET", "/admin/gifts/coupons"], ["POST", "/admin/gifts/coupons"],
      ["POST", "/admin/gifts/coupons/ABCD2345/deactivate"], ["GET", "/admin/gifts/presents"],
      ["POST", "/admin/gifts/presents"], ["POST", "/admin/gifts/presents/x/deactivate"],
    ] as const) {
      const response = await call(method, path, method === "POST" ? {} : undefined);
      expect(response.status).toBe(403);
      expect(response.body.code).toBe("ADMIN_DISABLED");
    }
    params[ADMIN_PARAM] = "owner@example.com";
    mocks.verifyGoogleIdentity.mockResolvedValue({
      sub: "g", email: "someone@example.com", email_verified: true,
    });
    expect((await call("GET", "/admin/gifts/coupons")).body.code).toBe("ADMIN_FORBIDDEN");
    expect(fake.items.size).toBe(0);
  });

  it("validates coupon and present definitions", async () => {
    const until = new Date(NOW + DAY).toISOString();
    const bad = async (path: string, body: Record<string, unknown>) =>
      (await call("POST", path, body)).body.code;
    expect(await bad("/admin/gifts/coupons", { coins: 0, validUntil: until })).toBe("GIFT_INVALID_COINS");
    expect(await bad("/admin/gifts/coupons", { coins: 1, validUntil: "2026-12-02" }))
      .toBe("GIFT_INVALID_TIME");
    expect(await bad("/admin/gifts/coupons", { coins: 1, validUntil: new Date(NOW - 1).toISOString() }))
      .toBe("GIFT_INVALID_WINDOW");
    expect(await bad("/admin/gifts/coupons", {
      coins: 1, validUntil: new Date(NOW + 400 * DAY).toISOString(),
    })).toBe("GIFT_INVALID_WINDOW");
    expect(await bad("/admin/gifts/coupons", {
      coins: 1, validUntil: until, eligibility: { accountIds: [alice] },
    })).toBe("GIFT_INVALID_ELIGIBILITY");
    expect(await bad("/admin/gifts/presents", { coins: 1, claimUntil: until })).toBe("GIFT_INVALID_TEXT");
    expect(await bad("/admin/gifts/presents", {
      coins: 1, title: "t", claimUntil: until, eligibility: { accountIds: ["nope"] },
    })).toBe("GIFT_INVALID_ELIGIBILITY");
    await createCoupon({ code: "TAKEN234" });
    expect(await bad("/admin/gifts/coupons", { code: "taken-234", coins: 1, validUntil: until }))
      .toBe("COUPON_CODE_TAKEN");
  });

  it("lists coupons and presents for the admin page", async () => {
    const generated = await createCoupon({});
    expect(generated.displayCode).toMatch(/^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/);
    await createPresent({ translations: { en: { title: "Sorry", body: "Thanks." } } });
    const coupons = await call("GET", "/admin/gifts/coupons");
    expect(coupons.body.coupons).toHaveLength(1);
    expect(coupons.body.coupons[0]).toMatchObject({ coins: 500, active: true, redeemedCount: 0 });
    const presents = await call("GET", "/admin/gifts/presents");
    expect(presents.body.presents[0]).toMatchObject({
      coins: 300, translations: { en: { title: "Sorry", body: "Thanks." } },
    });
    const inbox = await call("GET", "/me/gifts");
    expect(inbox.body.presents[0].translations.en.title).toBe("Sorry");
  });
});
