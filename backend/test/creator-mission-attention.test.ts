import { beforeEach, describe, expect, it, vi } from "vitest";
import { BatchGetCommand, GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
const { send, getUser } = vi.hoisted(() => ({
  send: vi.fn(), getUser: vi.fn(async () => ({ followerCount: 0 })),
}));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({niarimUserId:"Nowner"})),
  getUser,
}));
import { getMyCreatorMissionAttention } from "../src/api/routes/creatorMissionAttention";
import { PER_WORK_MISSIONS } from "../src/lib/missionCatalog";

const req = {
  headers: { authorization:"Bearer id-token" },
  queryStringParameters: { niarimUserId:"Nattacker" },
} as unknown as APIGatewayProxyEventV2;
const work = (id:string, n:number) => ({
  itemType:"WORK",workId:id,authorId:"Nowner",bookmarkCount:n,
  isNiarimPublished:true,youtubePrivacyStatus:"public",
  gsi2pk:"BOOKMARK_RANKING",
});
const ids=["abcdefghijk","lmnopqrstuv","wxyzabcdefg"];
beforeEach(()=>{
  process.env.TABLE_NAME="test";
  send.mockReset();send.mockResolvedValue({});
  getUser.mockReset();getUser.mockResolvedValue({followerCount:0});
});
describe("creator mission drawer attention is read-only and owner-bound",()=>{
  it("signals an unclaimed follower milestone without a work scan",async()=>{
    getUser.mockResolvedValue({followerCount:10});
    const data=JSON.parse((await getMyCreatorMissionAttention(req)).body??"{}");
    expect(data).toMatchObject({
      hasAchievedUnclaimed:true,source:"followers",complete:true,
    });
    expect(send.mock.calls.map(([c])=>c).every(c=>c instanceof GetCommand))
      .toBe(true);
  });
  it("flags a just-published work even with zero bookmarks",async()=>{
    send.mockImplementation(async(c:unknown)=>{
      if(c instanceof QueryCommand)return {Items:[work(ids[0],0)]};
      return {};
    });
    const data=JSON.parse((await getMyCreatorMissionAttention(req)).body??"{}");
    expect(data).toMatchObject({
      hasAchievedUnclaimed:true,source:"work",provisional:true,
    });
    const query=send.mock.calls.map(([c])=>c)
      .find(c=>c instanceof QueryCommand) as QueryCommand;
    expect(query.input.ExpressionAttributeValues?.[":author"]).toBe("AUTHOR#Nowner");
    expect(send.mock.calls.every(([c])=>
      c instanceof QueryCommand||c instanceof GetCommand||c instanceof BatchGetCommand))
      .toBe(true);
  });
  it("finds a 3-work posting milestone after individual posts were claimed",async()=>{
    const posted=PER_WORK_MISSIONS.find(m=>m.id==="work_posted")!;
    send.mockImplementation(async(c:unknown)=>{
      if(c instanceof QueryCommand)return {Items:ids.map(id=>work(id,0))};
      if(c instanceof BatchGetCommand && c.input.RequestItems?.test?.Keys
          ?.some(x=>typeof x.sk==="string" && x.sk.startsWith("MISSION_WORK#"))){
        return {Responses:{test:ids.map(id=>({
          pk:"USER#Nowner",sk:"MISSION_WORK#"+id,
          itemType:"CREATOR_WORK_MISSIONS_V1",claimedMask:2**posted.bit,
        }))}};
      }
      if(c instanceof BatchGetCommand)return {Responses:{test:[]}};
      return {};
    });
    const data=JSON.parse((await getMyCreatorMissionAttention(req)).body??"{}");
    expect(data).toMatchObject({
      hasAchievedUnclaimed:true,source:"works",complete:true,
    });
  });
  it("does not show a marker when the only posted-work bit is claimed",async()=>{
    const posted=PER_WORK_MISSIONS.find(m=>m.id==="work_posted")!;
    send.mockImplementation(async(c:unknown)=>{
      if(c instanceof QueryCommand)return {Items:[work(ids[0],0)]};
      if(c instanceof BatchGetCommand && c.input.RequestItems?.test?.Keys
          ?.some(x=>typeof x.sk==="string" && x.sk.startsWith("MISSION_WORK#"))){
        return {Responses:{test:[{
          pk:"USER#Nowner",sk:"MISSION_WORK#"+ids[0],
          itemType:"CREATOR_WORK_MISSIONS_V1",claimedMask:2**posted.bit,
        }]}};
      }
      if(c instanceof BatchGetCommand)return {Responses:{test:[]}};
      return {};
    });
    const data=JSON.parse((await getMyCreatorMissionAttention(req)).body??"{}");
    expect(data).toMatchObject({
      hasAchievedUnclaimed:false,source:"none",complete:true,
    });
  });
});
