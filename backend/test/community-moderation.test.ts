import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { describe, expect, it, vi, beforeEach } from "vitest";

const { send, authenticate, getUser, reserveReportQuota } = vi.hoisted(() => ({
  send: vi.fn(), authenticate: vi.fn(), getUser: vi.fn(), reserveReportQuota: vi.fn(),
}));
vi.mock("../src/lib/auth", () => ({ authenticate, getUser }));
vi.mock("../src/lib/reportQuota", () => ({ reserveReportQuota }));

import { ddb } from "../src/lib/dynamo";
import { TABLE_ITEM_TYPE } from "../src/lib/types";
import { blockedFromViewer, createBlock, deleteBlock, getMyBlocks } from "../src/api/routes/blocks";
import { getLatestWorks } from "../src/api/routes/worksLatest";
import { createReport } from "../src/api/routes/reports";

vi.spyOn(ddb, "send").mockImplementation(send);
const viewer = "N" + "a".repeat(32);
const other = "N" + "b".repeat(32);
const unrelated = "N" + "c".repeat(32);
const workId = "X".repeat(11);

function event(body?: Record<string, unknown>, signedIn = true) {
  return {
    headers: signedIn ? { authorization: "mock" } : {},
    body: body && JSON.stringify(body),
    queryStringParameters: {},
  } as APIGatewayProxyEventV2;
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.stubEnv("TABLE_NAME", "moderation-test");
  authenticate.mockResolvedValue({ niarimUserId: viewer });
});

describe("community moderation", () => {
  it("blocks and unblocks both views atomically without writing a notification", async () => {
    send.mockResolvedValueOnce({ Item: { itemType: TABLE_ITEM_TYPE.User } });
    send.mockResolvedValueOnce({});
    await createBlock(event({ blockedUserId: other }));
    const operations = send.mock.calls[1][0].input.TransactItems;
    const writes = operations.filter((item: { Put?: unknown }) => item.Put);
    expect(writes).toHaveLength(2);
    expect(writes.map(({ Put }: { Put: { Item: Record<string, unknown> } }) => Put.Item)).toEqual([
      expect.objectContaining({ pk: "USER#" + viewer, sk: "BLOCK#" + other }),
      expect.objectContaining({ pk: "USER#" + other, sk: "BLOCKED_BY#" + viewer }),
    ]);
    send.mockResolvedValueOnce({});
    await deleteBlock(event(), other);
    expect(send.mock.calls[2][0].input.TransactItems).toHaveLength(2);
  });

  it("uses inbound blocks internally without showing callers who blocked them", async () => {
    const incoming = { itemType: TABLE_ITEM_TYPE.Block, blockerId: other, blockedId: viewer };
    send.mockResolvedValueOnce({ Items: [incoming] });
    expect(await blockedFromViewer(event())).toEqual(new Set([other]));
    expect(send.mock.calls[0][0].input.ConsistentRead).toBe(true);

    send.mockResolvedValueOnce({ Items: [] });
    const response = await getMyBlocks(event());
    expect(JSON.parse(response.body!).blockedUserIds).toEqual([]);
    expect(await blockedFromViewer(event(undefined, false))).toEqual(new Set());
  });

  it("omits posts from a blocked creator and hides moderation-stopped posts without changing the author's settings", async () => {
    const publicWork = {
      itemType: TABLE_ITEM_TYPE.Work,
      workId,
      authorId: other,
      isNiarimPublished: true,
      youtubePrivacyStatus: "public",
      title: "published",
    };
    const hidden = { ...publicWork, workId: "Y".repeat(11), authorId: unrelated, moderationHidden: true };
    const visible = { ...publicWork, workId: "Z".repeat(11), authorId: unrelated };
    send
      .mockResolvedValueOnce({ Items: [{ itemType: TABLE_ITEM_TYPE.Block, blockerId: other, blockedId: viewer }] })
      .mockResolvedValueOnce({ Items: [publicWork, hidden, visible] })
      .mockResolvedValueOnce({ Responses: { "moderation-test": [publicWork, hidden, visible] } });
    const response = await getLatestWorks(event());
    expect(JSON.parse(response.body!).works.map((work: { workId: string }) => work.workId)).toEqual([visible.workId]);
    expect(hidden.isNiarimPublished).toBe(true);
  });

  it("stores a private pending report for a valid creator or public work", async () => {
    getUser.mockResolvedValueOnce({ itemType: TABLE_ITEM_TYPE.User });
    reserveReportQuota.mockResolvedValue(undefined);
    send.mockResolvedValueOnce({});
    await createReport(event({ authorId: other, reason: "  example  " }));
    expect(send.mock.calls[0][0].input.TransactItems.at(-1).Put.Item).toMatchObject({
      targetId: other, pk: "USER#" + other, reporterId: viewer,
      reason: "example", status: "pending", gsi7pk: "REPORT_STATUS#pending",
    });
    send.mockResolvedValueOnce({ Item: {
      itemType: TABLE_ITEM_TYPE.Work, workId, isNiarimPublished: false,
      authorId: other, youtubePrivacyStatus: "public",
    } });
    await expect(createReport(event({ workId, reason: "example" }))).rejects.toMatchObject({ statusCode: 404 });
    expect(reserveReportQuota).toHaveBeenCalledTimes(1);
  });
});
