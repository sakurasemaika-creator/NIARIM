import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  BatchGetCommand, QueryCommand,
  type BatchGetCommandInput, type BatchGetCommandOutput,
} from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { ok } from "../../lib/response";
import { decodePageCursor, encodePageCursor, requestedPageSize } from "../../lib/pagination";
import type { WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

/**
 * GSI4 keyset paging. Each reply contains at most 25 works, even for search.
 * Search scans bounded 25-item Dynamo pages, so it never loads all works.
 * The cursor advances over scanned items, not just matched ones.
 * Always re-read candidates from the primary table with strong consistency:
 * GSI4 may lag a privacy change and must not leak its cached metadata.
 */
export async function getLatestWorks(event: APIGatewayProxyEventV2) {
  const qp = event.queryStringParameters ?? {};
  const limit = requestedPageSize(qp.limit);
  const query = (qp.q ?? "").trim().toLowerCase();
  const tagMode = qp.tagMode === "true";
  const exact = qp.exact === "true";
  const scope = `latest|${query}|${tagMode}|${exact}`;
  let key = decodePageCursor(qp.cursor, scope);
  const works: WorkItem[] = [];
  // Bound Lambda read cost even for a rare query with few matches.
  let more = true;
  for (let scan = 0; scan < 10 && works.length < limit && more; scan++) {
    const result = await ddb.send(
      new QueryCommand({
        TableName: tableName(),
        IndexName: "GSI4",
        KeyConditionExpression: "gsi4pk = :pk",
        ExpressionAttributeValues: { ":pk": "LATEST" },
        ScanIndexForward: false,
        Limit: limit - works.length,
        ExclusiveStartKey: key,
      }),
    );
    const candidates = (result.Items ?? []) as WorkItem[];
    const active = await currentPublicWorks(candidates);
    for (const candidate of candidates) {
      const work = active.get(candidate.workId);
      if (work && matchesSearch(work, query, tagMode, exact)) works.push(work);
    }
    key = result.LastEvaluatedKey;
    more = Boolean(key);
  }
  return ok({
    works: works.map(toPublicWork),
    nextCursor: more ? encodePageCursor(key, scope) : null,
  });
}

/**
 * GSI results can contain recently hidden or deleted works. Query results
 * are only identifiers/order hints; only consistent META records supply
 * public titles, thumbnails and search data.
 */
async function currentPublicWorks(candidates: WorkItem[]): Promise<Map<string, WorkItem>> {
  const ids = [...new Set(candidates.map(c => c.workId).filter(
    (id): id is string => typeof id === "string" &&
      /^[A-Za-z0-9_-]{11}$/.test(id),
  ))];
  if (!ids.length) return new Map();
  const table = tableName();
  let requests: BatchGetCommandInput["RequestItems"] = {
    [table]: { Keys: ids.map(Keys.work), ConsistentRead: true },
  };
  const visible = new Map<string, WorkItem>();
  for (let attempt = 0; attempt < 4 && requests &&
       Object.keys(requests).length; attempt++) {
    const result: BatchGetCommandOutput = await ddb.send(
      new BatchGetCommand({ RequestItems: requests }),
    );
    for (const raw of result.Responses?.[table] ?? []) {
      const work = raw as WorkItem;
      if (work.itemType === TABLE_ITEM_TYPE.Work &&
          work.isNiarimPublished &&
          (work.youtubePrivacyStatus === "public" ||
           work.youtubePrivacyStatus === "unlisted")) {
        visible.set(work.workId, work);
      }
    }
    requests = result.UnprocessedKeys;
  }
  if (requests && Object.keys(requests).length) {
    throw new Error("Latest works privacy check incomplete; retry the request");
  }
  return visible;
}

function matchesSearch(work: WorkItem, query: string, tagMode: boolean, exact: boolean) {
  if (!query) return true;
  const terms = query.match(/-?"[^"]+"|-?\S+/g) ?? [];
  return terms.every((raw) => {
    const negative = raw.startsWith("-") && raw.length > 1;
    const term = (negative ? raw.slice(1) : raw).replace(/"/g, "").replace(/^#/, "");
    const foundTag = (work.tags ?? []).some((tag) => {
      const normalized = tag.toLowerCase().replace(/^[#＃]/, "");
      return exact ? normalized === term : normalized.includes(term);
    });
    const title = work.title.toLowerCase();
    const found = tagMode ? foundTag : foundTag || (exact ? title === term : title.includes(term));
    return negative ? !found : found;
  });
}
