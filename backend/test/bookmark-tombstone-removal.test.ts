import { beforeEach, describe, expect, it, vi } from "vitest";
import { DeleteCommand, GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({ niarimUserId: "viewer" })),
}));

import { toggleBookmark } from "../src/api/routes/bookmarks";

const workId = "abcdefghijk";
const event = { headers: {} } as APIGatewayProxyEventV2;
const body = (result: { body?: string }) => JSON.parse(result.body ?? "{}");

beforeEach(() => {
  process.env.TABLE_NAME = "test";
  send.mockReset();
});

function mockDeletedWork(hasBookmark: boolean, hasTombstone = true) {
  send.mockImplementation(async (command: unknown) => {
    if (command instanceof GetCommand) {
      const pk = command.input.Key?.pk;
      if (pk === `WORK#${workId}`) {
        return { Item: hasTombstone ? { itemType: "WORK_TOMBSTONE", workId } : undefined };
      }
      return {
        Item: hasBookmark ? {
          itemType: "BOOKMARK", niarimUserId: "viewer", workId,
        } : undefined,
      };
    }
    if (command instanceof DeleteCommand) return {};
    throw Error("Unexpected write");
  });
}

describe("removing a bookmark after work deletion", () => {
  it("removes the old bookmark without writing to a missing work counter", async () => {
    mockDeletedWork(true);
    const result = body(await toggleBookmark(event, workId));
    expect(result).toEqual({ bookmarked: false });
    const deletes = send.mock.calls.map(([cmd]) => cmd)
      .filter(cmd => cmd instanceof DeleteCommand);
    expect(deletes).toHaveLength(1);
    expect(deletes[0].input.Key.pk).toBe("USER#viewer");
    expect(deletes[0].input.ConditionExpression).toBe("attribute_exists(pk)");
    expect(send.mock.calls.some(([cmd]) => cmd instanceof TransactWriteCommand)).toBe(false);
  });

  it("also cleans up old bookmarks when the work record is absent", async () => {
    mockDeletedWork(true, false);
    expect(body(await toggleBookmark(event, workId))).toEqual({ bookmarked: false });
  });

  it("never creates a new bookmark for a deleted work", async () => {
    mockDeletedWork(false);
    await expect(toggleBookmark(event, workId)).rejects.toThrow();
    expect(send.mock.calls.some(([cmd]) => cmd instanceof DeleteCommand)).toBe(false);
  });
});
