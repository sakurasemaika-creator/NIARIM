import { describe, expect, it } from "vitest";
import {
  verifyVideoOwnership,
  type YoutubeVideoSnippet,
} from "../src/lib/youtube";

function snippet(
  overrides: Partial<YoutubeVideoSnippet> = {},
): YoutubeVideoSnippet {
  return {
    id: "video1",
    channelId: "channelA",
    publishedAt: new Date().toISOString(),
    title: "テスト動画",
    thumbnailUrl: "https://example.com/thumb.jpg",
    privacyStatus: "public",
    ...overrides,
  };
}

describe("verifyVideoOwnership（6章：videoId所有者検証）", () => {
  it("連携済みチャンネルIDと一致し、直近に投稿された動画は許可する", () => {
    const now = new Date("2026-01-01T00:00:00Z");
    const result = verifyVideoOwnership(
      snippet({ publishedAt: new Date(now.getTime() - 60_000).toISOString() }),
      "channelA",
      now,
    );
    expect(result.ok).toBe(true);
  });

  it("連携済みチャンネルIDと異なる場合は拒否する（他人の動画IDの持ち込み防止）", () => {
    const result = verifyVideoOwnership(
      snippet({ channelId: "channelB" }),
      "channelA",
    );
    expect(result).toEqual({
      ok: false,
      reason: expect.stringContaining("チャンネルの投稿ではありません"),
    });
  });

  it("投稿から時間が経ちすぎている場合は拒否する（過去動画の使い回し防止）", () => {
    const now = new Date("2026-01-01T00:00:00Z");
    const oldPublishedAt = new Date(
      now.getTime() - 60 * 60 * 1000,
    ).toISOString(); // 1時間前
    const result = verifyVideoOwnership(
      snippet({ publishedAt: oldPublishedAt }),
      "channelA",
      now,
    );
    expect(result.ok).toBe(false);
  });

  it("未来の日時（時計ズレ等の異常値）は拒否する", () => {
    const now = new Date("2026-01-01T00:00:00Z");
    const futurePublishedAt = new Date(now.getTime() + 60_000).toISOString();
    const result = verifyVideoOwnership(
      snippet({ publishedAt: futurePublishedAt }),
      "channelA",
      now,
    );
    expect(result.ok).toBe(false);
  });

  it("maxAgeMinutesちょうどの境界では許可する", () => {
    const now = new Date("2026-01-01T00:00:00Z");
    const publishedAt = new Date(now.getTime() - 15 * 60 * 1000).toISOString();
    const result = verifyVideoOwnership(
      snippet({ publishedAt }),
      "channelA",
      now,
      15,
    );
    expect(result.ok).toBe(true);
  });
});
