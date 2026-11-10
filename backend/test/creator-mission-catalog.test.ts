import { describe, expect, it } from "vitest";
import {
  ACCOUNT_MISSIONS, CREATOR_MISSIONS, PER_WORK_MISSIONS,
  MAX_CREATOR_MISSION_COINS,
  claimMissionInMask, missionClaimed,
  missionRewardCoins, rankingDifficultyMultiplier,
  RANKING_POPULATION_TIERS, rankingMissionEligible,
  rankingEffectiveRankLimit,
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
    expect([0, 100, 1000, 10000, 100000, 1000000]
      .map(rankingDifficultyMultiplier)).toEqual([1, 1, 2, 3, 4, 5]);
    const ranked = CREATOR_MISSIONS.find((m) => m.id === "bookmark_rank_1")!;
    expect(missionRewardCoins(ranked, 100)).toBe(200);
    expect(missionRewardCoins(ranked, 10000)).toBe(600);
    expect(missionRewardCoins(ranked, 1000000)).toBe(1000);
    const edited = CREATOR_MISSIONS.find((m) => m.id === "edit_100000h")!;
    expect(missionRewardCoins(edited, 1000000)).toBe(75);
  });

  it("makes rare top rankings more valuable than ordinary bookmark goals", () => {
    const byId = (id: string) => CREATOR_MISSIONS.find((m) => m.id === id)!;
    const maxBookmarkReward = byId("work_bookmarks_1000").coins;
    expect(maxBookmarkReward).toBe(120);
    const orderedRanks = [50, 10, 3, 1].map(rank => byId(`bookmark_rank_${rank}`));
    expect(orderedRanks.map(m => m.coins)).toEqual([30, 75, 125, 200]);
    expect(orderedRanks[2].coins).toBeGreaterThan(maxBookmarkReward);
    expect(orderedRanks[3].coins).toBeGreaterThan(maxBookmarkReward);
    const populations = [0, 1000, 10000, 100000, 1000000];
    for (const pop of populations) {
      const prizes = orderedRanks.map(m => missionRewardCoins(m, pop));
      expect(prizes.every(c => c > 0 && c % 5 === 0)).toBe(true);
      expect(prizes.every((c, i) => i === 0 || c > prizes[i - 1])).toBe(true);
    }
    expect(orderedRanks.map(m => missionRewardCoins(m, 1000000)))
      .toEqual([150, 375, 625, 1000]);
  });

  it("refuses trivial ranks in a tiny pool and requires real bookmark activity",()=>{
    expect(rankingMissionEligible({
      goalRank:10,liveRank:1,publishedWorkCount:99,workBookmarks:500,
    })).toBe(false);
    expect(rankingMissionEligible({
      goalRank:10,liveRank:6,publishedWorkCount:100,workBookmarks:100,
    })).toBe(false);
    expect(rankingMissionEligible({
      goalRank:10,liveRank:5,publishedWorkCount:100,workBookmarks:15,
    })).toBe(true);
    expect(rankingEffectiveRankLimit(50,99)).toBe(0);
    expect(rankingEffectiveRankLimit(50,100)).toBe(10);
    expect(rankingEffectiveRankLimit(10,100)).toBe(5);
    expect(rankingEffectiveRankLimit(3,100)).toBe(3);
    expect(rankingEffectiveRankLimit(1,100)).toBe(1);
    expect(rankingMissionEligible({
      goalRank:1,liveRank:1,publishedWorkCount:150,workBookmarks:49,
    })).toBe(false);
    expect(rankingMissionEligible({
      goalRank:1,liveRank:1,publishedWorkCount:150,workBookmarks:50,
    })).toBe(true);
    expect(rankingMissionEligible({
      goalRank:50,liveRank:50,publishedWorkCount:100,workBookmarks:100,
    })).toBe(false);
  });

  it("increases the coin reward at EVERY early pool tier before 1,000",()=>{
    const rank=CREATOR_MISSIONS.find(m=>m.id==="bookmark_rank_50")!;
    const early=RANKING_POPULATION_TIERS.filter(n=>n<=1000);
    expect(early).toEqual([100,150,250,400,600,800,1000]);
    expect(early.map(n=>missionRewardCoins(rank,n)))
      .toEqual([30,35,40,45,50,55,60]);
    for(const threshold of RANKING_POPULATION_TIERS.slice(1)){
      expect(missionRewardCoins(rank,threshold))
        .toBeGreaterThan(missionRewardCoins(rank,threshold-1));
    }
  });

  it("never makes YouTube engagement metrics eligible for ranking rewards", () => {
    expect(PER_WORK_MISSIONS.filter((m) => m.id.startsWith("bookmark_rank"))
      .every((m) => m.kind === "niarimBookmarkRanking")).toBe(true);
  });
});
