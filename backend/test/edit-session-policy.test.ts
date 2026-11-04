import { describe, it, expect } from "vitest";
import {
  boundedCandidateEditSeconds, validEditSession, utcEditDay,
  EDIT_CHECKPOINT_INTERVAL_SECONDS, EDIT_DAILY_CANDIDATE_MAX_SECONDS,
} from "../src/lib/editSessionPolicy";

describe("inexpensive unverified creator editing time pilot", () => {
  const base = {
    serverElapsedMs: 900000,
    reportedActiveSeconds: 900,
    meaningfulMutations: 20,
    alreadyCreditedToday: 0,
  };
  it("limits an interval to the actual server elapsed time", () => {
    expect(boundedCandidateEditSeconds({
      ...base, serverElapsedMs: 270000,
    })).toBe(270);
    expect(boundedCandidateEditSeconds(base))
      .toBe(EDIT_CHECKPOINT_INTERVAL_SECONDS);
  });
  it("does not count touch-only activity without content changes", () => {
    expect(boundedCandidateEditSeconds({
      ...base, meaningfulMutations: 0,
    })).toBe(0);
    expect(boundedCandidateEditSeconds({
      ...base, meaningfulMutations: 1,
    })).toBe(0);
    expect(boundedCandidateEditSeconds({
      ...base, meaningfulMutations: 3,
    })).toBe(270);
  });
  it("caps per-UTC-day candidate time", () => {
    expect(boundedCandidateEditSeconds({
      ...base,
      alreadyCreditedToday: EDIT_DAILY_CANDIDATE_MAX_SECONDS - 35,
    })).toBe(35);
    expect(boundedCandidateEditSeconds({
      ...base,
      alreadyCreditedToday: EDIT_DAILY_CANDIDATE_MAX_SECONDS,
    })).toBe(0);
  });
  it("rejects future/stale/invalid count reports", () => {
    expect(() => boundedCandidateEditSeconds({
      ...base, serverElapsedMs: 21 * 60000,
    })).toThrow("expired");
    expect(() => boundedCandidateEditSeconds({
      ...base, reportedActiveSeconds: -1,
    })).toThrow("Invalid");
    expect(() => boundedCandidateEditSeconds({
      ...base, meaningfulMutations: 0.5,
    })).toThrow("Invalid");
  });
  it("validates compact session state and UTC day", () => {
    expect(validEditSession({
      id: "3c32e099-3c43-40aa-bb11-88388172e8a9",
      startedAtMs: 123, lastAtMs: 456, lastSequence: 3,
    })).toBe(true);
    expect(validEditSession({
      id: "not-an-id", startedAtMs: 1, lastAtMs: 2, lastSequence: 2,
    })).toBe(false);
    expect(utcEditDay(86400000)).toBe(1);
  });
});
