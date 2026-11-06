import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const source = readFileSync(
  resolve(__dirname, "../src/batch/statsUpdate.ts"),
  "utf8",
);

describe("stats update DynamoDB contract", () => {
  it("defines every ranking GSI placeholder used by the visible-work update", () => {
    expect(source).toContain('"gsi1pk = :rankPk"');
    expect(source).toContain('values[":rankPk"] = "RANKING#ALL"');
    expect(source).toContain('"gsi2pk = :bmPk"');
    expect(source).toContain('values[":bmPk"] = "BOOKMARK_RANKING"');
    expect(source).toContain('"gsi3pk = :authorPk"');
    expect(source).toContain('values[":authorPk"] = `AUTHOR#${work.authorId}`');
    expect(source).toContain('"gsi4pk = :latestPk"');
    expect(source).toContain('values[":latestPk"] = "LATEST"');
  });

  it("removes all public GSI keys when a work is hidden", () => {
    for (const key of [
      "gsi1pk",
      "gsi1sk",
      "gsi2pk",
      "gsi2sk",
      "gsi3pk",
      "gsi3sk",
      "gsi4pk",
      "gsi4sk",
    ]) {
      expect(source).toContain(`"${key}"`);
    }
  });

  it("does not let a stale scan overwrite a concurrent visibility change", () => {
    expect(source).toContain('"isNiarimPublished = :expectedPublished"');
    expect(source).toContain("ConditionalCheckFailedException");
    expect(source).toContain("MAX_VISIBILITY_CONFLICT_RETRIES = 2");
    expect(source).toContain("new GetCommand");
    expect(source).toMatch(
      /updateWorkStats\(\s*latestRaw as WorkItem,\s*stats,\s*topLists,/s,
    );
  });

  it("does not rewrite bookmark ranking from a stale scan during normal visible updates", () => {
    expect(source).toContain("const hasPublicIndexes =");
    expect(source).toContain("if (!hasPublicIndexes)");
    expect(source).toContain('conditions.push("bookmarkCount = :expectedBookmarkCount")');
  });

  it("adds period ranking entries only after the conditional DynamoDB update succeeds", () => {
    const sendIndex = source.indexOf("await ddb.send(", source.indexOf("async function updateWorkStats"));
    const rankingInsertIndex = source.indexOf(
      "for (const period of DELTA_RANKING_PERIODS)",
      sendIndex,
    );
    expect(sendIndex).toBeGreaterThanOrEqual(0);
    expect(rankingInsertIndex).toBeGreaterThan(sendIndex);
  });
});
