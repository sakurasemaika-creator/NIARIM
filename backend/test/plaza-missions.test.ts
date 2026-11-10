import {beforeEach,describe,expect,it,vi} from "vitest";
import type {APIGatewayProxyEventV2} from "aws-lambda";
import {ConditionalCheckFailedException} from "@aws-sdk/client-dynamodb";
import {GetCommand,TransactWriteCommand,UpdateCommand}
  from "@aws-sdk/lib-dynamodb";

const {send}=vi.hoisted(()=>({send:vi.fn()}));
vi.mock("../src/lib/dynamo",async original=>({
  ...(await original<typeof import("../src/lib/dynamo")>()),ddb:{send},
}));
vi.mock("../src/lib/auth",()=>({
  authenticate:vi.fn(async()=>({niarimUserId:"Nverified"})),
}));
import {
  PLAZA_MISSIONS,PLAZA_MISSION_STATE_TYPE,
  advancePlazaPulse,plazaProgress,defaultPlazaState,
} from "../src/lib/plazaMissionCatalog";
import {recurringPeriodKeys} from "../src/lib/recurringMissionCatalog";
import {
  getMyPlazaMissions,pulseMyPlazaMissions,claimMyPlazaMission,
} from "../src/api/routes/plazaMissions";

const session="v_abcdefghijklmnopqrstuv0123456789";
const req=(body:object={})=>({
  headers:{authorization:"Bearer valid"},
  body:JSON.stringify(body),
}) as unknown as APIGatewayProxyEventV2;
const period=()=>recurringPeriodKeys();
beforeEach(()=>{
  send.mockReset();
  send.mockResolvedValue({});
  process.env.TABLE_NAME="test";
  delete process.env.PLAZA_MISSION_PAYOUTS_ENABLED;
});

describe("plaza open-time low-value missions",()=>{
  it("has a bounded daily weekly and monthly catalogue",()=>{
    expect(PLAZA_MISSIONS).toHaveLength(10);
    expect(PLAZA_MISSIONS.filter(m=>m.period==="day")).toHaveLength(4);
    expect(PLAZA_MISSIONS.every(m=>m.coins>=1&&m.coins<=8)).toBe(true);
    expect(new Set(PLAZA_MISSIONS.map(m=>m.id)).size).toBe(10);
  });
  it("does not count a client-supplied duration or first heartbeat",async()=>{
    const result=JSON.parse((await pulseMyPlazaMissions(req({
      sessionId:session,seconds:999999,coins:1000000,
    }))).body??"{}");
    expect(result.newlyAchieved).toEqual([]);
    expect(send).toHaveBeenCalledTimes(2);
    const write=send.mock.calls[1][0] as UpdateCommand;
    expect(write.input.Key?.sk).toBe("PLAZA_MISSIONS_STATE_V1");
    expect(write.input.ExpressionAttributeValues?.[":daySeconds"]).toBe(0);
    expect(write.input.ExpressionAttributeValues?.[":session"]).toBe(session);
    expect(write.input.ConditionExpression).toContain("attribute_not_exists");
  });
  it("counts only a server-clock minute and ignores idle gaps",()=>{
    const now=Date.now(),p=period();
    const original={...defaultPlazaState(),sessionId:session,
      lastPulseMs:now-60000,dayKey:p.day,weekKey:p.week,monthKey:p.month};
    const after=advancePlazaPulse(original,session,now,p);
    expect(after.daySeconds).toBe(60);
    expect(after.weekSeconds).toBe(60);
    expect(after.monthSeconds).toBe(60);
    expect(advancePlazaPulse(original,session,now+600000,p).daySeconds).toBe(0);
    expect(advancePlazaPulse(original,session+"n",now,p).daySeconds).toBe(0);
    expect(plazaProgress({...after,daySeconds:300},PLAZA_MISSIONS[0],p)
      .eligible).toBe(true);
  });
  it("never lets a GET write a wallet or claim a prize",async()=>{
    const data=JSON.parse((await getMyPlazaMissions(req())).body??"{}");
    expect(data.enabled).toBe(false);
    expect(data.missions).toHaveLength(10);
    expect(send).toHaveBeenCalledTimes(1);
    expect(send.mock.calls[0][0]).toBeInstanceOf(GetCommand);
  });
  it("requires an independently approved payout switch",async()=>{
    await expect(claimMyPlazaMission(req({
      missionId:"plaza_day_5m",
    }))).rejects.toMatchObject({code:"PLAZA_PAYOUT_DISABLED"});
    expect(send).not.toHaveBeenCalled();
  });
  it("atomically credits an earned milestone just once",async()=>{
    process.env.PLAZA_MISSION_PAYOUTS_ENABLED="true";
    const p=period();
    send.mockResolvedValueOnce({Item:{
      itemType:PLAZA_MISSION_STATE_TYPE,
      version:4,dayKey:p.day,daySeconds:300,
      dayMask:0,weekKey:p.week,monthKey:p.month,
    }});
    const data=JSON.parse((await claimMyPlazaMission(req({
      missionId:"plaza_day_5m",coins:123456,
    }))).body??"{}");
    expect(data).toMatchObject({claimed:true,awardedCoins:1});
    const tx=send.mock.calls[1][0] as TransactWriteCommand;
    expect(tx).toBeInstanceOf(TransactWriteCommand);
    const [mark,wallet,history]=tx.input.TransactItems!;
    expect(mark.Update?.ExpressionAttributeValues?.[":newVersion"]).toBe(5);
    expect(wallet.Update?.ExpressionAttributeValues?.[":coins"]).toBe(1);
    expect(history.Put?.Item?.deltaCoins).toBe(1);
  });
  it("rejects repeat claims without a wallet write",async()=>{
    process.env.PLAZA_MISSION_PAYOUTS_ENABLED="true";
    const p=period();
    send.mockResolvedValueOnce({Item:{
      itemType:PLAZA_MISSION_STATE_TYPE,version:4,
      dayKey:p.day,daySeconds:300,dayMask:1,
    }});
    const data=JSON.parse((await claimMyPlazaMission(req({
      missionId:"plaza_day_5m",
    }))).body??"{}");
    expect(data).toMatchObject({claimed:true,duplicate:true,awardedCoins:0});
    expect(send).toHaveBeenCalledTimes(1);
  });
  it("retries concurrent heartbeats without overwriting claimed masks",async()=>{
    send.mockResolvedValueOnce({Item:undefined})
      .mockRejectedValueOnce(new ConditionalCheckFailedException({
        $metadata:{},message:"race",
      }))
      .mockResolvedValueOnce({Item:{
        itemType:PLAZA_MISSION_STATE_TYPE,version:1,dayMask:1,
      }}).mockResolvedValueOnce({});
    await pulseMyPlazaMissions(req({sessionId:session}));
    const update=send.mock.calls[3][0] as UpdateCommand;
    expect(update.input.ExpressionAttributeValues?.[":dayMask"]).toBe(0);
    expect(update.input.ExpressionAttributeValues?.[":old"]).toBe(1);
    // Previous bit was for an old day; reset is intentional.
  });
});
