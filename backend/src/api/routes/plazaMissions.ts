import { randomUUID } from "node:crypto";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { ConditionalCheckFailedException, TransactionCanceledException }
  from "@aws-sdk/client-dynamodb";
import { GetCommand, UpdateCommand, TransactWriteCommand }
  from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { parseJsonObject } from "../../lib/request";
import { badRequest, conflict, forbidden, ok } from "../../lib/response";
import { recurringPeriodKeys } from "../../lib/recurringMissionCatalog";
import {
  PLAZA_MISSIONS, PLAZA_MISSION_CATALOG_VERSION, PLAZA_MISSION_STATE_TYPE,
  normalizePlazaState, plazaProgress, advancePlazaPulse,
  plazaMissionEnabled,
} from "../../lib/plazaMissionCatalog";

async function load(userId:string) {
  const result=await ddb.send(new GetCommand({
    TableName:tableName(), Key:Keys.plazaMissionState(userId),
    ConsistentRead:true,
  }));
  if (result.Item?.itemType && result.Item.itemType!==PLAZA_MISSION_STATE_TYPE) {
    forbidden("作品広場ミッションの記録を確認できません", "PLAZA_STATE_INVALID");
  }
  return {raw:result.Item, state:normalizePlazaState(result.Item)};
}
function view(state:ReturnType<typeof normalizePlazaState>, now:Date) {
  const periods=recurringPeriodKeys(now);
  const enabled=plazaMissionEnabled();
  return {
    enabled,catalogVersion:PLAZA_MISSION_CATALOG_VERSION,
    resetTimeZone:"Asia/Tokyo",
    missions:PLAZA_MISSIONS.map(m=>{
      const progress=plazaProgress(state,m,periods);
      return {...m,...progress,
        ready:enabled && progress.eligible && !progress.claimed};
    }),
  };
}
export async function getMyPlazaMissions(event:APIGatewayProxyEventV2) {
  const auth=await authenticate(
    event.headers["authorization"]??event.headers["Authorization"]);
  const {state}=await load(auth.niarimUserId);
  return ok(view(state,new Date()));
}

/**
 * The client supplies a session nonce only. Never accept supplied seconds,
 * elapsed duration, target progress or coins. Server clock and a versioned
 * single-row update prevent replay and simultaneous-device inflation.
 */
export async function pulseMyPlazaMissions(event:APIGatewayProxyEventV2) {
  const auth=await authenticate(
    event.headers["authorization"]??event.headers["Authorization"]);
  const body=parseJsonObject(event.body);
  const sessionId=body.sessionId;
  if(typeof sessionId!=="string" || !/^[A-Za-z0-9_-]{20,96}$/.test(sessionId)) {
    badRequest("セッションIDが不正です", "PLAZA_SESSION_INVALID");
  }
  for(let attempt=0;attempt<4;attempt++) {
    const now=Date.now();
    const periods=recurringPeriodKeys(new Date(now));
    const {raw,state}=await load(auth.niarimUserId);
    // A second pulse inside one minute yields the existing state without
    // another paid DynamoDB write. A new session still starts immediately.
    if (state.sessionId === sessionId && now-state.lastPulseMs >= 0 &&
        now-state.lastPulseMs < 60000) {
      return ok({...view(state,new Date(now)),newlyAchieved:[]});
    }
    const next=advancePlazaPulse(state,sessionId,now,periods);
    const achieved=PLAZA_MISSIONS.filter(m=>
      !plazaProgress(state,m,periods).eligible &&
      plazaProgress(next,m,periods).eligible).map(m=>({
        id:m.id,period:m.period,requiredSeconds:m.requiredSeconds,coins:m.coins,
      }));
    const attrs:Record<string,string|number>={
      ":type":PLAZA_MISSION_STATE_TYPE,":next":next.version,
      ":dayKey":next.dayKey,":weekKey":next.weekKey,":monthKey":next.monthKey,
      ":daySeconds":next.daySeconds,":weekSeconds":next.weekSeconds,
      ":monthSeconds":next.monthSeconds,":dayMask":next.dayMask,
      ":weekMask":next.weekMask,":monthMask":next.monthMask,
      ":session":next.sessionId,":pulse":next.lastPulseMs,
      ...(raw ? {":old":state.version} : {}),
    };
    try {
      await ddb.send(new UpdateCommand({
        TableName:tableName(),Key:Keys.plazaMissionState(auth.niarimUserId),
        UpdateExpression:"SET itemType=:type, #version=:next, " +
          "dayKey=:dayKey, weekKey=:weekKey, monthKey=:monthKey, " +
          "daySeconds=:daySeconds, weekSeconds=:weekSeconds, " +
          "monthSeconds=:monthSeconds, dayMask=:dayMask, weekMask=:weekMask, " +
          "monthMask=:monthMask, sessionId=:session, lastPulseMs=:pulse",
        ConditionExpression:raw ? "#version=:old" :
          "attribute_not_exists(#version)",
        ExpressionAttributeNames:{"#version":"version"},
        ExpressionAttributeValues:attrs,
      }));
      return ok({...view(next,new Date(now)),newlyAchieved:achieved});
    } catch(error) {
      if(error instanceof ConditionalCheckFailedException) continue;
      throw error;
    }
  }
  conflict("別の端末の進捗更新と競合しました", "PLAZA_UPDATE_CONFLICT");
}

export async function claimMyPlazaMission(event:APIGatewayProxyEventV2) {
  const auth=await authenticate(
    event.headers["authorization"]??event.headers["Authorization"]);
  if(!plazaMissionEnabled())
    forbidden("作品広場ミッション報酬は準備中です","PLAZA_PAYOUT_DISABLED");
  const body=parseJsonObject(event.body);
  const mission=PLAZA_MISSIONS.find(m=>m.id===body.missionId);
  if(!mission)badRequest("不明なミッションです","PLAZA_MISSION_INVALID");
  const {state}=await load(auth.niarimUserId);
  const progress=plazaProgress(state,mission,recurringPeriodKeys());
  if(progress.claimed)return ok({
    claimed:true,duplicate:true,awardedCoins:0,missionId:mission.id,
  });
  if(!progress.eligible)conflict("達成条件を満たしていません","PLAZA_NOT_ELIGIBLE");
  const maskAttr=(mission.period+"Mask") as "dayMask"|"weekMask"|"monthMask";
  const keyAttr=mission.period+"Key";
  const secAttr=mission.period+"Seconds";
  const oldMask=state[maskAttr];
  const now=Date.now();
  try {
    await ddb.send(new TransactWriteCommand({TransactItems:[
      {Update:{
        TableName:tableName(),Key:Keys.plazaMissionState(auth.niarimUserId),
        UpdateExpression:"SET #mask=:next, #version=:newVersion",
        ConditionExpression:"itemType=:type AND #version=:version " +
          "AND #key=:period AND #seconds>=:required AND #mask=:oldMask",
        ExpressionAttributeNames:{
          "#mask":maskAttr,"#key":keyAttr,"#seconds":secAttr,
          "#version":"version",
        },
        ExpressionAttributeValues:{
          ":type":PLAZA_MISSION_STATE_TYPE,":next":oldMask+2**mission.bit,
          ":version":state.version,":newVersion":state.version+1,
          ":period":progress.periodKey,":required":mission.requiredSeconds,
          ":oldMask":oldMask,
        },
      }},
      {Update:{
        TableName:tableName(),Key:Keys.coinWallet(auth.niarimUserId),
        UpdateExpression:"SET itemType=:type ADD balanceCoins :coins, " +
          "missionEarnedCoins :coins",
        ConditionExpression:"(attribute_not_exists(itemType) OR itemType=:type) " +
          "AND (attribute_not_exists(balanceCoins) OR " +
          "balanceCoins BETWEEN :zero AND :max)",
        ExpressionAttributeValues:{
          ":type":"COIN_WALLET",":coins":mission.coins,
          ":zero":0,":max":Number.MAX_SAFE_INTEGER-mission.coins,
        },
      }},
      {Put:{
        TableName:tableName(),
        Item:{
          ...Keys.coinHistory(auth.niarimUserId,now,
            "plaza-"+mission.id+"-"+randomUUID()),
          itemType:"COIN_HISTORY",source:"plaza-mission",
          missionId:mission.id,periodKey:progress.periodKey,
          deltaCoins:mission.coins,occurredAtEpochMs:now,
        },
        ConditionExpression:"attribute_not_exists(pk)",
      }},
    ]}));
  }catch(error) {
    if(error instanceof TransactionCanceledException ||
      error instanceof ConditionalCheckFailedException) {
      const updated=(await load(auth.niarimUserId)).state;
      const refreshed=plazaProgress(updated,mission,recurringPeriodKeys());
      if(refreshed.claimed && refreshed.periodKey===progress.periodKey)
        return ok({claimed:true,duplicate:true,awardedCoins:0,missionId:mission.id});
      conflict("受取状態が更新されました","PLAZA_CLAIM_CONFLICT");
    }
    throw error;
  }
  return ok({claimed:true,duplicate:false,awardedCoins:mission.coins,
    missionId:mission.id});
}
