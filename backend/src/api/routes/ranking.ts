import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { QueryCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName } from '../../lib/dynamo';
import { ok, json } from '../../lib/response';
import { isImplementedRankingPeriod } from '../../lib/ranking';
import type { WorkItem } from '../../lib/types';
import { toPublicWork } from './_publicWork';

/**
 * `GET /ranking/{period}`（8.2節）。Top 50をGSI1へのQuery1回で返す。
 * 8.5節のブックマーク数ランキングは`period=bookmarks`として同じ
 * エンドポイントに乗せている（GSI2を使う点以外は同じ形）。
 */
export async function getRanking(event: APIGatewayProxyEventV2, period: string) {
  if (period === 'bookmarks') return getBookmarkRanking();

  if (!isImplementedRankingPeriod(period)) {
    // 8章では累計/年間/月間/週間/デイリーの5種類を掲げているが、期間別
    // スコアの算出方式（year/month/week/day単位の差分集計）は仕様書側で
    // まだ確定していない設計のため、現状は累計（all）のみ実装している。
    // ranking.tsのIMPLEMENTED_RANKING_PERIODSのコメント参照。
    return json(501, {
      error: `期間別ランキング（period=${period}）は未実装です。現在はperiod=allのみ対応しています。`,
      code: 'RANKING_PERIOD_NOT_IMPLEMENTED',
    });
  }

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
