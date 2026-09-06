import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const source = readFileSync(
  resolve(__dirname, "../src/api/routes/bookmarks.ts"),
  "utf8",
);

describe("bookmark visibility contract", () => {
  it("uses the work publication fields as the visibility source of truth", () => {
    expect(source).toContain("function isWorkPublic(work: WorkItem)");
    expect(source).toContain("work.isNiarimPublished &&");
    expect(source).toContain('work.youtubePrivacyStatus !== "private"');
    expect(source).toContain('work.youtubePrivacyStatus !== "deleted"');
  });

  it("does not expose hidden works through a user's bookmark list", () => {
    expect(source).toContain("Boolean(w) && isWorkPublic(w!)");
  });

  it("does not allow a new bookmark on a hidden work for a non-author", () => {
    expect(source).toContain(
      "!isPublic && work.authorId !== auth.niarimUserId && !isBookmarked",
    );
  });

  it("still allows an existing bookmark to be removed after the work becomes hidden", () => {
    const guard = source.indexOf(
      "!isPublic && work.authorId !== auth.niarimUserId && !isBookmarked",
    );
    const removeBranch = source.indexOf("if (isBookmarked)", guard);
    expect(guard).toBeGreaterThanOrEqual(0);
    expect(removeBranch).toBeGreaterThan(guard);
  });

  it("hides bookmarker details for a hidden work from everyone except its author", () => {
    expect(source).toContain(
      "!isWorkPublic(work) && caller?.niarimUserId !== work.authorId",
    );
    expect(source).toContain('notFound("作品が見つかりません")');
  });
});
