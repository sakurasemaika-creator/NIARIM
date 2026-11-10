
/**
 * OWNER-FINALIZED coin rewards for the 20 x 24 = 480 mission grid.
 * Every reward is fixed in the approved 5-coin progression. Achievement
 * IDs, bit positions and per-user claim shards must stay stable.
 *
 * Approval of the AMOUNT does not enable payment: the existing independent
 * cross-work consistency / wallet integrity gates remain fail-closed.
 */
export const WORK_COUNT_GOALS = Object.freeze([
  3, 5, ...Array.from({length:9},(_,i)=>(i+1)*10),
  ...Array.from({length:9},(_,i)=>100+i*50),
]);
export const BOOKMARK_GOALS = Object.freeze([
  0, ...Array.from({length:9},(_,i)=>(i+1)*10),
  ...Array.from({length:8},(_,i)=>100+i*50),
  ...Array.from({length:6},(_,i)=>500+i*100),
]);
export const ACCOUNT_GRID_CATALOG_VERSION = "qualified-works-grid-v3-progressive-step5";
export interface GridMission {
  id: string;
  kind: "qualifiedWorks";
  required: number;
  eachWorkBookmarks: number;
  perWork: false;
  bit: number;
  shard: number;
  coins: number;
  priceFinal: true;
}
/** Each strictly harder goal in either dimension increases the reward.
 * 20 work tiers x 24 bookmark tiers: 5 through 215 coins in steps of five.
 */
function gridCoins(works: number, bookmarks: number): number {
  const countIndex = WORK_COUNT_GOALS.indexOf(works);
  const bookmarkIndex = BOOKMARK_GOALS.indexOf(bookmarks);
  if (countIndex < 0 || bookmarkIndex < 0) {
    throw new Error("Unknown work-count mission goal");
  }
  return 5 * (1 + countIndex + bookmarkIndex);
}
/** 20 shards x 24 bits. Never reuse a shard/bit pair for another goal. */
export const WORK_COUNT_MISSIONS: readonly GridMission[] =
  Object.freeze(WORK_COUNT_GOALS.flatMap((works,shard) =>
    BOOKMARK_GOALS.map((bookmarks,bit) => ({
      id: `works_${works}_x_${bookmarks}`,
      kind:"qualifiedWorks" as const,required:works,
      eachWorkBookmarks:bookmarks,perWork:false as const,
      bit,shard,coins:gridCoins(works,bookmarks),
      priceFinal:true as const,
    }))
  ));
export function gridClaimsEnabled():boolean{
  return process.env.CREATOR_MISSION_CLAIMS_ENABLED==="true" &&
    process.env.CREATOR_MISSION_CLAIMS_REVIEW_APPROVED==="true" &&
    process.env.CREATOR_GRID_PAYOUTS_ENABLED==="true" &&
    process.env.CREATOR_GRID_REWARDS_REVIEW_APPROVED==="true";
}
export const TOTAL_GRID_MISSIONS=WORK_COUNT_MISSIONS.length;
export const ACCOUNT_GRID_MAX_COINS=WORK_COUNT_MISSIONS.reduce((n,m)=>n+m.coins,0);
export function workCountMissionById(id:string):GridMission|undefined{
  return WORK_COUNT_MISSIONS.find(m=>m.id===id);
}
