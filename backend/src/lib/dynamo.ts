import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient } from "@aws-sdk/lib-dynamodb";

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
  if (!name) throw new Error("TABLE_NAME環境変数が設定されていません");
  return name;
}

// --- キー生成ヘルパー（types.tsのキー設計と対応） ---

export const Keys = {
  work: (workId: string) => ({ pk: `WORK#${workId}`, sk: "META" }),
  workDetail: (workId: string) => ({ pk: `WORK#${workId}`, sk: "DETAIL" }),
  user: (niarimUserId: string) => ({ pk: `USER#${niarimUserId}`, sk: "META" }),
  googleSubLookup: (sub: string) => ({ pk: `GOOGLESUB#${sub}`, sk: "META" }),
  /** A Play purchase token is bound to a single account by its SHA256 hash. */
  playPurchaseToken: (hash: string) => ({ pk: `PLAY_PURCHASE#${hash}`, sk: "META" }),
  /** Reward entitlement is server-issued only; clients cannot write this key. */
  rewardEntitlement: (niarimUserId: string, entitlement: string) => ({
    pk: `USER#${niarimUserId}`,
    sk: `ENTITLEMENT#${entitlement}`,
  }),
  loginBonusState: (userId: string) => ({
    pk: `USER#${userId}`, sk: "LOGIN_BONUS_STATE",
  }),
  loginBonusMilestone: (userId: string, days: number) => ({
    pk: `USER#${userId}`, sk: `LOGIN_BONUS_MILESTONE#${days}`,
  }),
  coinWallet: (niarimUserId: string) => ({
    pk: `USER#${niarimUserId}`, sk: "COIN_WALLET",
  }),
  /** 20 account-owned shards, each containing 24 independent grid bits. */
  creatorGridShard: (userId: string, workGoal: number) => ({
    pk: `USER#${userId}`, sk: `MISSION_GRID#${workGoal}`,
  }),
  /** Once-only marker for each distinct mission achievement event. */
  missionNoticeDedupe: (userId: string, eventId: string) => ({
    pk: `USER#${userId}`, sk: `MISSION_NOTICE_KEY#${eventId}`,
  }),
  /** Newest-first ordered personal activity entry. */
  missionActivity: (userId: string, epochMs: number, eventId: string) => ({
    pk: `USER#${userId}`,
    sk: `MISSION_ACTIVITY#${String(9_999_999_999_999-epochMs).padStart(13,"0")}#${eventId}`,
  }),
  creatorMissionState: (niarimUserId: string) => ({
    pk: `USER#${niarimUserId}`, sk: "MISSION_STATE_V1",
  }),
  /** Server-owned bounded progress scanner; never a spendable coin proof. */
  creatorQualifiedWorksScan: (userId: string) => ({
    pk: `USER#${userId}`, sk: "MISSION_QUALIFIED_WORK_SCAN_V1",
  }),
  /** Persistent per-work bitmask; one tiny item only after a work earns a reward. */
  creatorWorkMissionState: (niarimUserId: string, workId: string) => ({
    pk: `USER#${niarimUserId}`, sk: `MISSION_WORK#${workId}`,
  }),
  coinTransaction: (niarimUserId: string, transactionId: string) => ({
    pk: `USER#${niarimUserId}`, sk: `COIN_TX#${transactionId}`,
  }),
  /** Chronological per-user movement journal, written atomically with coins. */
  coinHistory: (userId: string, occurredAtEpochMs: number, id: string) => ({
    pk: `USER#${userId}`,
    sk: `COIN_HISTORY#${String(9_999_999_999_999 - occurredAtEpochMs).padStart(13, "0")}#${id}`,
  }),
  /** Global SSV receipt: a transaction ID is unique across ALL accounts.
   * Short retention is safe only because callback timestamps expire in 7d.
   */
  admobReceipt: (transactionId: string) => ({
    pk: `ADMOB_TX#${transactionId}`, sk: "META",
  }),
  /** One replaceable ad invitation per signed-in account. */
  rewardedAdSession: (niarimUserId: string) => ({
    pk: `USER#${niarimUserId}`, sk: "REWARDED_AD_SESSION",
  }),
  /** One compact per-account per-UTC-day counter only when capped. */
  rewardAdDailyCount: (niarimUserId: string, dayUtc: string) => ({
    pk: `USER#${niarimUserId}`, sk: `REWARDED_AD_DAY#${dayUtc}`,
  }),

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
  followNotification: (
    targetId: string,
    createdAt: string,
    notifId: string,
  ) => ({
    pk: `USER#${targetId}`,
    sk: `NOTIF#${createdAt}#${notifId}`,
  }),
  dailyCounter: (niarimUserId: string, yyyymmdd: string) => ({
    pk: `COUNTER#${niarimUserId}#${yyyymmdd}`,
    sk: "META",
  }),
  batchState: () => ({ pk: "BATCHSTATE#STATS_UPDATE", sk: "META" }),
  /**
   * 通報レート制限用の窓カウンター（20章）。窓ごとに別アイテムへ分けて
   * おり、ADDによる原子的インクリメント＋TTLで自動失効させる。
   */
  reportCounter: (reporterId: string, windowId: string) => ({
    pk: `REPORTCOUNTER#${reporterId}#${windowId}`,
    sk: "META",
  }),
  /** 22.7節：プッシュ通知の端末トークン。1ユーザーに複数端末ぶら下がる。 */
  deviceToken: (niarimUserId: string, tokenHash: string) => ({
    pk: `USER#${niarimUserId}`,
    sk: `DEVICE#${tokenHash}`,
  }),
  /** 8.2節：期間別ランキングの事前計算結果（期間ごとに1アイテム）。 */
  rankingSnapshot: (period: string) => ({
    pk: `RANKINGSNAPSHOT#${period.toUpperCase()}`,
    sk: "META",
  }),
} as const;

/** 全体投稿カウンター専用のNIARIM User ID（12章：全体上限も同じ形で扱う）。 */
export const GLOBAL_COUNTER_USER_ID = "GLOBAL";

/** 今日の日付をyyyymmdd（UTC基準）で返す。 */
export function todayYyyymmdd(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10).replace(/-/g, "");
}
