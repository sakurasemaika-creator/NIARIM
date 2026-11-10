import { describe, expect, it } from "vitest";
import {
  ACCOUNT_MISSIONS, CREATOR_MISSIONS, PER_WORK_MISSIONS,
  MAX_CREATOR_MISSION_COINS,
  claimMissionInMask, missionClaimed,
  missionRewardCoins, rankingDifficultyMultiplier,
} from "../src/lib/missionCatalog";

describe("creator missions with separate account and work scopes", () => {
  it("contains stable unique bit IDs within the 53-bit integer mask", () => {
    expect(CREATOR_MISSIONS).toHaveLength(55);
    expect(new Set(CREATOR_MISSIONS.map((m) => m.id)).size).toBe(55);
    // Account and per-work records use DIFFERENT DynamoDB keys. Bit indexes
    // can overlap safely between scopes, but never within a single scope.
    expect(new Set(ACCOUNT_MISSIONS.map((m) => m.bit)).size).toBe(27);
    expect(new Set(PER_WORK_MISSIONS.map((m) => m.bit)).size).toBe(28);
    expect(CREATOR_MISSIONS.every((m) =>
      Number.isSafeInteger(m.coins) && m.coins > 0 &&
      m.bit >= 0 && m.bit <= 52)).toBe(true);
    expect(ACCOUNT_MISSIONS).toHaveLength(27);
    expect(PER_WORK_MISSIONS).toHaveLength(28);
    expect(MAX_CREATOR_MISSION_COINS).toBe(
      ACCOUNT_MISSIONS.reduce((n, m) => n + m.coins, 0),
    );
  });

  it("tracks claims in one safe-number bitmask without duplicate awards", () => {
    for (const scope of [ACCOUNT_MISSIONS,PER_WORK_MISSIONS]) {
      let mask = 0;
      for (const mission of scope) {
        expect(missionClaimed(mask, mission.bit)).toBe(false);
        mask = claimMissionInMask(mask, mission.bit);
        expect(missionClaimed(mask, mission.bit)).toBe(true);
        expect(claimMissionInMask(mask, mission.bit)).toBe(mask);
      }
      expect(Number.isSafeInteger(mask)).toBe(true);
    }
  });

  it("retains long-term edit and follower milestones while limiting work bookmarks", () => {
    const byId = (id: string) => CREATOR_MISSIONS.find((m) => m.id === id)!;
    expect(byId("edit_100000h").required).toBe(100000 * 3600);
    expect(byId("followers_1000000").required).toBe(1000000);
    expect(byId("work_posted").required).toBe(0);
    expect(byId("work_bookmarks_1000").required).toBe(1000);
    expect(CREATOR_MISSIONS.some((m)=>m.id==="works_10000_x_20")).toBe(false);
    expect(byId("edit_50h").coins).toBe(25);
    expect(CREATOR_MISSIONS.every(m => m.coins >= 1)).toBe(true);
    expect(byId("edit_50h").perWork).toBe(false);
    expect(byId("work_bookmarks_100").perWork).toBe(true);
    expect(byId("bookmark_rank_1").perWork).toBe(true);
  });

  it("adjusts NIARIM bookmark ranking rewards as eligible work pool grows", () => {
    expect([0, 999, 1000, 9999, 10000, 100000, 1000000]
      .map(rankingDifficultyMultiplier)).toEqual([1, 1, 2, 2, 3, 4, 5]);
    const ranked = CREATOR_MISSIONS.find((m) => m.id === "bookmark_rank_1")!;
    expect(missionRewardCoins(ranked, 100)).toBe(20);
    expect(missionRewardCoins(ranked, 10000)).toBe(60);
    expect(missionRewardCoins(ranked, 1000000)).toBe(100);
    const edited = CREATOR_MISSIONS.find((m) => m.id === "edit_100000h")!;
    expect(missionRewardCoins(edited, 1000000)).toBe(75);
  });

  it("never makes YouTube engagement metrics eligible for ranking rewards", () => {
    expect(PER_WORK_MISSIONS.filter((m) => m.id.startsWith("bookmark_rank"))
      .every((m) => m.kind === "niarimBookmarkRanking")).toBe(true);
  });
});
