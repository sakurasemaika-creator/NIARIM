import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const createSource = readFileSync(
  resolve(__dirname, "../src/api/routes/worksCreate.ts"),
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
});
