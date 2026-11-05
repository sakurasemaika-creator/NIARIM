import { describe, expect, it, vi, beforeEach } from "vitest";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
const {send} = vi.hoisted(() => ({send:vi.fn()}));
vi.mock("../src/lib/dynamo", async (original) => ({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb:{send},
}));
import {
  missionEventId, recordMissionAchievement,
} from "../src/lib/missionNotifications";
const post={
  kind:"workPublished" as const,missionId:"work_posted",
  workId:"abcdefghijk",workTitle:"My first video",
  required:0,occurredAt:"2026-11-05T00:00:00.000Z",
};
beforeEach(()=>{
  process.env.TABLE_NAME="test";
  send.mockReset();send.mockResolvedValue({});
});
describe("durable mission bell notices",()=>{
  it("stores one user-bound ordered event plus an immutable dedupe marker",async()=>{
    expect(await recordMissionAchievement("Nowner",post)).toBe(true);
    const tx=send.mock.calls[0][0] as TransactWriteCommand;
    expect(tx).toBeInstanceOf(TransactWriteCommand);
    expect(tx.input.TransactItems).toHaveLength(2);
    const [marker,activity]=tx.input.TransactItems!;
    expect(marker.Put?.Item?.pk).toBe("USER#Nowner");
    expect(marker.Put?.Item?.sk).toBe("MISSION_NOTICE_KEY#work_abcdefghijk_work_posted");
    expect(marker.Put?.ConditionExpression).toBe("attribute_not_exists(pk)");
    expect(activity.Put?.Item?.sk).toMatch(/^MISSION_ACTIVITY#[0-9]{13}#work_/);
    expect(activity.Put?.Item?.occurredAt).toBe("2026-11-05T00:00:00.000Z");
    expect(activity.Put?.Item?.targetRoute).toBe("/creator-missions");
  });
  it("returns false for a previously committed event without minting coins",async()=>{
    send.mockImplementation(async(command:unknown)=>{
      if (command instanceof TransactWriteCommand) {
        throw new TransactionCanceledException({
          $metadata:{},message:"Duplicate marker",
        });
      }
      if (command instanceof GetCommand)return {Item:{
        itemType:"MISSION_NOTICE_DEDUPE_V1",
        eventId:"work_abcdefghijk_work_posted",
      }};
      return {};
    });
    expect(await recordMissionAchievement("Nowner",post)).toBe(false);
    expect(send).toHaveBeenCalledTimes(2);
  });
  it("does not swallow an unrelated transaction failure",async()=>{
    send.mockImplementation(async(command:unknown)=>{
      if(command instanceof TransactWriteCommand)
        throw new TransactionCanceledException({
          $metadata:{},message:"Canceled for another reason",
        });
      return {};
    });
    await expect(recordMissionAchievement("Nowner",post)).rejects
      .toBeInstanceOf(TransactionCanceledException);
  });
  it("won't accept a notification without a valid server work ID",()=>{
    expect(()=>missionEventId({...post,workId:"!!!"})).toThrow();
  });
});
