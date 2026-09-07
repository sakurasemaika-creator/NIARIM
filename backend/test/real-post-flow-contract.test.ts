import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const createSource = readFileSync(
  resolve(__dirname, "../src/api/routes/worksCreate.ts"),
  "utf8",
);
const updateSource = readFileSync(
  resolve(__dirname, "../src/api/routes/worksUpdate.ts"),
  "utf8",
);
const statsSource = readFileSync(
  resolve(__dirname, "../src/batch/statsUpdate.ts"),
  "utf8",
);
const handlerSource = readFileSync(
  resolve(__dirname, "../src/api/handler.ts"),
  "utf8",
);
const userWorksSource = readFileSync(
  resolve(__dirname, "../src/api/routes/userWorks.ts"),
  "utf8",
);

describe("real posting flow contract", () => {
  it("uses the YouTube video id as the canonical NIARIM work id", () => {
    expect(createSource).toContain("Keys.work(body.youtubeVideoId)");
    expect(createSource).toContain("workId: body.youtubeVideoId");
    expect(createSource).toContain("youtubeVideoId: body.youtubeVideoId");
  });

  it("makes POST /works idempotent for a same-author retry", () => {
    expect(createSource).toContain("if (existing)");
    expect(createSource).toContain("existing.authorId !== auth.niarimUserId");
    expect(createSource).toContain("return created({ work: toPublicWork(existing) })");
  });

  it("creates an initially hidden NIARIM work without a temporary public-index window", () => {
    expect(createSource).toContain("isNiarimPublished?: boolean");
    expect(createSource).toContain(
      "const isNiarimPublished = body.isNiarimPublished ?? true",
    );
    expect(createSource).toContain(
      "isNiarimPublished && isYoutubeVisible(snippet.privacyStatus)",
    );
    expect(createSource).toContain("isNiarimPublished,");
  });

  it("discovers and caches the upload account's YouTube channel on first post", () => {
    expect(createSource).toContain(
      "const channelInfo = await getOwnChannelInfo(body.youtubeAccessToken)",
    );
    expect(createSource).toContain(
      "const linkedChannelId = user.youtubeChannelId ?? channelInfo?.channelId",
    );
    expect(createSource).toContain("await cacheChannelInfo(auth.niarimUserId");
  });

  it("rejects a token whose YouTube channel differs from an already linked channel", () => {
    expect(createSource).toContain("user.youtubeChannelId !== channelInfo.channelId");
    expect(createSource).toContain("アカウントを切り替えてください");
  });
});

describe("YouTube visibility recovery contract", () => {
  it("keeps the NIARIM publish preference while YouTube temporarily forces the work hidden", () => {
    expect(updateSource).toContain(
      "const nextPublished = body.isNiarimPublished ?? work.isNiarimPublished",
    );
    expect(updateSource).toContain('work.youtubePrivacyStatus === "private"');
    expect(updateSource).toContain("const nowVisible = nextPublished && !forcedHidden");
    expect(updateSource).toContain('"isNiarimPublished = :pub"');
  });

  it("restores public indexes automatically when YouTube becomes public again", () => {
    expect(statsSource).toContain(
      "const isVisible = work.isNiarimPublished && !forcedHidden",
    );
    expect(statsSource).toContain('youtubePrivacyStatus = :status');
    expect(statsSource).toContain('"gsi2pk = :bmPk"');
    expect(statsSource).toContain('"gsi3pk = :authorPk"');
    expect(statsSource).toContain('"gsi4pk = :latestPk"');
    expect(statsSource).toContain("if (!hasPublicIndexes)");
  });

  it("treats a missing YouTube video as deleted rather than a recoverable private state", () => {
    expect(statsSource).toContain(
      'const youtubePrivacyStatus = stats ? stats.privacyStatus : "deleted"',
    );
    expect(statsSource).toContain('youtubePrivacyStatus === "deleted"');
  });
});

describe("current-user works contract", () => {
  it("routes GET /me/works to an authenticated owner lookup", () => {
    expect(handlerSource).toContain('route("GET", "/me/works", (e) => getMyWorks(e))');
    expect(userWorksSource).toContain("export async function getMyWorks");
    expect(userWorksSource).toContain("caller.niarimUserId");
  });

  it("queries the all-states author index so hidden own posts remain manageable", () => {
    expect(userWorksSource).toContain('IndexName: "GSI3AllStates"');
    expect(userWorksSource).toContain('`AUTHOR#${authorId}`');
  });

  it("returns YouTube privacy state only on owner-visible work lists", () => {
    expect(userWorksSource).toContain("function toOwnerWork(work: WorkItem)");
    expect(userWorksSource).toContain("youtubePrivacyStatus: work.youtubePrivacyStatus");
    expect(userWorksSource).toContain("works: works.map(toOwnerWork)");
    expect(userWorksSource).toContain(
      "works: includeHidden ? result.map(toOwnerWork) : result.map(toPublicWork)",
    );
  });
});
