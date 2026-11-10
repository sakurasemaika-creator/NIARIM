/**
 * Low-write, server-clock-bounded editing session policy.
 *
 * A device cannot create server elapsed time, bypass daily caps or replay
 * a checkpoint. A modified device CAN fabricate mutation counters, however.
 * Genuine drawing cannot be proven solely by this local editor protocol.
 * Mission payouts require separate human anti-abuse approval.
 */
export const EDIT_CHECKPOINT_INTERVAL_SECONDS = 15 * 60;
export const EDIT_CHECKPOINT_MAX_GAP_SECONDS = 20 * 60;
export const EDIT_DAILY_CANDIDATE_MAX_SECONDS = 8 * 60 * 60;

/** Double approval for server-bounded, authenticated session time.
 * Candidate-only observations gathered before activation NEVER become
 * verified seconds retroactively.
 */
export function editTimeVerificationEnabled():boolean {
  return process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED==="true" &&
    process.env.CREATOR_EDIT_TIME_VERIFICATION_ENABLED==="true" &&
    process.env.CREATOR_EDIT_TIME_VERIFICATION_REVIEW_APPROVED==="true";
}

/** One real committed content change is enough for short sessions. */
export const SECONDS_PER_MEANINGFUL_MUTATION = 180;

/**
 * No edit data, images or coordinates are sent. This upper-bounds how much
 * server-bounded active time one server-observed interval may produce.
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
