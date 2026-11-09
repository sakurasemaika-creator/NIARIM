import type { TransactWriteCommandInput } from "@aws-sdk/lib-dynamodb";
import { currentWindowId } from "./ranking";
import { Keys, tableName } from "./dynamo";

/**
 * Calendar-period leaderboards count new bookmarks in the named JST window.
 * Reuses existing GSI2 (no new provisioned indexes). Each score changes in
 * the SAME Dynamo transaction as bookmark creation/deletion and all-time count.
 */
export const BOOKMARK_PERIODS = ["daily","weekly","monthly","yearly"] as const;
export type BookmarkPeriod = (typeof BOOKMARK_PERIODS)[number];
export const PERIOD_SCORE_VERSION = 1;

export function isBookmarkPeriod(s: string): s is BookmarkPeriod {
  return (BOOKMARK_PERIODS as readonly string[]).includes(s);
}
export function bookmarkPeriodPartition(period: BookmarkPeriod, now: Date): string {
  return "BOOKMARK_PERIOD#" + period.toUpperCase() + "#" + currentWindowId(period, now);
}
export function periodScoreKey(workId: string, period: BookmarkPeriod, now: Date) {
  return Keys.periodBookmarkScore(workId, period, currentWindowId(period, now));
}
export function periodScoreTtl(period: BookmarkPeriod, now: Date): number {
  const days = {daily: 3, weekly: 14, monthly: 62, yearly: 400}[period];
  return Math.floor(now.getTime()/1000) + days*86400;
}
export function periodsStillInWindow(recordedAt: string|undefined, now: Date): BookmarkPeriod[] {
  if (typeof recordedAt !== "string") return [];
  const at=new Date(recordedAt);
  if (!Number.isFinite(at.getTime()) || at.getTime() > now.getTime()) return [];
  return BOOKMARK_PERIODS.filter(
    period => currentWindowId(period, at) === currentWindowId(period, now),
  );
}
type TxItems = NonNullable<TransactWriteCommandInput["TransactItems"]>;

/** Unmarked bookmarks from before rollout must NOT decrement a missing
 * counter on removal; they were never added to period leaderboards. */
export function periodBookmarkWrites(
  workId: string, periods: readonly BookmarkPeriod[],
  delta: 1|-1, now: Date,
): TxItems {
  return periods.map(period => ({
    Update: {
      TableName: tableName(),
      Key: periodScoreKey(workId,period,now),
      UpdateExpression:
        "SET #kind = :kind, #work = :work, #period = :period, " +
        "#window = :window, #partition = :partition, #expiry = :expiry " +
        "ADD #score :delta, #sort :delta",
      ...(delta < 0
        ? {ConditionExpression:"attribute_exists(pk) AND #score >= :one"}
        : {}),
      ExpressionAttributeNames: {
        "#kind":"itemType","#work":"workId","#period":"period",
        "#window":"windowId","#partition":"gsi2pk","#expiry":"ttl",
        "#score":"score","#sort":"gsi2sk",
      },
      ExpressionAttributeValues: {
        ":kind":"BOOKMARK_PERIOD_SCORE",":work":workId,
        ":period":period,":window":currentWindowId(period,now),
        ":partition":bookmarkPeriodPartition(period,now),
        ":expiry":periodScoreTtl(period,now),
        ":delta":delta,...(delta<0?{":one":1}:{}),
      },
    },
  }));
}
