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
  /** Initial non-cash coins. Ranking missions may use a difficulty multiplier. */
  coins: number;
  /** true: claimed once per WORK, false: claimed once per NIARIM User ID */
  perWork: boolean;
  eachWorkBookmarks?: number;
}

export const MISSION_CATALOG_VERSION = "creator-v3" as const;
export const CREATOR_MISSIONS: readonly MissionDefinition[] = Object.freeze([
  { id: "edit_1h", bit: 0, kind: "verifiedEditSeconds", required: 3600, coins: 30, perWork: false },
  { id: "edit_5h", bit: 1, kind: "verifiedEditSeconds", required: 18000, coins: 100, perWork: false },
  { id: "edit_20h", bit: 2, kind: "verifiedEditSeconds", required: 72000, coins: 1000, perWork: false },
  { id: "edit_50h", bit: 3, kind: "verifiedEditSeconds", required: 180000, coins: 55000, perWork: false },
  { id: "edit_100h", bit: 4, kind: "verifiedEditSeconds", required: 360000, coins: 1500, perWork: false },
  { id: "edit_10h", bit: 17, kind: "verifiedEditSeconds", required: 36000, coins: 300, perWork: false },
  { id: "edit_250h", bit: 18, kind: "verifiedEditSeconds", required: 900000, coins: 3000, perWork: false },
  { id: "edit_500h", bit: 19, kind: "verifiedEditSeconds", required: 1800000, coins: 5000, perWork: false },
  { id: "edit_1000h", bit: 20, kind: "verifiedEditSeconds", required: 3600000, coins: 8000, perWork: false },
  { id: "edit_2500h", bit: 21, kind: "verifiedEditSeconds", required: 9000000, coins: 15000, perWork: false },
  { id: "edit_5000h", bit: 22, kind: "verifiedEditSeconds", required: 18000000, coins: 25000, perWork: false },
  { id: "edit_10000h", bit: 23, kind: "verifiedEditSeconds", required: 36000000, coins: 50000, perWork: false },
  { id: "edit_25000h", bit: 24, kind: "verifiedEditSeconds", required: 90000000, coins: 100000, perWork: false },
  { id: "edit_50000h", bit: 25, kind: "verifiedEditSeconds", required: 180000000, coins: 175000, perWork: false },
  { id: "edit_100000h", bit: 26, kind: "verifiedEditSeconds", required: 360000000, coins: 300000, perWork: false },
  { id: "followers_10", bit: 10, kind: "followers", required: 10, coins: 50, perWork: false },
  { id: "followers_50", bit: 11, kind: "followers", required: 50, coins: 200, perWork: false },
  { id: "followers_100", bit: 12, kind: "followers", required: 100, coins: 400, perWork: false },
  { id: "followers_500", bit: 27, kind: "followers", required: 500, coins: 700, perWork: false },
  { id: "followers_1000", bit: 28, kind: "followers", required: 1000, coins: 1200, perWork: false },
  { id: "followers_5000", bit: 29, kind: "followers", required: 5000, coins: 2500, perWork: false },
  { id: "followers_10000", bit: 30, kind: "followers", required: 10000, coins: 4000, perWork: false },
  { id: "followers_50000", bit: 31, kind: "followers", required: 50000, coins: 10000, perWork: false },
  { id: "followers_100000", bit: 32, kind: "followers", required: 100000, coins: 20000, perWork: false },
  { id: "followers_250000", bit: 33, kind: "followers", required: 250000, coins: 35000, perWork: false },
  { id: "followers_500000", bit: 34, kind: "followers", required: 500000, coins: 55000, perWork: false },
  { id: "followers_1000000", bit: 35, kind: "followers", required: 1000000, coins: 100000, perWork: false },
  { id: "work_posted", bit: 0, kind: "workBookmarks", required: 0, coins: 20, perWork: true },
  { id: "work_bookmarks_20", bit: 1, kind: "workBookmarks", required: 20, coins: 80, perWork: true },
  { id: "work_bookmarks_30", bit: 2, kind: "workBookmarks", required: 30, coins: 110, perWork: true },
  { id: "work_bookmarks_40", bit: 3, kind: "workBookmarks", required: 40, coins: 130, perWork: true },
  { id: "work_bookmarks_60", bit: 4, kind: "workBookmarks", required: 60, coins: 190, perWork: true },
  { id: "work_bookmarks_70", bit: 8, kind: "workBookmarks", required: 70, coins: 220, perWork: true },
  { id: "work_bookmarks_80", bit: 9, kind: "workBookmarks", required: 80, coins: 240, perWork: true },
  { id: "work_bookmarks_90", bit: 10, kind: "workBookmarks", required: 90, coins: 270, perWork: true },
  { id: "work_bookmarks_150", bit: 11, kind: "workBookmarks", required: 150, coins: 360, perWork: true },
  { id: "work_bookmarks_200", bit: 12, kind: "workBookmarks", required: 200, coins: 430, perWork: true },
  { id: "work_bookmarks_250", bit: 17, kind: "workBookmarks", required: 250, coins: 490, perWork: true },
  { id: "work_bookmarks_300", bit: 18, kind: "workBookmarks", required: 300, coins: 550, perWork: true },
  { id: "work_bookmarks_350", bit: 19, kind: "workBookmarks", required: 350, coins: 610, perWork: true },
  { id: "work_bookmarks_400", bit: 20, kind: "workBookmarks", required: 400, coins: 680, perWork: true },
  { id: "work_bookmarks_450", bit: 21, kind: "workBookmarks", required: 450, coins: 740, perWork: true },
  { id: "work_bookmarks_600", bit: 22, kind: "workBookmarks", required: 600, coins: 940, perWork: true },
  { id: "work_bookmarks_700", bit: 23, kind: "workBookmarks", required: 700, coins: 1080, perWork: true },
  { id: "work_bookmarks_800", bit: 24, kind: "workBookmarks", required: 800, coins: 1220, perWork: true },
  { id: "work_bookmarks_900", bit: 25, kind: "workBookmarks", required: 900, coins: 1360, perWork: true },
  { id: "work_bookmarks_10", bit: 5, kind: "workBookmarks", required: 10, coins: 50, perWork: true },
  { id: "work_bookmarks_50", bit: 6, kind: "workBookmarks", required: 50, coins: 150, perWork: true },
  { id: "work_bookmarks_100", bit: 7, kind: "workBookmarks", required: 100, coins: 300, perWork: true },
  { id: "work_bookmarks_500", bit: 46, kind: "workBookmarks", required: 500, coins: 800, perWork: true },
  { id: "work_bookmarks_1000", bit: 47, kind: "workBookmarks", required: 1000, coins: 1500, perWork: true },
  { id: "bookmark_rank_50", bit: 13, kind: "niarimBookmarkRanking", required: 50, coins: 100, perWork: true },
  { id: "bookmark_rank_10", bit: 14, kind: "niarimBookmarkRanking", required: 10, coins: 300, perWork: true },
  { id: "bookmark_rank_3", bit: 15, kind: "niarimBookmarkRanking", required: 3, coins: 600, perWork: true },
  { id: "bookmark_rank_1", bit: 16, kind: "niarimBookmarkRanking", required: 1, coins: 1000, perWork: true },
]);

export const ACCOUNT_MISSIONS = CREATOR_MISSIONS.filter((m) => !m.perWork);
export const PER_WORK_MISSIONS = CREATOR_MISSIONS.filter((m) => m.perWork);

/** Account-wide guaranteed MAX; per-work missions have no account-wide cap. */
export const MAX_CREATOR_MISSION_COINS = ACCOUNT_MISSIONS.reduce(
  (sum, m) => sum + m.coins, 0,
);

/**
 * A published-work population bracket, updated by the EXISTING statistics
 * scan, increases future NIARIM-native bookmark rank rewards. No read-heavy
 * COUNT across all works is needed during a claim.
 *
 * Untrusted/unknown population uses x1; a 48h held offer must freeze the
 * quoted amount rather than retroactively changing it.
 */
export function rankingDifficultyMultiplier(publishedWorkCount: number): number {
  if (!Number.isSafeInteger(publishedWorkCount) || publishedWorkCount < 0) {
    return 1;
  }
  if (publishedWorkCount >= 1_000_000) return 5;
  if (publishedWorkCount >= 100_000) return 4;
  if (publishedWorkCount >= 10_000) return 3;
  if (publishedWorkCount >= 1_000) return 2;
  return 1;
}

export function missionRewardCoins(
  mission: MissionDefinition, publishedWorkCount = 0,
): number {
  return mission.kind === "niarimBookmarkRanking"
    ? mission.coins * rankingDifficultyMultiplier(publishedWorkCount)
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
