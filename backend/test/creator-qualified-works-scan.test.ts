import { beforeEach, describe, expect, it, vi } from "vitest";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { GetCommand, PutCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()), ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({ niarimUserId: "NactualOwner" })),
}));
import { scanMyQualifiedWorks } from "../src/api/routes/creatorQualifiedWorksScan";

const request = (body?: object) => ({
  headers: { authorization: "Bearer verified" },
  body: body === undefined ? undefined : JSON.stringify(body),
  queryStringParameters: { niarimUserId: "Nattacker" },
}) as unknown as APIGatewayProxyEventV2;
const work = (bookmarkCount: number, authorId = "NactualOwner") => ({
  itemType: "WORK", authorId, isNiarimPublished: true,
  youtubePrivacyStatus: "public", gsi2pk: "BOOKMARK_RANKING",
  bookmarkCount,
});
beforeEach(() => {
  process.env.TABLE_NAME = "test-table";
  delete process.env.CREATOR_QUALIFIED_WORK_SCAN_ENABLED;
  send.mockReset();
  send.mockResolvedValue({});
});
describe("bounded per-author candidate scans", () => {
  it("does not read DB until explicitly enabled", async () => {
    await expect(scanMyQualifiedWorks(request()))
      .rejects.toMatchObject({code: "MISSION_SCAN_DISABLED"});
    expect(send).not.toHaveBeenCalled();
  });
  it("does not accept client progress or client owner identities", async () => {
    process.env.CREATOR_QUALIFIED_WORK_SCAN_ENABLED = "true";
    send.mockImplementation(async (command: unknown) => {
      if (command instanceof GetCommand) return {};
      if (command instanceof QueryCommand) return {
        Items: [work(10), work(20), work(500, "Nattacker"), work(9)],
      };
      return {};
    });
    const response = await scanMyQualifiedWorks(request({
      processedWorks: 99999, worksWith20Bookmarks: 9999,
    }));
    const body = JSON.parse(response.body ?? "{}");
    expect(body).toMatchObject({
      processedWorks: 4, worksWith10Bookmarks: 2,
      worksWith20Bookmarks: 1, scanComplete: true,
      authoritativeForRewards: false, provisional: true,
      pagesScanned: 1,
    });
    const query = send.mock.calls.map(([x])=>x)
      .find(x=>x instanceof QueryCommand) as QueryCommand;
    expect(query.input.ExpressionAttributeValues?.[":author"])
      .toBe("AUTHOR#NactualOwner");
    const put = send.mock.calls.map(([x])=>x)
      .find(x=>x instanceof PutCommand) as PutCommand;
    expect(put.input.Item?.pk).toBe("USER#NactualOwner");
    expect(put.input.Item?.revision).toBe(1);
  });
  it("resumes the server cursor and version under an atomic compare", async () => {
    process.env.CREATOR_QUALIFIED_WORK_SCAN_ENABLED = "true";
    const started = Date.now() - 60000;
    const cursor = {pk: "WORK#aaaaaaaaaaa", sk:"META", gsi3pk:"AUTHOR#NactualOwner",gsi3sk:"2026-10-01"};
    const old = {
      pk: "USER#NactualOwner", sk:"MISSION_QUALIFIED_WORK_SCAN_V1",
      itemType:"MISSION_QUALIFIED_WORK_SCAN_V1", revision: 7,
      startedAtEpochMs: started, updatedAtEpochMs: started,
      processedWorks: 500, worksWith10Bookmarks: 80,
      worksWith20Bookmarks: 17, cursor, scanComplete: false,
    };
    send.mockImplementation(async (cmd: unknown) => {
      if (cmd instanceof GetCommand) return {Item: old};
      if (cmd instanceof QueryCommand) return {Items: [work(20), work(15)]};
      return {};
    });
    const body = JSON.parse((await scanMyQualifiedWorks(request())).body ?? "{}");
    expect(body).toMatchObject({processedWorks:502,worksWith10Bookmarks:82,
      worksWith20Bookmarks:18,scanComplete:true});
    const query = send.mock.calls.map(([x])=>x)
      .find(x=>x instanceof QueryCommand) as QueryCommand;
    expect(query.input.ExclusiveStartKey).toEqual(cursor);
    const put = send.mock.calls.map(([x])=>x)
      .find(x=>x instanceof PutCommand) as PutCommand;
    expect(put.input.ConditionExpression).toContain("revision = :revision");
    expect(put.input.ExpressionAttributeValues?.[":revision"]).toBe(7);
    expect(put.input.Item?.cursor).toBeUndefined();
  });
  it("never scans more than 8 pages within one 10-second Lambda request", async () => {
    process.env.CREATOR_QUALIFIED_WORK_SCAN_ENABLED = "true";
    let page = 0;
    send.mockImplementation(async (cmd: unknown) => {
      if (cmd instanceof GetCommand) return {};
      if (cmd instanceof QueryCommand) {
        page++;
        return {Items:Array.from({length:25},()=>work(20)),
          LastEvaluatedKey:{pk:`WORK#${page}`,sk:"META"}};
      }
      return {};
    });
    const body = JSON.parse((await scanMyQualifiedWorks(request())).body ?? "{}");
    expect(body).toMatchObject({processedWorks:200,worksWith20Bookmarks:200,
      scanComplete:false,pagesScanned:8,morePages:true});
    expect(page).toBe(8);
    expect(send.mock.calls.filter(([c])=>c instanceof PutCommand)).toHaveLength(1);
  });
  it("requires an explicit restart for completed current scans", async () => {
    process.env.CREATOR_QUALIFIED_WORK_SCAN_ENABLED = "true";
    const stamp = Date.now();
    send.mockResolvedValueOnce({Item:{
      pk:"USER#NactualOwner",sk:"MISSION_QUALIFIED_WORK_SCAN_V1",
      itemType:"MISSION_QUALIFIED_WORK_SCAN_V1",revision:11,
      startedAtEpochMs:stamp,updatedAtEpochMs:stamp,
      processedWorks:11000,worksWith10Bookmarks:10070,
      worksWith20Bookmarks:10001,scanComplete:true,
    }});
    const out=JSON.parse((await scanMyQualifiedWorks(request())).body??"{}");
    expect(out).toMatchObject({processedWorks:11000,
      worksWith20Bookmarks:10001,scanComplete:true,unchanged:true,
      authoritativeForRewards:false});
    expect(send).toHaveBeenCalledTimes(1);
  });
});
