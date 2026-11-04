import { describe, expect, it } from "vitest";
import {
  ACCOUNT_MISSIONS, CREATOR_MISSIONS, PER_WORK_MISSIONS,
  MAX_CREATOR_MISSION_COINS,
  claimMissionInMask, missionClaimed,
  missionRewardCoins, rankingDifficultyMultiplier,
} from "../src/lib/missionCatalog";

describe("creator mission v2, compact scopes and reward tiers", () => {
  it("contains stable unique bit IDs within the 53-bit integer mask", () => {
    expect(CREATOR_MISSIONS).toHaveLength(53);
    expect(new Set(CREATOR_MISSIONS.map((m) => m.id)).size).toBe(53);
    expect(new Set(CREATOR_MISSIONS.map((m) => m.bit)).size).toBe(53);
    expect(CREATOR_MISSIONS.every((m) =>
      Number.isSafeInteger(m.coins) && m.coins > 0 &&
      m.bit >= 0 && m.bit <= 52)).toBe(true);
    expect(ACCOUNT_MISSIONS).toHaveLength(39);
    expect(PER_WORK_MISSIONS).toHaveLength(14);
    expect(MAX_CREATOR_MISSION_COINS).toBe(
      ACCOUNT_MISSIONS.reduce((n, m) => n + m.coins, 0),
    );
  });

  it("tracks claims in one safe-number bitmask without duplicate awards", () => {
    let mask = 0;
    for (const mission of CREATOR_MISSIONS) {
      expect(missionClaimed(mask, mission.bit)).toBe(false);
      mask = claimMissionInMask(mask, mission.bit);
      expect(missionClaimed(mask, mission.bit)).toBe(true);
      expect(claimMissionInMask(mask, mission.bit)).toBe(mask);
    }
    expect(mask).toBe(2 ** 53 - 1);
  });

  it("reaches 100k verified hours, 1m followers, and 10k qualified works", () => {
    const byId = (id: string) => CREATOR_MISSIONS.find((m) => m.id === id)!;
    expect(byId("edit_100000h").required).toBe(100000 * 3600);
    expect(byId("followers_1000000").required).toBe(1000000);
    expect(byId("works_10000_x_20").required).toBe(10000);
    expect(byId("edit_50h").coins).toBe(55000);
    expect(byId("edit_50h").perWork).toBe(false);
    expect(byId("work_bookmarks_100").perWork).toBe(true);
    expect(byId("bookmark_rank_1").perWork).toBe(true);
  });

  it("adjusts NIARIM bookmark ranking rewards as eligible work pool grows", () => {
    expect([0, 999, 1000, 9999, 10000, 100000, 1000000]
      .map(rankingDifficultyMultiplier)).toEqual([1, 1, 2, 2, 3, 4, 5]);
    const ranked = CREATOR_MISSIONS.find((m) => m.id === "bookmark_rank_1")!;
    expect(missionRewardCoins(ranked, 100)).toBe(1000);
    expect(missionRewardCoins(ranked, 10000)).toBe(3000);
    expect(missionRewardCoins(ranked, 1000000)).toBe(5000);
    const edited = CREATOR_MISSIONS.find((m) => m.id === "edit_50h")!;
    expect(missionRewardCoins(edited, 1000000)).toBe(55000);
  });

  it("never makes YouTube engagement metrics eligible for ranking rewards", () => {
    expect(PER_WORK_MISSIONS.filter((m) => m.id.startsWith("bookmark_rank"))
      .every((m) => m.kind === "niarimBookmarkRanking")).toBe(true);
  });
});
