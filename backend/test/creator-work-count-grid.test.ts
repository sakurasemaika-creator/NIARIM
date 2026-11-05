import {beforeEach,describe,it,expect,vi} from "vitest";
import {BatchGetCommand,QueryCommand} from "@aws-sdk/lib-dynamodb";
import type {APIGatewayProxyEventV2} from "aws-lambda";
const {send}=vi.hoisted(()=>({send:vi.fn()}));
vi.mock("../src/lib/dynamo",async(original)=>({
  ...(await original<typeof import("../src/lib/dynamo")>()),ddb:{send},
}));
vi.mock("../src/lib/auth",()=>({
  authenticate:vi.fn(async()=>({niarimUserId:"Nowner"})),
}));
import {getMyWorkCountMissionGrid} from "../src/api/routes/creatorWorkCountGrid";
const req={headers:{authorization:"Bearer good"}} as unknown as APIGatewayProxyEventV2;
const work=(count:number)=>({itemType:"WORK",authorId:"Nowner",bookmarkCount:count,
  isNiarimPublished:true,youtubePrivacyStatus:"public",gsi2pk:"BOOKMARK_RANKING"});
beforeEach(()=>{
 process.env.TABLE_NAME="test";send.mockReset();send.mockResolvedValue({});
});
describe("work-count grid display",()=>{
 it("calculates 480 rows from one bounded author scan, never pays coins",async()=>{
   send.mockImplementation(async(cmd:unknown)=>{
     if(cmd instanceof BatchGetCommand)return {Responses:{"test":[{
       pk:"USER#Nowner",sk:"MISSION_GRID#3",itemType:"CREATOR_GRID_V1",
       claimedMask:2,firstQualifiedAt:{},
     }]}};
     if(cmd instanceof QueryCommand)return {Items:[work(0),work(10),work(20)]};
     return {};
   });
   const r=await getMyWorkCountMissionGrid(req);const data=JSON.parse(r.body??"{}");
   expect(data.missions).toHaveLength(480);
   expect(data).toMatchObject({complete:true,scanned:3,rewardEnabled:false});
   expect(data.missions.find((m:{id:string})=>m.id==="works_3_x_0"))
    .toMatchObject({eligible:true,claimed:false,readyForClaim:true});
   expect(data.missions.find((m:{id:string})=>m.id==="works_3_x_10"))
    .toMatchObject({eligible:false,claimed:true});
   expect(send.mock.calls.map(([cmd])=>cmd).every(c=>
     c instanceof QueryCommand||c instanceof BatchGetCommand)).toBe(true);
   const q=send.mock.calls.map(([c])=>c).find(c=>c instanceof QueryCommand) as QueryCommand;
   expect(q.input.ExpressionAttributeValues?.[":author"]).toBe("AUTHOR#Nowner");
 });
 it("marks thresholds above an unfinished 500-work page limit as unknown",async()=>{
   send.mockImplementation(async(cmd:unknown)=>{
     if(cmd instanceof BatchGetCommand)return {};
     if(cmd instanceof QueryCommand)return {Items:[work(0)],
        LastEvaluatedKey:{pk:"WORK#abcdefghijk",sk:"META"}};
     return {};
   });
   const data=JSON.parse((await getMyWorkCountMissionGrid(req)).body??"{}");
   expect(data).toMatchObject({complete:false,readLimit:500});
   expect(data.missions.find((m:{id:string})=>m.id==="works_500_x_1000"))
    .toMatchObject({eligible:null,progressAuthoritative:false});
   expect(send.mock.calls.filter(([c])=>c instanceof QueryCommand)).toHaveLength(20);
 });
});
