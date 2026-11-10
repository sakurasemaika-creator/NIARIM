/**
 * Creator missions v2. Award rules are versioned, sourced in code, and NEVER
 * triggered by locally reported work time or YouTube engagement metrics.
 *
 * Account-lifetime missions and per-published-work missions use separate,
 * compact DynamoDB claim bitmasks. IDs/bits are stable across releases.
 * A claimed amount is stored in the wallet and must never be recalculated.
 *
 * This catalog alone does not enable payments or mission claims.
 */
export type MissionKind =
  | "verifiedEditSeconds" | "workBookmarks" | "qualifiedWorks"
  | "followers" | "niarimBookmarkRanking";

export interface MissionDefinition {
  id: string;
  /** Bit indices are stable, max 52 for an exactly representable JS integer. */
  bit: number;
  kind: MissionKind;
  required: number;
  /** Five-coin denominations: each harder goal awards at least 5 more. */
  coins: number;
  /** true: claimed once per WORK, false: claimed once per NIARIM User ID */
  perWork: boolean;
  eachWorkBookmarks?: number;
}

export const MISSION_CATALOG_VERSION = "creator-v9-early-ranking-guard" as const;
export const CREATOR_MISSIONS: readonly MissionDefinition[] = Object.freeze([
  { id: "edit_1h", bit: 0, kind: "verifiedEditSeconds", required: 3600, coins: 5, perWork: false },
  { id: "edit_5h", bit: 1, kind: "verifiedEditSeconds", required: 18000, coins: 10, perWork: false },
  { id: "edit_20h", bit: 2, kind: "verifiedEditSeconds", required: 72000, coins: 20, perWork: false },
  { id: "edit_50h", bit: 3, kind: "verifiedEditSeconds", required: 180000, coins: 25, perWork: false },
  { id: "edit_100h", bit: 4, kind: "verifiedEditSeconds", required: 360000, coins: 30, perWork: false },
  { id: "edit_10h", bit: 17, kind: "verifiedEditSeconds", required: 36000, coins: 15, perWork: false },
  { id: "edit_250h", bit: 18, kind: "verifiedEditSeconds", required: 900000, coins: 35, perWork: false },
  { id: "edit_500h", bit: 19, kind: "verifiedEditSeconds", required: 1800000, coins: 40, perWork: false },
  { id: "edit_1000h", bit: 20, kind: "verifiedEditSeconds", required: 3600000, coins: 45, perWork: false },
  { id: "edit_2500h", bit: 21, kind: "verifiedEditSeconds", required: 9000000, coins: 50, perWork: false },
  { id: "edit_5000h", bit: 22, kind: "verifiedEditSeconds", required: 18000000, coins: 55, perWork: false },
  { id: "edit_10000h", bit: 23, kind: "verifiedEditSeconds", required: 36000000, coins: 60, perWork: false },
  { id: "edit_25000h", bit: 24, kind: "verifiedEditSeconds", required: 90000000, coins: 65, perWork: false },
  { id: "edit_50000h", bit: 25, kind: "verifiedEditSeconds", required: 180000000, coins: 70, perWork: false },
  { id: "edit_100000h", bit: 26, kind: "verifiedEditSeconds", required: 360000000, coins: 75, perWork: false },
  { id: "followers_10", bit: 10, kind: "followers", required: 10, coins: 5, perWork: false },
  { id: "followers_50", bit: 11, kind: "followers", required: 50, coins: 10, perWork: false },
  { id: "followers_100", bit: 12, kind: "followers", required: 100, coins: 15, perWork: false },
  { id: "followers_500", bit: 27, kind: "followers", required: 500, coins: 20, perWork: false },
  { id: "followers_1000", bit: 28, kind: "followers", required: 1000, coins: 25, perWork: false },
  { id: "followers_5000", bit: 29, kind: "followers", required: 5000, coins: 30, perWork: false },
  { id: "followers_10000", bit: 30, kind: "followers", required: 10000, coins: 35, perWork: false },
  { id: "followers_50000", bit: 31, kind: "followers", required: 50000, coins: 40, perWork: false },
  { id: "followers_100000", bit: 32, kind: "followers", required: 100000, coins: 45, perWork: false },
  { id: "followers_250000", bit: 33, kind: "followers", required: 250000, coins: 50, perWork: false },
  { id: "followers_500000", bit: 34, kind: "followers", required: 500000, coins: 55, perWork: false },
  { id: "followers_1000000", bit: 35, kind: "followers", required: 1000000, coins: 60, perWork: false },
  { id: "work_posted", bit: 0, kind: "workBookmarks", required: 0, coins: 5, perWork: true },
  { id: "work_bookmarks_20", bit: 1, kind: "workBookmarks", required: 20, coins: 15, perWork: true },
  { id: "work_bookmarks_30", bit: 2, kind: "workBookmarks", required: 30, coins: 20, perWork: true },
  { id: "work_bookmarks_40", bit: 3, kind: "workBookmarks", required: 40, coins: 25, perWork: true },
  { id: "work_bookmarks_60", bit: 4, kind: "workBookmarks", required: 60, coins: 35, perWork: true },
  { id: "work_bookmarks_70", bit: 8, kind: "workBookmarks", required: 70, coins: 40, perWork: true },
  { id: "work_bookmarks_80", bit: 9, kind: "workBookmarks", required: 80, coins: 45, perWork: true },
  { id: "work_bookmarks_90", bit: 10, kind: "workBookmarks", required: 90, coins: 50, perWork: true },
  { id: "work_bookmarks_150", bit: 11, kind: "workBookmarks", required: 150, coins: 60, perWork: true },
  { id: "work_bookmarks_200", bit: 12, kind: "workBookmarks", required: 200, coins: 65, perWork: true },
  { id: "work_bookmarks_250", bit: 17, kind: "workBookmarks", required: 250, coins: 70, perWork: true },
  { id: "work_bookmarks_300", bit: 18, kind: "workBookmarks", required: 300, coins: 75, perWork: true },
  { id: "work_bookmarks_350", bit: 19, kind: "workBookmarks", required: 350, coins: 80, perWork: true },
  { id: "work_bookmarks_400", bit: 20, kind: "workBookmarks", required: 400, coins: 85, perWork: true },
  { id: "work_bookmarks_450", bit: 21, kind: "workBookmarks", required: 450, coins: 90, perWork: true },
  { id: "work_bookmarks_600", bit: 22, kind: "workBookmarks", required: 600, coins: 100, perWork: true },
  { id: "work_bookmarks_700", bit: 23, kind: "workBookmarks", required: 700, coins: 105, perWork: true },
  { id: "work_bookmarks_800", bit: 24, kind: "workBookmarks", required: 800, coins: 110, perWork: true },
  { id: "work_bookmarks_900", bit: 25, kind: "workBookmarks", required: 900, coins: 115, perWork: true },
  { id: "work_bookmarks_10", bit: 5, kind: "workBookmarks", required: 10, coins: 10, perWork: true },
  { id: "work_bookmarks_50", bit: 6, kind: "workBookmarks", required: 50, coins: 30, perWork: true },
  { id: "work_bookmarks_100", bit: 7, kind: "workBookmarks", required: 100, coins: 55, perWork: true },
  { id: "work_bookmarks_500", bit: 46, kind: "workBookmarks", required: 500, coins: 95, perWork: true },
  { id: "work_bookmarks_1000", bit: 47, kind: "workBookmarks", required: 1000, coins: 120, perWork: true },
  { id: "bookmark_rank_50", bit: 13, kind: "niarimBookmarkRanking", required: 50, coins: 30, perWork: true },
  { id: "bookmark_rank_10", bit: 14, kind: "niarimBookmarkRanking", required: 10, coins: 75, perWork: true },
  { id: "bookmark_rank_3", bit: 15, kind: "niarimBookmarkRanking", required: 3, coins: 125, perWork: true },
  { id: "bookmark_rank_1", bit: 16, kind: "niarimBookmarkRanking", required: 1, coins: 200, perWork: true },
]);

export const ACCOUNT_MISSIONS = CREATOR_MISSIONS.filter((m) => !m.perWork);
export const PER_WORK_MISSIONS = CREATOR_MISSIONS.filter((m) => m.perWork)
  .sort((a, b) => a.kind === "workBookmarks" && b.kind === "workBookmarks"
    ? a.required - b.required : 0);

/** Account-wide guaranteed MAX; per-work missions have no account-wide cap. */
export const MAX_CREATOR_MISSION_COINS = ACCOUNT_MISSIONS.reduce(
  (sum, m) => sum + m.coins, 0,
);

/**
 * Ranking is a rare per-work achievement: top-three baseline rewards exceed
 * the 120 coins for 1,000 bookmarks on a single work. Relative reward
 * strength grows with rank and public work pool size.
 *
 * A published-work population bracket, updated by the EXISTING statistics
 * scan, increases future NIARIM-native bookmark rank rewards. No read-heavy
 * COUNT across all works is needed during a claim.
 *
 * Untrusted/unknown population uses x1; a 48h held offer must freeze the
 * quoted amount rather than retroactively changing it.
 */
/** Server-owned published-work counts, with finer tiers even below 1,000.
 * Count 100 starts at x1; 1,000=x2; 10,000=x3; 100,000=x4;
 * 1,000,000=x5. Intermediate tiers pay progressively more.
 */
export const RANKING_POPULATION_TIERS: readonly number[] = Object.freeze([
  100,150,250,400,600,800,
  1000,1500,2500,4000,6000,8000,
  10000,15000,25000,40000,60000,80000,
  100000,150000,250000,400000,600000,800000,
  1000000,
]);
export const MIN_RANK_MISSION_PUBLIC_WORKS = 100;
export const RANKING_MIN_BOOKMARKS: Readonly<Record<number,number>> =
  Object.freeze({50:5,10:15,3:30,1:50});
const rankingPopulationStep = (publishedWorkCount: number): number => {
  if (!Number.isSafeInteger(publishedWorkCount) || publishedWorkCount < 0) return 0;
  let index = 0;
  for (let i=0;i<RANKING_POPULATION_TIERS.length;i++) {
    if (publishedWorkCount < RANKING_POPULATION_TIERS[i]) break;
    index=i;
  }
  return index;
};
export function rankingDifficultyMultiplier(publishedWorkCount: number): number {
  return 1 + rankingPopulationStep(publishedWorkCount) / 6;
}
/** At launch, ranking 50th out of just 50 works is not an achievement.
 * The relative threshold prevents "top ten by merely posting". A genuine
 * NIARIM bookmark count is required in addition to the live position.
 */
export function rankingMissionEligible(args: {
  goalRank: number; liveRank: number; publishedWorkCount: number;
  workBookmarks: number;
}): boolean {
  const {goalRank,liveRank,publishedWorkCount,workBookmarks}=args;
  const minimum=RANKING_MIN_BOOKMARKS[goalRank];
  if (minimum===undefined ||
      !Number.isSafeInteger(publishedWorkCount) ||
      publishedWorkCount < MIN_RANK_MISSION_PUBLIC_WORKS ||
      !Number.isSafeInteger(workBookmarks) || workBookmarks<minimum ||
      !Number.isSafeInteger(liveRank) || liveRank<1) return false;
  const percentile=goalRank===50 ? 10 : goalRank===10 ? 5 :
    goalRank===3 ? 3 : 1;
  const limit=Math.min(goalRank,
    Math.max(1,Math.floor(publishedWorkCount*percentile/100)));
  return liveRank<=limit;
}

export function missionRewardCoins(
  mission: MissionDefinition, publishedWorkCount = 0,
): number {
  // The 10-coin ad reward is not a mission cap.
  // Multiply as integer sixths then round UP to 5 coins. An early tier
  // cannot collapse onto the same reward as the preceding tier.
  return mission.kind === "niarimBookmarkRanking"
    ? 5 * Math.ceil(mission.coins * (6 + rankingPopulationStep(publishedWorkCount)) / 30)
    : mission.coins;
}

export function missionClaimed(mask: number, bit: number): boolean {
  if (!Number.isSafeInteger(mask) || mask < 0 ||
      !Number.isSafeInteger(bit) || bit < 0 || bit > 52) return false;
  return Math.floor(mask / 2 ** bit) % 2 === 1;
}

export function claimMissionInMask(mask: number, bit: number): number {
  if (!Number.isSafeInteger(mask) || mask < 0 ||
      !Number.isSafeInteger(bit) || bit < 0 || bit > 52) {
    throw new Error("Invalid mission mask");
  }
  if (missionClaimed(mask, bit)) return mask;
  const result = mask + 2 ** bit;
  if (!Number.isSafeInteger(result)) throw new Error("Mission mask overflow");
  return result;
}

/** One compact record per account (no per-action production logs). */
export interface CreatorMissionState {
  itemType: "CREATOR_MISSIONS_V1";
  claimedMask: number;
  verifiedEditSeconds: number;
  totalMissionCoins: number;
  firstQualifiedAt?: Record<string, number>;
  claimedAt?: Record<string, number>;
  /** Snapshot of server quoted coin amount during 48h verification window. */
  pendingCoins?: Record<string, number>;
}

/** One compact record only when a specific published work earns missions. */
export interface CreatorWorkMissionState {
  itemType: "CREATOR_WORK_MISSIONS_V1";
  claimedMask: number;
  revision: number;
  firstQualifiedAt?: Record<string, number>;
  claimedAt?: Record<string, number>;
  pendingCoins?: Record<string, number>;
}
