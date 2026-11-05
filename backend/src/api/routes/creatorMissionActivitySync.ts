import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { BatchGetCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { badRequest, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import {
  missionEventId, recordMissionAchievement,
  type MissionAchievement,
} from "../../lib/missionNotifications";
import { getMyWorkMissionAchievements } from "./creatorWorkAchievements";
import { getMyWorkCountMissionGrid } from "./creatorWorkCountGrid";

/**
 * On-demand backfill and discovery on opening the plaza bell.
 *
 *  - Reads are server owned. A client can't send counts or coin awards.
 *  - Only 25 authored works and bounded grid scan per invocation.
 *  - Up to 12 work and 12 account notices are persisted per call.
 *  - The GSI does not represent an exact-time snapshot. Notifications for
 *    historical milestones use the date FIRST OBSERVED by the scanner.
 *  - Manual mission claim + wallet transaction remain entirely separate.
 *  - Duplicate events never create extra rows (permanent dedupe marker).
 */
const WORK_WRITE_LIMIT=12;
const GRID_WRITE_LIMIT=12;
type Candidate = MissionAchievement;
function parseResponse(body: string | undefined): Record<string, any> {
  const data=JSON.parse(body??"{}");
  if(!data || typeof data!=="object" || Array.isArray(data)) {
    throw new Error("Invalid internal mission response");
  }
  return data;
}
function chunks<T>(input:T[],size:number):T[][] {
  const pages:T[][]=[];
  for(let i=0;i<input.length;i+=size)pages.push(input.slice(i,i+size));
  return pages;
}
function validDate(value:unknown):value is string {
  return typeof value==="string" &&
    Number.isSafeInteger(Date.parse(value)) && Date.parse(value)>0 &&
    Date.parse(value)<=Date.now()+86_400_000;
}
async function keepUnseen(userId:string, entries:Candidate[]):Promise<Candidate[]>{
  const ids=[...new Set(entries.map(missionEventId))];
  const table=tableName();
  const pages=await Promise.all(chunks(ids,100).map(async idsPage=>{
    const result=await ddb.send(new BatchGetCommand({
      RequestItems:{[table]:{Keys:idsPage.map(id=>
        Keys.missionNoticeDedupe(userId,id)),ConsistentRead:true}},
    }));
    if((result.UnprocessedKeys?.[table]?.Keys?.length??0)>0){
      throw new Error("Unprocessed mission notification dedupe reads");
    }
    return result.Responses?.[table]??[];
  }));
  const seen=new Set<string>();
  for(const page of pages){
    for(const x of page) {
      if(x.pk===`USER#${userId}` &&
        x.itemType==="MISSION_NOTICE_DEDUPE_V1" &&
        typeof x.eventId==="string")seen.add(x.eventId);
    }
  }
  return entries.filter(x=>!seen.has(missionEventId(x)));
}
export async function syncMyMissionActivity(event:APIGatewayProxyEventV2){
  const auth=await authenticate(
    event.headers["authorization"]??event.headers["Authorization"],
  );
  const body=parseJsonObject(event.body,{allowEmpty:true});
  if(body.cursor!==undefined && (typeof body.cursor!=="string" ||
      body.cursor.length>2048)){
    badRequest("作品カーソルが不正です","MISSION_ACTIVITY_SYNC_CURSOR_INVALID");
  }
  // Pagination cursor is still checked by the author-owned work listing.
  const workEvent={
    ...event,queryStringParameters:body.cursor
      ? {cursor:body.cursor} : {},
  } as APIGatewayProxyEventV2;
  const [workResult,gridResult]=await Promise.all([
    getMyWorkMissionAchievements(workEvent),
    body.cursor ? Promise.resolve(undefined) : getMyWorkCountMissionGrid(event),
  ]);
  const workData=parseResponse(workResult.body);
  const gridData=gridResult ? parseResponse(gridResult.body) : undefined;
  const now=new Date().toISOString();
  const works:Candidate[]=[];
  for(const raw of workData.items??[]){
    if(!raw || typeof raw!=="object" ||
      typeof raw.missionId!=="string" ||
      typeof raw.workId!=="string" ||
      typeof raw.required!=="number")continue;
    const published=raw.required===0;
    const occurredAt=published&&validDate(raw.workPostedAt)
      ? raw.workPostedAt : now;
    works.push({
      kind:published?"workPublished":"workBookmarks",
      missionId:raw.missionId,workId:raw.workId,workTitle:raw.workTitle,
      required:raw.required,occurredAt,
      dateIsObserved:!published,
    });
  }
  // Prioritize a work's publication then its most important achievements.
  works.sort((a,b)=>{
    const workA=a.kind==="workPublished"?0:1;
    const workB=b.kind==="workPublished"?0:1;
    return workA!==workB?workA-workB:
      a.workId!==b.workId ? (a.workId??"").localeCompare(b.workId??"")
        : b.required-a.required;
  });
  const grid:Candidate[]=[];
  for(const raw of gridData?.missions??[]){
    if(!raw || typeof raw!=="object" || raw.eligible!==true ||
       typeof raw.id!=="string" || typeof raw.required!=="number" ||
       typeof raw.eachWorkBookmarks!=="number")continue;
    grid.push({
      kind:"qualifiedWorks",missionId:raw.id,required:raw.required,
      eachWorkBookmarks:raw.eachWorkBookmarks,
      occurredAt:now,dateIsObserved:true,
    });
  }
  // Within newly discovered cohorts, prioritize high-value thresholds.
  grid.sort((a,b)=>b.required-a.required ||
    (b.eachWorkBookmarks??0)-(a.eachWorkBookmarks??0));
  const [newWorks,newGrid]=await Promise.all([
    keepUnseen(auth.niarimUserId,works),
    grid.length?keepUnseen(auth.niarimUserId,grid):Promise.resolve([]),
  ]);
  const toWrite=[
    ...newWorks.slice(0,WORK_WRITE_LIMIT),
    ...newGrid.slice(0,GRID_WRITE_LIMIT),
  ];
  // Duplicate notifications are safely ignored if another device wins.
  // Unrelated transaction/storage failures propagate, not false success.
  const wrote=await Promise.all(toWrite.map(m=>
    recordMissionAchievement(auth.niarimUserId,m)));
  return ok({
    added:wrote.filter(Boolean).length,
    hadMore: newWorks.length>WORK_WRITE_LIMIT ||
      newGrid.length>GRID_WRITE_LIMIT ||
      workData.nextCursor!==null,
    nextWorkCursor:workData.nextCursor??null,
    gridComplete:gridData?.complete??null,
    datePolicy:"source-for-publishing; first-observed-for-older-milestones",
  });
}
