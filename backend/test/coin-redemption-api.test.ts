import { beforeEach, describe, expect, it, vi } from "vitest";
import { GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
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
  getUser: vi.fn(async () => ({
    itemType: "USER", membershipTier: "free",
  })),
}));
import { getCoinRedemptionQuote, redeemCoins } from
  "../src/api/routes/coinRedemption";
import { getUser } from "../src/lib/auth";
import {
  addOneCalendarMonthUtc, premiumRedemptionOffer,
} from "../src/lib/coinRedemption";

const req = (body?: unknown) => ({
  headers: { authorization: "Bearer test-only" },
  queryStringParameters: { target: "fullPremium", months: "1" },
  body: body === undefined ? undefined : JSON.stringify(body),
}) as unknown as APIGatewayProxyEventV2;

const requestId = "123e4567-e89b-12d3-a456-426614174000";

function enable() {
  process.env.COIN_REDEMPTION_ENABLED = "true";
  process.env.COIN_REDEMPTION_REVIEW_APPROVED = "true";
  process.env.COIN_FULL_PREMIUM_MONTH_COINS = "55000";
  process.env.COIN_PRICE_VERSION = "v1-premium-month";
}
beforeEach(() => {
  send.mockReset();
  send.mockResolvedValue({});
  vi.mocked(getUser).mockReset();
  vi.mocked(getUser).mockResolvedValue({
    itemType: "USER", membershipTier: "free",
  } as Awaited<ReturnType<typeof getUser>>);
  process.env.TABLE_NAME = "unit-test-table";
  delete process.env.COIN_REDEMPTION_ENABLED;
  delete process.env.COIN_REDEMPTION_REVIEW_APPROVED;
  delete process.env.COIN_FULL_PREMIUM_MONTH_COINS;
  delete process.env.COIN_PRICE_VERSION;
});

describe("fail-closed one-month full Premium coin redemption", () => {
  it("rejects unapproved or unusually low prices, with no database writes", async () => {
    expect(premiumRedemptionOffer().enabled).toBe(false);
    await expect(redeemCoins(req({}))).rejects.toMatchObject({
      code: "REDEMPTION_DISABLED",
    });
    expect(send).not.toHaveBeenCalled();
    enable();
    process.env.COIN_FULL_PREMIUM_MONTH_COINS = "100";
    expect(premiumRedemptionOffer().enabled).toBe(false);
    const quote = await getCoinRedemptionQuote(req());
    expect(JSON.parse(quote.body ?? "{}")).toMatchObject({
      enabled: false, priceCoins: null,
    });
  });

  it("extends exact calendar months, including the 31st and leap days", () => {
    expect(new Date(addOneCalendarMonthUtc(
      Date.UTC(2027, 0, 31, 9, 21),
    )).toISOString()).toBe("2027-02-28T09:21:00.000Z");
    expect(new Date(addOneCalendarMonthUtc(
      Date.UTC(2028, 0, 31),
    )).toISOString()).toBe("2028-02-29T00:00:00.000Z");
  });

  it("never trusts a client price and debits wallet only in 3-item transaction", async () => {
    enable();
    const result = await redeemCoins(req({
      target: "fullPremium", months: 1,
      priceVersion: "v1-premium-month", requestId,
      priceCoins: 0, niarimUserId: "attacker",
    }));
    expect(JSON.parse(result.body ?? "{}")).toMatchObject({
      redeemed: true, costCoins: 55000,
    });
    const tx = send.mock.calls.find(([x]) => x instanceof TransactWriteCommand)?.[0] as TransactWriteCommand;
    expect(tx).toBeInstanceOf(TransactWriteCommand);
    const rows = tx.input.TransactItems!;
    expect(rows).toHaveLength(5);
    expect(rows[0].Put?.Item?.pk).toBe("USER#Nverified-account");
    expect(rows[1].Update?.Key?.sk).toBe("COIN_WALLET");
    expect(rows[1].Update?.ConditionExpression).toContain("balanceCoins >= :price");
    expect(rows[1].Update?.ExpressionAttributeValues?.[":minus"]).toBe(-55000);
    expect(rows[2].Update?.Key?.sk).toBe("ENTITLEMENT#fullPremium");
    expect(rows[2].Update?.ConditionExpression)
      .toContain("attribute_not_exists(expiresAtEpochMs)");
    expect(rows[3].Update?.Key?.sk).toBe("META");
    expect(rows[3].Update?.ExpressionAttributeValues?.[":user"]).toBe("USER");
    expect(rows[3].Update?.ConditionExpression).toContain("membershipTier = :free");
    expect(rows[3].Update?.ConditionExpression).toContain("playPremiumExpiresAtEpochMs");
    expect(rows[3].Update?.ConditionExpression)
      .not.toContain("playPremiumVerifiedUntilEpochMs");
    expect(rows[4].Put?.Item?.source).toBe("coin-redemption");
    expect(rows[4].Put?.Item?.deltaCoins).toBe(-55000);
  });

  it("extends an existing coin-funded Premium without mixing an active Play purchase", async () => {
    enable();
    const priorExpiry = Date.now() + 12 * 86400_000;
    vi.mocked(getUser).mockResolvedValueOnce({
      itemType: "USER", membershipTier: "free",
      coinPremiumExpiresAtEpochMs: priorExpiry,
    } as Awaited<ReturnType<typeof getUser>>);
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof GetCommand &&
          command.input.Key?.sk === "ENTITLEMENT#fullPremium") {
        return {Item: {
          itemType: "REWARD_ENTITLEMENT", status: "active",
          expiresAtEpochMs: priorExpiry,
        }};
      }
      return {};
    });
    const result = await redeemCoins(req({
      target: "fullPremium", months: 1,
      priceVersion: "v1-premium-month", requestId,
    }));
    const response = JSON.parse(result.body ?? "{}");
    expect(response.redeemed).toBe(true);
    expect(response.expiresAtEpochMs).toBeGreaterThan(priorExpiry);
    const tx = (send.mock.calls.find(
      ([c]) => c instanceof TransactWriteCommand,
    )?.[0]) as TransactWriteCommand;
    expect(tx.input.TransactItems?.[2].Update
      ?.ExpressionAttributeValues?.[":oldExpiry"]).toBe(priorExpiry);
    expect(tx.input.TransactItems?.[3].Update
      ?.ExpressionAttributeValues?.[":now"]).toBeGreaterThan(0);
  });

  it("rejects Play term overlap even after the short validation lease expires", async () => {
    enable();
    const now = Date.now();
    vi.mocked(getUser).mockResolvedValueOnce({
      itemType: "USER", membershipTier: "free",
      playPremiumExpiresAtEpochMs: now + 20 * 86400_000,
      playPremiumVerifiedUntilEpochMs: now - 1000,
    } as Awaited<ReturnType<typeof getUser>>);
    await expect(redeemCoins(req({
      target: "fullPremium", months: 1,
      priceVersion: "v1-premium-month", requestId,
    }))).rejects.toMatchObject({code: "REDEMPTION_SUBSCRIPTION_CONFLICT"});
    expect(send.mock.calls.some(([x]) => x instanceof TransactWriteCommand))
      .toBe(false);
  });

  it("rejects an active Play subscription even when the account tier is free", async () => {
    enable();
    const future = Date.now() + 3600_000;
    vi.mocked(getUser).mockResolvedValueOnce({
      itemType: "USER", membershipTier: "free",
      playPremiumExpiresAtEpochMs: future,
      playPremiumVerifiedUntilEpochMs: future,
    } as Awaited<ReturnType<typeof getUser>>);
    await expect(redeemCoins(req({
      target: "fullPremium", months: 1,
      priceVersion: "v1-premium-month", requestId,
    }))).rejects.toMatchObject({code:"REDEMPTION_SUBSCRIPTION_CONFLICT"});
    expect(send.mock.calls.some(([x]) => x instanceof TransactWriteCommand)).toBe(false);
  });

  it("retrying a committed transaction returns the old receipt, never debits twice", async () => {
    enable();
    let receiptReads = 0;
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof TransactWriteCommand) {
        throw new TransactionCanceledException({
          $metadata: {}, message: "already committed",
        });
      }
      if (command instanceof GetCommand &&
          command.input.Key?.sk === `COIN_TX#redeem-${requestId}`) {
        if (++receiptReads === 1) return {};
        return { Item: {
          itemType: "COIN_REDEMPTION",
          target: "fullPremium", months: 1,
          priceVersion: "v1-premium-month",
          costCoins: 55000, expiresAtEpochMs: 12345,
        }};
      }
      return {};
    });
    const result = await redeemCoins(req({
      target: "fullPremium", months: 1,
      priceVersion: "v1-premium-month", requestId,
    }));
    expect(JSON.parse(result.body ?? "{}")).toMatchObject({
      redeemed: true, duplicate: true, costCoins: 55000,
    });
    expect(send.mock.calls.filter(([x]) => x instanceof TransactWriteCommand))
      .toHaveLength(1);
  });

  it("stale price and invalid request ID cannot debit coins", async () => {
    enable();
    await expect(redeemCoins(req({
      target: "fullPremium", months: 1,
      priceVersion: "v0", requestId,
    }))).rejects.toMatchObject({ code: "REDEMPTION_PRICE_CHANGED" });
    await expect(redeemCoins(req({
      target: "fullPremium", months: 1,
      priceVersion: "v1-premium-month", requestId: "not-a-uuid",
    }))).rejects.toMatchObject({ code: "REDEMPTION_REQUEST_ID_INVALID" });
    expect(send.mock.calls.some(([x]) => x instanceof TransactWriteCommand))
      .toBe(false);
  });
});
