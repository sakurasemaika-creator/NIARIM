import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient } from '@aws-sdk/lib-dynamodb';

/**
 * DynamoDBクライアント。テーブル名は環境変数`TABLE_NAME`から取る
 * （CDKスタック側でLambdaの環境変数として注入する。lib/niarim-backend-stack.ts参照）。
 */
const client = new DynamoDBClient({});
export const ddb = DynamoDBDocumentClient.from(client, {
  marshallOptions: {
    removeUndefinedValues: true, // GSI属性を省略（undefined）したいケースがあるため
  },
});

export function tableName(): string {
  const name = process.env.TABLE_NAME;
  if (!name) throw new Error('TABLE_NAME環境変数が設定されていません');
  return name;
}

// --- キー生成ヘルパー（types.tsのキー設計と対応） ---

export const Keys = {
  work: (workId: string) => ({ pk: `WORK#${workId}`, sk: 'META' }),
  user: (niarimUserId: string) => ({ pk: `USER#${niarimUserId}`, sk: 'META' }),
  googleSubLookup: (sub: string) => ({ pk: `GOOGLESUB#${sub}`, sk: 'META' }),
  bookmark: (niarimUserId: string, workId: string) => ({
    pk: `USER#${niarimUserId}`,
    sk: `BOOKMARK#${workId}`,
  }),
  repost: (niarimUserId: string, workId: string) => ({
    pk: `USER#${niarimUserId}`,
    sk: `REPOST#${workId}`,
  }),
  followerRecord: (targetId: string, followerId: string) => ({
    pk: `USER#${targetId}`,
    sk: `FOLLOWER#${followerId}`,
  }),
  followingRecord: (followerId: string, targetId: string) => ({
    pk: `USER#${followerId}`,
    sk: `FOLLOWING#${targetId}`,
  }),
  report: (workId: string, reporterId: string, createdAt: string) => ({
    pk: `WORK#${workId}`,
    sk: `REPORT#${reporterId}#${createdAt}`,
  }),
  block: (blockerId: string, blockedId: string) => ({
    pk: `USER#${blockerId}`,
    sk: `BLOCK#${blockedId}`,
  }),
  followNotification: (targetId: string, createdAt: string, notifId: string) => ({
    pk: `USER#${targetId}`,
    sk: `NOTIF#${createdAt}#${notifId}`,
  }),
  dailyCounter: (niarimUserId: string, yyyymmdd: string) => ({
    pk: `COUNTER#${niarimUserId}#${yyyymmdd}`,
    sk: 'META',
  }),
  batchState: () => ({ pk: 'BATCHSTATE#STATS_UPDATE', sk: 'META' }),
  /**
   * 通報レート制限用の窓カウンター（20章）。窓ごとに別アイテムへ分けて
   * おり、ADDによる原子的インクリメント＋TTLで自動失効させる。
   */
  reportCounter: (reporterId: string, windowId: string) => ({
    pk: `REPORTCOUNTER#${reporterId}#${windowId}`,
    sk: 'META',
  }),
  /** 22.7節：プッシュ通知の端末トークン。1ユーザーに複数端末ぶら下がる。 */
  deviceToken: (niarimUserId: string, tokenHash: string) => ({
    pk: `USER#${niarimUserId}`,
    sk: `DEVICE#${tokenHash}`,
  }),
  /** 8.2節：期間別ランキングの事前計算結果（期間ごとに1アイテム）。 */
  rankingSnapshot: (period: string) => ({
    pk: `RANKINGSNAPSHOT#${period.toUpperCase()}`,
    sk: 'META',
  }),
} as const;

/** 全体投稿カウンター専用のNIARIM User ID（12章：全体上限も同じ形で扱う）。 */
export const GLOBAL_COUNTER_USER_ID = 'GLOBAL';

/** 今日の日付をyyyymmdd（UTC基準）で返す。 */
export function todayYyyymmdd(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10).replace(/-/g, '');
}
