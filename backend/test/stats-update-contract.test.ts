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
});
