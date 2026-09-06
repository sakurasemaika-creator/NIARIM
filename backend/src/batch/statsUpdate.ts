import {
  ConditionalCheckFailedException,
} from "@aws-sdk/client-dynamodb";
import { LambdaClient, InvokeCommand } from "@aws-sdk/client-lambda";
import {
  GetCommand,
  PutCommand,
  ScanCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../lib/dynamo";
import { batchGetVideoStats } from "../lib/youtube";
import {
  computePeriodScore,
  computeRankingScore,
  currentWindowId,
  insertIntoTopList,
  rollStatsWindows,
  DELTA_RANKING_PERIODS,
  RANKING_TOP_LIMIT,
  type DeltaRankingPeriod,
  type RankingSnapshotEntry,
} from "../lib/ranking";
import type { RankingSnapshotItem, WorkItem } from "../lib/types";
import { TABLE_ITEM_TYPE } from "../lib/types";

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
const MAX_VISIBILITY_CONFLICT_RETRIES = 2;

/** 期間別ランキングの集計途中経過（ページ間で持ち回る）。 */
type TopLists = Record<DeltaRankingPeriod, RankingSnapshotEntry[]>;

interface BatchPayload {
  lastEvaluatedKey?: Record<string, unknown>;
  pageIndex?: number;
  /**
   * 8.2節：期間別ランキングの途中集計。ページごとの自己再帰呼び出しに
   * 載せて持ち回る。4期間×50件×{workId(11文字), score}なのでJSONでも
   * 10KB未満に収まり、Lambdaの非同期ペイロード上限（256KB）に対して
   * 十分小さい。
   */
  topLists?: TopLists;
}

function emptyTopLists(): TopLists {
  return { yearly: [], monthly: [], weekly: [], daily: [] };
}

export async function handler(event: BatchPayload = {}): Promise<void> {
  const pageIndex = event.pageIndex ?? 0;
  if (pageIndex >= MAX_PAGES) {
    console.error(
      `統計更新バッチが最大反復回数（${MAX_PAGES}）に達したため中断します。`,
    );
    return;
  }

  const apiKey = requireEnv("YOUTUBE_API_KEY");

  const scanResult = await ddb.send(
    new ScanCommand({
      TableName: tableName(),
      FilterExpression: "itemType = :type",
      ExpressionAttributeValues: { ":type": "WORK" },
      Limit: PAGE_SIZE,
      ExclusiveStartKey: event.lastEvaluatedKey as never,
    }),
  );

  const works = (scanResult.Items ?? []) as WorkItem[];
  const topLists = event.topLists ?? emptyTopLists();
  await processPage(works, apiKey, topLists);

  if (scanResult.LastEvaluatedKey) {
    await invokeSelfAsync({
      lastEvaluatedKey: scanResult.LastEvaluatedKey,
      pageIndex: pageIndex + 1,
      topLists,
    });
    return;
  }

  // 全作品を見終わったので、期間別ランキングを確定して書き出す（8.2節）。
  await writeRankingSnapshots(topLists);

  // 全ページの処理が完了：「最終更新完了日時」を記録する（8.1節）。
  // 表示側（GSI Query）は更新途中の中途半端な状態を参照しないよう、
  // rankingScore自体はページ処理のたびに随時反映済みだが、この完了
  // 印は監視・デバッグ用途（次回実行までにバッチが完走したかの確認）
  // に使う。
  await ddb.send(
    new UpdateCommand({
      TableName: tableName(),
      Key: Keys.batchState(),
      UpdateExpression:
        "SET itemType = :type, lastCompletedAt = :now, inProgress = :false",
      ExpressionAttributeValues: {
        ":type": "BATCH_STATE",
        ":now": new Date().toISOString(),
        ":false": false,
      },
    }),
  );
}

async function processPage(
  works: WorkItem[],
  apiKey: string,
  topLists: TopLists,
): Promise<void> {
  if (works.length === 0) return;

  // videos.batchGetStatsの1回あたり件数上限は【要確認】（youtube.ts参照）。
  // 保守的に50件ずつのチャンクへ分割して呼び出す。
  const chunks = chunk(works, 50);
  for (const workChunk of chunks) {
    const stats = await batchGetVideoStats(
      workChunk.map((w) => w.youtubeVideoId),
      apiKey,
    );
    await Promise.all(
      workChunk.map((work) =>
        updateWorkStats(work, stats.get(work.youtubeVideoId), topLists),
      ),
    );
  }
}

async function updateWorkStats(
  work: WorkItem,
  stats:
    | {
        viewCount: number;
        likeCount: number;
        commentCount: number;
        privacyStatus: "public" | "unlisted" | "private";
      }
    | undefined,
  topLists: TopLists,
  conflictAttempt = 0,
): Promise<void> {
  const nowDate = new Date();
  const now = nowDate.toISOString();

  // videos.batchGetStatsで取得できなかった動画はYouTube側で削除済みと
  // みなす（13章の状態表）。
  const youtubePrivacyStatus = stats ? stats.privacyStatus : "deleted";
  const viewCount = stats?.viewCount ?? work.viewCount;
  const likeCount = stats?.likeCount ?? work.likeCount;
  const commentCount = stats?.commentCount ?? work.commentCount;
  const rankingScore = computeRankingScore({
    viewCount,
    likeCount,
    commentCount,
  });

  // 13章：非公開(private)・削除済み(deleted)は強制非表示。それ以外
  // （public/unlisted）は、NIARIM側のisNiarimPublished設定どおりに表示。
  const forcedHidden =
    youtubePrivacyStatus === "private" || youtubePrivacyStatus === "deleted";
  const isVisible = work.isNiarimPublished && !forcedHidden;

  const setParts = [
    "viewCount = :view",
    "likeCount = :like",
    "commentCount = :comment",
    "lastFetchedAt = :now",
    "youtubePrivacyStatus = :status",
  ];
  const values: Record<string, unknown> = {
    ":view": viewCount,
    ":like": likeCount,
    ":comment": commentCount,
    ":now": now,
    ":status": youtubePrivacyStatus,
    ":expectedPublished": work.isNiarimPublished,
  };
  const removes: string[] = [];
  const conditions = ["isNiarimPublished = :expectedPublished"];

  // 8.2節：期間別ランキング用スナップショットを現在の窓へ進める。
  // 窓が変わっていなければ基準点は据え置かれ、期間中スコアが積み上がる。
  const current = { viewCount, likeCount, commentCount };
  const statsWindows = rollStatsWindows(work.statsWindows, current, nowDate);
  setParts.push("statsWindows = :windows");
  values[":windows"] = statsWindows;

  if (isVisible) {
    // 累計ランキングだけはYouTube統計に合わせて毎回更新する。
    setParts.push(
      "rankingScore = :score",
      "gsi1pk = :rankPk",
      "gsi1sk = :score",
    );
    values[":score"] = rankingScore;
    values[":rankPk"] = "RANKING#ALL";

    // ブックマークGSI・作者GSI・新着GSIは通常の可視作品なら別処理が常に
    // 最新状態を保っているので触らない。YouTube非公開→公開復帰などで
    // インデックスが欠けている場合だけ復元する。復元時はScan後に
    // bookmarkCountが変わっていないことも条件に入れ、古い値をgsi2skへ
    // 書き戻さない。
    const hasPublicIndexes =
      work.gsi2pk != null &&
      work.gsi2sk != null &&
      work.gsi3pk != null &&
      work.gsi3sk != null &&
      work.gsi4pk != null &&
      work.gsi4sk != null;
    if (!hasPublicIndexes) {
      setParts.push(
        "gsi2pk = :bmPk",
        "gsi2sk = :bm",
        "gsi3pk = :authorPk",
        "gsi3sk = :postedAt",
        "gsi4pk = :latestPk",
        "gsi4sk = :postedAt",
      );
      values[":bmPk"] = "BOOKMARK_RANKING";
      values[":bm"] = work.bookmarkCount;
      values[":authorPk"] = `AUTHOR#${work.authorId}`;
      values[":postedAt"] = work.postedAt;
      values[":latestPk"] = "LATEST";
      values[":expectedBookmarkCount"] = work.bookmarkCount;
      conditions.push("bookmarkCount = :expectedBookmarkCount");
    }
  } else {
    removes.push(
      "rankingScore",
      "gsi1pk",
      "gsi1sk",
      "gsi2pk",
      "gsi2sk",
      "gsi3pk",
      "gsi3sk",
      "gsi4pk",
      "gsi4sk",
    );
  }

  const updateExpression =
    `SET ${setParts.join(", ")}` +
    (removes.length ? ` REMOVE ${removes.join(", ")}` : "");

  try {
    await ddb.send(
      new UpdateCommand({
        TableName: tableName(),
        Key: Keys.work(work.workId),
        UpdateExpression: updateExpression,
        ConditionExpression: conditions.join(" AND "),
        ExpressionAttributeValues: values,
      }),
    );
  } catch (error) {
    if (
      error instanceof ConditionalCheckFailedException &&
      conflictAttempt < MAX_VISIBILITY_CONFLICT_RETRIES
    ) {
      // Scan後に作者の公開設定またはブックマーク数が変わった。最新Itemを
      // 読み直し、同じYouTube統計値を使って条件・GSIを組み直す。
      const latestResult = await ddb.send(
        new GetCommand({ TableName: tableName(), Key: Keys.work(work.workId) }),
      );
      const latest = latestResult.Item as WorkItem | undefined;
      if (latest) {
        await updateWorkStats(latest, stats, topLists, conflictAttempt + 1);
      }
      return;
    }
    if (error instanceof ConditionalCheckFailedException) {
      // 公開設定を連続操作中などで競合が続く場合は、古いScan結果で公開状態を
      // 上書きするより、この作品の統計更新を次サイクルへ回す方を優先する。
      console.warn(
        `作品${work.workId}の統計更新を公開設定競合のためスキップしました`,
      );
      return;
    }
    throw error;
  }

  // ランキング途中集計は、DynamoDB更新が成功して「この作品が現在も可視」
  // と確認できた後にだけ追加する。競合前の古い公開状態でTop50へ混入させない。
  if (isVisible) {
    for (const period of DELTA_RANKING_PERIODS) {
      const score = computePeriodScore(current, statsWindows[period]);
      topLists[period] = insertIntoTopList(
        topLists[period],
        { workId: work.workId, score },
        RANKING_TOP_LIMIT,
      );
    }
  }
}

/**
 * 期間別ランキングを`RANKINGSNAPSHOT#{PERIOD}`へ書き出す（8.2節）。
 * 期間ごとに1アイテムなので書き込みは4回だけで、GSIも増えない。
 * 途中でバッチが失敗した場合は前回のスナップショットが残るため、
 * 「順位が古いまま」にはなっても壊れた順位は表示されない。
 */
async function writeRankingSnapshots(topLists: TopLists): Promise<void> {
  const now = new Date();
  await Promise.all(
    DELTA_RANKING_PERIODS.map((period) => {
      const item: RankingSnapshotItem = {
        itemType: TABLE_ITEM_TYPE.RankingSnapshot,
        ...Keys.rankingSnapshot(period),
        period,
        windowId: currentWindowId(period, now),
        entries: topLists[period],
        computedAt: now.toISOString(),
      };
      return ddb.send(new PutCommand({ TableName: tableName(), Item: item }));
    }),
  );
}

async function invokeSelfAsync(payload: BatchPayload): Promise<void> {
  const functionName = requireEnv("SELF_FUNCTION_NAME");
  const client = new LambdaClient({});
  await client.send(
    new InvokeCommand({
      FunctionName: functionName,
      InvocationType: "Event",
      Payload: Buffer.from(JSON.stringify(payload)),
    }),
  );
}

function chunk<T>(items: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let i = 0; i < items.length; i += size)
    result.push(items.slice(i, i + size));
  return result;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name}環境変数が設定されていません`);
  return value;
}
