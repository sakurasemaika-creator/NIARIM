import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const source = readFileSync(
  resolve(__dirname, "../src/api/routes/worksCreate.ts"),
  "utf8",
);

describe("work registration idempotency contract", () => {
  it("treats the YouTube video id as the NIARIM work idempotency key", () => {
    expect(source).toContain("workId: body.youtubeVideoId");
    expect(source).toContain("youtubeVideoId: body.youtubeVideoId");
    expect(source).toContain("Key: Keys.work(body.youtubeVideoId)");
  });

  it("returns an existing work unchanged for a duplicate POST by the same author", () => {
    expect(source).toContain("if (existing) {");
    expect(source).toContain("existing.authorId !== auth.niarimUserId");
    expect(source).toContain("return created({ work: toPublicWork(existing) })");
    expect(source).not.toContain("new UpdateCommand");
  });

  it("does not reserve post quota before the duplicate-POST early return", () => {
    const duplicateReturn = source.indexOf(
      "return created({ work: toPublicWork(existing) })",
    );
    const quotaReservation = source.indexOf("await reservePostQuota");
    expect(duplicateReturn).toBeGreaterThan(-1);
    expect(quotaReservation).toBeGreaterThan(duplicateReturn);
  });

  it("applies the recent-upload ownership check only to a new work", () => {
    const duplicateReturn = source.indexOf(
      "return created({ work: toPublicWork(existing) })",
    );
    const ownershipCheck = source.indexOf(
      "const verification = verifyVideoOwnership(",
    );
    expect(ownershipCheck).toBeGreaterThan(duplicateReturn);
  });

  it("keeps publish-state changes outside POST /works", () => {
    expect(source).toContain("公開/非公開切り替えやタイトル変更はPATCH /works/{id}");
    expect(source).not.toContain("existing.isNiarimPublished");
    expect(source).not.toContain("hasPublicIndexes");
  });

  it("protects first registration from concurrent overwrite", () => {
    expect(source).toContain('ConditionExpression: "attribute_not_exists(pk)"');
    expect(source).toContain("ConditionalCheckFailedException");
    expect(source).toContain('"VIDEO_REGISTRATION_CONFLICT"');
  });

  it("never revives a deleted work id", () => {
    expect(source).toContain('existingRaw?.itemType === "WORK_TOMBSTONE"');
    expect(source).toContain('"WORK_DELETED"');
  });
});
