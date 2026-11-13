/**
 * Low-value, repeatable missions for genuine Works Plaza visits.
 * Higher time thresholds earn at least five more coins in each period.
 * The rewarded-ad amount does not cap mission prizes.
 * A session heartbeat is authenticated; NO client-reported seconds count.
 * The server's own elapsed time is capped per heartbeat and per period.
 * Each user needs a single compact DynamoDB row, not a per-minute log.
 */
export type PlazaPeriod = "day" | "week" | "month";
export interface PlazaMission {
  id: string;
  period: PlazaPeriod;
  bit: number;
  requiredSeconds: number;
  coins: number;
}
export const PLAZA_MISSION_CATALOG_VERSION = "plaza-time-v5-min10";
export const PLAZA_MISSION_STATE_TYPE = "PLAZA_MISSIONS_V1";
export const PLAZA_MISSIONS: readonly PlazaMission[] = Object.freeze([
  {id:"plaza_day_5m",period:"day",bit:0,requiredSeconds:300,coins:10},
  {id:"plaza_day_15m",period:"day",bit:1,requiredSeconds:900,coins:15},
  {id:"plaza_day_30m",period:"day",bit:2,requiredSeconds:1800,coins:20},
  {id:"plaza_day_60m",period:"day",bit:3,requiredSeconds:3600,coins:25},
  {id:"plaza_week_1h",period:"week",bit:0,requiredSeconds:3600,coins:10},
  {id:"plaza_week_3h",period:"week",bit:1,requiredSeconds:10800,coins:15},
  {id:"plaza_week_6h",period:"week",bit:2,requiredSeconds:21600,coins:20},
  {id:"plaza_month_10h",period:"month",bit:0,requiredSeconds:36000,coins:20},
  {id:"plaza_month_20h",period:"month",bit:1,requiredSeconds:72000,coins:25},
  {id:"plaza_month_40h",period:"month",bit:2,requiredSeconds:144000,coins:30},
]);
export interface PlazaState {
  version: number;
  dayKey: string; weekKey: string; monthKey: string;
  daySeconds: number; weekSeconds: number; monthSeconds: number;
  dayMask: number; weekMask: number; monthMask: number;
  sessionId: string; lastPulseMs: number;
}
export function defaultPlazaState(): PlazaState {
  return {version:0,dayKey:"",weekKey:"",monthKey:"",
    daySeconds:0,weekSeconds:0,monthSeconds:0,
    dayMask:0,weekMask:0,monthMask:0,
    sessionId:"",lastPulseMs:0};
}
export function normalizePlazaState(raw?: Record<string,unknown>): PlazaState {
  if (!raw || raw.itemType!==PLAZA_MISSION_STATE_TYPE) return defaultPlazaState();
  const n=(x:unknown)=>typeof x==="number" && Number.isSafeInteger(x) && x>=0 ? x:0;
  const s=(x:unknown)=>typeof x==="string"?x:"";
  return {version:n(raw.version),dayKey:s(raw.dayKey),weekKey:s(raw.weekKey),
    monthKey:s(raw.monthKey),daySeconds:n(raw.daySeconds),
    weekSeconds:n(raw.weekSeconds),monthSeconds:n(raw.monthSeconds),
    dayMask:n(raw.dayMask),weekMask:n(raw.weekMask),monthMask:n(raw.monthMask),
    sessionId:s(raw.sessionId),lastPulseMs:n(raw.lastPulseMs)};
}
export function plazaMissionEnabled() {
  return process.env.PLAZA_MISSION_PAYOUTS_ENABLED==="true";
}
export function plazaProgress(state:PlazaState, mission:PlazaMission,
  period:{day:string;week:string;month:string}) {
  const current = mission.period==="day" ? state.dayKey===period.day
    : mission.period==="week"?state.weekKey===period.week:state.monthKey===period.month;
  const seconds = current ? (mission.period==="day"?state.daySeconds
    : mission.period==="week"?state.weekSeconds:state.monthSeconds):0;
  const mask=current ? (mission.period==="day"?state.dayMask
    : mission.period==="week"?state.weekMask:state.monthMask):0;
  return {progressSeconds:seconds,claimed:Math.floor(mask/2**mission.bit)%2===1,
    eligible:seconds>=mission.requiredSeconds,
    periodKey:period[mission.period]};
}
/** Server-time heartbeat. Keeping the page open counts; playback is not required.
 * A lost/resumed session never credits its idle gap. */
export function advancePlazaPulse(state:PlazaState, sessionId:string, nowMs:number,
    period:{day:string;week:string;month:string}):PlazaState {
  const sameSession=state.sessionId===sessionId && sessionId.length>=20;
  const elapsed=nowMs-state.lastPulseMs;
  const delta=sameSession && elapsed>=0 && elapsed<=180000 ? Math.floor(elapsed/1000):0;
  const daySame=state.dayKey===period.day;
  const weekSame=state.weekKey===period.week;
  const monthSame=state.monthKey===period.month;
  return {
    version:state.version+1,
    dayKey:period.day,weekKey:period.week,monthKey:period.month,
    daySeconds:Math.min(86400,(daySame?state.daySeconds:0)+delta),
    weekSeconds:Math.min(604800,(weekSame?state.weekSeconds:0)+delta),
    monthSeconds:Math.min(2678400,(monthSame?state.monthSeconds:0)+delta),
    dayMask:daySame?state.dayMask:0,
    weekMask:weekSame?state.weekMask:0,
    monthMask:monthSame?state.monthMask:0,
    sessionId,lastPulseMs:nowMs,
  };
}
