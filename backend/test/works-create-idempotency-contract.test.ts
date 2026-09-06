import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const source = readFileSync(
  resolve(__dirname, "../src/api/routes/worksCreate.ts"),
  "utf8",
);

describe("work registration idempotency contract", () => {
  it("does not consume post quota when the same author re-registers a work", () => {
    expect(source).toContain("const isNewWork = existing == null");
    expect(source).toContain("if (isNewWork)");
    expect(source).toContain("reservePostQuota");
  });

  it("updates existing work metadata without overwriting mutable community state", () => {
    expect(source).toContain("new UpdateCommand");
    expect(source).toContain('ConditionExpression: "authorId = :authorId"');
    expect(source).not.toContain("tags: existing?.tags");
    expect(source).not.toContain("lockedTags: existing?.lockedTags");
    expect(source).not.toContain("repostCount: existing?.repostCount");
    expect(source).not.toContain("bookmarkCount: existing?.bookmarkCount");
  });

  it("protects first registration from concurrent overwrite", () => {
    expect(source).toContain('ConditionExpression: "attribute_not_exists(pk)"');
    expect(source).toContain("ConditionalCheckFailedException");
    expect(source).toContain('"VIDEO_REGISTRATION_CONFLICT"');
  });

  it("removes public indexes immediately when YouTube or NIARIM visibility is off", () => {
    expect(source).toContain("existing.isNiarimPublished &&");
    expect(source).toContain('status !== "private"');
    expect(source).toContain('status !== "deleted"');
    expect(source).toContain('"gsi1pk"');
    expect(source).toContain('"gsi4sk"');
  });
});
