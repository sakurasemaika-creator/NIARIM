/**
 * Initial cumulative login reward proposal. Distinct calendar days, never
 * a streak. A missed day does not reset progress. The server's JST day
 * prevents device clock/timezone edits from double-claiming.
 *
 * The server day boundary is midnight JST (UTC+09:00).
 * 1 coin per checked-in day, with progressively higher milestone prizes.
 * These are proposals and payout is OFF unless separately approved.
 */
export const DAILY_LOGIN_COINS = 1;
export const LOGIN_BONUS_CATALOG_VERSION = "cumulative-login-v3-progressive";
export const LOGIN_BONUS_MAX_MILESTONE = 3600;

export type LoginMilestone = {
  days: number;
  coins: number;
};
const tiers = [
  {from:5,to:50,step:5,startCoins:5,increment:1},
  {from:60,to:100,step:10,startCoins:15,increment:1},
  {from:150,to:500,step:50,startCoins:40,increment:2},
  {from:600,to:1000,step:100,startCoins:60,increment:4},
  {from:1100,to:3600,step:100,startCoins:80,increment:5},
] as const;

export const LOGIN_BONUS_MILESTONES: readonly LoginMilestone[] =
  Object.freeze(tiers.flatMap(tier => {
    const rows:LoginMilestone[] = [];
    for (let days= tier.from; days <= tier.to; days += tier.step) {
      rows.push({days,
        coins: tier.startCoins + ((days - tier.from) / tier.step) * tier.increment});
    }
    return rows;
  }));
export function milestoneCoins(days:number):number|undefined {
  return LOGIN_BONUS_MILESTONES.find(m=>m.days===days)?.coins;
}
export function jstLoginDay(now=Date.now()):string {
  return new Date(now+9*60*60*1000).toISOString().slice(0,10);
}
export function loginBonusRewardEnabled():boolean {
  return process.env.LOGIN_BONUS_CLAIMS_ENABLED==="true" &&
    process.env.LOGIN_BONUS_REWARDS_REVIEW_APPROVED==="true";
}
