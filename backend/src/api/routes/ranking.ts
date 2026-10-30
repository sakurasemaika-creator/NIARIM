import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  BatchGetCommand,
  GetCommand,
  QueryCommand,
} from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { ok, badRequest } from "../../lib/response";
import { requestedPageSize } from "../../lib/pagination";
import { isDeltaRankingPeriod, isRankingPeriod } from "../../lib/ranking";
import type { RankingSnapshotItem, WorkItem } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

/**
 * `GET /ranking/{period}`（8.2節）。
 *
 * - `period=all`：累計。GSI1へのQuery 1回でrankingScore降順Top 50。
 * - `period=yearly|monthly|weekly|daily`：期間別。統計更新バッチが
 *   事前計算した`RANKINGSNAPSHOT#{PERIOD}`をGetItem 1回で読み、そこに
 *   並んでいるworkIdをBatchGetItemで引き当てる。期間別GSIを持たずに
 *   済ませるための設計（ranking.tsの設計メモ参照）。
 * - `period=bookmarks`：8.5節のブックマーク数ランキング。GSI2を使う。
 */
// eventは現状使っていないが、他のルートと引数の形を揃えておく
// （router側が全ルートを同じシグネチャで呼び分けるため）。
// eslint/tscの未使用検出を避けるためアンダースコア始まりにする。
export async function getRanking(
  event: APIGatewayProxyEventV2,
  period: string,
) {
  const qp = event.queryStringParameters ?? {};
  const limit = requestedPageSize(qp.limit);
  const offset = qp.cursor === undefined ? 0 : Number(qp.cursor);
  if (!Number.isInteger(offset) || offset < 0 || offset > 50 || offset % limit !== 0) {
    badRequest("ランキングのページカーソルが不正です", "INVALID_PAGE_CURSOR");
  }
  const ascending = qp.ascending === "true";
  const bookmarks = qp.sort === "bookmarks";
  if (period === "bookmarks") return getBookmarkRanking(offset, limit, ascending);
  if (period === "all") return getAllTimeRanking(offset, limit, ascending);
  if (isDeltaRankingPeriod(period)) return getPeriodRanking(period, offset, limit, ascending, bookmarks);

  if (!isRankingPeriod(period)) {
    badRequest(
      `periodが不正です（all/yearly/monthly/weekly/daily/bookmarksのいずれかを指定してください）: ${period}`,
      "INVALID_RANKING_PERIOD",
    );
  }
  // isRankingPeriodを通ったのにここへ来ることは無いが、型を絞り切るため。
  return getAllTimeRanking(offset, limit, ascending);
}

async function getAllTimeRanking(offset: number, limit: number, ascending: boolean) {
  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      IndexName: "GSI1",
      KeyConditionExpression: "gsi1pk = :pk",
      ExpressionAttributeValues: { ":pk": "RANKING#ALL" },
      ScanIndexForward: false, // rankingScore降順
      Limit: 50,
    }),
  );

  const works = (result.Items ?? []) as WorkItem[];
  return rankingPage("all", works, offset, limit, ascending);
}

/**
 * 期間別ランキング。スナップショットがまだ無い（バッチ未実行）場合は
 * 空配列を返す。クライアントは「まだ集計されていません」の表示にする。
 */
async function getPeriodRanking(period: string, offset: number, limit: number, ascending: boolean, bookmarks: boolean) {
  const snapshotResult = await ddb.send(
    new GetCommand({
      TableName: tableName(),
      Key: Keys.rankingSnapshot(period),
    }),
  );
  const snapshot = snapshotResult.Item as RankingSnapshotItem | undefined;
  const entries = snapshot?.entries ?? [];
  if (entries.length === 0) {
    return ok({
      period,
      works: [],
      nextCursor: null,
      computedAt: snapshot?.computedAt ?? null,
      windowId: snapshot?.windowId ?? null,
    });
  }

  const works = await batchGetWorks(entries.map((e) => e.workId));

  // BatchGetItemは順序を保証しないので、スナップショットの並びへ戻す。
  // 期間中に非公開化・削除された作品は取得できないか可視性が落ちている
  // ため、ここで除外する（次回のバッチでスナップショットからも消える）。
  const byId = new Map(works.map((w) => [w.workId, w]));
  const ordered = entries
    .map((e) => byId.get(e.workId))
    .filter((w): w is WorkItem => Boolean(w) && Boolean(w!.gsi1pk));

  if (bookmarks) ordered.sort((a, b) => b.bookmarkCount - a.bookmarkCount);
  return rankingPage(period, ordered, offset, limit, ascending, {
    computedAt: snapshot?.computedAt ?? null,
    windowId: snapshot?.windowId ?? null,
  });
}

/** BatchGetItemは1回100件までなので分割して引く（Top 50なので実質1回）。 */
async function batchGetWorks(workIds: string[]): Promise<WorkItem[]> {
  const found: WorkItem[] = [];
  for (let i = 0; i < workIds.length; i += 100) {
    const keys = workIds.slice(i, i + 100).map((id) => Keys.work(id));
    let request:
      | Record<string, { Keys: Record<string, unknown>[] }>
      | undefined = {
      [tableName()]: { Keys: keys },
    };
    // UnprocessedKeysが返る場合があるため、無くなるまで繰り返す。
    let guard = 0;
    while (request && Object.keys(request).length > 0 && guard++ < 5) {
      const result: any = await ddb.send(
        new BatchGetCommand({ RequestItems: request as never }),
      );
      found.push(...((result.Responses?.[tableName()] ?? []) as WorkItem[]));
      request = result.UnprocessedKeys;
    }
  }
  return found;
}

async function getBookmarkRanking(offset: number, limit: number, ascending: boolean) {
  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      IndexName: "GSI2",
      KeyConditionExpression: "gsi2pk = :pk",
      ExpressionAttributeValues: { ":pk": "BOOKMARK_RANKING" },
      ScanIndexForward: false, // bookmarkCount降順
      Limit: 50,
    }),
  );
  const works = (result.Items ?? []) as WorkItem[];
  return rankingPage("bookmarks", works, offset, limit, ascending);
}

/** The ranking universe remains Top 50; only the API response is paginated. */
function rankingPage(
  period: string,
  source: WorkItem[],
  offset: number,
  limit: number,
  ascending: boolean,
  extra: Record<string, unknown> = {},
) {
  const ordered = ascending ? [...source].reverse() : source;
  const page = ordered.slice(offset, offset + limit);
  return ok({
    period,
    works: page.map(toPublicWork),
    nextCursor: offset + limit < ordered.length ? String(offset + limit) : null,
    ...extra,
  });
}
