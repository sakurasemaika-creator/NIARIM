import { afterEach, describe, expect, it, vi } from "vitest";
import { batchGetVideoStats } from "../src/lib/youtube";

afterEach(() => vi.unstubAllGlobals());
function mockResponses(stats: unknown, statuses: unknown) {
  const fetch = vi
    .fn()
    .mockResolvedValueOnce(Response.json(stats))
    .mockResolvedValueOnce(Response.json(statuses));
  vi.stubGlobal("fetch", fetch);
  return fetch;
}

describe("YouTube statistics and visibility", () => {
  it("uses the documented endpoint and reads privacy separately", async () => {
    const fetch = mockResponses(
      {
        items: [
          { id: "video", statistics: { viewCount: "12", likeCount: "3" } },
        ],
      },
      { items: [{ id: "video", status: { privacyStatus: "unlisted" } }] },
    );
    const result = await batchGetVideoStats(["video"], "test-key");
    const url = fetch.mock.calls[0][0] as URL;
    expect(url.pathname).toBe("/youtube/v3/videos:batchGetStats");
    expect(url.searchParams.get("part")).toBe("statistics");
    expect((fetch.mock.calls[1][0] as URL).searchParams.get("part")).toBe(
      "status",
    );
    expect(result.get("video")).toEqual({
      id: "video",
      privacyStatus: "unlisted",
      viewCount: 12,
      likeCount: 3,
      commentCount: undefined,
    });
  });

  it("does not turn a partial statistics failure into deletion or zero counts", async () => {
    mockResponses(
      { items: [], summary: { failedVideoIds: ["video"] } },
      { items: [{ id: "video", status: { privacyStatus: "public" } }] },
    );
    expect((await batchGetVideoStats(["video"], "key")).get("video")).toEqual({
      id: "video",
      privacyStatus: "public",
      viewCount: undefined,
      likeCount: undefined,
      commentCount: undefined,
    });
  });

  it("keeps an inaccessible video hidden without declaring it deleted", async () => {
    mockResponses({ items: [] }, { items: [] });
    expect(
      (await batchGetVideoStats(["video"], "key")).get("video")?.privacyStatus,
    ).toBe("private");
  });

  it("rejects an unknown privacy response instead of treating it as public", async () => {
    mockResponses({ items: [] }, { items: [{ id: "video", status: {} }] });
    await expect(batchGetVideoStats(["video"], "key")).rejects.toThrow(
      "公開状態が不正",
    );
  });

  it("preserves previous values when counters are missing, negative or unsafe", async () => {
    mockResponses(
      {
        items: [
          {
            id: "video",
            statistics: {
              viewCount: "-1",
              likeCount: "9007199254740992",
              commentCount: "invalid",
            },
          },
        ],
      },
      { items: [{ id: "video", status: { privacyStatus: "public" } }] },
    );
    const stats = (await batchGetVideoStats(["video"], "key")).get("video");
    expect(stats?.viewCount).toBeUndefined();
    expect(stats?.likeCount).toBeUndefined();
    expect(stats?.commentCount).toBeUndefined();
  });
});
