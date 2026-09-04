import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName } from "../../lib/dynamo";
import { ok } from "../../lib/response";
import type { WorkItem } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 100;

/**
 * `GET /works/latest`（8.3節）。GSI4（LatestIndex）へのQuery1回で完結
 * する。非公開・強制非表示の作品はGSI4のソートキー属性が存在しない
 * ため、そもそもQuery結果に含まれない（13章）。
 *
 * 8.6節の検索は`q`クエリパラメータで受け、Lambda側で部分一致フィルタを
 * かける（初期規模向けの簡易実装。大規模化時はOpenSearch等へ移行）。
 */
export async function getLatestWorks(event: APIGatewayProxyEventV2) {
  const qp = event.queryStringParameters ?? {};
  const limit = clampLimit(qp.limit);
  const query = qp.q?.trim().toLowerCase();

  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      IndexName: "GSI4",
      KeyConditionExpression: "gsi4pk = :pk",
      ExpressionAttributeValues: { ":pk": "LATEST" },
      ScanIndexForward: false, // 新着順（postedAt降順）
      Limit: query ? undefined : limit, // 検索時はフィルタ後に件数を絞るためLimitを付けない
    }),
  );

  let works = (result.Items ?? []) as WorkItem[];
  if (query) {
    works = works.filter(
      (w) =>
        w.title.toLowerCase().includes(query) ||
        w.channelName.toLowerCase().includes(query),
    );
    works = works.slice(0, limit);
  }

  return ok({ works: works.map(toPublicWork) });
}

function clampLimit(raw: string | undefined): number {
  const n = raw ? Number(raw) : DEFAULT_LIMIT;
  if (!Number.isFinite(n) || n <= 0) return DEFAULT_LIMIT;
  return Math.min(n, MAX_LIMIT);
}
