import { LambdaClient, InvokeCommand } from '@aws-sdk/client-lambda';
import { ScanCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName, Keys } from '../lib/dynamo';
import { batchGetVideoStats } from '../lib/youtube';
import { computeRankingScore } from '../lib/ranking';
import type { WorkItem } from '../lib/types';

/**
 * 統計更新バッチ（8.1節）。EventBridge Schedulerが更新サイクルの開始
 * のみをトリガーし、Lambdaは1ページ分（DynamoDB Scanの1回のレスポンス
 * 分）を処理したら`LastEvaluatedKey`をペイロードに載せて自分自身を
 * 非同期呼び出し（`InvocationType=Event`）し、そのまま終了する。
 * Step Functionsは使わず、Lambda + DynamoDB + EventBridgeのみで完結
 * させる設計（8.1節）。
 *
 * 1ページの件数（PAGE_SIZE）は、DynamoDBの無料枠（25 RCU）を統計更新
 * だけで使い切らないよう15〜20 RCU程度に抑える方針（8.1節）に基づき
 * 小さめに設定している。作品1件あたりの読み取りコストは項目サイズ
 * （最大2KB、5章）次第で変わるため、実運用で計測のうえ調整すること。
 */
const PAGE_SIZE = 25;

/**
 * 無限ループ事故を防ぐガード（8.1節）。50万作品 ÷ PAGE_SIZE(25) =
 * 20,000ページ相当を上限の目安とし、余裕を持たせて設定している。
 */
const MAX_PAGES = 25_000;

interface BatchPayload {
  lastEvaluatedKey?: Record<string, unknown>;
  pageIndex?: number;
}

export async function handler(event: BatchPayload = {}): Promise<void> {
  const pageIndex = event.pageIndex ?? 0;
  if (pageIndex >= MAX_PAGES) {
    console.error(`統計更新バッチが最大反復回数（${MAX_PAGES}）に達したため中断します。`);
    return;
  }

  const apiKey = requireEnv('YOUTUBE_API_KEY');

  const scanResult = await ddb.send(
    new ScanCommand({
      TableName: tableName(),
      FilterExpression: 'itemType = :type',
      ExpressionAttributeValues: { ':type': 'WORK' },
      Limit: PAGE_SIZE,
      ExclusiveStartKey: event.lastEvaluatedKey as never,
    }),
  );

  const works = (scanResult.Items ?? []) as WorkItem[];
  await processPage(works, apiKey);

  if (scanResult.LastEvaluatedKey) {
    await invokeSelfAsync({
      lastEvaluatedKey: scanResult.LastEvaluatedKey,
      pageIndex: pageIndex + 1,
    });
    return;
  }

  // 全ページの処理が完了：「最終更新完了日時」を記録する（8.1節）。
  // 表示側（GSI Query）は更新途中の中途半端な状態を参照しないよう、
  // rankingScore自体はページ処理のたびに随時反映済みだが、この完了
  // 印は監視・デバッグ用途（次回実行までにバッチが完走したかの確認）
  // に使う。
  await ddb.send(
    new UpdateCommand({
      TableName: tableName(),
      Key: Keys.batchState(),
      UpdateExpression: 'SET itemType = :type, lastCompletedAt = :now, inProgress = :false',
      ExpressionAttributeValues: {
        ':type': 'BATCH_STATE',
        ':now': new Date().toISOString(),
        ':false': false,
      },
    }),
  );
}

async function processPage(works: WorkItem[], apiKey: string): Promise<void> {
  if (works.length === 0) return;

  // videos.batchGetStatsの1回あたり件数上限は【要確認】（youtube.ts参照）。
  // 保守的に50件ずつのチャンクへ分割して呼び出す。
  const chunks = chunk(works, 50);
  for (const workChunk of chunks) {
    const stats = await batchGetVideoStats(
      workChunk.map((w) => w.youtubeVideoId),
      apiKey,
    );
    await Promise.all(workChunk.map((work) => updateWorkStats(work, stats.get(work.youtubeVideoId))));
  }
}

async function updateWorkStats(
  work: WorkItem,
  stats: { viewCount: number; likeCount: number; commentCount: number; privacyStatus: 'public' | 'unlisted' | 'private' } | undefined,
): Promise<void> {
  const now = new Date().toISOString();

  // videos.batchGetStatsで取得できなかった動画はYouTube側で削除済みと
  // みなす（13章の状態表）。
  const youtubePrivacyStatus = stats ? stats.privacyStatus : 'deleted';
  const viewCount = stats?.viewCount ?? work.viewCount;
  const likeCount = stats?.likeCount ?? work.likeCount;
  const commentCount = stats?.commentCount ?? work.commentCount;
  const rankingScore = computeRankingScore({ viewCount, likeCount, commentCount });

  // 13章：非公開(private)・削除済み(deleted)は強制非表示。それ以外
  // （public/unlisted）は、NIARIM側のisNiarimPublished設定どおりに表示。
  const forcedHidden = youtubePrivacyStatus === 'private' || youtubePrivacyStatus === 'deleted';
  const isVisible = work.isNiarimPublished && !forcedHidden;

  const setParts = [
    'viewCount = :view',
    'likeCount = :like',
    'commentCount = :comment',
    'lastFetchedAt = :now',
    'youtubePrivacyStatus = :status',
  ];
  const values: Record<string, unknown> = {
    ':view': viewCount,
    ':like': likeCount,
    ':comment': commentCount,
    ':now': now,
    ':status': youtubePrivacyStatus,
  };
  const removes: string[] = [];

  if (isVisible) {
    setParts.push(
      'rankingScore = :score',
      'gsi1pk = :rankPk',
      'gsi1sk = :score',
      'gsi2pk = :bmPk',
      'gsi2sk = :bm',
      'gsi3pk = :authorPk',
      'gsi3sk = :postedAt',
      'gsi4pk = :latestPk',
      'gsi4sk = :postedAt',
    );
    values[':score'] = rankingScore;
    values[':bmPk'] = 'BOOKMARK_RANKING';
    values[':bm'] = work.bookmarkCount;
    values[':authorPk'] = `AUTHOR#${work.authorId}`;
    values[':postedAt'] = work.postedAt;
    values[':latestPk'] = 'LATEST';
  } else {
    removes.push('rankingScore', 'gsi1pk', 'gsi1sk', 'gsi2pk', 'gsi2sk', 'gsi3pk', 'gsi3sk', 'gsi4pk', 'gsi4sk');
  }

  const updateExpression = `SET ${setParts.join(', ')}` + (removes.length ? ` REMOVE ${removes.join(', ')}` : '');

  // rankingScoreの更新は「最新値で上書き」なので、Lambdaの非同期呼び出し
  // が失敗時に自動リトライされ同一ページが二重処理されても結果は壊れ
  // ない（冪等、8.1節）。ConditionExpressionは付けない。
  await ddb.send(
    new UpdateCommand({
      TableName: tableName(),
      Key: Keys.work(work.workId),
      UpdateExpression: updateExpression,
      ExpressionAttributeValues: values,
    }),
  );
}

async function invokeSelfAsync(payload: BatchPayload): Promise<void> {
  const functionName = requireEnv('SELF_FUNCTION_NAME');
  const client = new LambdaClient({});
  await client.send(
    new InvokeCommand({
      FunctionName: functionName,
      InvocationType: 'Event',
      Payload: Buffer.from(JSON.stringify(payload)),
    }),
  );
}

function chunk<T>(items: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let i = 0; i < items.length; i += size) result.push(items.slice(i, i + size));
  return result;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name}環境変数が設定されていません`);
  return value;
}
