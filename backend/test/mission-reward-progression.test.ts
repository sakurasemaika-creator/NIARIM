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
import {finalBenefitCoins,finalBenefitCostCoins,FINAL_PREMIUM_YEARLY_COINS,
  isBundledPremiumCheaperForAllDurations}
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
    for(const works of [0,100,150,250,400,600,800,1000,10000,100000,1000000])
      increasing(ranks.map(m=>missionRewardCoins(m,works)));
    for(const m of ranks)
      increasing([0,1000,10000,100000,1000000]
        .map(n=>missionRewardCoins(m,n)));
    expect(missionRewardCoins(ranks[ranks.length-1],1000000)).toBe(1025);
  });
  it("raises every one of the 480 grid rewards along both dimensions",()=>{
    expect(WORK_COUNT_MISSIONS).toHaveLength(480);
    for(const works of WORK_COUNT_GOALS)
      increasing(BOOKMARK_GOALS.map(bookmarks=>
        workCountMissionById(`works_${works}_x_${bookmarks}`)!.coins));
    for(const bookmarks of BOOKMARK_GOALS)
      increasing(WORK_COUNT_GOALS.map(works=>
        workCountMissionById(`works_${works}_x_${bookmarks}`)!.coins));
    expect(workCountMissionById("works_500_x_1000")!.coins).toBe(220);
  });
  it("never stalls or decreases at any of the 54 cumulative login goals",()=>{
    expect(DAILY_LOGIN_COINS).toBe(10);
    expect(LOGIN_BONUS_MILESTONES).toHaveLength(54);
    increasing(LOGIN_BONUS_MILESTONES.map(m=>m.days));
    increasing(LOGIN_BONUS_MILESTONES.map(m=>m.coins));
    expect(LOGIN_BONUS_MILESTONES.find(m=>m.days===500)?.coins).toBe(59);
    expect(LOGIN_BONUS_MILESTONES.find(m=>m.days===3600)?.coins).toBe(210);
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
      expect(m.coins).toBeGreaterThanOrEqual(10);
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
    for(const m of WORK_COUNT_MISSIONS){denomination(m.coins);expect(m.coins).toBeGreaterThanOrEqual(10);}
    for(const works of WORK_COUNT_GOALS)
      increasingFive(BOOKMARK_GOALS.map(bookmarks=>
        workCountMissionById(`works_${works}_x_${bookmarks}`)!.coins));
    for(const bookmarks of BOOKMARK_GOALS)
      increasingFive(WORK_COUNT_GOALS.map(works=>
        workCountMissionById(`works_${works}_x_${bookmarks}`)!.coins));
    expect(workCountMissionById("works_3_x_0")!.coins).toBe(10);
    expect(workCountMissionById("works_500_x_1000")!.coins).toBe(220);
  });
  it("covers all 16 recurring/time missions",()=>{
    expect(PLAZA_MISSIONS).toHaveLength(10);
    expect(RECURRING_MISSIONS).toHaveLength(6);
    for(const m of [...PLAZA_MISSIONS,...RECURRING_MISSIONS]){
      denomination(m.coins);
      expect(m.coins).toBeGreaterThanOrEqual(10);
    }
    for(const period of ["day","week","month"] as const)
      increasingFive(PLAZA_MISSIONS.filter(m=>m.period===period)
        .sort((a,b)=>a.requiredSeconds-b.requiredSeconds).map(m=>m.coins));
    for(const period of ["week","month"] as const)
      increasingFive(RECURRING_MISSIONS.filter(m=>m.period===period)
        .sort((a,b)=>a.requiredDays-b.requiredDays).map(m=>m.coins));
  });
  it("ensures ten-coin minimum while keeping the ad and monthly bundle reference stable",()=>{
    expect(DAILY_LOGIN_COINS).toBe(10);
    expect(LOGIN_BONUS_MILESTONES.every(m=>m.coins>=10)).toBe(true);
    expect(INITIAL_REWARDED_COINS_PER_COMPLETION).toBe(10);
    expect(finalBenefitCoins("endCardEdit","hour")).toBe(500);
    expect(finalBenefitCoins("fullPremium","month")).toBe(55000);
  });
});

describe("owner-finalized coin exchange rates round the ones digit upwards",()=>{
  const targets=[
    "endCardEdit","watermark","toneCurve","levelAdjustment",
    "unlimitedDuration","customAutomation","projectListAds",
    "canvasAds","timelineAds","processingAds","allAds","fullPremium",
  ] as const;
  const durations=["hour","day","week","month"] as const;
  it("produces only nonzero ten-coin multiples and never rounds downward",()=>{
    for(const target of targets){
      for(const unit of durations){
        const cost=finalBenefitCoins(target,unit);
        expect(cost).toBeGreaterThan(0);
        expect(cost%10).toBe(0);
      }
    }
    expect(finalBenefitCoins("endCardEdit","hour")).toBe(500);
    expect(finalBenefitCoins("endCardEdit","day")).toBe(1200);
    expect(finalBenefitCoins("endCardEdit","week")).toBe(6000);
    expect(finalBenefitCoins("endCardEdit","month")).toBe(12000);
    expect(finalBenefitCoins("fullPremium","month")).toBe(55000);
    expect(FINAL_PREMIUM_YEARLY_COINS).toBe(550000);
    expect(finalBenefitCostCoins("fullPremium","month",12)).toBe(550000);
    expect(finalBenefitCostCoins("fullPremium","month",13)).toBe(605000);
    expect(finalBenefitCostCoins("fullPremium","month",24)).toBe(1100000);
    expect(finalBenefitCostCoins("fullPremium","month",11)).toBe(605000);
    expect(finalBenefitCostCoins("toneCurve","month",12)).toBe(216000);
    expect(isBundledPremiumCheaperForAllDurations()).toBe(true);
    // Freeze the complete 12 × 4 launch rate card, not just 4 examples.
    const fixed: readonly (readonly [typeof targets[number],readonly number[]])[] = [["endCardEdit",[500,1200,6000,12000]],["watermark",[750,1800,9000,18000]],["toneCurve",[750,1800,9000,18000]],["levelAdjustment",[630,1500,7500,15000]],["unlimitedDuration",[1050,2500,12500,25000]],["customAutomation",[1050,2500,12500,25000]],["projectListAds",[500,1200,6000,12000]],["canvasAds",[840,2000,10000,20000]],["timelineAds",[670,1600,8000,16000]],["processingAds",[420,1000,5000,10000]],["allAds",[1670,4000,20000,40000]],["fullPremium",[5000,10000,30000,55000]]];
    for(const [target,amounts] of fixed){
      expect(durations.map(d=>finalBenefitCoins(target,d))).toEqual(amounts);
    }
  });
});
