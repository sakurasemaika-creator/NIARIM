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

  it("hides bookmarker details for a hidden work from everyone except its author", () => {
    expect(source).toContain(
      "!isWorkPublic(work) && caller?.niarimUserId !== work.authorId",
    );
    expect(source).toContain('notFound("作品が見つかりません")');
  });
});

const { send, tryAuthenticate, getUser } = vi.hoisted(() => ({
  send: vi.fn(), tryAuthenticate: vi.fn(), getUser: vi.fn(),
}));
vi.mock("../src/lib/dynamo", async (load) => ({
  ...(await load<typeof import("../src/lib/dynamo")>()),
  ddb: { send },
}));
vi.mock("../src/lib/auth", () => ({ tryAuthenticate, getUser }));
import { getUserBookmarks, getWorkBookmarkers } from "../src/api/routes/bookmarks";

it("returns totals and only the caller's own bookmark even with legacy public flags", async () => {
  vi.stubEnv("TABLE_NAME", "test");
  try {
    const workId = "Ab_12345678";
    const event = { headers: {} } as Parameters<typeof getWorkBookmarkers>[0];
    const work = {
      itemType: "WORK", authorId: "author", isNiarimPublished: true,
      youtubePrivacyStatus: "public", bookmarkCount: 5,
    };
    tryAuthenticate.mockResolvedValueOnce(null).mockResolvedValueOnce({ niarimUserId: "viewer" });
    send.mockResolvedValueOnce({ Item: work }).mockResolvedValueOnce({ Item: work })
      .mockResolvedValueOnce({ Item: { itemType: "BOOKMARK", bookmarkedAt: "2026-11-18" } });
    getUser.mockResolvedValueOnce({ channelName: "Viewer", bookmarksPublic: true });
    expect(JSON.parse((await getWorkBookmarkers(event, workId)).body!))
      .toEqual({ workId, totalCount: 5, users: [] });
    expect(JSON.parse((await getWorkBookmarkers(event, workId)).body!))
      .toEqual({ workId, totalCount: 5, users: [
        { userId: "viewer", channelName: "Viewer", channelAvatarUrl: null, bookmarkedAt: "2026-11-18" },
      ] });
    expect(send.mock.calls[2][0].input.Key).toEqual({
      pk: "USER#viewer", sk: "BOOKMARK#" + workId,
    });
    expect(getUser.mock.calls).toEqual([["viewer"]]);

    tryAuthenticate.mockResolvedValueOnce({ niarimUserId: "viewer" });
    await expect(getUserBookmarks(event, "author")).rejects.toMatchObject({ statusCode: 403 });
    expect(send).toHaveBeenCalledTimes(3);
  } finally {
    vi.unstubAllEnvs();
  }
});
