import { beforeEach, describe, expect, it, vi } from "vitest";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { GetCommand, QueryCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({
    niarimUserId: "NverifiedByGoogle",
    googleSub: "test-google-sub",
    membershipTier: "free",
  })),
  getUser: vi.fn(async () => ({
    niarimUserId: "NverifiedByGoogle",
    followerCount: 14,
  })),
}));
import { claimCreatorMission, getMyCreatorMissions } from "../src/api/routes/creatorMissions";
import { ApiError } from "../src/lib/response";

const req = (body?: object) => ({
  headers: { authorization: "Bearer mock-google-id-token" },
  queryStringParameters: { niarimUserId: "Nattacker" },
  body: body === undefined ? undefined : JSON.stringify(body),
}) as unknown as APIGatewayProxyEventV2;

beforeEach(() => {
  process.env.TABLE_NAME = "test-table";
  delete process.env.CREATOR_MISSION_CLAIMS_ENABLED;
  delete process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED;
  send.mockReset();
  send.mockResolvedValue({});
});

describe("creator mission endpoints", () => {
  it("GET uses only point reads and verified user ID", async () => {
    const resp = await getMyCreatorMissions(req());
    expect(resp.statusCode).toBe(200);
    const body = JSON.parse(resp.body ?? "{}");
    expect(body.enabled).toBe(false);
    expect(body.missions).toHaveLength(55);
    expect(body.missions.find((m: {id: string}) => m.id === 'edit_50h').coins).toBe(55000);
    expect(body.missions.find((m: {id: string}) => m.id === 'bookmark_rank_1').claimed).toBe(null);
    expect(body.editTimeVerificationReady).toBe(false);
    expect(body.verifiedEditSeconds).toBe(0);
    const commands = send.mock.calls.map(([command]) => command);
    expect(commands).toHaveLength(2);
    expect(commands[0]).toBeInstanceOf(GetCommand);
    expect(commands[0].input.Key?.pk).toBe("USER#NverifiedByGoogle");
    expect(commands[1].input.Key?.pk).toBe("BATCHSTATE#STATS_UPDATE");
    expect(commands[0]).not.toBeInstanceOf(QueryCommand);
  });

  it("does not allow arbitrary user claims or award coins before launch", async () => {
    await expect(claimCreatorMission(req({
      missionId: "followers_10",
      niarimUserId: "Nattacker",
    }))).rejects.toMatchObject({
      statusCode: 403,
      code: "CREATOR_MISSIONS_DISABLED",
    } satisfies Partial<ApiError>);
    expect(send).not.toHaveBeenCalled();
  });

  it("experimental feature toggle alone never authorizes a mission payout", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    await expect(claimCreatorMission(req({ missionId: "followers_10" })))
      .rejects.toMatchObject({ code: "CREATOR_MISSIONS_DISABLED" });
    expect(send).not.toHaveBeenCalled();
  });

  it("never pays from locally editable project work seconds", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    await expect(claimCreatorMission(req({
      missionId: "edit_100h", totalWorkSeconds: 1000000,
    }))).rejects.toMatchObject({
      code: "MISSION_VERIFICATION_PENDING",
    });
    expect(send.mock.calls.some(([c]) => c instanceof TransactWriteCommand)).toBe(false);
  });

  it("first eligible follower claim enters hold and creates no coins", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    const resp = await claimCreatorMission(req({ missionId: "followers_10" }));
    expect(JSON.parse(resp.body ?? "{}")).toMatchObject({
      claimed: false, pending: true, awardedCoins: 0,
    });
    const writes = send.mock.calls.map(([c]) => c);
    expect(writes.filter((c) => c instanceof UpdateCommand)).toHaveLength(1);
    expect(writes.filter((c) => c instanceof TransactWriteCommand)).toHaveLength(0);
  });

  it("matured achievement credits the existing wallet atomically once", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    const old = Math.floor(Date.now() / 1000) - 3 * 86400;
    send.mockImplementation(async (c: unknown) => {
      if (c instanceof GetCommand) return { Item: {
        itemType: "CREATOR_MISSIONS_V1",
        claimedMask: 0,
        revision: 3,
        totalMissionCoins: 0,
        verifiedEditSeconds: 0,
        firstQualifiedAt: { "10": old },
        pendingCoins: { "10": 50 },
      }};
      return {};
    });
    const resp = await claimCreatorMission(req({ missionId: "followers_10" }));
    expect(JSON.parse(resp.body ?? "{}")).toMatchObject({
      claimed: true, awardedCoins: 50,
    });
    const tx = send.mock.calls.map(([c]) => c)
      .find((c) => c instanceof TransactWriteCommand);
    if (!tx) throw new Error("Missing atomic mission award transaction");
    expect(tx.input.TransactItems).toHaveLength(4);
    expect(tx.input.TransactItems?.[0].Update?.Key?.pk).toBe("USER#NverifiedByGoogle");
    expect(tx.input.TransactItems?.[1].Update?.Key?.pk).toBe("USER#NverifiedByGoogle");
    expect(tx.input.TransactItems?.[1].Update?.ExpressionAttributeValues?.[":reward"]).toBe(50);
    expect(tx.input.TransactItems?.[1].Update?.ExpressionAttributeValues?.[":maxBefore"])
      .toBe(Number.MAX_SAFE_INTEGER - 50);
    expect(tx.input.TransactItems?.[2].Put?.Item?.deltaCoins).toBe(50);
    expect(tx.input.TransactItems?.[2].Put?.Item?.sk).toMatch(/^COIN_HISTORY#/);
    expect(tx.input.TransactItems?.[0].Update?.ExpressionAttributeValues?.[":newMask"]).toBe(2 ** 10);
    expect(tx.input.TransactItems?.[3].ConditionCheck?.Key?.sk).toBe("META");
    expect(tx.input.TransactItems?.[3].ConditionCheck?.ExpressionAttributeValues?.[":minimum"])
      .toBe(10);
  });

  it("duplicate claimed mask never pays the wallet twice", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    send.mockImplementation(async (c: unknown) => {
      if (c instanceof GetCommand) return { Item: {
        itemType: "CREATOR_MISSIONS_V1", claimedMask: 2 ** 10,
        revision: 4, totalMissionCoins: 50,
      }};
      return {};
    });
    const resp = await claimCreatorMission(req({ missionId: "followers_10" }));
    expect(JSON.parse(resp.body ?? "{}")).toMatchObject({
      claimed: true, awardedCoins: 0,
    });
    expect(send.mock.calls.some(([c]) => c instanceof TransactWriteCommand)).toBe(false);
  });
  it("requires explicit owned work ID for per-work mission payouts", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    await expect(claimCreatorMission(req({
      missionId: "work_bookmarks_10",
    }))).rejects.toMatchObject({ code: "MISSION_WORK_ID_REQUIRED" });
    expect(send).not.toHaveBeenCalled();
  });

  it("claims bookmark milestones for one named work, never the whole account", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    send.mockImplementation(async (c: unknown) => {
      if (c instanceof GetCommand && c.input.Key?.pk === "WORK#abcdefghijk") {
        return { Item: {
          itemType: "WORK", workId: "abcdefghijk",
          authorId: "NverifiedByGoogle",
          isNiarimPublished: true, youtubePrivacyStatus: "public",
          gsi2pk: "BOOKMARK_RANKING", bookmarkCount: 21,
        }};
      }
      return {};
    });
    const resp = await claimCreatorMission(req({
      missionId: "work_bookmarks_10",
      workId: "abcdefghijk",
    }));
    expect(JSON.parse(resp.body ?? "{}")).toMatchObject({
      pending: true, offeredCoins: 50, awardedCoins: 0,
      workId: "abcdefghijk",
    });
    const write = send.mock.calls.map(([c]) => c)
      .find((c) => c instanceof UpdateCommand);
    expect(write?.input.Key).toEqual({
      pk: "USER#NverifiedByGoogle",
      sk: "MISSION_WORK#abcdefghijk",
    });
  });

  it("refuses to award for another author's work", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    send.mockImplementation(async (c: unknown) => {
      if (c instanceof GetCommand) return {
        Item: { itemType: "WORK", workId: "abcdefghijk",
          authorId: "Nother", isNiarimPublished: true,
          youtubePrivacyStatus: "public", gsi2pk: "BOOKMARK_RANKING" },
      };
      return {};
    });
    await expect(claimCreatorMission(req({
      missionId: "work_bookmarks_10",
      workId: "abcdefghijk",
    }))).rejects.toMatchObject({
      code: "MISSION_WORK_NOT_ELIGIBLE",
    });
    expect(send.mock.calls.some(([c]) => c instanceof TransactWriteCommand)).toBe(false);
  });

  it("clears a held offer when bookmark progress drops below the requirement", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    const first = Math.floor(Date.now() / 1000) - 49 * 3600;
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof GetCommand &&
          command.input.Key?.pk === "WORK#abcdefghijk") {
        return {Item: {
          itemType: "WORK", workId: "abcdefghijk",
          authorId: "NverifiedByGoogle", isNiarimPublished: true,
          youtubePrivacyStatus: "public",
          gsi2pk: "BOOKMARK_RANKING", bookmarkCount: 9,
        }};
      }
      if (command instanceof GetCommand &&
          command.input.Key?.sk === "MISSION_WORK#abcdefghijk") {
        return {Item: {
          itemType: "CREATOR_WORK_MISSIONS_V1", revision: 9, claimedMask: 0,
          firstQualifiedAt: { "5": first }, pendingCoins: { "5": 50 },
        }};
      }
      return {};
    });
    await expect(claimCreatorMission(req({
      missionId: "work_bookmarks_10", workId: "abcdefghijk",
    }))).rejects.toMatchObject({code:"MISSION_NOT_YET_COMPLETE"});
    const writes = send.mock.calls.map(([command]) => command);
    const clear = writes.find((x) => x instanceof UpdateCommand);
    expect(clear?.input.ExpressionAttributeValues?.[":first"]).toEqual({});
    expect(clear?.input.ExpressionAttributeValues?.[":coins"]).toEqual({});
    expect(writes.some((x) => x instanceof TransactWriteCommand)).toBe(false);
  });

  it("pays matured per-work award only with the work's own bitmask", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    const old = Math.floor(Date.now() / 1000) - 3 * 86400;
    send.mockImplementation(async (c: unknown) => {
      if (c instanceof GetCommand && c.input.Key?.pk === "WORK#abcdefghijk") {
        return { Item: {
          itemType: "WORK", workId: "abcdefghijk", authorId: "NverifiedByGoogle",
          isNiarimPublished: true, youtubePrivacyStatus: "public",
          gsi2pk: "BOOKMARK_RANKING", bookmarkCount: 20,
        }};
      }
      if (c instanceof GetCommand && c.input.Key?.sk === "MISSION_WORK#abcdefghijk") {
        return { Item: {
          itemType: "CREATOR_WORK_MISSIONS_V1", claimedMask: 0,
          revision: 5, totalMissionCoins: 0,
          firstQualifiedAt: { "5": old }, pendingCoins: { "5": 50 },
        }};
      }
      return {};
    });
    const resp = await claimCreatorMission(req({
      missionId: "work_bookmarks_10", workId: "abcdefghijk",
    }));
    expect(JSON.parse(resp.body ?? "{}")).toMatchObject({
      claimed: true, awardedCoins: 50,
    });
    const tx = send.mock.calls.map(([c]) => c)
      .find((c) => c instanceof TransactWriteCommand);
    expect(tx?.input.TransactItems?.[0].Update?.Key?.sk).toBe("MISSION_WORK#abcdefghijk");
    expect(tx?.input.TransactItems?.[1].Update?.ExpressionAttributeValues?.[":reward"]).toBe(50);
    expect(tx?.input.TransactItems?.[3].ConditionCheck?.Key?.pk)
      .toBe("WORK#abcdefghijk");
    expect(tx?.input.TransactItems?.[3].ConditionCheck?.ConditionExpression)
      .toContain("bookmarkCount >= :required");
    expect(tx?.input.TransactItems?.[3].ConditionCheck?.ExpressionAttributeValues?.[":required"])
      .toBe(10);
  });

  it("a claimed bit for the same work and mission is never payable again", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof GetCommand &&
          command.input.Key?.pk === "WORK#abcdefghijk") {
        return {Item:{
          itemType:"WORK",workId:"abcdefghijk",
          authorId:"NverifiedByGoogle",isNiarimPublished:true,
          youtubePrivacyStatus:"public",gsi2pk:"BOOKMARK_RANKING",
          bookmarkCount:150,
        }};
      }
      if (command instanceof GetCommand &&
          command.input.Key?.sk === "MISSION_WORK#abcdefghijk") {
        return {Item:{
          itemType:"CREATOR_WORK_MISSIONS_V1",
          claimedMask:2**5,revision:3,totalMissionCoins:50,
        }};
      }
      return {};
    });
    const result = await claimCreatorMission(req({
      missionId:"work_bookmarks_10",workId:"abcdefghijk",
    }));
    expect(JSON.parse(result.body ?? "{}")).toMatchObject({
      claimed:true,awardedCoins:0,
    });
    expect(send.mock.calls.some(([c])=>c instanceof TransactWriteCommand)).toBe(false);
    expect(send.mock.calls.some(([c])=>c instanceof UpdateCommand)).toBe(false);
  });

  it("two distinct works have independently persisted claim keys", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof GetCommand &&
          typeof command.input.Key?.pk === "string" &&
          command.input.Key.pk.startsWith("WORK#")) {
        return {Item:{
          itemType:"WORK",workId:command.input.Key.pk.slice(5),
          authorId:"NverifiedByGoogle",isNiarimPublished:true,
          youtubePrivacyStatus:"public",gsi2pk:"BOOKMARK_RANKING",
          bookmarkCount:110,
        }};
      }
      return {};
    });
    for (const workId of ["abcdefghijk","lmnopqrstuv"]) {
      const result = await claimCreatorMission(req({
        missionId:"work_bookmarks_100",workId,
      }));
      expect(JSON.parse(result.body ?? "{}")).toMatchObject({
        pending:true,awardedCoins:0,workId,
      });
    }
    const writes = send.mock.calls.map(([c])=>c)
      .filter(c=>c instanceof UpdateCommand);
    expect(writes.map(c=>c.input.Key?.sk)).toEqual([
      "MISSION_WORK#abcdefghijk","MISSION_WORK#lmnopqrstuv",
    ]);
  });

  it("concurrent state changes cancel the whole wallet and mask transaction", async () => {
    process.env.CREATOR_MISSION_CLAIMS_ENABLED = "true";
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED = "true";
    const eligibleSince = Math.floor(Date.now()/1000)-3*86400;
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof GetCommand) return {Item:{
        itemType:"CREATOR_MISSIONS_V1",claimedMask:0,revision:3,
        totalMissionCoins:0,firstQualifiedAt:{"10":eligibleSince},
        pendingCoins:{"10":50},
      }};
      if (command instanceof TransactWriteCommand) {
        throw new TransactionCanceledException({
          $metadata:{},message:"Conditional check failed",
        });
      }
      return {};
    });
    await expect(claimCreatorMission(req({
      missionId:"followers_10",
    }))).rejects.toMatchObject({code:"MISSION_STATE_CHANGED"});
    expect(send.mock.calls.filter(([c])=>c instanceof TransactWriteCommand))
      .toHaveLength(1);
  });

});
