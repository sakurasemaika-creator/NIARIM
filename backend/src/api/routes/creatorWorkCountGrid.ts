import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { BatchGetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { ok } from "../../lib/response";
import { missionClaimed } from "../../lib/missionCatalog";
import {
  WORK_COUNT_GOALS,BOOKMARK_GOALS,WORK_COUNT_MISSIONS,
  ACCOUNT_GRID_CATALOG_VERSION,gridClaimsEnabled,
} from "../../lib/workCountMissionGrid";
import type { WorkItem } from "../../lib/types";

/**
 * Read-only work-count grid. 480 mission rows are computed from one bounded
 * author-index pass; NEVER 480 individual queries. Each shard's claimed mask
 * is read consistently. A GSI response is eventually consistent, so its
 * candidates are not proof of reward eligibility and never pay coins here.
 */
const PAGE_SIZE=25,MAX_PAGES=20;
const HOLD_SECONDS=48*3600;
export async function getMyWorkCountMissionGrid(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const table=tableName();
  const keys=WORK_COUNT_GOALS.map(count=>Keys.creatorGridShard(auth.niarimUserId,count));
  const statesPromise=ddb.send(new BatchGetCommand({
    RequestItems:{[table]:{Keys:keys,ConsistentRead:true}},
  }));
  const totals=new Map<number,number>(BOOKMARK_GOALS.map(x=>[x,0]));
  let cursor:Record<string,any>|undefined;
  let exhausted=false;
  let scanned=0;
  for(let i=0;i<MAX_PAGES;i++){
    const page=await ddb.send(new QueryCommand({
      TableName:table,IndexName:"GSI3",
      KeyConditionExpression:"gsi3pk = :author",
      ExpressionAttributeValues:{":author":`AUTHOR#${auth.niarimUserId}`},
      Limit:PAGE_SIZE,ExclusiveStartKey:cursor,
    }));
    for(const raw of page.Items??[]){
      const w=raw as WorkItem;
      if(w.itemType!=="WORK" || w.authorId!==auth.niarimUserId ||
        w.isNiarimPublished!==true ||
        w.youtubePrivacyStatus==="private" ||
        w.youtubePrivacyStatus==="deleted" ||
        w.gsi2pk!=="BOOKMARK_RANKING" ||
        !Number.isSafeInteger(w.bookmarkCount) || w.bookmarkCount<0)continue;
      scanned++;
      for(const threshold of BOOKMARK_GOALS){
        if(w.bookmarkCount>=threshold)totals.set(threshold,totals.get(threshold)!+1);
      }
    }
    cursor=page.LastEvaluatedKey;
    if(!cursor){exhausted=true;break;}
  }
  const stateResponse=await statesPromise;
  if((stateResponse.UnprocessedKeys?.[table]?.Keys?.length??0)>0){
    throw new Error("Unprocessed creator mission grid shards");
  }
  const shards=new Map<number,Record<string,unknown>>();
  for(const raw of stateResponse.Responses?.[table]??[]){
    const sk=raw.sk;
    if(raw.pk!==`USER#${auth.niarimUserId}` || typeof sk!=="string")continue;
    const workGoal=Number(sk.match(/^MISSION_GRID#([0-9]+)$/)?.[1]);
    if(!WORK_COUNT_GOALS.includes(workGoal) || raw.itemType!=="CREATOR_GRID_V1")
      continue;
    shards.set(workGoal,raw);
  }
  const now=Math.floor(Date.now()/1000);
  const missions=WORK_COUNT_MISSIONS.map(m=>{
    const count=totals.get(m.eachWorkBookmarks)??0;
    const record=shards.get(m.required);
    const mask=Number.isSafeInteger(record?.claimedMask) &&
      (record!.claimedMask as number)>=0 ? record!.claimedMask as number:0;
    const dates=record?.firstQualifiedAt;
    const pending=dates && typeof dates==="object" && !Array.isArray(dates)
      ?(dates as Record<string,unknown>)[String(m.bit)]:null;
    const pendingSince=typeof pending==="number" &&
      Number.isSafeInteger(pending)&&pending>0?pending:null;
    const claimed=missionClaimed(mask,m.bit);
    const eligible=count>=m.required?true:exhausted?false:null;
    const readyForClaim=eligible===true&&!claimed&&
      (pendingSince===null||now-pendingSince>=HOLD_SECONDS);
    return {
      ...m,claimed,progress:count,
      eligible,progressAuthoritative:false,
      pendingSince,readyForClaim,
      // Payout approval is independent from display-only eligibility.
      rewardEnabled:gridClaimsEnabled(),
    };
  });
  return ok({
    catalogVersion:ACCOUNT_GRID_CATALOG_VERSION,
    missions,scanned,complete:exhausted,
    readLimit:MAX_PAGES*PAGE_SIZE,
    rewardEnabled:gridClaimsEnabled(),
    authoritativeForRewards:false,
  });
}
