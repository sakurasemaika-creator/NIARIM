import { describe, expect, it } from "vitest";
import {
  CREATOR_MISSIONS,
  MAX_CREATOR_MISSION_COINS,
  claimMissionInMask,
  missionClaimed,
} from "../src/lib/missionCatalog";

describe("compact lifetime mission history", () => {
  it("has unique stable ids and unique bit positions", () => {
    expect(CREATOR_MISSIONS).toHaveLength(17);
    expect(new Set(CREATOR_MISSIONS.map((m) => m.id)).size).toBe(17);
    expect(new Set(CREATOR_MISSIONS.map((m) => m.bit)).size).toBe(17);
    expect(CREATOR_MISSIONS.every((m) =>
      Number.isSafeInteger(m.coins) && m.coins > 0 && m.bit <= 52)).toBe(true);
    expect(MAX_CREATOR_MISSION_COINS).toBe(5930);
  });

  it("claims once with integer masks without adding rows per mission", () => {
    let mask = 0;
    for (const mission of CREATOR_MISSIONS) {
      expect(missionClaimed(mask, mission.bit)).toBe(false);
      mask = claimMissionInMask(mask, mission.bit);
      expect(missionClaimed(mask, mission.bit)).toBe(true);
      expect(claimMissionInMask(mask, mission.bit)).toBe(mask);
    }
    expect(mask).toBe(2 ** 17 - 1);
  });

  it("never turns local work-time totals into trusted paid eligibility", () => {
    expect(CREATOR_MISSIONS.filter((m) =>
      m.kind === "verifiedEditSeconds").map((m) => m.required)
    ).toEqual([3600, 18000, 72000, 180000, 360000]);
  });

  it("ranking rewards are solely NIARIM native bookmark rankings", () => {
    expect(CREATOR_MISSIONS.filter((m) =>
      m.id.startsWith("bookmark_rank")).every((m) =>
        m.kind === "niarimBookmarkRanking")).toBe(true);
  });
});
