import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { BatchGetCommand, GetCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName, Keys } from '../../lib/dynamo';
import { ok, badRequest } from '../../lib/response';
import { isDeltaRankingPeriod, isRankingPeriod } from '../../lib/ranking';
import type { RankingSnapshotItem, WorkItem } from '../../lib/types';
import { toPublicWork } from './_publicWork';

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
export async function getRanking(event: APIGatewayProxyEventV2, period: string) {
  if (period === 'bookmarks') return getBookmarkRanking();
  if (period === 'all') return getAllTimeRanking();
  if (isDeltaRankingPeriod(period)) return getPeriodRanking(period);

  if (!isRankingPeriod(period)) {
    badRequest(
      `periodが不正です（all/yearly/monthly/weekly/daily/bookmarksのいずれかを指定してください）: ${period}`,
      'INVALID_RANKING_PERIOD',
    );
  }
  // isRankingPeriodを通ったのにここへ来ることは無いが、型を絞り切るため。
  return getAllTimeRanking();
}

async function getAllTimeRanking() {
  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      IndexName: 'GSI1',
      KeyConditionExpression: 'gsi1pk = :pk',
      ExpressionAttributeValues: { ':pk': 'RANKING#ALL' },
      ScanIndexForward: false, // rankingScore降順
      Limit: 50,
    }),
  );

  const works = (result.Items ?? []) as WorkItem[];
  return ok({ period: 'all', works: works.map(toPublicWork) });
}

/**
 * 期間別ランキング。スナップショットがまだ無い（バッチ未実行）場合は
 * 空配列を返す。クライアントは「まだ集計されていません」の表示にする。
 */
async function getPeriodRanking(period: string) {
  const snapshotResult = await ddb.send(
    new GetCommand({ TableName: tableName(), Key: Keys.rankingSnapshot(period) }),
  );
  const snapshot = snapshotResult.Item as RankingSnapshotItem | undefined;
  const entries = snapshot?.entries ?? [];
  if (entries.length === 0) {
    return ok({ period, works: [], computedAt: snapshot?.computedAt ?? null, windowId: snapshot?.windowId ?? null });
  }

  const works = await batchGetWorks(entries.map((e) => e.workId));

  // BatchGetItemは順序を保証しないので、スナップショットの並びへ戻す。
  // 期間中に非公開化・削除された作品は取得できないか可視性が落ちている
  // ため、ここで除外する（次回のバッチでスナップショットからも消える）。
  const byId = new Map(works.map((w) => [w.workId, w]));
  const ordered = entries
    .map((e) => byId.get(e.workId))
    .filter((w): w is WorkItem => Boolean(w) && Boolean(w!.gsi1pk));

  return ok({
    period,
    works: ordered.map(toPublicWork),
    computedAt: snapshot?.computedAt ?? null,
    windowId: snapshot?.windowId ?? null,
  });
}

/** BatchGetItemは1回100件までなので分割して引く（Top 50なので実質1回）。 */
async function batchGetWorks(workIds: string[]): Promise<WorkItem[]> {
  const found: WorkItem[] = [];
  for (let i = 0; i < workIds.length; i += 100) {
    const keys = workIds.slice(i, i + 100).map((id) => Keys.work(id));
    let request: Record<string, { Keys: Record<string, unknown>[] }> | undefined = {
      [tableName()]: { Keys: keys },
    };
    // UnprocessedKeysが返る場合があるため、無くなるまで繰り返す。
    let guard = 0;
    while (request && Object.keys(request).length > 0 && guard++ < 5) {
      const result: any = await ddb.send(new BatchGetCommand({ RequestItems: request as never }));
      found.push(...((result.Responses?.[tableName()] ?? []) as WorkItem[]));
      request = result.UnprocessedKeys;
    }
  }
  return found;
}

async function getBookmarkRanking() {
  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      IndexName: 'GSI2',
      KeyConditionExpression: 'gsi2pk = :pk',
      ExpressionAttributeValues: { ':pk': 'BOOKMARK_RANKING' },
      ScanIndexForward: false, // bookmarkCount降順
      Limit: 50,
    }),
  );
  const works = (result.Items ?? []) as WorkItem[];
  return ok({ period: 'bookmarks', works: works.map(toPublicWork) });
}
