import {
  ConditionalCheckFailedException,
  TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import {
  GetCommand,
  TransactWriteCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import {
  ddb,
  tableName,
  Keys,
  GLOBAL_COUNTER_USER_ID,
  todayYyyymmdd,
} from "./dynamo";
import type { MembershipTier } from "./types";
import { conflict } from "./response";
import { resolvePostMembershipTier } from "./rewardEntitlement";

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
export async function reservePostQuota(
  niarimUserId: string,
  tier: MembershipTier,
): Promise<void> {
  const now = new Date();
  const date = todayYyyymmdd(now);
  // Use only entitlements obtained from the authenticated, server-side NIARIM ID.
  // An expired/paused reward reverts to free quota, but previously posted
  // works and the already-used daily counter remain unchanged.
  const effectiveTier = await resolvePostMembershipTier(niarimUserId, tier, now);
  const userLimit = DAILY_POST_LIMIT_PER_USER[effectiveTier];
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
                "SET niarimUserId = :uid, #d = :date, itemType = :type, #ttl = :ttl ADD #c :one",
              ConditionExpression: "attribute_not_exists(#c) OR #c < :limit",
              ExpressionAttributeNames: { "#c": "count", "#d": "date", "#ttl": "ttl" },
              ExpressionAttributeValues: {
                ":one": 1,
                ":limit": userLimit,
                ":uid": niarimUserId,
                ":date": date,
                ":type": "DAILY_COUNTER",
                ":ttl": ttl,
              },
            },
          },
          {
            Update: {
              TableName: tableName(),
              Key: globalKey,
              UpdateExpression:
                "SET niarimUserId = :uid, #d = :date, itemType = :type, #ttl = :ttl ADD #c :one",
              ConditionExpression: "attribute_not_exists(#c) OR #c < :limit",
              ExpressionAttributeNames: { "#c": "count", "#d": "date", "#ttl": "ttl" },
              ExpressionAttributeValues: {
                ":one": 1,
                ":limit": DAILY_POST_LIMIT_GLOBAL,
                ":uid": GLOBAL_COUNTER_USER_ID,
                ":date": date,
                ":type": "DAILY_COUNTER",
                ":ttl": ttl,
              },
            },
          },
        ],
      }),
    );
  } catch (err) {
    if (
      err instanceof TransactionCanceledException ||
      err instanceof ConditionalCheckFailedException
    ) {
      conflict(
        "本日の投稿上限に達しています。日をまたぐと投稿できるようになります。",
        "POST_QUOTA_EXCEEDED",
      );
    }
    throw err;
  }
}

/** 今日の投稿枠の残り（`GET /me/post-quota`の応答）。 */
export interface PostQuotaStatus {
  /** この利用者の1日の上限（会員種別・特典で決まる）。 */
  limit: number;
  /** この利用者が今日（UTCの日付）すでに使った数。 */
  used: number;
  /** 今投稿できる数。利用者の残りとNIARIM全体の残りの小さい方（0以上）。 */
  remaining: number;
}

/**
 * 今日の投稿枠を読むだけ（書き込まない）。アプリはYouTubeへアップロードする
 * 前にこれを見て、枠が無ければアップロードを始めない（アップロードした後で
 * `POST /works`が409になり、動画だけがYouTubeに残るのを防ぐ）。
 *
 * カウンターのキー・日付・会員種別の決め方は`reservePostQuota`と同じ。
 * 決めるのは今までどおり`reservePostQuota`の条件付き書き込みで、ここは目安
 * （読んでからアップロードし終えるまでに、別の端末の投稿で枠が埋まることは
 * ある）。読むのは利用者と全体のカウンターの2件だけ（インデックスは使わない）。
 */
export async function readPostQuota(
  niarimUserId: string,
  tier: MembershipTier,
  now: Date = new Date(),
): Promise<PostQuotaStatus> {
  const date = todayYyyymmdd(now);
  const [effectiveTier, used, globalUsed] = await Promise.all([
    resolvePostMembershipTier(niarimUserId, tier, now),
    readCounter(Keys.dailyCounter(niarimUserId, date)),
    readCounter(Keys.dailyCounter(GLOBAL_COUNTER_USER_ID, date)),
  ]);
  const limit = DAILY_POST_LIMIT_PER_USER[effectiveTier];
  const remaining = Math.max(
    0,
    Math.min(limit - used, DAILY_POST_LIMIT_GLOBAL - globalUsed),
  );
  return { limit, used, remaining };
}

async function readCounter(key: { pk: string; sk: string }): Promise<number> {
  const result = await ddb.send(
    new GetCommand({ TableName: tableName(), Key: key, ConsistentRead: true }),
  );
  const count = result.Item?.count;
  return typeof count === "number" && Number.isSafeInteger(count) && count > 0
    ? count
    : 0;
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
            UpdateExpression: "ADD #c :minusOne",
            ConditionExpression: "attribute_exists(#c) AND #c > :zero",
            ExpressionAttributeNames: { "#c": "count" },
            ExpressionAttributeValues: { ":minusOne": -1, ":zero": 0 },
          }),
        )
        .catch((err: unknown) => {
          // 既に0まで戻っている等は無視してよい（解放は best-effort）。
          if (!(err instanceof ConditionalCheckFailedException)) throw err;
        }),
    ),
  );
}
