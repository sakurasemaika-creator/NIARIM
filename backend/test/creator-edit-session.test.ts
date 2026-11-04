import { beforeEach, describe, expect, it, vi } from "vitest";
import { GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({
    niarimUserId: "Nauthenticated",
    membershipTier: "free",
    googleSub: "trusted-google-sub",
  })),
}));
import { editSessionAction } from "../src/api/routes/creatorEditSession";

const id = "4e5d649e-b265-4004-881e-1a089b2cd00d";
const nonce = "60020780-6bfb-4a0a-bd1d-e2d049a27a94";
const event = (body: object) => ({
  headers: { authorization: "Bearer verified-in-mock" },
  body: JSON.stringify(body),
  queryStringParameters: { niarimUserId: "Nattacker" },
}) as unknown as APIGatewayProxyEventV2;

beforeEach(() => {
  send.mockReset();
  send.mockResolvedValue({});
  process.env.TABLE_NAME = "test";
  delete process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED;
});

describe("edit session pilot: no coins or verified time issued", () => {
  it("remains disabled, with no DynamoDB traffic", async () => {
    await expect(editSessionAction(event({
      action: "start", startNonce: nonce,
    }))).rejects.toMatchObject({
      statusCode: 403, code: "EDIT_SESSION_PILOT_DISABLED",
    });
    expect(send).not.toHaveBeenCalled();
  });

  it("creates one user-scoped short session without uploading strokes", async () => {
    process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED = "true";
    const result = await editSessionAction(event({
      action: "start", startNonce: nonce,
    }));
    const body = JSON.parse(result.body ?? "{}");
    expect(body.verified).toBe(false);
    expect(body.nextSequence).toBe(1);
    expect(body.checkpointIntervalSeconds).toBe(900);
    expect(body.sessionId).toHaveLength(36);
    expect(send.mock.calls.map(([c]) => c.constructor.name)).toEqual([
      "GetCommand", "UpdateCommand",
    ]);
    const update = send.mock.calls[1][0] as UpdateCommand;
    expect(update.input.Key).toEqual({
      pk: "USER#Nauthenticated",
      sk: "MISSION_STATE_V1",
    });
    expect(update.input.ExpressionAttributeValues?.[":nonce"]).toBe(nonce);
    expect(JSON.stringify(update.input)).not.toContain("stroke");
  });

  it("reuses same valid startNonce on a lost response without a write", async () => {
    process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED = "true";
    send.mockImplementation(async (c: unknown) => c instanceof GetCommand ? {
      Item: {
        editSession: {
          id, startedAtMs: Date.now() - 60000,
          lastAtMs: Date.now() - 15000, lastSequence: 2,
        },
        editSessionStartNonce: nonce, candidateEditSeconds: 120,
        revision: 3,
      },
    } : {});
    const result = await editSessionAction(event({
      action: "start", startNonce: nonce,
    }));
    expect(JSON.parse(result.body ?? "{}")).toMatchObject({
      replay: true, sessionId: id, nextSequence: 3,
      candidateEditSeconds: 120,
    });
    expect(send).toHaveBeenCalledTimes(1);
  });

  it("accepts time only within real server interval, without verifying it", async () => {
    process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED = "true";
    send.mockImplementation(async (c: unknown) => c instanceof GetCommand ? {
      Item: {
        editSession: {
          id, startedAtMs: Date.now() - 750000,
          lastAtMs: Date.now() - 600000, lastSequence: 3,
        },
        candidateEditSeconds: 150,
        editDailyCandidateSeconds: 200,
        editDay: Math.floor(Date.now() / 86400000),
        revision: 7,
      },
    } : {});
    const result = await editSessionAction(event({
      action: "checkpoint", sessionId: id, sequence: 4,
      activeSeconds: 900, meaningfulMutations: 20, stop: false,
    }));
    const body = JSON.parse(result.body ?? "{}");
    expect(body.verified).toBe(false);
    expect(body.acceptedCandidateSeconds).toBeGreaterThan(0);
    expect(body.acceptedCandidateSeconds).toBeLessThanOrEqual(600);
    expect(body.candidateEditSeconds).toBe(
      150 + body.acceptedCandidateSeconds);
    const write = send.mock.calls.map(([c]) => c)
      .find((c) => c instanceof UpdateCommand) as UpdateCommand;
    expect(write.input.ConditionExpression).toContain("editSession.id = :sid");
    expect(write.input.UpdateExpression).not.toContain("verifiedEditSeconds");
    expect(write.input.UpdateExpression).not.toContain("balanceCoins");
  });

  it("recognizes duplicate checkpoint sequence without any wallet write", async () => {
    process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED = "true";
    send.mockResolvedValueOnce({ Item: {
      editSession: {
        id, startedAtMs: Date.now() - 750000,
        lastAtMs: Date.now() - 1000, lastSequence: 4,
      }, candidateEditSeconds: 500,
    }});
    const result = await editSessionAction(event({
      action: "checkpoint", sessionId: id, sequence: 4,
      activeSeconds: 900, meaningfulMutations: 20, stop: false,
    }));
    expect(JSON.parse(result.body ?? "{}")).toMatchObject({
      replay: true, acceptedCandidateSeconds: 0,
      candidateEditSeconds: 500,
    });
    expect(send).toHaveBeenCalledTimes(1);
  });

  it("ends a session with an idempotent tiny receipt and no coin change", async () => {
    process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED = "true";
    send.mockImplementation(async (c: unknown) => c instanceof GetCommand ? {
      Item: {
        editSession: {
          id, startedAtMs: Date.now() - 600000,
          lastAtMs: Date.now() - 300000, lastSequence: 2,
        },
        revision: 2,
      },
    } : {});
    const result = await editSessionAction(event({
      action: "checkpoint", sessionId: id, sequence: 3,
      activeSeconds: 300, meaningfulMutations: 10, stop: true,
    }));
    expect(JSON.parse(result.body ?? "{}")).toMatchObject({
      stopped: true, verified: false, nextSequence: null,
    });
    const tx = send.mock.calls.map(([c]) => c)
      .find((c) => c instanceof UpdateCommand) as UpdateCommand;
    expect(tx.input.UpdateExpression).toContain("REMOVE editSession");
    expect(tx.input.ExpressionAttributeValues?.[":closed"]).toMatchObject({
      id, sequence: 3,
    });
    expect(JSON.stringify(tx.input)).not.toContain("balanceCoins");
  });

  it("replays an already committed stop without second write", async () => {
    process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED = "true";
    send.mockResolvedValueOnce({ Item: {
      lastEditStop: { id, sequence: 3, atMs: Date.now() - 1000 },
      candidateEditSeconds: 800,
    }});
    const result = await editSessionAction(event({
      action: "checkpoint", sessionId: id, sequence: 3,
      activeSeconds: 300, meaningfulMutations: 10, stop: true,
    }));
    expect(JSON.parse(result.body ?? "{}")).toMatchObject({
      replay: true, stopped: true, acceptedCandidateSeconds: 0,
      candidateEditSeconds: 800,
    });
    expect(send).toHaveBeenCalledTimes(1);
  });

  it("rejects checkpoints older than the maximum window", async () => {
    process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED = "true";
    send.mockResolvedValueOnce({ Item: {
      editSession: {
        id, startedAtMs: Date.now() - 1800000,
        lastAtMs: Date.now() - 1260000, lastSequence: 2,
      }, revision: 3,
    }});
    await expect(editSessionAction(event({
      action: "checkpoint", sessionId: id, sequence: 3,
      activeSeconds: 900, meaningfulMutations: 20, stop: false,
    }))).rejects.toMatchObject({ code: "EDIT_SESSION_EXPIRED" });
    expect(send).toHaveBeenCalledTimes(1);
  });
});
