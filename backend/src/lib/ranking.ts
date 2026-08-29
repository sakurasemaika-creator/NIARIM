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
  return Math.max(0, viewCount) + Math.max(0, likeCount) * 5 + Math.max(0, commentCount) * 2;
}

/**
 * 現状実装しているランキング期間。
 *
 * 仕様書（1章冒頭・8章・14章）は累計/年間/月間/週間/デイリーの5種類を
 * 掲げているが、期間別（年間〜デイリー）のスコアを効率よく算出するには
 * 「各作品の期間開始時点の統計スナップショット」を保持し、そこからの
 * 差分を取る仕組みが別途必要になる（5章の1作品2KB制約の中で長期の
 * 日次スナップショットを保持するのは現実的でないため、別テーブル or
 * 別の圧縮方式の検討が要る）。この設計自体が仕様書内で確定していない
 * ため、今回のバックエンド実装では**累計（ALL）のみ**を実装し、他の
 * 期間はAPI側で501を返す（ranking.tsルート参照）。将来実装する場合は
 * ここに期間別スコア計算を追加する。
 */
export const IMPLEMENTED_RANKING_PERIODS = ['all'] as const;
export type RankingPeriod = 'all' | 'yearly' | 'monthly' | 'weekly' | 'daily';

export function isImplementedRankingPeriod(
  period: string,
): period is (typeof IMPLEMENTED_RANKING_PERIODS)[number] {
  return (IMPLEMENTED_RANKING_PERIODS as readonly string[]).includes(period);
}
