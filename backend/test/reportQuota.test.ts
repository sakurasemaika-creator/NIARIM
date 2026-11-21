import { describe, expect, it } from "vitest";
import {
  reportDayWindowId,
  reportWindowId,
  REPORT_MAX_PER_DAY,
  REPORT_MAX_PER_WINDOW,
  REPORT_WINDOW_MINUTES,
} from "../src/lib/reportQuota";

describe("通報レート制限の窓ID", () => {
  it("同じ10分窓の中では同一IDになる", () => {
    const a = new Date("2026-09-02T12:00:00Z");
    const b = new Date("2026-09-02T12:09:59Z");
    expect(reportWindowId(a)).toBe(reportWindowId(b));
  });

  it("窓をまたぐとIDが変わる（＝カウンターがリセットされる）", () => {
    const a = new Date("2026-09-02T12:09:59Z");
    const b = new Date("2026-09-02T12:10:00Z");
    expect(reportWindowId(a)).not.toBe(reportWindowId(b));
  });

  it("窓の長さは定数どおり10分", () => {
    const base = new Date("2026-09-02T00:00:00Z");
    const justInside = new Date(
      base.getTime() + (REPORT_WINDOW_MINUTES * 60 * 1000 - 1),
    );
    const justOutside = new Date(
      base.getTime() + REPORT_WINDOW_MINUTES * 60 * 1000,
    );
    expect(reportWindowId(base)).toBe(reportWindowId(justInside));
    expect(reportWindowId(base)).not.toBe(reportWindowId(justOutside));
  });

  it("日次窓はUTCの日付で切り替わる", () => {
    expect(reportDayWindowId(new Date("2026-09-02T23:59:59Z"))).toBe(
      "D20260902",
    );
    expect(reportDayWindowId(new Date("2026-09-03T00:00:00Z"))).toBe(
      "D20260903",
    );
  });

  it("短期窓の上限は日次上限より小さい（2段構えとして意味がある）", () => {
    expect(REPORT_MAX_PER_WINDOW).toBeLessThan(REPORT_MAX_PER_DAY);
  });
});
