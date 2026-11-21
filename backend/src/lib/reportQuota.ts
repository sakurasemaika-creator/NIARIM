import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "./dynamo";
import { conflict } from "./response";

/**
 * 通報レート制限（20章）の本格実装。
 *
 * 初期実装はGSI7（REPORT_STATUSインデックス）を`pending`で丸ごと引いて
 * から通報者でフィルタしていたが、これは通報が増えるほど1回の通報で
 * 読む件数が増え、しかも「他人の通報」まで読むため無駄が大きい。また
 * 対応済み（resolved）へ status が変わった通報はGSI7の`pending`
 * パーティションから消えるため、運営が処理した直後だけレート制限が
 * ゆるむという実質的な穴もあった。
 *
 * ここでは通報者ごと・時間窓ごとの専用カウンターへ切り替える。
 * `ADD`による原子的インクリメントと`ConditionExpression`で上限判定を
 * 1回のUpdateItemにまとめるため、同時リクエストでもすり抜けない
 * （quota.tsの投稿枠予約と同じ考え方）。カウンターはTTLで自動失効
 * するので、掃除も不要。
 */

/** 短期の連投を止める窓（分）。 */
export const REPORT_WINDOW_MINUTES = 10;
/** 短期窓での上限件数。 */
export const REPORT_MAX_PER_WINDOW = 5;
/** 1日単位の上限件数（短期窓を待ってから再開する荒らしを止める）。 */
export const REPORT_MAX_PER_DAY = 20;

/**
 * 時間窓のID。`REPORT_WINDOW_MINUTES`ごとに切り上がる固定境界にする
 * （スライディングウィンドウではないため、窓の境目では最大2倍まで
 * 通れる。荒らし対策としてはこの粒度で十分で、そのぶん読み書きが
 * 1回で済む）。
 */
export function reportWindowId(now: Date = new Date()): string {
  const bucket = Math.floor(
    now.getTime() / (REPORT_WINDOW_MINUTES * 60 * 1000),
  );
  return `W${bucket}`;
}

/** 日単位の窓ID（UTC基準）。 */
export function reportDayWindowId(now: Date = new Date()): string {
  return `D${now.toISOString().slice(0, 10).replace(/-/g, "")}`;
}

function ttlSeconds(now: Date, windowMinutes: number): number {
  // 窓の長さ＋余裕を持たせて失効させる。
  return Math.floor(now.getTime() / 1000) + windowMinutes * 60 * 2;
}

/**
 * 通報を1件分予約する。上限に達している場合は409を投げる。
 *
 * 短期窓 → 日次窓 の順に確認する。短期窓が通って日次窓で弾かれた場合、
 * 短期窓のカウントは1つ進んだままになるが、これは「弾かれた通報も
 * 試行としては数える」という保守的な側に倒れるだけなので許容する
 * （逆にロールバックすると、日次上限に達したユーザーが短期窓を無限に
 * 叩けてしまい、UpdateItemの書き込み量が青天井になる）。
 */
export async function reserveReportQuota(
  reporterId: string,
  now: Date = new Date(),
): Promise<void> {
  await incrementOrReject(
    reporterId,
    reportWindowId(now),
    REPORT_MAX_PER_WINDOW,
    ttlSeconds(now, REPORT_WINDOW_MINUTES),
  );
  await incrementOrReject(
    reporterId,
    reportDayWindowId(now),
    REPORT_MAX_PER_DAY,
    ttlSeconds(now, 24 * 60),
  );
}

async function incrementOrReject(
  reporterId: string,
  windowId: string,
  limit: number,
  ttl: number,
): Promise<void> {
  try {
    await ddb.send(
      new UpdateCommand({
        TableName: tableName(),
        Key: Keys.reportCounter(reporterId, windowId),
        UpdateExpression:
          "SET itemType = :type, reporterId = :rid, windowId = :wid, ttl = :ttl ADD #c :one",
        ConditionExpression: "attribute_not_exists(#c) OR #c < :limit",
        ExpressionAttributeNames: { "#c": "count" },
        ExpressionAttributeValues: {
          ":one": 1,
          ":limit": limit,
          ":type": "REPORT_COUNTER",
          ":rid": reporterId,
          ":wid": windowId,
          ":ttl": ttl,
        },
      }),
    );
  } catch (err) {
    if (err instanceof ConditionalCheckFailedException) {
      conflict(
        "通報が短時間に集中しています。しばらく時間をおいてから再度お試しください。",
        "REPORT_RATE_LIMITED",
      );
    }
    throw err;
  }
}
