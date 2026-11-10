/**
 * Bounded recurring login missions. Server-authoritative JST calendar visits
 * are counted once per day; no client-reported view durations or ad views.
 *
 * One DynamoDB state row per account holds this week's/month's counters and
 * claimed bit masks. A GET never pays, and claims use atomic transactions.
 */
export type RecurringPeriod = "week" | "month";

export interface RecurringMission {
  id: string;
  period: RecurringPeriod;
  bit: number;
  requiredDays: number;
  coins: number;
}

export const RECURRING_MISSION_CATALOG_VERSION = "recurring-login-v4-progressive";
export const RECURRING_MISSIONS: readonly RecurringMission[] = Object.freeze([
  { id: "visit_week_3", period: "week", bit: 0, requiredDays: 3, coins: 2 },
  { id: "visit_week_5", period: "week", bit: 1, requiredDays: 5, coins: 3 },
  { id: "visit_week_7", period: "week", bit: 2, requiredDays: 7, coins: 4 },
  { id: "visit_month_10", period: "month", bit: 0, requiredDays: 10, coins: 5 },
  { id: "visit_month_20", period: "month", bit: 1, requiredDays: 20, coins: 7 },
  { id: "visit_month_25", period: "month", bit: 2, requiredDays: 25, coins: 10 },
]);

export const RECURRING_MISSION_STATE_TYPE = "RECURRING_MISSIONS_V1";

export function recurringMissionPayoutEnabled(): boolean {
  return process.env.RECURRING_MISSION_PAYOUTS_ENABLED === "true";
}

/** Uses JST (UTC+9), never the caller's locale or system clock. */
export function recurringPeriodKeys(now: Date = new Date()): {
  day: string; week: string; month: string;
} {
  const local = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const day = local.toISOString().slice(0, 10);
  const month = day.slice(0, 7);
  // ISO-style Monday start, expressed as the week's Monday JST date.
  const weekdayFromMonday = (local.getUTCDay() + 6) % 7;
  local.setUTCDate(local.getUTCDate() - weekdayFromMonday);
  const week = local.toISOString().slice(0, 10);
  return { day, week, month };
}

export interface RecurringMissionState {
  lastVisitedDay: string;
  weekKey: string;
  weekDays: number;
  weekClaimedMask: number;
  monthKey: string;
  monthDays: number;
  monthClaimedMask: number;
}

export function normalizeRecurringState(raw: Record<string, unknown> | undefined):
    RecurringMissionState {
  if (raw?.itemType !== RECURRING_MISSION_STATE_TYPE) {
    return {lastVisitedDay: "",weekKey: "",weekDays: 0,
      weekClaimedMask: 0,monthKey: "",monthDays: 0,monthClaimedMask: 0};
  }
  const nonNegative = (input: unknown) =>
    typeof input === "number" && Number.isSafeInteger(input) && input >= 0
      ? input : 0;
  const key = (input: unknown) => typeof input === "string" ? input : "";
  return {
    lastVisitedDay: key(raw.lastVisitedDay),
    weekKey: key(raw.weekKey),
    weekDays: nonNegative(raw.weekDays),
    weekClaimedMask: nonNegative(raw.weekClaimedMask),
    monthKey: key(raw.monthKey),
    monthDays: nonNegative(raw.monthDays),
    monthClaimedMask: nonNegative(raw.monthClaimedMask),
  };
}

export function recurringProgress(
  state: RecurringMissionState, mission: RecurringMission,
  periods: ReturnType<typeof recurringPeriodKeys>,
): {periodKey: string; progressDays: number; claimed: boolean} {
  const current = mission.period === "week"
    ? state.weekKey === periods.week : state.monthKey === periods.month;
  const mask = current
    ? mission.period === "week" ? state.weekClaimedMask : state.monthClaimedMask
    : 0;
  return {
    periodKey: mission.period === "week" ? periods.week : periods.month,
    progressDays: current
      ? mission.period === "week" ? state.weekDays : state.monthDays : 0,
    claimed: Math.floor(mask / 2 ** mission.bit) % 2 === 1,
  };
}
