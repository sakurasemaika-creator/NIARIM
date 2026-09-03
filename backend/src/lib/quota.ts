import { ConditionalCheckFailedException, TransactionCanceledException } from '@aws-sdk/client-dynamodb';
import { TransactWriteCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName, Keys, GLOBAL_COUNTER_USER_ID, todayYyyymmdd } from './dynamo';
import type { MembershipTier } from './types';
import { conflict } from './response';

/** 11.1節の初期仕様。 */
export const DAILY_POST_LIMIT_PER_USER: Record<MembershipTier, number> = {
  free: 1,
  premium: 3,
};

/** 11.1節：NIARIM全体の1日あたり投稿上限。 */
export const DAILY_POST_LIMIT_GLOBAL = 100;

/** カウンターTTL（日次カウンターは数日で自動失効させる。11章の運用に影響しない）。 */
const COUNTER_TTL_DAYS = 3;

function counterTtl(now: Date): number {
  return Math.floor(now.getTime() / 1000) + COUNTER_TTL_DAYS * 24 * 60 * 60;
}

/**
 * 12.2節「投稿枠の原子的な予約」。
 *
 * ユーザー単位・全体単位の両カウンターを、DynamoDBの条件付き書き込み
 * （`ConditionExpression`）で「上限未満の場合のみインクリメント」する
 * ことでアトミックに予約する。`TransactWriteItems`で2件を同時に更新し、
 * どちらかが上限超過なら両方ロールバックされる（中途半端に片方だけ
 * 加算される事態を防ぐ）。
 *
 * 上限に達している場合は409を投げる（呼び出し元でuser-facingな
 * 「本日の公開上限に達しました」メッセージへ変換する。11.3節）。
 */
export async function reservePostQuota(niarimUserId: string, tier: MembershipTier): Promise<void> {
  const now = new Date();
  const date = todayYyyymmdd(now);
  const userLimit = DAILY_POST_LIMIT_PER_USER[tier];
  const ttl = counterTtl(now);

  const userKey = Keys.dailyCounter(niarimUserId, date);
  const globalKey = Keys.dailyCounter(GLOBAL_COUNTER_USER_ID, date);

  try {
    await ddb.send(
      new TransactWriteCommand({
        TransactItems: [
          {
            Update: {
              TableName: tableName(),
              Key: userKey,
              UpdateExpression:
                'SET niarimUserId = :uid, #d = :date, itemType = :type, ttl = :ttl ADD #c :one',
              ConditionExpression: 'attribute_not_exists(#c) OR #c < :limit',
              ExpressionAttributeNames: { '#c': 'count', '#d': 'date' },
              ExpressionAttributeValues: {
                ':one': 1,
                ':limit': userLimit,
                ':uid': niarimUserId,
                ':date': date,
                ':type': 'DAILY_COUNTER',
                ':ttl': ttl,
              },
            },
          },
          {
            Update: {
              TableName: tableName(),
              Key: globalKey,
              UpdateExpression:
                'SET niarimUserId = :uid, #d = :date, itemType = :type, ttl = :ttl ADD #c :one',
              ConditionExpression: 'attribute_not_exists(#c) OR #c < :limit',
              ExpressionAttributeNames: { '#c': 'count', '#d': 'date' },
              ExpressionAttributeValues: {
                ':one': 1,
                ':limit': DAILY_POST_LIMIT_GLOBAL,
                ':uid': GLOBAL_COUNTER_USER_ID,
                ':date': date,
                ':type': 'DAILY_COUNTER',
                ':ttl': ttl,
              },
            },
          },
        ],
      }),
    );
  } catch (err) {
    if (err instanceof TransactionCanceledException || err instanceof ConditionalCheckFailedException) {
      conflict('本日の投稿上限に達しています。日をまたぐと投稿できるようになります。', 'POST_QUOTA_EXCEEDED');
    }
    throw err;
  }
}

/**
 * 予約した投稿枠を解放する（12.2節：YouTubeアップロード自体が失敗した
 * 場合に、予約済みカウンターを1つ戻す）。ConditionExpressionで0未満に
 * ならないようにガードする。
 */
export async function releasePostQuota(niarimUserId: string): Promise<void> {
  const now = new Date();
  const date = todayYyyymmdd(now);
  // ユーザー単位と全体の2カウンターは互いに独立で、どちらも best-effort。
  // 直列にawaitするとDynamoDBへの往復が2回ぶん待ち時間になるため並列に送る。
  await Promise.all(
    [
      Keys.dailyCounter(niarimUserId, date),
      Keys.dailyCounter(GLOBAL_COUNTER_USER_ID, date),
    ].map((key) =>
      ddb
        .send(
          new UpdateCommand({
            TableName: tableName(),
            Key: key,
            UpdateExpression: 'ADD #c :minusOne',
            ConditionExpression: 'attribute_exists(#c) AND #c > :zero',
            ExpressionAttributeNames: { '#c': 'count' },
            ExpressionAttributeValues: { ':minusOne': -1, ':zero': 0 },
          }),
        )
        .catch((err: unknown) => {
          // 既に0まで戻っている等は無視してよい（解放は best-effort）。
          if (!(err instanceof ConditionalCheckFailedException)) throw err;
        }),
    ),
  );
}
