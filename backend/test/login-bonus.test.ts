import { beforeEach,describe,expect,it,vi } from "vitest";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { ConditionalCheckFailedException,TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { BatchGetCommand,GetCommand,TransactWriteCommand,UpdateCommand } from "@aws-sdk/lib-dynamodb";
const {send}=vi.hoisted(()=>({send:vi.fn()}));
vi.mock("../src/lib/dynamo",async original=>({
  ...(await original<typeof import("../src/lib/dynamo")>()),ddb:{send},
}));
vi.mock("../src/lib/auth",()=>({
  authenticate:vi.fn(async()=>({niarimUserId:"Nowner"})),
}));
import {
  visitMyLoginBonus,getMyLoginBonus,claimMyLoginBonus,
} from "../src/api/routes/loginBonus";
import {
  DAILY_LOGIN_COINS,LOGIN_BONUS_MILESTONES,milestoneCoins,jstLoginDay,
} from "../src/lib/loginBonusCatalog";

const req=(body?:object)=>({
  headers:{authorization:"Bearer valid"},
  queryStringParameters:{userId:"Nattacker"},
  body:JSON.stringify(body??{}),
}) as unknown as APIGatewayProxyEventV2;
const state={itemType:"LOGIN_BONUS_STATE_V1",
 totalDays:100,lastVisitedDay:jstLoginDay(),lastClaimedDay:"2020-01-01"};
function enable(){
 process.env.LOGIN_BONUS_CLAIMS_ENABLED="true";
 process.env.LOGIN_BONUS_REWARDS_REVIEW_APPROVED="true";
}
beforeEach(()=>{
 process.env.TABLE_NAME="test";
 delete process.env.LOGIN_BONUS_CLAIMS_ENABLED;
 delete process.env.LOGIN_BONUS_REWARDS_REVIEW_APPROVED;
 send.mockReset();
 send.mockResolvedValue({});
});
describe("cumulative login bonus and non-streak earning",()=>{
 it("switches calendar day at midnight Japan time",()=>{
  expect(jstLoginDay(Date.parse("2026-11-04T14:59:59Z"))).toBe("2026-11-04");
  expect(jstLoginDay(Date.parse("2026-11-04T15:00:00Z"))).toBe("2026-11-05");
 });
 it("uses the specified five milestone ranges with extra round-number prizes",()=>{
  expect(DAILY_LOGIN_COINS).toBe(1);
  expect(LOGIN_BONUS_MILESTONES).toHaveLength(54);
  expect(LOGIN_BONUS_MILESTONES[0]).toMatchObject({days:5,coins:5});
  expect(milestoneCoins(50)).toBe(10);
  expect(milestoneCoins(100)).toBe(15);
  expect(milestoneCoins(500)).toBe(25);
  expect(milestoneCoins(1000)).toBe(40);
  expect(milestoneCoins(3600)).toBe(40);
  expect(milestoneCoins(51)).toBeUndefined();
 });
 it("visit increments only a distinct server-side day and never mints",async()=>{
  send.mockResolvedValueOnce({Attributes:{
    itemType:"LOGIN_BONUS_STATE_V1",totalDays:4,
    lastVisitedDay:jstLoginDay(),
  }});
  const result=JSON.parse((await visitMyLoginBonus(req())).body??"{}");
  expect(result).toMatchObject({totalDays:4,visitedToday:true});
  const c=send.mock.calls[0][0] as UpdateCommand;
  expect(c).toBeInstanceOf(UpdateCommand);
  expect(c.input.Key?.pk).toBe("USER#Nowner");
  expect(c.input.Key?.sk).toBe("LOGIN_BONUS_STATE");
  expect(c.input.ConditionExpression).toContain("lastVisitedDay < :day");
  // Daily login is still one conditional write. The new weekly/monthly
  // counter adds one account-state read and at most one conditional write.
  expect(send).toHaveBeenCalledTimes(3);
  expect(send.mock.calls[1][0]).toBeInstanceOf(GetCommand);
  const recurring = send.mock.calls[2][0] as UpdateCommand;
  expect(recurring).toBeInstanceOf(UpdateCommand);
  expect(recurring.input.Key?.sk).toBe("RECURRING_MISSIONS_STATE_V1");
  expect(recurring.input.ConditionExpression).toContain("lastVisitedDay < :day");
 });
 it("repeat same-day visit is read-only, never increments twice",async()=>{
  send.mockRejectedValueOnce(new ConditionalCheckFailedException({
    $metadata:{},message:"already visited",
  })).mockResolvedValueOnce({Item:state});
  const result=JSON.parse((await visitMyLoginBonus(req())).body??"{}");
  expect(result).toMatchObject({totalDays:100,visitedToday:true});
  expect(send.mock.calls[1][0]).toBeInstanceOf(GetCommand);
 });
 it("shows only authenticated owner's claimed milestones",async()=>{
  send.mockImplementation(async c=>{
    if(c instanceof GetCommand)return {Item:state};
    if(c instanceof BatchGetCommand)return {Responses:{test:[{
      pk:"USER#Nowner",sk:"LOGIN_BONUS_MILESTONE#50",
      itemType:"LOGIN_BONUS_MILESTONE_V1",days:50,
    }]}};
    return {};
  });
  const result=JSON.parse((await getMyLoginBonus(req())).body??"{}");
  expect(result).toMatchObject({
    totalDays:100,dailyClaimed:false,rewardEnabled:false,
  });
  expect(result.milestones.find((m:{days:number})=>m.days===50))
    .toMatchObject({eligible:true,claimed:true});
  expect(result.milestones.find((m:{days:number})=>m.days===150))
    .toMatchObject({eligible:false,claimed:false});
 });
 it("denies any payout without independent double approval",async()=>{
  await expect(claimMyLoginBonus(req({kind:"daily"})))
    .rejects.toMatchObject({code:"LOGIN_BONUS_PAYOUTS_DISABLED"});
  expect(send).not.toHaveBeenCalled();
 });
 it("daily claim atomically marks the date and credits one coin exactly once",async()=>{
  enable();
  const result=JSON.parse((await claimMyLoginBonus(req({kind:"daily"}))).body??"{}");
  expect(result).toMatchObject({claimed:true,awardedCoins:1});
  const transaction=send.mock.calls[0][0] as TransactWriteCommand;
  expect(transaction).toBeInstanceOf(TransactWriteCommand);
  expect(transaction.input.TransactItems).toHaveLength(3);
  const [claim,wallet,history]=transaction.input.TransactItems!;
  expect(claim.Update?.ConditionExpression).toContain("lastClaimedDay <> :day");
  expect(claim.Update?.Key?.pk).toBe("USER#Nowner");
  expect(wallet.Update?.Key?.sk).toBe("COIN_WALLET");
  expect(history.Put?.Item?.source).toBe("login-bonus");
  expect(history.Put?.Item?.deltaCoins).toBe(1);
 });
 it("milestone uses an immutable per-goal claim marker, wallet and history",async()=>{
  enable();
  const result=JSON.parse((await claimMyLoginBonus(
    req({kind:"milestone",days:100}))).body??"{}");
  expect(result).toMatchObject({claimed:true,awardedCoins:15,days:100});
  const transaction=send.mock.calls[0][0] as TransactWriteCommand;
  expect(transaction.input.TransactItems).toHaveLength(4);
  expect(transaction.input.TransactItems?.[0].ConditionCheck?.ConditionExpression)
    .toContain("totalDays >= :days");
  expect(transaction.input.TransactItems?.[1].Put?.Item?.sk)
    .toBe("LOGIN_BONUS_MILESTONE#100");
  expect(transaction.input.TransactItems?.[1].Put?.ConditionExpression)
    .toBe("attribute_not_exists(pk)");
  expect(transaction.input.TransactItems?.[2].Update?.Key?.sk).toBe("COIN_WALLET");
 });
 it("concurrent duplicate claim never credits after transaction canceled",async()=>{
  enable();
  send.mockRejectedValueOnce(new TransactionCanceledException({
    $metadata:{},message:"already claimed",
  }));
  await expect(claimMyLoginBonus(req({kind:"daily"})))
    .rejects.toMatchObject({
      code:"LOGIN_BONUS_ALREADY_CLAIMED_OR_NOT_ELIGIBLE",
    });
 });
 it("rejects arbitrary client-controlled milestones",async()=>{
  enable();
  await expect(claimMyLoginBonus(req({kind:"milestone",days:51})))
    .rejects.toMatchObject({code:"LOGIN_BONUS_INVALID_GOAL"});
  expect(send).not.toHaveBeenCalled();
 });
});
