import {describe,it,expect} from "vitest";
import {CREATOR_MISSIONS,missionClaimed,claimMissionInMask} from "../src/lib/missionCatalog";
import {
  WORK_COUNT_GOALS,BOOKMARK_GOALS,WORK_COUNT_MISSIONS,
  workCountMissionById,ACCOUNT_GRID_MAX_COINS,
} from "../src/lib/workCountMissionGrid";
describe("creator mission achievement matrix",()=>{
  it("includes all specified 20 work-count and 24 per-work stages",()=>{
    expect(WORK_COUNT_GOALS).toEqual([3,5,10,20,30,40,50,60,70,80,90,
      100,150,200,250,300,350,400,450,500]);
    expect(BOOKMARK_GOALS).toEqual([0,10,20,30,40,50,60,70,80,90,
      100,150,200,250,300,350,400,450,500,600,700,800,900,1000]);
    expect(WORK_COUNT_MISSIONS).toHaveLength(480);
    expect(ACCOUNT_GRID_MAX_COINS).toBeGreaterThan(0);
  });
  it("has stable, non-overlapping shard bits and all 24 per-work milestones",()=>{
    expect(new Set(WORK_COUNT_MISSIONS.map(m=>`${m.shard}:${m.bit}`)).size).toBe(480);
    expect(new Set(WORK_COUNT_MISSIONS.map(m=>m.id)).size).toBe(480);
    const perWork=CREATOR_MISSIONS.filter(m=>m.kind==="workBookmarks");
    expect(perWork).toHaveLength(24);
    expect(perWork.map(m=>m.required).sort((a,b)=>a-b)).toEqual([...BOOKMARK_GOALS]);
    expect(new Set(perWork.map(m=>m.bit)).size).toBe(24);
    expect(perWork.every(m=>m.required<=1000&&m.coins>0)).toBe(true);
    expect(workCountMissionById("works_500_x_1000")).toMatchObject({shard:19,bit:23});
  });
  it("cannot claim a shard bit twice; old per-work claimed bits stay stable",()=>{
    const m=workCountMissionById("works_3_x_10")!;
    const mask=claimMissionInMask(0,m.bit);
    expect(missionClaimed(mask,m.bit)).toBe(true);
    expect(claimMissionInMask(mask,m.bit)).toBe(mask);
    expect(CREATOR_MISSIONS.find(m=>m.id==="work_bookmarks_10")?.bit).toBe(5);
    expect(CREATOR_MISSIONS.find(m=>m.id==="work_bookmarks_50")?.bit).toBe(6);
    expect(CREATOR_MISSIONS.find(m=>m.id==="work_bookmarks_100")?.bit).toBe(7);
    expect(CREATOR_MISSIONS.find(m=>m.id==="work_bookmarks_500")?.bit).toBe(46);
    expect(CREATOR_MISSIONS.find(m=>m.id==="work_bookmarks_1000")?.bit).toBe(47);
  });
});
