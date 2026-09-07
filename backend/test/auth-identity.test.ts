import { beforeEach, describe, expect, it, vi } from "vitest";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("google-auth-library", () => ({
  OAuth2Client: class {
    async verifyIdToken() {
      return { getPayload: () => ({ sub: "google-sub" }) };
    }
  },
}));
import { authenticate } from "../src/lib/auth";

const user = { niarimUserId: "Nexisting", membershipTier: "premium" };
const lookup = { niarimUserId: user.niarimUserId };
const conflict = () =>
  new TransactionCanceledException({ message: "conflict", $metadata: {} });

beforeEach(() => {
  send.mockReset();
  process.env.GOOGLE_CLIENT_ID = "test-client";
  process.env.TABLE_NAME = "test-table";
});

describe("stable account identity", () => {
  it("preserves an existing account and membership using consistent reads", async () => {
    send
      .mockResolvedValueOnce({ Item: lookup })
      .mockResolvedValueOnce({ Item: user });
    expect(await authenticate("Bearer token")).toMatchObject(user);
    expect(send.mock.calls).toHaveLength(2);
    for (const [command] of send.mock.calls) {
      expect(command).toBeInstanceOf(GetCommand);
      expect(command.input.ConsistentRead).toBe(true);
    }
  });

  it("joins the winning account after concurrent registration", async () => {
    send
      .mockResolvedValueOnce({})
      .mockRejectedValueOnce(conflict())
      .mockResolvedValueOnce({ Item: lookup })
      .mockResolvedValueOnce({ Item: user });
    expect(await authenticate("Bearer token")).toMatchObject(user);
    const writes = send.mock.calls
      .map(([c]) => c)
      .filter((c) => c instanceof TransactWriteCommand);
    expect(writes).toHaveLength(1);
    for (const action of writes[0].input.TransactItems ?? []) {
      expect(action.Put?.ConditionExpression).toBe("attribute_not_exists(pk)");
    }
  });

  it("repairs a missing user under the original identity without replacing its lookup", async () => {
    send
      .mockResolvedValueOnce({ Item: lookup })
      .mockResolvedValueOnce({})
      .mockResolvedValueOnce({});
    expect(await authenticate("Bearer token")).toMatchObject({
      niarimUserId: user.niarimUserId,
    });
    const transaction = send.mock.calls[2][0].input.TransactItems;
    expect(
      transaction[0].ConditionCheck.ExpressionAttributeValues[":uid"],
    ).toBe(user.niarimUserId);
    expect(transaction[1].Put.Item.niarimUserId).toBe(user.niarimUserId);
    expect(transaction[1].Put.ConditionExpression).toBe(
      "attribute_not_exists(pk)",
    );
  });

  it("fails safely on repeated transaction cancellation without unconditional writes", async () => {
    send.mockImplementation(async (command) => {
      if (command instanceof GetCommand) return {};
      throw conflict();
    });
    await expect(authenticate("Bearer token")).rejects.toBeInstanceOf(
      TransactionCanceledException,
    );
    const writes = send.mock.calls
      .map(([c]) => c)
      .filter((c) => c instanceof TransactWriteCommand);
    expect(writes).toHaveLength(3);
    expect(
      writes.every((c) =>
        c.input.TransactItems?.every((a) => a.Put?.ConditionExpression),
      ),
    ).toBe(true);
  });
});
