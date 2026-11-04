import { beforeEach, describe, expect, it, vi } from "vitest";
import { BatchGetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
const { send } = vi.hoisted(() => ({send:vi.fn()}));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: {send},
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({niarimUserId:"Nowner",membershipTier:"free"})),
}));
import { getMyWorkMissionAchievements } from "../src/api/routes/creatorWorkAchievements";
const request = (cursor?: string) => ({
  headers: {authorization:"Bearer verified"},
  queryStringParameters:{...(cursor ? {cursor}:{}),niarimUserId:"Nattacker"},
}) as unknown as APIGatewayProxyEventV2;
const work = (workId: string, title: string, bookmarkCount: number) => ({
  itemType:"WORK",workId,title,bookmarkCount,authorId:"Nowner",
  isNiarimPublished:true,youtubePrivacyStatus:"public",
  gsi2pk:"BOOKMARK_RANKING",
});
beforeEach(()=>{
  process.env.TABLE_NAME="test-table";
  delete process.env.CREATOR_MISSION_CLAIMS_ENABLED;
  delete process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED;
  send.mockReset();
  send.mockResolvedValue({});
});
describe("manual, per-work mission achievement list",()=>{
  it("lists only achieved bookmark milestones without granting any coins",async()=>{
    send.mockImplementation(async(command:unknown)=>{
      if(command instanceof QueryCommand)return {Items:[
        work("abcdefghijk","My animation",123),
        work("lmnopqrstuv","Not yet",4),
        {...work("wxyzabcdefg","Another artist",150),authorId:"Nattacker"},
      ]};
      if(command instanceof BatchGetCommand)return {Responses:{"test-table":[{
        pk:"USER#Nowner",sk:"MISSION_WORK#abcdefghijk",
        itemType:"CREATOR_WORK_MISSIONS_V1",claimedMask:2**5,
      }]}};
      return {};
    });
    const result=await getMyWorkMissionAchievements(request());
    const body=JSON.parse(result.body??"{}");
    expect(body.rewardEnabled).toBe(false);
    expect(body.items).toHaveLength(3);
    expect(body.items.map((x:{required:number})=>x.required)).toEqual([10,50,100]);
    expect(body.items[0]).toMatchObject({workTitle:"My animation",
      claimed:true,workId:"abcdefghijk",missionId:"work_bookmarks_10"});
    expect(body.items[2]).toMatchObject({claimed:false,required:100,readyForClaim:true});
    expect(send.mock.calls.some(([c])=>c instanceof BatchGetCommand)).toBe(true);
    expect(send.mock.calls.every(([c])=>c instanceof QueryCommand ||
      c instanceof BatchGetCommand)).toBe(true);
    const q=send.mock.calls[0][0] as QueryCommand;
    expect(q.input.ExpressionAttributeValues?.[":author"]).toBe("AUTHOR#Nowner");
    expect(q.input.Limit).toBe(25);
  });
  it("restricts cursors to the logged-in author",async()=>{
    const forged=Buffer.from(JSON.stringify({
      pk:"WORK#abcdefghijk",sk:"META",gsi3pk:"AUTHOR#Nattacker",
      gsi3sk:"2026-11-01T00:00:00Z",
    })).toString("base64url");
    await expect(getMyWorkMissionAchievements(request(forged)))
      .rejects.toMatchObject({code:"WORK_MISSION_CURSOR_INVALID"});
    expect(send).not.toHaveBeenCalled();
  });
  it("returns server cursor for the next 25 works, without client reward writes",async()=>{
    const key={pk:"WORK#abcdefghijk",sk:"META",
      gsi3pk:"AUTHOR#Nowner",gsi3sk:"2026-11-01T00:00:00Z"};
    send.mockResolvedValueOnce({Items:[],LastEvaluatedKey:key});
    const result=await getMyWorkMissionAchievements(request());
    const body=JSON.parse(result.body??"{}");
    expect(JSON.parse(Buffer.from(body.nextCursor,"base64url").toString("utf8")))
      .toEqual(key);
    expect(body.items).toEqual([]);
    expect(send).toHaveBeenCalledTimes(1);
  });
});
