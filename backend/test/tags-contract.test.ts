import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const source = readFileSync(
  resolve(__dirname, "../src/api/routes/tags.ts"),
  "utf8",
);

describe("tag editing contract", () => {
  it("limits one work to 10 tags", () => {
    expect(source).toContain("const MAX_TAGS_PER_WORK = 10");
    expect(source).toContain('"TAG_LIMIT_EXCEEDED"');
  });

  it("keeps author-only lock and locked-tag delete protection", () => {
    expect(source).toContain('body.action === "lock"');
    expect(source).toContain('body.action === "unlock"');
    expect(source).toContain("!isOwner");
    expect(source).toContain("work.lockedTags.includes(body.tag)");
  });

  it("prevents lost updates during concurrent tag edits", () => {
    expect(source).toContain("ConditionExpression");
    expect(source).toContain(":expectedTags");
    expect(source).toContain(":expectedLockedTags");
    expect(source).toContain("ConditionalCheckFailedException");
    expect(source).toContain("MAX_CONFLICT_RETRIES = 3");
    expect(source).toContain('"TAG_UPDATE_CONFLICT"');
  });
});
