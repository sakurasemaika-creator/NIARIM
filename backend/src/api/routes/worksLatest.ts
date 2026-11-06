import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName } from "../../lib/dynamo";
import { ok } from "../../lib/response";
import { decodePageCursor, encodePageCursor, requestedPageSize } from "../../lib/pagination";
import type { WorkItem } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

/**
 * GSI4 keyset paging. Each reply contains at most 25 works, even for search.
 * Search scans bounded 25-item Dynamo pages, so it never loads all works.
 * The cursor advances over scanned items, not just matched ones.
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
    for (const work of (result.Items ?? []) as WorkItem[]) {
      if (matchesSearch(work, query, tagMode, exact)) works.push(work);
    }
    key = result.LastEvaluatedKey;
    more = Boolean(key);
  }
  return ok({
    works: works.map(toPublicWork),
    nextCursor: more ? encodePageCursor(key, scope) : null,
  });
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
