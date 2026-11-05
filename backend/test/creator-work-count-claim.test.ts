import {beforeEach,describe,it,expect,vi} from "vitest";
import {BatchGetCommand,GetCommand,QueryCommand,TransactWriteCommand,UpdateCommand} from "@aws-sdk/lib-dynamodb";
import {TransactionCanceledException} from "@aws-sdk/client-dynamodb";
const {send}=vi.hoisted(()=>({send:vi.fn()}));
vi.mock("../src/lib/dynamo",async(original)=>({
  ...(await original<typeof import("../src/lib/dynamo")>()),ddb:{send},
}));
import {claimWorkCountMission} from "../src/api/routes/creatorWorkCountClaim";
import {workCountMissionById} from "../src/lib/workCountMissionGrid";
const mission=workCountMissionById("works_3_x_0")!;
const legacy=workCountMissionById("works_3_x_10")!;
const work=(n:number)=>({
  pk:`WORK#video00000${n}`,sk:"META",itemType:"WORK",
  authorId:"Nowner",isNiarimPublished:true,
  youtubePrivacyStatus:"public",gsi2pk:"BOOKMARK_RANKING",
  bookmarkCount:0,workId:`video00000${n}`,
});
beforeEach(()=>{
  process.env.TABLE_NAME="test";
  for(const name of ["CREATOR_MISSION_CLAIMS_ENABLED",
    "CREATOR_MISSION_CLAIMS_REVIEW_APPROVED","CREATOR_GRID_PAYOUTS_ENABLED",
    "CREATOR_GRID_REWARDS_REVIEW_APPROVED"])delete process.env[name];
  send.mockReset();send.mockResolvedValue({});
});
function enable(){
  process.env.CREATOR_MISSION_CLAIMS_ENABLED="true";
  process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED="true";
  process.env.CREATOR_GRID_PAYOUTS_ENABLED="true";
  process.env.CREATOR_GRID_REWARDS_REVIEW_APPROVED="true";
}
function eligibleSend(state?:Record<string,unknown>){
  send.mockImplementation(async(cmd:unknown)=>{
    if(cmd instanceof GetCommand && cmd.input.Key?.sk==="MISSION_GRID#3")
      return state?{Item:state}:{};
    if(cmd instanceof GetCommand)return {};
    if(cmd instanceof QueryCommand)return {Items:[work(1),work(2),work(3)]};
    if(cmd instanceof BatchGetCommand)return {Responses:{"test":[work(1),work(2),work(3)]}};
    return {};
  });
}
describe("manual grid coin claims remain independent of legacy reward toggles",()=>{
 it("denies any payout until two independent new approvals are enabled",async()=>{
   process.env.CREATOR_MISSION_CLAIMS_ENABLED="true";
   process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED="true";
   await expect(claimWorkCountMission("Nowner",mission))
    .rejects.toMatchObject({code:"MISSION_GRID_REWARDS_DISABLED"});
   expect(send).not.toHaveBeenCalled();
 });
 it("first tap starts a hold without crediting coins and stores a shard mask",async()=>{
   enable();eligibleSend();
   const result=await claimWorkCountMission("Nowner",mission);
   expect(JSON.parse(result.body??"{}")).toMatchObject({pending:true,awardedCoins:0});
   const write=send.mock.calls.map(([x])=>x).find(x=>x instanceof UpdateCommand) as UpdateCommand;
   expect(write.input.Key?.sk).toBe("MISSION_GRID#3");
   expect(write.input.ExpressionAttributeValues?.[":coins"]).toMatchObject({
     "0":mission.coins,
   });
   expect(send.mock.calls.some(([x])=>x instanceof TransactWriteCommand)).toBe(false);
 });
 it("after hold pays once and writes account shard, wallet and history together",async()=>{
   enable();
   const old=Math.floor(Date.now()/1000)-49*3600;
   eligibleSend({itemType:"CREATOR_GRID_V1",revision:4,claimedMask:0,
     totalMissionCoins:0,firstQualifiedAt:{"0":old},
     pendingCoins:{"0":mission.coins}});
   const result=await claimWorkCountMission("Nowner",mission);
   expect(JSON.parse(result.body??"{}")).toMatchObject({
     claimed:true,awardedCoins:mission.coins,
   });
   const tx=send.mock.calls.map(([x])=>x)
      .find(x=>x instanceof TransactWriteCommand) as TransactWriteCommand;
   expect(tx.input.TransactItems).toHaveLength(3);
   expect(tx.input.TransactItems?.[0].Update?.Key?.sk).toBe("MISSION_GRID#3");
   expect(tx.input.TransactItems?.[1].Update?.Key?.sk).toBe("COIN_WALLET");
   expect(tx.input.TransactItems?.[2].Put?.Item?.source).toBe("creator-grid");
   expect(tx.input.TransactItems?.[0].Update
     ?.ExpressionAttributeValues?.[":newMask"]).toBe(1);
 });
 it("claimed bit alone makes retries harmless with no further reads",async()=>{
   enable();eligibleSend({itemType:"CREATOR_GRID_V1",revision:4,
     claimedMask:1,totalMissionCoins:mission.coins});
   const result=await claimWorkCountMission("Nowner",mission);
   expect(JSON.parse(result.body??"{}")).toMatchObject({
     claimed:true,awardedCoins:0,
   });
   expect(send.mock.calls.every(([c])=>c instanceof GetCommand)).toBe(true);
 });
 it("blocks a previously claimed legacy cross-goal from being paid twice",async()=>{
   enable();
   send.mockImplementation(async(cmd:unknown)=>{
     if(cmd instanceof GetCommand && cmd.input.Key?.sk==="MISSION_STATE_V1")
       return {Item:{itemType:"CREATOR_MISSIONS_V1",claimedMask:2**8}};
     return {};
   });
   const result=await claimWorkCountMission("Nowner",legacy);
   expect(JSON.parse(result.body??"{}")).toMatchObject({
     claimed:true,awardedCoins:0,
   });
   expect(send.mock.calls.every(([c])=>c instanceof GetCommand)).toBe(true);
 });
 it("cannot pay if strong work reads invalidate the GSI's candidate works",async()=>{
   enable();
   send.mockImplementation(async(cmd:unknown)=>{
     if(cmd instanceof GetCommand)return {};
     if(cmd instanceof QueryCommand)return {Items:[work(1),work(2),work(3)]};
     if(cmd instanceof BatchGetCommand)return {Responses:{"test":[
       work(1),{...work(2),isNiarimPublished:false},work(3),
     ]}};
     return {};
   });
   await expect(claimWorkCountMission("Nowner",mission))
     .rejects.toMatchObject({code:"MISSION_NOT_YET_COMPLETE"});
   expect(send.mock.calls.some(([c])=>c instanceof UpdateCommand||
     c instanceof TransactWriteCommand)).toBe(false);
 });
 it("transaction conflict never awards partial wallet coins",async()=>{
   enable();const old=Math.floor(Date.now()/1000)-49*3600;
   eligibleSend({itemType:"CREATOR_GRID_V1",revision:4,claimedMask:0,
     totalMissionCoins:0,firstQualifiedAt:{"0":old},
     pendingCoins:{"0":mission.coins}});
   const previous=send.getMockImplementation()!;
   send.mockImplementation(async(cmd:unknown)=>{
     if(cmd instanceof TransactWriteCommand)throw new TransactionCanceledException({
       $metadata:{},message:"revision changed",
     });
     return previous(cmd);
   });
   await expect(claimWorkCountMission("Nowner",mission))
     .rejects.toMatchObject({code:"MISSION_GRID_STATE_CHANGED"});
 });
});
