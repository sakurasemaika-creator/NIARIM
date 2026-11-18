import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it, vi } from "vitest";

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

  it("retains a redacted placeholder without exposing hidden work metadata", () => {
    expect(source).toContain("toUnavailableWork(bookmarks[index].workId)");
    expect(source).toContain("isWorkPublic(raw as WorkItem)");
    expect(source).not.toContain("publicWorks");
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

});

const { send, tryAuthenticate } = vi.hoisted(() => ({
  send: vi.fn(), tryAuthenticate: vi.fn(),
}));
vi.mock("../src/lib/dynamo", async (load) => ({
  ...(await load<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({ tryAuthenticate }));
import { getUserBookmarks } from "../src/api/routes/bookmarks";

it("blocks bookmark list reads by anyone other than the owner", async () => {
  tryAuthenticate.mockResolvedValueOnce(null)
    .mockResolvedValueOnce({ niarimUserId: "viewer" });
  const event = { headers: {} } as Parameters<typeof getUserBookmarks>[0];
  for (let i = 0; i < 2; i++) {
    await expect(getUserBookmarks(event, "author")).rejects.toMatchObject({ statusCode: 403 });
  }
  expect(send).not.toHaveBeenCalled();
});
