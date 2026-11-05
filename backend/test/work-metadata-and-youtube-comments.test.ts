import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { GetCommand, PutCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({ niarimUserId: "Nowner" })),
}));
import { getWorkMetadata, updateWorkMetadata } from "../src/api/routes/workMetadata";
import { getYoutubeComments } from "../src/api/routes/youtubeComments";
import { deleteWork } from "../src/api/routes/worksDelete";

const work = {
  pk: "WORK#abcdefghijk", sk: "META", itemType: "WORK",
  workId: "abcdefghijk", youtubeVideoId: "abcdefghijk",
  title: "Original", authorId: "Nowner",
  isNiarimPublished: true, youtubePrivacyStatus: "unlisted",
};

const event = (body?: object, auth = false): APIGatewayProxyEventV2 => ({
  headers: auth ? { authorization: "Bearer test" } : {},
  body: body === undefined ? undefined : JSON.stringify(body),
  queryStringParameters: {},
} as APIGatewayProxyEventV2);

beforeEach(() => {
  send.mockReset();
  process.env.TABLE_NAME = "test-table";
  process.env.YOUTUBE_API_KEY = "demo-key";
  send.mockImplementation(async (cmd) => {
    if (cmd instanceof GetCommand) {
      return { Item: cmd.input.Key?.sk === "META" ? work
        : { pk: work.pk, sk: "DETAIL", description: "Saved description" } };
    }
    return {};
  });
});
afterEach(() => vi.unstubAllGlobals());

describe("NIARIM-owned description row", () => {
  it("fetches the public description only when requested", async () => {
    const result = await getWorkMetadata(event(), work.workId);
    const data = JSON.parse(result.body ?? "{}");
    expect(data).toEqual({ title: "Original", description: "Saved description" });
    expect(send.mock.calls).toHaveLength(2);
    expect(send.mock.calls.every(([cmd]) => cmd instanceof GetCommand)).toBe(true);
  });

  it("never reveals hidden work descriptions without the owner's identity", async () => {
    send.mockResolvedValueOnce({ Item: { ...work, isNiarimPublished: false } });
    await expect(getWorkMetadata(event(), work.workId))
      .rejects.toMatchObject({ statusCode: 404 });
    expect(send).toHaveBeenCalledTimes(1);
  });

  it("atomically edits title and a separate non-indexed description", async () => {
    const result = await updateWorkMetadata(
      event({ title: "Edited work", description: "New text" }, true), work.workId,
    );
    expect(JSON.parse(result.body ?? "{}"))
      .toEqual({ title: "Edited work", description: "New text" });
    const txn = send.mock.calls.map(([cmd]) => cmd)
      .find((cmd) => cmd instanceof TransactWriteCommand) as TransactWriteCommand;
    expect(txn).toBeDefined();
    expect(txn.input.TransactItems?.[0].Update?.UpdateExpression)
      .toBe("SET title = :title");
    const detail = txn.input.TransactItems?.[1].Put?.Item;
    expect(detail).toMatchObject({
      pk: "WORK#abcdefghijk", sk: "DETAIL",
      itemType: "WORK_DETAIL", description: "New text", authorId: "Nowner",
    });
    expect(detail?.gsi1pk).toBeUndefined();
    expect(detail?.gsi2pk).toBeUndefined();
  });

  it("deletes the separate detail item when the author clears the description", async () => {
    await updateWorkMetadata(
      event({ title: "Original", description: "" }, true), work.workId,
    );
    const txn = send.mock.calls.map(([cmd]) => cmd)
      .find((cmd) => cmd instanceof TransactWriteCommand) as TransactWriteCommand;
    expect(txn.input.TransactItems?.[1].Delete?.Key)
      .toEqual({ pk: "WORK#abcdefghijk", sk: "DETAIL" });
  });

  it("does not write when both author-owned values are unchanged", async () => {
    await updateWorkMetadata(
      event({ title: "Original", description: "Saved description" }, true), work.workId,
    );
    expect(send.mock.calls.some(([cmd]) => cmd instanceof TransactWriteCommand)).toBe(false);
  });

  it("rejects an oversized description before touching the database", async () => {
    await expect(updateWorkMetadata(
      event({ title: "Title", description: "x".repeat(2001) }, true), work.workId,
    )).rejects.toMatchObject({ statusCode: 400 });
    expect(send).not.toHaveBeenCalled();
  });
});

describe("work deletion with a separate detail row", () => {
  it("atomically replaces a work with its tombstone and deletes its description", async () => {
    await deleteWork(event(undefined, true), work.workId);
    const txn = send.mock.calls.map(([cmd]) => cmd)
      .find((cmd) => cmd instanceof TransactWriteCommand) as TransactWriteCommand;
    expect(txn).toBeDefined();
    expect(txn.input.TransactItems?.[0].Put?.Item?.itemType).toBe("WORK_TOMBSTONE");
    expect(txn.input.TransactItems?.[1].Delete?.Key)
      .toEqual({ pk: "WORK#abcdefghijk", sk: "DETAIL" });
  });
});

describe("read-only, on-demand YouTube comments", () => {
  it("requests up to 20 threads without saving any comment text to DynamoDB", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        items: [{
          id: "thread",
          snippet: { totalReplyCount: 1,
            topLevelComment: { id: "comment", snippet: {
              authorDisplayName: "Reader", textDisplay: "Love this animation!",
              publishedAt: "2026-11-05T00:00:00Z",
            } },
          },
          replies: { comments: [{ id: "reply", snippet: {
            authorDisplayName: "Artist", textDisplay: "Thank you!",
          } }] },
        }],
        nextPageToken: "NEXT_PAGE",
      }),
    });
    vi.stubGlobal("fetch", fetchMock);
    const result = await getYoutubeComments(event(), work.workId);
    const data = JSON.parse(result.body ?? "{}");
    expect(data.comments).toHaveLength(1);
    expect(data.comments[0].text).toBe("Love this animation!");
    expect(data.comments[0].replies[0].text).toBe("Thank you!");
    expect(data.nextCursor).toBe("NEXT_PAGE");
    const url = new URL(fetchMock.mock.calls[0][0]);
    expect(url.searchParams.get("part")).toBe("snippet,replies");
    expect(url.searchParams.get("maxResults")).toBe("20");
    expect(url.searchParams.get("textFormat")).toBe("plainText");
    expect(send.mock.calls.every(([cmd]) => cmd instanceof GetCommand)).toBe(true);
  });

  it("does not contact YouTube for a hidden NIARIM work", async () => {
    send.mockResolvedValueOnce({ Item: { ...work, isNiarimPublished: false } });
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
    await expect(getYoutubeComments(event(), work.workId))
      .rejects.toMatchObject({ statusCode: 404 });
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
