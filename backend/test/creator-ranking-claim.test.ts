import {beforeEach,describe,expect,it,vi} from "vitest";
import {BatchGetCommand,GetCommand,QueryCommand,TransactWriteCommand,UpdateCommand}
  from "@aws-sdk/lib-dynamodb";
import type {APIGatewayProxyEventV2} from "aws-lambda";
const {send}=vi.hoisted(()=>({send:vi.fn()}));
vi.mock("../src/lib/dynamo",async original=>({
  ...(await original<typeof import("../src/lib/dynamo")>()),ddb:{send},
}));
vi.mock("../src/lib/auth",()=>({
  authenticate:vi.fn(async()=>({niarimUserId:"Nowner"})),
}));
import {claimCreatorMission} from "../src/api/routes/creatorMissions";

const workId="abcdefghijk";
const work={
  pk:"WORK#"+workId,sk:"META",itemType:"WORK",workId,
  authorId:"Nowner",title:"ranked work",
  isNiarimPublished:true,youtubePrivacyStatus:"public",
  gsi2pk:"BOOKMARK_RANKING",gsi2sk:60,bookmarkCount:60,
};
const ev=(missionId:string)=>({
  headers:{authorization:"Bearer valid"},
  body:JSON.stringify({missionId,workId}),
}) as unknown as APIGatewayProxyEventV2;
const now=()=>Math.floor(Date.now()/1000);
const state=(overrides:Record<string,unknown>={})=>({
  itemType:"CREATOR_WORK_MISSIONS_V1",
  claimedMask:0,revision:1,totalMissionCoins:0,
  firstQualifiedAt:{},pendingCoins:{},claimedAt:{},
  ...overrides,
});
let current:Record<string,any>;
let population:number;
let rank:boolean;
let writes:unknown[];

beforeEach(()=>{
  process.env.TABLE_NAME="test";
  process.env.CREATOR_MISSION_CLAIMS_ENABLED="true";
  process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED="true";
  current=state();
  population=100;
  rank=true;
  writes=[];
  send.mockReset();
  send.mockImplementation(async cmd=>{
    if(cmd instanceof GetCommand){
      const key=cmd.input.Key;
      if(key?.pk==="WORK#"+workId)return {Item:work};
      if(key?.pk==="BATCHSTATE#STATS_UPDATE")
        return {Item:{publishedWorkCount:population}};
      if(key?.pk==="USER#Nowner" && key?.sk==="MISSION_WORK#"+workId)
        return {Item:current};
      return {};
    }
    if(cmd instanceof QueryCommand)
      return {Items:rank?[work]:[]};
    if(cmd instanceof BatchGetCommand)
      return {Responses:{test:rank?[work]:[]}};
    if(cmd instanceof UpdateCommand){
      writes.push(cmd);
      // Simulate the conditional state update on the first qualified rank.
      const expression=cmd.input.ExpressionAttributeValues ?? {};
      if(expression[":first"] && expression[":coins"]){
        current={...current,
          firstQualifiedAt:expression[":first"],
          pendingCoins:expression[":coins"],
          revision:current.revision+1};
      }
      return {};
    }
    if(cmd instanceof TransactWriteCommand){
      writes.push(cmd);
      const values=cmd.input.TransactItems?.[0].Update?.ExpressionAttributeValues;
      if(!values)throw Error("missing claim update");
      current={...current,
        claimedMask:values[":newMask"],
        totalMissionCoins:values[":total"],
        firstQualifiedAt:values[":pending"],
        pendingCoins:values[":pendingCoins"],
        revision:current.revision+1};
      return {};
    }
    throw Error("unexpected command");
  });
});
describe("live rankings are per-work, per-rank, and once-only",()=>{
  it("first observation starts a 48h hold but never credits coins",async()=>{
    const result=JSON.parse((await claimCreatorMission(ev("bookmark_rank_1"))).body??"{}");
    expect(result).toMatchObject({pending:true,claimed:false,
      offeredCoins:200,awardedCoins:0});
    expect(current.firstQualifiedAt["16"]).toBeGreaterThan(0);
    expect(writes.filter(w=>w instanceof TransactWriteCommand)).toHaveLength(0);
  });
  it("after a fresh live rank check, credits same work/rank only once",async()=>{
    current=state({
      revision:2,firstQualifiedAt:{"16":now()-3*86400},
      pendingCoins:{"16":200},
    });
    const first=JSON.parse((await claimCreatorMission(ev("bookmark_rank_1"))).body??"{}");
    expect(first).toMatchObject({claimed:true,awardedCoins:200});
    const tx=writes.find(w=>w instanceof TransactWriteCommand) as TransactWriteCommand;
    expect(tx.input.TransactItems?.[0].Update?.ExpressionAttributeValues?.[":newMask"])
      .toBe(2**16);
    expect(tx.input.TransactItems?.[1].Update?.ExpressionAttributeValues?.[":reward"])
      .toBe(200);
    const second=JSON.parse((await claimCreatorMission(ev("bookmark_rank_1"))).body??"{}");
    expect(second).toMatchObject({claimed:true,awardedCoins:0});
    expect(writes.filter(w=>w instanceof TransactWriteCommand)).toHaveLength(1);
    const otherTier=JSON.parse((await claimCreatorMission(ev("bookmark_rank_3"))).body??"{}");
    expect(otherTier).toMatchObject({pending:true,offeredCoins:125,awardedCoins:0});
    expect(current.firstQualifiedAt["15"]).toBeGreaterThan(0);
    expect(current.claimedMask).toBe(2**16);
  });
  it("does not give top-ten rewards just because there are 99 works",async()=>{
    population=99;
    await expect(claimCreatorMission(ev("bookmark_rank_10")))
      .rejects.toMatchObject({code:"MISSION_NOT_YET_COMPLETE"});
    expect(writes).toHaveLength(0);
    expect(send.mock.calls.some(([c])=>c instanceof QueryCommand)).toBe(false);
  });
  it("if ranking changes before the held reward, the hold is invalidated",async()=>{
    rank=false;
    current=state({
      firstQualifiedAt:{"16":now()-3*86400},
      pendingCoins:{"16":200},
    });
    await expect(claimCreatorMission(ev("bookmark_rank_1")))
      .rejects.toMatchObject({code:"MISSION_NOT_YET_COMPLETE"});
    expect(writes.filter(w=>w instanceof TransactWriteCommand)).toHaveLength(0);
    expect(current.firstQualifiedAt["16"]).toBeUndefined();
  });
});
