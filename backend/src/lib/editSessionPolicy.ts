/**
 * Low-write editing session policy.
 *
 * A device can forge edit events. Every value returned here is only a
 * *candidate* for later integrity review, NEVER verified mission time.
 * The server binds time to its own clock and rate-limits accumulation.
 */
export const EDIT_CHECKPOINT_INTERVAL_SECONDS = 15 * 60;
export const EDIT_CHECKPOINT_MAX_GAP_SECONDS = 20 * 60;
export const EDIT_DAILY_CANDIDATE_MAX_SECONDS = 8 * 60 * 60;

/** One real committed content change is enough for short sessions. */
export const SECONDS_PER_MEANINGFUL_MUTATION = 180;

/**
 * No edit data, images or coordinates are sent. This upper-bounds how much
 * unverified candidate time one server-observed interval may produce.
 */
export function boundedCandidateEditSeconds(args: {
  serverElapsedMs: number;
  reportedActiveSeconds: number;
  meaningfulMutations: number;
  alreadyCreditedToday: number;
}): number {
  const { serverElapsedMs, reportedActiveSeconds, meaningfulMutations,
    alreadyCreditedToday } = args;
  if (![serverElapsedMs, reportedActiveSeconds, meaningfulMutations,
    alreadyCreditedToday].every((n) => Number.isSafeInteger(n) && n >= 0)) {
    throw new Error("Invalid edit activity counters");
  }
  if (serverElapsedMs > EDIT_CHECKPOINT_MAX_GAP_SECONDS * 1000) {
    throw new Error("Editing session expired");
  }
  if (meaningfulMutations < 1) return 0;
  return Math.max(0, Math.min(
    Math.floor(serverElapsedMs / 1000),
    reportedActiveSeconds,
    EDIT_CHECKPOINT_INTERVAL_SECONDS,
    meaningfulMutations * SECONDS_PER_MEANINGFUL_MUTATION,
    EDIT_DAILY_CANDIDATE_MAX_SECONDS - alreadyCreditedToday,
  ));
}

export interface CandidateEditSession {
  id: string;
  startedAtMs: number;
  lastAtMs: number;
  lastSequence: number;
}

export function validEditSession(
  value: unknown,
): value is CandidateEditSession {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const v = value as Record<string, unknown>;
  return typeof v.id === "string" &&
    /^[0-9a-f-]{36}$/.test(v.id) &&
    [v.startedAtMs, v.lastAtMs, v.lastSequence]
      .every((n) => typeof n === "number" &&
        Number.isSafeInteger(n) && n >= 0);
}

export function utcEditDay(epochMs: number): number {
  if (!Number.isSafeInteger(epochMs) || epochMs < 0) {
    throw new Error("Invalid server time");
  }
  return Math.floor(epochMs / 86400000);
}
