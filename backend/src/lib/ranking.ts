/**
 * ランキングスコアの計算（8.1/8.2節）。
 *
 * 仕様書はrankingScoreを「YouTube統計から計算する」とだけ定めており、
 * 厳密な計算式までは規定していない。ここでは一般的な人気度指標として
 * 再生数を主軸に、高評価・コメントを重み付けして加算する式を採用する
 * （荒らし防止のためコメント数の重みは低めにしてある）。将来の
 * チューニング対象として、この関数だけを差し替えれば全体に反映される。
 */
export function computeRankingScore(input: {
  viewCount: number;
  likeCount: number;
  commentCount: number;
}): number {
  const { viewCount, likeCount, commentCount } = input;
  return (
    Math.max(0, viewCount) +
    Math.max(0, likeCount) * 5 +
    Math.max(0, commentCount) * 2
  );
}

/**
 * ランキング期間（1章冒頭・8章・14章）。
 */
export const RANKING_PERIODS = [
  "all",
  "yearly",
  "monthly",
  "weekly",
  "daily",
] as const;
export type RankingPeriod = (typeof RANKING_PERIODS)[number];

/** 期間別（累計を除く）ランキング。統計スナップショットの差分で求める。 */
export const DELTA_RANKING_PERIODS = [
  "yearly",
  "monthly",
  "weekly",
  "daily",
] as const;
export type DeltaRankingPeriod = (typeof DELTA_RANKING_PERIODS)[number];

export function isRankingPeriod(period: string): period is RankingPeriod {
  return (RANKING_PERIODS as readonly string[]).includes(period);
}

export function isDeltaRankingPeriod(
  period: string,
): period is DeltaRankingPeriod {
  return (DELTA_RANKING_PERIODS as readonly string[]).includes(period);
}

/**
 * 期間別ランキングの設計（8.2節）。
 *
 * 「その期間にどれだけ伸びたか」を出すには、期間開始時点の統計を持って
 * おいて現在値との差分を取る必要がある。ただし5章の「1作品2KB」制約が
 * あるため、日次の履歴を全部持つことはできない。
 *
 * そこで各作品には**期間ごとに1点だけ**スナップショットを持たせる
 * （`statsWindows`）。統計更新バッチが作品を触るたびに、
 * 「保存してある窓ID」と「現在の窓ID」を比べ、窓が切り替わっていたら
 * その時点の値で取り直す。保持するのは4期間×3数値＋窓IDだけなので
 * 増えるのは100バイト程度で、2KB制約に収まる。
 *
 * ランキング表示は、期間別のGSIを4本足すとAlways Free枠（25 RCU/WCU）を
 * 明確に超えるため使わない。代わりに、全作品を走査する統計更新バッチが
 * そのついでに期間ごとのTop 50を集計し、`RANKINGSNAPSHOT#{PERIOD}`という
 * 1アイテムへ書き出す。読み出しはGetItem 1回（1 RCU未満）で済み、GSIも
 * 追加の書き込み容量も要らない。順位が更新されるのはバッチ実行時
 * （既定1日2回）だが、期間別ランキングは元々その粒度で十分。
 */

/** 作品が持つ期間別スナップショット。 */
export interface StatsSnapshot {
  windowId: string;
  viewCount: number;
  likeCount: number;
  commentCount: number;
}
export type StatsWindows = Partial<Record<DeltaRankingPeriod, StatsSnapshot>>;

/**
 * 現在の窓ID。UTC基準の固定境界で、年=YYYY・月=YYYYMM・週=ISO週・
 * 日=YYYYMMDD。窓が変わった瞬間に全作品のスナップショットが順次
 * 取り直され、その期間のランキングが0から積み上がる。
 */
export function currentWindowId(
  period: DeltaRankingPeriod,
  now: Date = new Date(),
): string {
  const iso = now.toISOString();
  switch (period) {
    case "yearly":
      return iso.slice(0, 4);
    case "monthly":
      return iso.slice(0, 7).replace("-", "");
    case "weekly":
      return isoWeekId(now);
    case "daily":
      return iso.slice(0, 10).replace(/-/g, "");
  }
}

/** ISO 8601の「年-週番号」（例：2026W36）。週の始まりは月曜。 */
export function isoWeekId(now: Date): string {
  const d = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
  // ISO週：木曜日が属する年をその週の年とする。
  const dayNum = d.getUTCDay() || 7; // 月=1 … 日=7
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(
    ((d.getTime() - yearStart.getTime()) / 86_400_000 + 1) / 7,
  );
  return `${d.getUTCFullYear()}W${String(week).padStart(2, "0")}`;
}

export interface StatsTriple {
  viewCount: number;
  likeCount: number;
  commentCount: number;
}

/**
 * スナップショットを現在の窓へ進める。窓が変わっていなければ既存の
 * スナップショットをそのまま返す（＝期間中は基準点が動かない）。
 * まだスナップショットが無い（新規投稿・機能追加直後）場合は、現在値を
 * 基準点として置く。この場合その期間のスコアは0から始まる。
 */
export function rollStatsWindows(
  existing: StatsWindows | undefined,
  current: StatsTriple,
  now: Date = new Date(),
): StatsWindows {
  const rolled: StatsWindows = {};
  for (const period of DELTA_RANKING_PERIODS) {
    const windowId = currentWindowId(period, now);
    const prev = existing?.[period];
    rolled[period] =
      prev && prev.windowId === windowId ? prev : { windowId, ...current };
  }
  return rolled;
}

/**
 * 期間別スコア。現在値 − 期間開始時点の値をcomputeRankingScoreと同じ
 * 重み付けで合成する。統計が減ることは通常ないが、YouTube側で高評価が
 * 取り消される等で負になり得るため0で下限を切る。
 */
export function computePeriodScore(
  current: StatsTriple,
  snapshot: StatsSnapshot | undefined,
): number {
  if (!snapshot) return 0;
  return computeRankingScore({
    viewCount: current.viewCount - snapshot.viewCount,
    likeCount: current.likeCount - snapshot.likeCount,
    commentCount: current.commentCount - snapshot.commentCount,
  });
}

/** 事前計算したランキングの1件分。 */
export interface RankingSnapshotEntry {
  workId: string;
  score: number;
}

/**
 * Top Nを保つ挿入。バッチはページごとに呼ばれるので、全件をメモリに
 * 載せずに済むよう都度切り詰める。同スコアはworkIdで安定順にする。
 */
export function insertIntoTopList(
  list: RankingSnapshotEntry[],
  entry: RankingSnapshotEntry,
  limit: number,
): RankingSnapshotEntry[] {
  if (entry.score <= 0) return list;
  const merged = [...list.filter((e) => e.workId !== entry.workId), entry];
  merged.sort((a, b) => b.score - a.score || a.workId.localeCompare(b.workId));
  return merged.slice(0, limit);
}

/** ランキングスナップショットに載せる件数（8.2節のTop 50に合わせる）。 */
export const RANKING_TOP_LIMIT = 50;
