import {describe,it,expect} from "vitest";
import {CREATOR_MISSIONS,missionRewardCoins} from "../src/lib/missionCatalog";
import {WORK_COUNT_GOALS,BOOKMARK_GOALS,WORK_COUNT_MISSIONS,workCountMissionById}
  from "../src/lib/workCountMissionGrid";
import {LOGIN_BONUS_MILESTONES,DAILY_LOGIN_COINS}
  from "../src/lib/loginBonusCatalog";
import {PLAZA_MISSIONS} from "../src/lib/plazaMissionCatalog";
import {RECURRING_MISSIONS} from "../src/lib/recurringMissionCatalog";
import {INITIAL_REWARDED_COINS_PER_COMPLETION}
  from "../src/lib/coinEconomyScale";
import {proposedBenefitCoins,isBundledPremiumCheaperForAllDurations}
  from "../src/lib/coinBenefitProposal";

describe("mission rewards strictly rise with difficulty",()=>{
  const increasing=(values:number[])=>{
    expect(values.length).toBeGreaterThan(1);
    for(let i=1;i<values.length;i++){
      expect(values[i],`tier ${i} must exceed tier ${i-1}`)
        .toBeGreaterThan(values[i-1]);
    }
  };
  it("raises edit, follower and work bookmark rewards at every new goal",()=>{
    for(const kind of ["verifiedEditSeconds","followers","workBookmarks"] as const){
      increasing(CREATOR_MISSIONS.filter(m=>m.kind===kind)
        .sort((a,b)=>a.required-b.required).map(m=>m.coins));
    }
    expect(CREATOR_MISSIONS.find(m=>m.id==="edit_100000h")!.coins)
      .toBeGreaterThan(INITIAL_REWARDED_COINS_PER_COMPLETION);
    expect(CREATOR_MISSIONS.find(m=>m.id==="work_bookmarks_1000")!.coins)
      .toBeGreaterThan(INITIAL_REWARDED_COINS_PER_COMPLETION);
  });
  it("raises ranking rewards at each stronger ranking and work population",()=>{
    const ranks=CREATOR_MISSIONS.filter(m=>m.kind==="niarimBookmarkRanking")
      .sort((a,b)=>b.required-a.required);
    for(const works of [0,1000,10000,100000,1000000])
      increasing(ranks.map(m=>missionRewardCoins(m,works)));
    for(const m of ranks)
      increasing([0,1000,10000,100000,1000000]
        .map(n=>missionRewardCoins(m,n)));
    expect(missionRewardCoins(ranks[ranks.length-1],1000000)).toBe(1000);
  });
  it("raises every one of the 480 grid rewards along both dimensions",()=>{
    expect(WORK_COUNT_MISSIONS).toHaveLength(480);
    for(const works of WORK_COUNT_GOALS)
      increasing(BOOKMARK_GOALS.map(bookmarks=>
        workCountMissionById(`works_${works}_x_${bookmarks}`)!.coins));
    for(const bookmarks of BOOKMARK_GOALS)
      increasing(WORK_COUNT_GOALS.map(works=>
        workCountMissionById(`works_${works}_x_${bookmarks}`)!.coins));
    expect(workCountMissionById("works_500_x_1000")!.coins).toBe(215);
  });
  it("never stalls or decreases at any of the 54 cumulative login goals",()=>{
    expect(DAILY_LOGIN_COINS).toBe(1);
    expect(LOGIN_BONUS_MILESTONES).toHaveLength(54);
    increasing(LOGIN_BONUS_MILESTONES.map(m=>m.days));
    increasing(LOGIN_BONUS_MILESTONES.map(m=>m.coins));
    expect(LOGIN_BONUS_MILESTONES.find(m=>m.days===500)?.coins).toBe(54);
    expect(LOGIN_BONUS_MILESTONES.find(m=>m.days===3600)?.coins).toBe(205);
  });
  it("raises repeatable plaza and recurring login goals within each period",()=>{
    for(const period of ["day","week","month"] as const)
      increasing(PLAZA_MISSIONS.filter(m=>m.period===period)
        .sort((a,b)=>a.requiredSeconds-b.requiredSeconds).map(m=>m.coins));
    for(const period of ["week","month"] as const)
      increasing(RECURRING_MISSIONS.filter(m=>m.period===period)
        .sort((a,b)=>a.requiredDays-b.requiredDays).map(m=>m.coins));
  });
});


describe("all 551 mission coins use strict five-coin steps",()=>{
  const denomination=(n:number)=>{expect(n).toBeGreaterThan(0);expect(n%5).toBe(0);};
  const increasingFive=(arr:number[])=>{
    for(let i=1;i<arr.length;i++)
      expect(arr[i]-arr[i-1],`tier ${i} needs at least five more`).toBeGreaterThanOrEqual(5);
  };
  it("covers every creator goal and ranking population tier",()=>{
    expect(CREATOR_MISSIONS).toHaveLength(55);
    for(const m of CREATOR_MISSIONS){
      denomination(m.coins);
      for(const pop of [0,1000,10000,100000,1000000])
        denomination(missionRewardCoins(m,pop));
    }
    for(const kind of ["verifiedEditSeconds","followers","workBookmarks"] as const)
      increasingFive(CREATOR_MISSIONS.filter(m=>m.kind===kind)
        .sort((a,b)=>a.required-b.required).map(m=>m.coins));
    const ranks=CREATOR_MISSIONS.filter(m=>m.kind==="niarimBookmarkRanking")
      .sort((a,b)=>b.required-a.required);
    for(const pop of [0,1000,10000,100000,1000000])
      increasingFive(ranks.map(m=>missionRewardCoins(m,pop)));
  });
  it("covers every grid row and both independent difficulty axes",()=>{
    expect(WORK_COUNT_MISSIONS).toHaveLength(480);
    for(const m of WORK_COUNT_MISSIONS)denomination(m.coins);
    for(const works of WORK_COUNT_GOALS)
      increasingFive(BOOKMARK_GOALS.map(bookmarks=>
        workCountMissionById(`works_${works}_x_${bookmarks}`)!.coins));
    for(const bookmarks of BOOKMARK_GOALS)
      increasingFive(WORK_COUNT_GOALS.map(works=>
        workCountMissionById(`works_${works}_x_${bookmarks}`)!.coins));
    expect(workCountMissionById("works_3_x_0")!.coins).toBe(5);
    expect(workCountMissionById("works_500_x_1000")!.coins).toBe(215);
  });
  it("covers all 16 recurring/time missions",()=>{
    expect(PLAZA_MISSIONS).toHaveLength(10);
    expect(RECURRING_MISSIONS).toHaveLength(6);
    for(const m of [...PLAZA_MISSIONS,...RECURRING_MISSIONS])denomination(m.coins);
    for(const period of ["day","week","month"] as const)
      increasingFive(PLAZA_MISSIONS.filter(m=>m.period===period)
        .sort((a,b)=>a.requiredSeconds-b.requiredSeconds).map(m=>m.coins));
    for(const period of ["week","month"] as const)
      increasingFive(RECURRING_MISSIONS.filter(m=>m.period===period)
        .sort((a,b)=>a.requiredDays-b.requiredDays).map(m=>m.coins));
  });
  it("keeps daily login, rewarded ads and exchange costs unchanged",()=>{
    expect(DAILY_LOGIN_COINS).toBe(1);
    expect(INITIAL_REWARDED_COINS_PER_COMPLETION).toBe(10);
    expect(proposedBenefitCoins("endCardEdit","hour")).toBe(70);
    expect(proposedBenefitCoins("fullPremium","month")).toBe(60000);
  });
});

describe("coin exchange proposals round the ones digit upwards",()=>{
  const targets=[
    "endCardEdit","watermark","toneCurve","levelAdjustment",
    "unlimitedDuration","customAutomation","projectListAds",
    "canvasAds","timelineAds","processingAds","allAds","fullPremium",
  ] as const;
  const durations=["hour","day","week","month"] as const;
  it("produces only nonzero ten-coin multiples and never rounds downward",()=>{
    for(const target of targets){
      for(const unit of durations){
        const cost=proposedBenefitCoins(target,unit);
        expect(cost).toBeGreaterThan(0);
        expect(cost%10).toBe(0);
      }
    }
    expect(proposedBenefitCoins("endCardEdit","hour")).toBe(70);
    expect(proposedBenefitCoins("endCardEdit","day")).toBe(290);
    expect(proposedBenefitCoins("endCardEdit","week")).toBe(2170);
    expect(proposedBenefitCoins("endCardEdit","month")).toBe(8000);
    expect(proposedBenefitCoins("fullPremium","month")).toBe(60000);
    expect(isBundledPremiumCheaperForAllDurations()).toBe(true);
  });
});
