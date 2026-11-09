import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  BatchGetCommand, QueryCommand,
  type BatchGetCommandInput,
  type BatchGetCommandOutput,
} from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { ok, badRequest } from "../../lib/response";
import { requestedPageSize } from "../../lib/pagination";
import { currentWindowId } from "../../lib/ranking";
import { bookmarkPeriodPartition, isBookmarkPeriod } from "../../lib/periodBookmarkRanking";
import type { BookmarkPeriod } from "../../lib/periodBookmarkRanking";
import type { WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

const TOP_LIMIT = 50;

/**
 * All-time: total ACTIVE NIARIM bookmarks.
 * Daily/weekly/monthly/yearly: ACTIVE NEW bookmarks made in that JST calendar
 * window. No YouTube views/likes/comments are used as ranking signals.
 *
 * Period scores are updated in the very same transaction as bookmark toggles,
 * and queried from independent partitions on the existing GSI2. This avoids
 * four new GSI capacities and never returns synthetic ranking data.
 */
export async function getRanking(event: APIGatewayProxyEventV2, period: string) {
  const qp = event.queryStringParameters ?? {};
  const limit = requestedPageSize(qp.limit);
  const offset = qp.cursor === undefined ? 0 : Number(qp.cursor);
  if (!Number.isInteger(offset) || offset < 0 ||
      offset > TOP_LIMIT || offset % limit !== 0) {
    badRequest("ランキングのページカーソルが不正です", "INVALID_PAGE_CURSOR");
  }
  const ascending = qp.ascending === "true";
  if (period === "all" || period === "bookmarks") {
    return getBookmarkRanking(offset, limit, ascending);
  }
  if (isBookmarkPeriod(period)) {
    return getPeriodBookmarkRanking(period, offset, limit, ascending);
  }
  badRequest("ランキング期間が不正です", "INVALID_RANKING_PERIOD");
}

function published(work: WorkItem | undefined): work is WorkItem {
  return Boolean(work &&
    work.itemType === TABLE_ITEM_TYPE.Work &&
    work.isNiarimPublished &&
    work.youtubePrivacyStatus !== "private" &&
    work.youtubePrivacyStatus !== "deleted");
}

/** Strongly consistent primary-key reads are required to avoid leaking titles
 * of works that have just become private. A GSI alone is insufficient. */
async function publicWorksById(workIds: string[]): Promise<Map<string,WorkItem>> {
  if (!workIds.length) return new Map();
  const table = tableName();
  let requests: BatchGetCommandInput["RequestItems"] = {
    [table]: {Keys: workIds.map(Keys.work), ConsistentRead: true},
  };
  const found = new Map<string,WorkItem>();
  for (let retry=0; retry<4 && requests && Object.keys(requests).length; retry++) {
    const result: BatchGetCommandOutput = await ddb.send(new BatchGetCommand({RequestItems:requests}));
    for (const item of result.Responses?.[table] ?? []) {
      const work=item as WorkItem;
      if (published(work)) found.set(work.workId,work);
    }
    requests=result.UnprocessedKeys;
  }
  if (requests && Object.keys(requests).length) {
    throw new Error("Ranking BatchGet did not complete; retry the request");
  }
  return found;
}

async function getPeriodBookmarkRanking(
  period: BookmarkPeriod, offset: number, limit: number, ascending: boolean,
) {
  const now=new Date();
  const windowId=currentWindowId(period,now);
  const partition=bookmarkPeriodPartition(period,now);
  const collected: Array<ReturnType<typeof toPublicWork> & {periodBookmarkCount:number}> = [];
  let nextKey: Record<string,string|number>|undefined;
  // Bounded by the public Top 50. Continue past hidden/deleted works; do NOT
  // leak their titles or accidentally let them occupy ranked slots.
  for (let page=0; page<20 && collected.length<TOP_LIMIT; page++) {
    const reply=await ddb.send(new QueryCommand({
      TableName:tableName(),IndexName:"GSI2",
      KeyConditionExpression:"gsi2pk = :pk AND gsi2sk > :zero",
      ExpressionAttributeValues:{":pk":partition,":zero":0},
      ScanIndexForward:ascending,
      Limit:TOP_LIMIT,
      ...(nextKey?{ExclusiveStartKey:nextKey}:{}),
    }));
    const entries=(reply.Items??[]) as Array<{
      itemType:string;workId:string;score:number;
    }>;
    const valid=entries.filter(x=>x.itemType==="BOOKMARK_PERIOD_SCORE" &&
      typeof x.workId==="string" && Number.isSafeInteger(x.score) && x.score>0);
    const byId=await publicWorksById([...new Set(valid.map(x=>x.workId))]);
    for(const entry of valid) {
      const work=byId.get(entry.workId);
      if(!work)continue;
      collected.push({...toPublicWork(work),periodBookmarkCount:entry.score});
      if(collected.length>=TOP_LIMIT)break;
    }
    nextKey=reply.LastEvaluatedKey as Record<string,string|number>|undefined;
    if(!nextKey)break;
  }
  return ok({
    period,metric:"periodBookmarks",windowId,
    works:collected.slice(offset,offset+limit),
    nextCursor:offset+limit<collected.length?String(offset+limit):null,
  });
}


/** Visibility-only bulk check for an ALREADY displayed ranking snapshot.
 * Missing/private/deleted all return false. No hidden title or existence leak.
 * The browser/app keeps the original slot number, but redacts it immediately.
 */
export async function getRankingVisibility(event: APIGatewayProxyEventV2) {
  const input = event.queryStringParameters?.ids;
  if (typeof input !== "string" || input.length > 600) {
    badRequest("作品ID一覧が不正です", "INVALID_RANKING_VISIBILITY_IDS");
  }
  const ids = input.split(",");
  if (ids.length < 1 || ids.length > 50 ||
      ids.some(id => !/^[A-Za-z0-9_-]{11}$/.test(id)) ||
      new Set(ids).size !== ids.length) {
    badRequest("作品ID一覧が不正です", "INVALID_RANKING_VISIBILITY_IDS");
  }
  const works = await publicWorksById(ids);
  return ok({visibility: Object.fromEntries(ids.map(id => [id, works.has(id)]))});
}

async function getAllTimePublicWorks(): Promise<WorkItem[]> {
  const collected: WorkItem[] = [];
  let nextKey: Record<string,string|number>|undefined;
  // GSI2 can lag publication changes. NEVER expose cached GSI metadata
  // without a strongly consistent Work META read. Fill hidden gaps only
  // when building a NEW ranking response; never mutate a client's snapshot.
  for (let page=0; page<20 && collected.length<TOP_LIMIT; page++) {
    const result=await ddb.send(new QueryCommand({
      TableName:tableName(),
      IndexName:"GSI2",
      KeyConditionExpression:"gsi2pk = :pk",
      ExpressionAttributeValues:{":pk":"BOOKMARK_RANKING"},
      ScanIndexForward:false,
      Limit:TOP_LIMIT,
      ...(nextKey?{ExclusiveStartKey:nextKey}:{}),
    }));
    const candidates=(result.Items??[]) as WorkItem[];
    const byId=await publicWorksById([...new Set(candidates.map(x=>x.workId)
      .filter((id):id is string => typeof id==="string" &&
          /^[A-Za-z0-9_-]{11}$/.test(id)))]);
    for(const candidate of candidates) {
      const actual=byId.get(candidate.workId);
      if(actual)collected.push(actual);
      if(collected.length>=TOP_LIMIT)break;
    }
    nextKey=result.LastEvaluatedKey as Record<string,string|number>|undefined;
    if(!nextKey)break;
  }
  return collected;
}

async function getBookmarkRanking(offset:number,limit:number,ascending:boolean) {
  const ordered = await getAllTimePublicWorks();
  const sorted = ascending ? [...ordered].reverse() : ordered;
  const page = sorted.slice(offset, offset+limit);
  return ok({
    period:"bookmarks",metric:"bookmarks",
    works:page.map(toPublicWork),
    nextCursor:offset+limit<sorted.length?String(offset+limit):null,
  });
}
