import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName } from "../../lib/dynamo";
import { ok, badRequest } from "../../lib/response";
import { requestedPageSize } from "../../lib/pagination";
import type { WorkItem } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

/**
 * NIARIM内のブックマーク数だけを順位基準にする。
 * YouTube再生数は取得もランキング提供もしない。
 * 期間別ブックマーク数はイベント集計が実装されるまでは未提供。
 * 一度に取得するTop 50の範囲は維持する。
 */
export async function getRanking(event: APIGatewayProxyEventV2, period: string) {
  const qp = event.queryStringParameters ?? {};
  const limit = requestedPageSize(qp.limit);
  const offset = qp.cursor === undefined ? 0 : Number(qp.cursor);
  if (!Number.isInteger(offset) || offset < 0 || offset > 50 || offset % limit !== 0) {
    badRequest("ランキングのページカーソルが不正です", "INVALID_PAGE_CURSOR");
  }
  const ascending = qp.ascending === "true";
  if (period === "all" || period === "bookmarks") {
    return getBookmarkRanking(offset, limit, ascending);
  }
  if (["daily", "weekly", "monthly", "yearly"].includes(period)) {
    return ok({
      period,
      metric: "bookmarks",
      works: [],
      nextCursor: null,
      unavailableReason: "BOOKMARK_PERIOD_NOT_IMPLEMENTED",
    });
  }
  badRequest("ランキング期間が不正です", "INVALID_RANKING_PERIOD");
}

async function getBookmarkRanking(offset: number, limit: number, ascending: boolean) {
  const result = await ddb.send(new QueryCommand({
    TableName: tableName(),
    IndexName: "GSI2",
    KeyConditionExpression: "gsi2pk = :pk",
    ExpressionAttributeValues: { ":pk": "BOOKMARK_RANKING" },
    ScanIndexForward: false,
    Limit: 50,
  }));
  const ordered = (result.Items ?? []) as WorkItem[];
  const sorted = ascending ? [...ordered].reverse() : ordered;
  const page = sorted.slice(offset, offset + limit);
  return ok({
    period: "bookmarks",
    metric: "bookmarks",
    works: page.map(toPublicWork),
    nextCursor: offset + limit < sorted.length ? String(offset + limit) : null,
  });
}
