/**
 * NIARIM creator missions, v1. One-time rewards; no recurring streaks that
 * encourage leaving the app open or farming engagement.
 *
 * IMPORTANT: prices are non-cash coins, not yen or guaranteed revenue.
 * These mission awards do not have associated AdMob impression revenue.
 * Awarding them must be budgeted separately from SSV-backed ad coins.
 *
 * IDs and bit positions are PERMANENT. To change an award, create a new
 * versioned mission instead of changing the amount under an old ID.
 */
export type MissionKind =
  | "verifiedEditSeconds"
  | "workBookmarks"
  | "qualifiedWorks"
  | "followers"
  | "niarimBookmarkRanking";

export interface MissionDefinition {
  id: string;
  bit: number;
  kind: MissionKind;
  required: number;
  coins: number;
  /** For qualifiedWorks: number of bookmarks required per unique work. */
  eachWorkBookmarks?: number;
}

export const MISSION_CATALOG_VERSION = "creator-v1" as const;

export const CREATOR_MISSIONS: readonly MissionDefinition[] = Object.freeze([
  // NOTE: time-based missions remain ineligible until server-validated active
  // editing sessions are implemented. Local Project.totalWorkSeconds is not proof.
  { id: "edit_1h", bit: 0, kind: "verifiedEditSeconds", required: 3600, coins: 30 },
  { id: "edit_5h", bit: 1, kind: "verifiedEditSeconds", required: 18000, coins: 100 },
  { id: "edit_20h", bit: 2, kind: "verifiedEditSeconds", required: 72000, coins: 300 },
  { id: "edit_50h", bit: 3, kind: "verifiedEditSeconds", required: 180000, coins: 600 },
  { id: "edit_100h", bit: 4, kind: "verifiedEditSeconds", required: 360000, coins: 1200 },

  { id: "work_bookmarks_10", bit: 5, kind: "workBookmarks", required: 10, coins: 50 },
  { id: "work_bookmarks_50", bit: 6, kind: "workBookmarks", required: 50, coins: 150 },
  { id: "work_bookmarks_100", bit: 7, kind: "workBookmarks", required: 100, coins: 300 },
  { id: "works_3_x_10", bit: 8, kind: "qualifiedWorks", required: 3, eachWorkBookmarks: 10, coins: 150 },
  { id: "works_5_x_20", bit: 9, kind: "qualifiedWorks", required: 5, eachWorkBookmarks: 20, coins: 400 },

  { id: "followers_10", bit: 10, kind: "followers", required: 10, coins: 50 },
  { id: "followers_50", bit: 11, kind: "followers", required: 50, coins: 200 },
  { id: "followers_100", bit: 12, kind: "followers", required: 100, coins: 400 },

  // Only the NIARIM-native BOOKMARK ranking; never YouTube views,
  // likes, subscribers or YouTube-derived ranking scores.
  { id: "bookmark_rank_50", bit: 13, kind: "niarimBookmarkRanking", required: 50, coins: 100 },
  { id: "bookmark_rank_10", bit: 14, kind: "niarimBookmarkRanking", required: 10, coins: 300 },
  { id: "bookmark_rank_3", bit: 15, kind: "niarimBookmarkRanking", required: 3, coins: 600 },
  { id: "bookmark_rank_1", bit: 16, kind: "niarimBookmarkRanking", required: 1, coins: 1000 },
]);

export const MAX_CREATOR_MISSION_COINS = CREATOR_MISSIONS.reduce(
  (sum, m) => sum + m.coins, 0,
);

export function missionClaimed(claimedMask: number, bit: number): boolean {
  if (!Number.isSafeInteger(claimedMask) || claimedMask < 0 ||
      !Number.isSafeInteger(bit) || bit < 0 || bit > 52) {
    return false;
  }
  const pow = 2 ** bit;
  return Math.floor(claimedMask / pow) % 2 === 1;
}

export function claimMissionInMask(claimedMask: number, bit: number): number {
  if (!Number.isSafeInteger(claimedMask) || claimedMask < 0 ||
      !Number.isSafeInteger(bit) || bit < 0 || bit > 52) {
    throw new Error("Invalid mission mask");
  }
  if (missionClaimed(claimedMask, bit)) return claimedMask;
  const next = claimedMask + 2 ** bit;
  if (!Number.isSafeInteger(next)) throw new Error("Mission mask overflow");
  return next;
}

/**
 * Small account-level state: one DynamoDB row, no raw edit actions,
 * screenshots, frame data, personal profiles or duplicate project records.
 */
export interface CreatorMissionState {
  itemType: "CREATOR_MISSIONS_V1";
  claimedMask: number;
  verifiedEditSeconds: number;
  totalMissionCoins: number;
  /** Server-observed maturity/anti-farming checkpoints, integer epoch seconds. */
  firstQualifiedAt?: Record<string, number>;
}
