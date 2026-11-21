import { beforeEach, describe, expect, it, vi } from "vitest";
import { GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));

import {
  isActiveRewardEntitlement,
  resolvePostMembershipTier,
} from "../src/lib/rewardEntitlement";
import { reservePostQuota } from "../src/lib/quota";

const now = new Date("2027-04-03T10:00:00.000Z");
const active = (entitlement: string) => ({
  itemType: "REWARD_ENTITLEMENT",
  entitlement,
  status: "active",
  expiresAtEpochMs: now.getTime() + 60_000,
});
const expired = (entitlement: string) => ({
  ...active(entitlement),
  expiresAtEpochMs: now.getTime() - 1,
});

beforeEach(() => {
  process.env.TABLE_NAME = "test-table";
  send.mockReset();
  send.mockResolvedValue({});
});

describe("posting entitlement lookup", () => {
  it("accepts only server active/unexpired records", () => {
    expect(isActiveRewardEntitlement(
      active("communityPostQuota"), "communityPostQuota", now
    )).toBe(true);
    expect(isActiveRewardEntitlement(
      expired("communityPostQuota"), "communityPostQuota", now
    )).toBe(false);
    expect(isActiveRewardEntitlement(
      { ...active("communityPostQuota"), status: "paused" },
      "communityPostQuota", now
    )).toBe(false);
    expect(isActiveRewardEntitlement(
      active("fullPremium"), "communityPostQuota", now
    )).toBe(false);
    expect(isActiveRewardEntitlement(
      { ...active("fullPremium"), expiresAtEpochMs: "later" },
      "fullPremium", now
    )).toBe(false);
  });

  it("recognizes an active post-quota reward under the existing user id", async () => {
    send.mockImplementation(async (command: unknown) => {
      if (!(command instanceof GetCommand)) return {};
      const key = command.input.Key;
      return key?.sk === "ENTITLEMENT#communityPostQuota"
        ? { Item: active("communityPostQuota") }
        : {};
    });
    expect(await resolvePostMembershipTier("N123", "free", now)).toBe("premium");
    expect(send).toHaveBeenCalledTimes(2);
    for (const [command] of send.mock.calls) {
      expect(command.input.Key.pk).toBe("USER#N123");
      expect(command.input.ConsistentRead).toBe(true);
    }
  });

  it("full Premium reward also unlocks posting quota", async () => {
    send.mockImplementation(async (command: unknown) =>
      command instanceof GetCommand && command.input.Key?.sk === "ENTITLEMENT#fullPremium"
        ? { Item: active("fullPremium") }
        : {}
    );
    expect(await resolvePostMembershipTier("N123", "free", now)).toBe("premium");
  });

  it("expired/paused records never unlock more posts", async () => {
    send.mockImplementation(async (command: unknown) =>
      command instanceof GetCommand
        ? { Item: command.input.Key?.sk === "ENTITLEMENT#fullPremium"
            ? { ...active("fullPremium"), status: "paused" }
            : expired("communityPostQuota") }
        : {}
    );
    expect(await resolvePostMembershipTier("N123", "free", now)).toBe("free");
  });

  it("verified membership tier remains eligible without reward lookup", async () => {
    expect(await resolvePostMembershipTier("N123", "premium", now)).toBe("premium");
    expect(send).not.toHaveBeenCalled();
  });
});

describe("atomic daily quota", () => {
  it("reserves 3 per day when reward is active and preserves global cap 100", async () => {
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof GetCommand) {
        return command.input.Key?.sk === "ENTITLEMENT#communityPostQuota"
          ? { Item: {
              ...active("communityPostQuota"),
              expiresAtEpochMs: Date.now() + 60_000,
            } }
          : {};
      }
      return {};
    });
    await reservePostQuota("N123", "free");
    const reservations = send.mock.calls
      .map(([command]) => command)
      .filter((command) => command instanceof TransactWriteCommand);
    expect(reservations).toHaveLength(1);
    const transaction = reservations[0].input.TransactItems ?? [];
    expect(transaction).toHaveLength(2);
    expect(transaction[0].Update?.ExpressionAttributeValues?.[":limit"]).toBe(3);
    expect(transaction[1].Update?.ExpressionAttributeValues?.[":limit"]).toBe(100);
  });

  it("retains free limit of 1 when reward is not active", async () => {
    await reservePostQuota("N123", "free");
    const transaction = send.mock.calls
      .map(([command]) => command)
      .find((command) => command instanceof TransactWriteCommand);
    expect(transaction?.input.TransactItems?.[0].Update?.ExpressionAttributeValues?.[":limit"])
      .toBe(1);
  });
});
