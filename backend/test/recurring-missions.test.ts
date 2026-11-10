import { beforeEach, describe, expect, it, vi } from "vitest";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  ConditionalCheckFailedException, TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import { GetCommand, TransactWriteCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const {send} = vi.hoisted(() => ({send: vi.fn()}));
vi.mock("../src/lib/dynamo", async original => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb: {send},
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: vi.fn(async () => ({niarimUserId:"Nowner"})),
}));

import {
  RECURRING_MISSION_STATE_TYPE, RECURRING_MISSIONS,
  recurringPeriodKeys, recurringProgress, normalizeRecurringState,
} from "../src/lib/recurringMissionCatalog";
import {
  recordRecurringLoginVisit, getMyRecurringMissions, claimMyRecurringMission,
} from "../src/api/routes/recurringMissions";

const req = (body: object = {}) => ({
  headers: {authorization:"Bearer valid"},
  queryStringParameters: {userId:"Nattacker"},
  body:JSON.stringify(body),
}) as unknown as APIGatewayProxyEventV2;

beforeEach(() => {
  send.mockReset();
  send.mockResolvedValue({});
  process.env.TABLE_NAME="test";
  delete process.env.RECURRING_MISSION_PAYOUTS_ENABLED;
});

describe("JST recurring login mission catalog", () => {
  it("defines 3 weekly and 3 monthly non-cash offers", () => {
    expect(RECURRING_MISSIONS.filter(m => m.period === "week")).toHaveLength(3);
    expect(RECURRING_MISSIONS.filter(m => m.period === "month")).toHaveLength(3);
    expect(RECURRING_MISSIONS.every(m => m.coins > 0)).toBe(true);
  });
  it("switches JST days and weeks on Monday and months at midnight", () => {
    expect(recurringPeriodKeys(new Date("2026-11-08T14:59:59Z")))
      .toMatchObject({day:"2026-11-08",week:"2026-11-02",month:"2026-11"});
    expect(recurringPeriodKeys(new Date("2026-11-08T15:00:00Z")))
      .toMatchObject({day:"2026-11-09",week:"2026-11-09",month:"2026-11"});
    expect(recurringPeriodKeys(new Date("2026-11-30T15:00:00Z")))
      .toMatchObject({day:"2026-12-01",week:"2026-11-30",month:"2026-12"});
  });
  it("resets old masks outside current period instead of retaining claim", () => {
    const old = normalizeRecurringState({
      itemType: RECURRING_MISSION_STATE_TYPE,
      lastVisitedDay:"2026-10-31",weekKey:"2026-10-26",weekDays:6,
      weekClaimedMask:7,monthKey:"2026-10",monthDays:25,monthClaimedMask:7,
    });
    const newPeriod = recurringPeriodKeys(new Date("2026-11-10T03:00:00Z"));
    expect(recurringProgress(old,RECURRING_MISSIONS[0],newPeriod))
      .toMatchObject({progressDays:0,claimed:false});
    expect(recurringProgress(old,RECURRING_MISSIONS[3],newPeriod))
      .toMatchObject({progressDays:0,claimed:false});
  });
  it("records only one conditional server-side day, with no client time", async () => {
    await recordRecurringLoginVisit("Nowner");
    expect(send).toHaveBeenCalledTimes(2);
    expect(send.mock.calls[0][0]).toBeInstanceOf(GetCommand);
    const update = send.mock.calls[1][0] as UpdateCommand;
    expect(update.input.Key?.pk).toBe("USER#Nowner");
    expect(update.input.Key?.sk).toBe("RECURRING_MISSIONS_STATE_V1");
    expect(update.input.ConditionExpression).toContain("lastVisitedDay < :day");
    expect(update.input.ExpressionAttributeValues?.[":weekDays"]).toBe(1);
  });
  it("same-day repeat is read-only", async () => {
    send.mockResolvedValueOnce({Item:{
      itemType:RECURRING_MISSION_STATE_TYPE,
      lastVisitedDay:recurringPeriodKeys().day,
    }});
    await recordRecurringLoginVisit("Nowner");
    expect(send).toHaveBeenCalledTimes(1);
  });
  it("concurrent coin claim never loses its claimed bit during daily visit", async () => {
    const period=recurringPeriodKeys();
    const previous={itemType:RECURRING_MISSION_STATE_TYPE,
      lastVisitedDay:"2026-01-01",weekKey:period.week,weekDays:2,
      weekClaimedMask:0,monthKey:period.month,monthDays:4,monthClaimedMask:0};
    send.mockResolvedValueOnce({Item:previous})
      .mockRejectedValueOnce(new ConditionalCheckFailedException({
        $metadata:{},message:"coin claim race",
      }))
      .mockResolvedValueOnce({Item:{...previous,weekClaimedMask:1}})
      .mockResolvedValueOnce({});
    await expect(recordRecurringLoginVisit("Nowner")).resolves.toBeUndefined();
    expect(send).toHaveBeenCalledTimes(4);
    const retry=send.mock.calls[3][0] as UpdateCommand;
    expect(retry.input.ExpressionAttributeValues?.[":weekMask"]).toBe(1);
    expect(retry.input.ConditionExpression).toContain("weekClaimedMask = :oldWeekMask");
    expect(retry.input.ConditionExpression).toContain("monthClaimedMask = :oldMonthMask");
  });
  it("GET returns account-scoped status and never credits coins", async () => {
    const period=recurringPeriodKeys();
    send.mockResolvedValueOnce({Item:{
      itemType:RECURRING_MISSION_STATE_TYPE,
      weekKey:period.week,weekDays:5,weekClaimedMask:1,
      monthKey:period.month,monthDays:10,monthClaimedMask:0,
    }});
    const result=JSON.parse((await getMyRecurringMissions(req())).body??"{}");
    expect(result.enabled).toBe(false);
    expect(result.missions.find((m:{id:string})=>m.id==="visit_week_3"))
      .toMatchObject({eligible:true,claimed:true});
    expect(result.missions.find((m:{id:string})=>m.id==="visit_month_10"))
      .toMatchObject({eligible:true,claimed:false,ready:false});
    expect(send).toHaveBeenCalledTimes(1);
    expect(send.mock.calls[0][0]).toBeInstanceOf(GetCommand);
  });
  it("claim is blocked before independent operator approval", async () => {
    await expect(claimMyRecurringMission(req({missionId:"visit_week_3"})))
      .rejects.toMatchObject({code:"RECURRING_PAYOUT_DISABLED"});
    expect(send).not.toHaveBeenCalled();
  });
  it("approved claim sends one atomic state+wallet+journal transaction", async () => {
    process.env.RECURRING_MISSION_PAYOUTS_ENABLED="true";
    const period=recurringPeriodKeys();
    send.mockResolvedValueOnce({Item:{
      itemType:RECURRING_MISSION_STATE_TYPE,
      weekKey:period.week,weekDays:3,weekClaimedMask:0,
      monthKey:period.month,monthDays:4,monthClaimedMask:0,
    }});
    const result=JSON.parse((await claimMyRecurringMission(
      req({missionId:"visit_week_3",coins:999999,days:999,owner:"Nattacker"})))
      .body??"{}");
    expect(result).toMatchObject({claimed:true,awardedCoins:15});
    const transaction=send.mock.calls[1][0] as TransactWriteCommand;
    expect(transaction).toBeInstanceOf(TransactWriteCommand);
    const [state,wallet,journal]=transaction.input.TransactItems!;
    expect(state.Update?.Key?.pk).toBe("USER#Nowner");
    expect(state.Update?.ConditionExpression).toContain("#days >= :required");
    expect(state.Update?.ExpressionAttributeValues?.[":required"]).toBe(3);
    expect(wallet.Update?.ExpressionAttributeValues?.[":coins"]).toBe(15);
    expect(journal.Put?.Item?.deltaCoins).toBe(15);
  });
  it("already claimed is a zero-coin idempotent no-write response", async () => {
    process.env.RECURRING_MISSION_PAYOUTS_ENABLED="true";
    const period=recurringPeriodKeys();
    send.mockResolvedValueOnce({Item:{
      itemType:RECURRING_MISSION_STATE_TYPE,
      weekKey:period.week,weekDays:3,weekClaimedMask:1,
    }});
    const result=JSON.parse((await claimMyRecurringMission(
      req({missionId:"visit_week_3"}))).body??"{}");
    expect(result).toMatchObject({claimed:true,duplicate:true,awardedCoins:0});
    expect(send).toHaveBeenCalledTimes(1);
  });
  it("transaction race re-reads state and reports duplicate without double credit", async () => {
    process.env.RECURRING_MISSION_PAYOUTS_ENABLED="true";
    const period=recurringPeriodKeys();
    const state={itemType:RECURRING_MISSION_STATE_TYPE,
      weekKey:period.week,weekDays:3,weekClaimedMask:0};
    send.mockResolvedValueOnce({Item:state})
      .mockRejectedValueOnce(new TransactionCanceledException({
        $metadata:{},message:"already credited",
      }))
      .mockResolvedValueOnce({Item:{...state,weekClaimedMask:1}});
    const result=JSON.parse((await claimMyRecurringMission(
      req({missionId:"visit_week_3"}))).body??"{}");
    expect(result).toMatchObject({claimed:true,duplicate:true,awardedCoins:0});
    expect(send).toHaveBeenCalledTimes(3);
  });
});
