/**
 * Initial cumulative login reward proposal. Distinct calendar days, never
 * a streak. A missed day does not reset progress. A UTC calendar day is
 * chosen deliberately so device clock/timezone edits cannot double-claim.
 *
 * 1 coin per checked-in day; notable round-number milestones grant extra.
 * These coin prices are launch proposals and payout is OFF by default.
 */
export const DAILY_LOGIN_COINS = 1;
export const LOGIN_BONUS_CATALOG_VERSION = "cumulative-login-v1";
export const LOGIN_BONUS_MAX_MILESTONE = 3600;

export type LoginMilestone = {
  days: number;
  coins: number;
};
const tiers = [
  {from:5,to:50,step:5,coins:5},
  {from:60,to:100,step:10,coins:10},
  {from:150,to:500,step:50,coins:50},
  {from:600,to:1000,step:100,coins:100},
  {from:1100,to:3600,step:100,coins:150},
] as const;

export const LOGIN_BONUS_MILESTONES: readonly LoginMilestone[] =
  Object.freeze(tiers.flatMap(tier => {
    const rows:LoginMilestone[]=[];
    for (let days=tier.from;days<=tier.to;days+=tier.step) {
      const roundBonus = days === 50 ? 50 : days === 100 ? 100
        : days === 500 ? 250 : days === 1000 ? 500 : tier.coins;
      rows.push({days,coins:roundBonus});
    }
    return rows;
  }));
export function milestoneCoins(days:number):number|undefined {
  return LOGIN_BONUS_MILESTONES.find(m=>m.days===days)?.coins;
}
export function utcLoginDay(now=Date.now()):string {
  return new Date(now).toISOString().slice(0,10);
}
export function loginBonusRewardEnabled():boolean {
  return process.env.LOGIN_BONUS_CLAIMS_ENABLED==="true" &&
    process.env.LOGIN_BONUS_REWARDS_REVIEW_APPROVED==="true";
}
