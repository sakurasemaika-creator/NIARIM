
/**
 * Publication/bookmark achievement matrix (planning catalog, v3).
 * Every requested count x bookmark target exists as a stable mission ID.
 * Claims require their own versioned account-scoped shard; never overload
 * the old MAX_SAFE_INTEGER claimedMask.
 *
 * Coin amounts are DRAFT launch offers until the operator explicitly reviews
 * budget, pricing and the newly introduced claims feature flags.
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
export const ACCOUNT_GRID_CATALOG_VERSION = "qualified-works-grid-v1";
export interface GridMission {
  id: string;
  kind: "qualifiedWorks";
  required: number;
  eachWorkBookmarks: number;
  perWork: false;
  bit: number;
  shard: number;
  coins: number;
  provisionalPrice: true;
}
/** Base offer is bounded and monotonic in both target dimensions.
 * Previously advertised v2 amounts remain intact for the corresponding
 * tiers, preventing surprising reductions if migration is later approved.
 */
const LEGACY_PRICES: Readonly<Record<string,number>> = {
  "3:10":150, "5:20":400,"10:20":700,"25:20":1200,
  "50:20":1800,"100:20":2800,"250:20":5000,"500:20":8000,
};
function gridCoins(works: number, bookmarks: number): number {
  const legacy = LEGACY_PRICES[`${works}:${bookmarks}`];
  if(legacy !== undefined)return legacy;
  // Draft-only (never live without an independent economic approval).
  const countIndex = WORK_COUNT_GOALS.indexOf(works);
  const bookmarkIndex = BOOKMARK_GOALS.indexOf(bookmarks);
  return Math.round((50 + countIndex*105 + bookmarkIndex*80)/10)*10;
}
/** 20 shards x 24 bits. Never reuse a shard/bit pair for another goal. */
export const WORK_COUNT_MISSIONS: readonly GridMission[] =
  Object.freeze(WORK_COUNT_GOALS.flatMap((works,shard) =>
    BOOKMARK_GOALS.map((bookmarks,bit) => ({
      id: `works_${works}_x_${bookmarks}`,
      kind:"qualifiedWorks" as const,required:works,
      eachWorkBookmarks:bookmarks,perWork:false as const,
      bit,shard,coins:gridCoins(works,bookmarks),
      provisionalPrice:true as const,
    }))
  ));
export const TOTAL_GRID_MISSIONS=WORK_COUNT_MISSIONS.length;
export const ACCOUNT_GRID_MAX_COINS=WORK_COUNT_MISSIONS.reduce((n,m)=>n+m.coins,0);
export function workCountMissionById(id:string):GridMission|undefined{
  return WORK_COUNT_MISSIONS.find(m=>m.id===id);
}
