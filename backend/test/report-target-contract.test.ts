import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const source = readFileSync(
  resolve(__dirname, "../src/api/routes/reports.ts"),
  "utf8",
);

describe("report target contract", () => {
  it("requires a real public work before reserving report quota", () => {
    const getIndex = source.indexOf("new GetCommand");
    const quotaIndex = source.indexOf("reserveReportQuota");
    expect(getIndex).toBeGreaterThanOrEqual(0);
    expect(quotaIndex).toBeGreaterThan(getIndex);
    expect(source).toContain("if (!work || !isWorkPublic(work))");
    expect(source).toContain('notFound("作品が見つかりません")');
  });

  it("does not allow hidden or YouTube-deleted works as report targets", () => {
    expect(source).toContain("work.isNiarimPublished &&");
    expect(source).toContain('work.youtubePrivacyStatus !== "private"');
    expect(source).toContain('work.youtubePrivacyStatus !== "deleted"');
  });
});
