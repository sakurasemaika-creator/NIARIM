import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const source = readFileSync(
  resolve(__dirname, "../src/api/routes/reposts.ts"),
  "utf8",
);

describe("repost visibility contract", () => {
  it("rejects a new repost when the work is hidden", () => {
    expect(source).toContain("function isWorkPublic(work: WorkItem)");
    expect(source).toContain("if (!isWorkPublic(work) && !isReposted)");
    expect(source).toContain('notFound("作品が見つかりません")');
  });

  it("keeps the removal branch reachable for an existing repost after hiding", () => {
    const guard = source.indexOf("if (!isWorkPublic(work) && !isReposted)");
    const removeBranch = source.indexOf("if (isReposted)", guard);
    expect(guard).toBeGreaterThanOrEqual(0);
    expect(removeBranch).toBeGreaterThan(guard);
  });
});
