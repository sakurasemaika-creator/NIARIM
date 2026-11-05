import {beforeEach,describe,it,expect,vi} from "vitest";
import type {APIGatewayProxyEventV2} from "aws-lambda";
import {BatchGetCommand} from "@aws-sdk/lib-dynamodb";
const {send,scanWorks,scanGrid,record}=vi.hoisted(()=>({
 send:vi.fn(),scanWorks:vi.fn(),scanGrid:vi.fn(),record:vi.fn(),
}));
vi.mock("../src/lib/auth",()=>({
 authenticate:vi.fn(async()=>({niarimUserId:"Nowner"})),
}));
vi.mock("../src/lib/dynamo",async original=>({
 ...(await original<typeof import("../src/lib/dynamo")>()),ddb:{send},
}));
vi.mock("../src/api/routes/creatorWorkAchievements",()=>({
 getMyWorkMissionAchievements:scanWorks,
}));
vi.mock("../src/api/routes/creatorWorkCountGrid",()=>({
 getMyWorkCountMissionGrid:scanGrid,
}));
vi.mock("../src/lib/missionNotifications",async original=>({
 ...(await original<typeof import("../src/lib/missionNotifications")>()),
 recordMissionAchievement:record,
}));
import {syncMyMissionActivity} from "../src/api/routes/creatorMissionActivitySync";
beforeEach(()=>{
 process.env.TABLE_NAME="test";
 send.mockReset();send.mockResolvedValue({Responses:{test:[]}});
 scanWorks.mockReset();scanWorks.mockResolvedValue({body:JSON.stringify({
   items:[{
    missionId:"work_posted",workId:"abcdefghijk",
    workTitle:"First video",required:0,
    workPostedAt:"2026-11-05T00:00:00.000Z",
   }],nextCursor:null,
 })});
 scanGrid.mockReset();scanGrid.mockResolvedValue({body:JSON.stringify({
  missions:[{id:"works_3_x_0",required:3,eachWorkBookmarks:0,eligible:true}],
  complete:true,
 })});
 record.mockReset();record.mockResolvedValue(true);
});
const req=(body?:object)=>({
 headers:{authorization:"Bearer good"},body:JSON.stringify(body??{}),
 queryStringParameters:{niarimUserId:"Nattacker"},
}) as unknown as APIGatewayProxyEventV2;
describe("idempotent plaza mission activity sync",()=>{
 it("records publication date and observed-date cohort, never user counts",async()=>{
  const x=JSON.parse((await syncMyMissionActivity(req())).body??"{}");
  expect(x).toMatchObject({added:2,hadMore:false});
  expect(record).toHaveBeenCalledTimes(2);
  expect(record.mock.calls[0][0]).toBe("Nowner");
  expect(record.mock.calls[0][1]).toMatchObject({
    missionId:"work_posted",dateIsObserved:false,
    occurredAt:"2026-11-05T00:00:00.000Z",
  });
  expect(record.mock.calls[1][1]).toMatchObject({
    missionId:"works_3_x_0",dateIsObserved:true,
  });
  expect(send.mock.calls.every(([x])=>x instanceof BatchGetCommand))
   .toBe(true);
 });
 it("a request with work cursor skips expensive 480-row grid scan",async()=>{
  scanWorks.mockResolvedValueOnce({body:JSON.stringify({
   items:[],nextCursor:null,
  })});
  const data=JSON.parse((await syncMyMissionActivity(
   req({cursor:"encoded-cursor"}))).body??"{}");
  expect(data.added).toBe(0);
  expect(scanGrid).not.toHaveBeenCalled();
 });
 it("never emits an already recorded milestone",async()=>{
  send.mockResolvedValue({
   Responses:{test:[{
    pk:"USER#Nowner",itemType:"MISSION_NOTICE_DEDUPE_V1",
    eventId:"work_abcdefghijk_work_posted",
   }]},
  });
  const data=JSON.parse((await syncMyMissionActivity(req())).body??"{}");
  expect(data.added).toBe(1);
  expect(record.mock.calls.map((call:unknown[])=>
    (call[1] as {missionId:string}).missionId))
   .toEqual(["works_3_x_0"]);
 });
});
