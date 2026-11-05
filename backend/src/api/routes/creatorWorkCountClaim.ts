import {ConditionalCheckFailedException,TransactionCanceledException} from "@aws-sdk/client-dynamodb";
import {BatchGetCommand,GetCommand,QueryCommand,TransactWriteCommand,UpdateCommand} from "@aws-sdk/lib-dynamodb";
import {ddb,Keys,tableName} from "../../lib/dynamo";
import {conflict,forbidden,ok} from "../../lib/response";
import {
  ACCOUNT_GRID_CATALOG_VERSION,WORK_COUNT_MISSIONS,
  LEGACY_GRID_BITS,gridClaimsEnabled,type GridMission,
} from "../../lib/workCountMissionGrid";
import {claimMissionInMask,missionClaimed} from "../../lib/missionCatalog";
import type {WorkItem} from "../../lib/types";
import {randomUUID} from "node:crypto";

/**
 * Server-only, manual and once-per-account grid claims.
 * A completed author-index scan is NOT trusted as reward proof. Before
 * starting a hold or paying, re-read the candidate works from the base table
 * using strongly consistent BatchGet. The resulting 500-work upper bound is
 * intentional; if it cannot prove achievement, fail closed.
 *
 * Concurrent work changes cannot be atomically rechecked across 500 works
 * in a DynamoDB transaction. Hence the v3 payout flags remain OFF pending
 * a production consistency review, even if legacy claims are approved.
 */
const PAGE_SIZE=25,MAX_PAGES=20,HOLD_SECONDS=48*3600;
async function validatedCount(userId:string, mission:GridMission):Promise<number>{
  const table=tableName();
  const ids:string[]=[];
  let cursor:Record<string,any>|undefined;
  for(let i=0;i<MAX_PAGES;i++){
    const page=await ddb.send(new QueryCommand({
      TableName:table,IndexName:"GSI3",
      KeyConditionExpression:"gsi3pk = :author",
      ExpressionAttributeValues:{":author":`AUTHOR#${userId}`},
      Limit:PAGE_SIZE,ExclusiveStartKey:cursor,
    }));
    for(const raw of page.Items??[]){
      const w=raw as WorkItem;
      if(w.itemType==="WORK" && w.authorId===userId &&
        typeof w.workId==="string" &&
        /^[A-Za-z0-9_-]{11}$/.test(w.workId) &&
        w.isNiarimPublished===true &&
        w.youtubePrivacyStatus!=="private" &&
        w.youtubePrivacyStatus!=="deleted" &&
        w.gsi2pk==="BOOKMARK_RANKING" &&
        Number.isSafeInteger(w.bookmarkCount) &&
        w.bookmarkCount>=mission.eachWorkBookmarks){
        ids.push(w.workId);
      }
    }
    if(ids.length>=mission.required)break;
    cursor=page.LastEvaluatedKey;
    if(!cursor)break;
  }
  if(ids.length<mission.required)return 0;
  const unique=[...new Set(ids)];
  let count=0;
  for(let start=0;start<unique.length;start+=100){
    const batch=unique.slice(start,start+100);
    const result=await ddb.send(new BatchGetCommand({
      RequestItems:{[table]:{
        Keys:batch.map(id=>Keys.work(id)),ConsistentRead:true,
      }},
    }));
    if((result.UnprocessedKeys?.[table]?.Keys?.length??0)>0){
      forbidden("作品の検証を完了できません", "MISSION_GRID_VERIFICATION_RETRY");
    }
    for(const raw of result.Responses?.[table]??[]){
      if(raw.itemType==="WORK" && raw.authorId===userId &&
        raw.isNiarimPublished===true &&
        raw.youtubePrivacyStatus!=="private" &&
        raw.youtubePrivacyStatus!=="deleted" &&
        raw.gsi2pk==="BOOKMARK_RANKING" &&
        Number.isSafeInteger(raw.bookmarkCount) &&
        raw.bookmarkCount>=mission.eachWorkBookmarks){
        count++;
      }
    }
  }
  return count;
}
type State={claimedMask:number,revision:number,totalMissionCoins:number,
  firstQualifiedAt:Record<string,number>,pendingCoins:Record<string,number>,
  claimedAt:Record<string,number>};
function normDates(raw:unknown):Record<string,number>{
  if(!raw||typeof raw!=="object"||Array.isArray(raw))return {};
  const result:Record<string,number>={};
  for(let bit=0;bit<24;bit++){
    const n=(raw as Record<string,unknown>)[String(bit)];
    if(typeof n==="number" && Number.isSafeInteger(n) && n>0)result[String(bit)]=n;
  }
  return result;
}
function normalize(raw:Record<string,unknown>|undefined):State{
  if(raw && raw.itemType!=="CREATOR_GRID_V1"){
    forbidden("ミッション履歴の形式を再検証してください","MISSION_GRID_STATE_INVALID");
  }
  function value(x:unknown){
    if(typeof x!=="number" || !Number.isSafeInteger(x) || x<0){
      forbidden("ミッションの数値状態が不正です","MISSION_GRID_STATE_INVALID");
    }
    return x;
  }
  return {
    claimedMask:raw?value(raw.claimedMask):0,
    revision:raw?value(raw.revision):0,
    totalMissionCoins:raw?value(raw.totalMissionCoins):0,
    firstQualifiedAt:normDates(raw?.firstQualifiedAt),
    pendingCoins:normDates(raw?.pendingCoins),
    claimedAt:normDates(raw?.claimedAt),
  };
}
function retryError(error:unknown):never{
  if(error instanceof TransactionCanceledException ||
      error instanceof ConditionalCheckFailedException){
    conflict("達成状態が更新されました。再読み込みしてください","MISSION_GRID_STATE_CHANGED");
  }
  throw error;
}
export async function claimWorkCountMission(userId:string,mission:GridMission){
  if(!gridClaimsEnabled()){
    forbidden("作品数ミッションの報酬は審査中です","MISSION_GRID_REWARDS_DISABLED");
  }
  const table=tableName();
  const key=Keys.creatorGridShard(userId,mission.required);
  const [stateResult,old]=await Promise.all([
    ddb.send(new GetCommand({TableName:table,Key:key,ConsistentRead:true})),
    ddb.send(new GetCommand({
      TableName:table,Key:Keys.creatorMissionState(userId),ConsistentRead:true,
    })),
  ]);
  const state=normalize(stateResult.Item as Record<string,unknown>|undefined);
  const oldBit=LEGACY_GRID_BITS[mission.id];
  if(oldBit!==undefined && Number.isSafeInteger(old.Item?.claimedMask) &&
      missionClaimed(old.Item!.claimedMask,oldBit)){
    return ok({missionId:mission.id,claimed:true,awardedCoins:0});
  }
  if(missionClaimed(state.claimedMask,mission.bit)){
    return ok({missionId:mission.id,claimed:true,awardedCoins:0});
  }
  if((await validatedCount(userId,mission))<mission.required){
    conflict("達成条件を確認できません","MISSION_NOT_YET_COMPLETE");
  }
  const nowSec=Math.floor(Date.now()/1000);
  const bitKey=String(mission.bit);
  const first=state.firstQualifiedAt[bitKey];
  const offered=state.pendingCoins[bitKey];
  if(!first || first>nowSec){
    const firstQualifiedAt={...state.firstQualifiedAt,[bitKey]:nowSec};
    const pendingCoins={...state.pendingCoins,[bitKey]:mission.coins};
    try{
      await ddb.send(new UpdateCommand({
        TableName:table,Key:key,
        UpdateExpression:
          "SET itemType = :type, catalogVersion = :catalog, " +
          "claimedMask = if_not_exists(claimedMask,:zero), " +
          "totalMissionCoins = if_not_exists(totalMissionCoins,:zero), " +
          "firstQualifiedAt = :first, pendingCoins = :coins ADD revision :one",
        ConditionExpression:
          "attribute_not_exists(pk) OR " +
          "(itemType = :type AND revision = :rev AND claimedMask = :mask)",
        ExpressionAttributeValues:{
          ":type":"CREATOR_GRID_V1",":catalog":ACCOUNT_GRID_CATALOG_VERSION,
          ":zero":0,":one":1,":rev":state.revision,":mask":state.claimedMask,
          ":first":firstQualifiedAt,":coins":pendingCoins,
        },
      }));
    }catch(e){retryError(e);}
    return ok({missionId:mission.id,claimed:false,pending:true,
      offeredCoins:mission.coins,awardedCoins:0,
      readyAt:(nowSec+HOLD_SECONDS)*1000});
  }
  if(nowSec-first<HOLD_SECONDS)return ok({
    missionId:mission.id,claimed:false,pending:true,awardedCoins:0,
    offeredCoins:offered??0,readyAt:(first+HOLD_SECONDS)*1000,
  });
  if(!Number.isSafeInteger(offered) || offered<=0 || offered>100_000){
    forbidden("報酬の再確認が必要です","MISSION_GRID_OFFER_MISSING");
  }
  const shardBudget=WORK_COUNT_MISSIONS.filter(m=>m.required===mission.required)
    .reduce((sum,m)=>sum+m.coins,0);
  const total=state.totalMissionCoins+offered;
  if(!Number.isSafeInteger(total)||total>shardBudget){
    forbidden("報酬の累計が不正です","MISSION_GRID_BUDGET");
  }
  const claimedAt={...state.claimedAt,[bitKey]:nowSec};
  const firstQualifiedAt={...state.firstQualifiedAt};
  const pendingCoins={...state.pendingCoins};
  delete firstQualifiedAt[bitKey];delete pendingCoins[bitKey];
  const now=Date.now();
  try{
    await ddb.send(new TransactWriteCommand({
      TransactItems:[
        {Update:{
          TableName:table,Key:key,
          UpdateExpression:
            "SET claimedMask = :newMask, totalMissionCoins = :total, " +
            "claimedAt = :claimedAt, firstQualifiedAt = :first, " +
            "pendingCoins = :coins ADD revision :one",
          ConditionExpression:"itemType = :type AND revision = :rev AND claimedMask = :oldMask",
          ExpressionAttributeValues:{
            ":type":"CREATOR_GRID_V1",":rev":state.revision,
            ":oldMask":state.claimedMask,
            ":newMask":claimMissionInMask(state.claimedMask,mission.bit),
            ":total":total,":claimedAt":claimedAt,":first":firstQualifiedAt,
            ":coins":pendingCoins,":one":1,
          },
        }},
        {Update:{
          TableName:table,Key:Keys.coinWallet(userId),
          UpdateExpression:"SET itemType = :type ADD balanceCoins :reward, missionEarnedCoins :reward",
          ConditionExpression:
            "(attribute_not_exists(itemType) OR itemType = :type) AND " +
            "(attribute_not_exists(balanceCoins) OR balanceCoins BETWEEN :zero AND :limit)",
          ExpressionAttributeValues:{
            ":type":"COIN_WALLET",":reward":offered,
            ":zero":0,":limit":Number.MAX_SAFE_INTEGER-offered,
          },
        }},
        {Put:{
          TableName:table,
          Item:{
            ...Keys.coinHistory(userId,now,`grid-${mission.id}-${randomUUID()}`),
            itemType:"COIN_HISTORY",source:"creator-grid",
            deltaCoins:offered,missionId:mission.id,
            occurredAtEpochMs:now,
          },
          ConditionExpression:"attribute_not_exists(pk)",
        }},
      ],
    }));
  }catch(e){retryError(e);}
  return ok({missionId:mission.id,claimed:true,awardedCoins:offered});
}
