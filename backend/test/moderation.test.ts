import type { APIGatewayProxyEventV2, APIGatewayProxyStructuredResultV2 } from "aws-lambda";
import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import Anthropic from "@anthropic-ai/sdk";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { FakeDynamo } from "./helpers/fakeDynamo";

const mocks = vi.hoisted(() => ({
  authenticate: vi.fn(),
  getUser: vi.fn(),
  verifyGoogleIdentity: vi.fn(),
  readSecureParameter: vi.fn(),
  reserveReportQuota: vi.fn(async () => {}),
  reservePostQuota: vi.fn(async () => {}),
  getVideoSnippet: vi.fn(),
}));
vi.mock("../src/lib/auth", () => ({
  authenticate: mocks.authenticate,
  getUser: mocks.getUser,
  verifyGoogleIdentity: mocks.verifyGoogleIdentity,
  tryAuthenticate: vi.fn(async () => null),
  cacheChannelInfo: vi.fn(async () => {}),
}));
vi.mock("../src/lib/ssmParameters", () => ({ readSecureParameter: mocks.readSecureParameter }));
vi.mock("../src/lib/reportQuota", () => ({ reserveReportQuota: mocks.reserveReportQuota }));
vi.mock("../src/lib/quota", () => ({
  reservePostQuota: mocks.reservePostQuota, releasePostQuota: vi.fn(async () => {}),
}));
vi.mock("../src/lib/youtube", () => ({
  getVideoSnippet: mocks.getVideoSnippet,
  getOwnChannelInfo: mocks.getVideoSnippet,
  verifyVideoOwnership: vi.fn(() => ({ ok: true })),
}));

import { ddb } from "../src/lib/dynamo";
import { ApiError } from "../src/lib/response";
import { handler } from "../src/api/handler";
import { createReport } from "../src/api/routes/reports";
import { createWork } from "../src/api/routes/worksCreate";
import { updateWork } from "../src/api/routes/worksUpdate";
import { decodeReportId, encodeReportId, moderationConfig } from "../src/lib/moderation";
import {
  buildTriageRequest,
  parseTriageResponse,
  triageReport,
  type TriageClient,
} from "../src/lib/moderationAi";
import { notifyNewReport, reportMail, SUBJECT_PREFIX } from "../src/lib/moderationNotify";
import { processNewReport, handler as workerHandler } from "../src/batch/moderationWorker";

const fake = new FakeDynamo();
vi.spyOn(ddb, "send").mockImplementation(fake.send as never);

const ADMIN_PARAM = "/niarim/moderation/admin-emails";
const RESEND_PARAM = "/niarim/moderation/resend-api-key";
const AI_PARAM = "/niarim/moderation/anthropic-api-key";
const ORIGIN = "https://niarim.miranima-studio.com";
const author = "N" + "a".repeat(32);
const reporters = ["b", "c", "d", "e"].map((c) => "N" + c.repeat(32));
const workIds = ["W".repeat(11), "X".repeat(11), "Y".repeat(11), "Z".repeat(11)];
let params: Record<string, string>;

function seedUser(id: string, extra: Record<string, unknown> = {}) {
  fake.put({
    itemType: "USER", pk: `USER#${id}`, sk: "META", niarimUserId: id, googleSub: id,
    membershipTier: "free", followerCount: 0, followingCount: 0, createdAt: "2026-11-01T00:00:00.000Z",
    channelName: id === author ? "Author Channel" : "Someone", ...extra,
  });
}

function seedWork(workId: string, extra: Record<string, unknown> = {}) {
  fake.put({
    itemType: "WORK", pk: `WORK#${workId}`, sk: "META", workId, youtubeVideoId: workId,
    authorId: author, title: `Title ${workId}`, tags: ["tag"], channelName: "Author Channel",
    youtubeUrl: `https://www.youtube.com/watch?v=${workId}`,
    thumbnailUrl: `https://i.ytimg.com/vi/${workId}/hqdefault.jpg`,
    isNiarimPublished: true, youtubePrivacyStatus: "public", postedAt: "2026-11-01T00:00:00.000Z",
    bookmarkCount: 0, repostCount: 0, ...extra,
  });
  fake.put({ itemType: "WORK_DETAIL", pk: `WORK#${workId}`, sk: "DETAIL", description: `About ${workId}` });
}

function seedReport(workId: string | undefined, reporter: string, at: string, extra: Record<string, unknown> = {}) {
  const pk = workId ? `WORK#${workId}` : `USER#${author}`;
  const item = {
    itemType: "REPORT", pk, sk: `REPORT#${reporter}#${at}`, workId, targetId: author,
    reporterId: reporter, reason: "不適切です", status: "pending", createdAt: at,
    gsi7pk: "REPORT_STATUS#pending", gsi7sk: at, ...extra,
  };
  fake.put(item);
  return item;
}

function httpEvent(method: string, path: string, options: {
  body?: unknown; query?: Record<string, string>; origin?: string; token?: boolean;
} = {}): APIGatewayProxyEventV2 {
  return {
    requestContext: { http: { method, path } },
    headers: {
      ...(options.token === false ? {} : { authorization: "Bearer token" }),
      ...(options.origin ? { origin: options.origin } : {}),
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
    queryStringParameters: options.query,
  } as unknown as APIGatewayProxyEventV2;
}

async function call(method: string, path: string, options: Parameters<typeof httpEvent>[2] = {}) {
  const response = await handler(httpEvent(method, path, options)) as APIGatewayProxyStructuredResultV2;
  return { status: response.statusCode, headers: response.headers ?? {}, body: JSON.parse(response.body || "{}") };
}

function admin(email = "owner@example.com", verified = true) {
  mocks.verifyGoogleIdentity.mockResolvedValue({ sub: "g", email, email_verified: verified });
}

beforeEach(() => {
  fake.items.clear();
  fake.calls.length = 0;
  vi.clearAllMocks();
  vi.unstubAllEnvs();
  vi.stubEnv("TABLE_NAME", "moderation-test");
  vi.stubEnv("MODERATION_ADMIN_EMAILS_PARAMETER", ADMIN_PARAM);
  vi.stubEnv("MODERATION_RESEND_API_KEY_PARAMETER", RESEND_PARAM);
  vi.stubEnv("MODERATION_ANTHROPIC_API_KEY_PARAMETER", AI_PARAM);
  params = { [ADMIN_PARAM]: " Owner@Example.com , helper@example.com " };
  mocks.readSecureParameter.mockImplementation(async (name: string) => params[name]);
  mocks.getUser.mockImplementation(async (id: string) => fake.get(`USER#${id}`, "META"));
  admin();
  seedUser(author);
  for (const id of reporters) seedUser(id);
});

describe("admin authentication", () => {
  it("refuses every admin request with 403 while the allowlist parameter is missing", async () => {
    delete params[ADMIN_PARAM];
    const response = await call("GET", "/admin/me");
    expect(response.status).toBe(403);
    expect(response.body.code).toBe("ADMIN_DISABLED");
    expect(mocks.verifyGoogleIdentity).not.toHaveBeenCalled();
  });

  it("needs a valid Google ID token and a verified allowlisted email", async () => {
    mocks.verifyGoogleIdentity.mockRejectedValueOnce(new ApiError(401, "bad token", "UNAUTHORIZED"));
    expect((await call("GET", "/admin/me")).status).toBe(401);
    admin("someone@example.com");
    expect((await call("GET", "/admin/me")).body.code).toBe("ADMIN_FORBIDDEN");
    admin("owner@example.com", false);
    expect((await call("GET", "/admin/me")).status).toBe(403);
    admin("HELPER@example.com");
    const ok = await call("GET", "/admin/me");
    expect(ok.status).toBe(200);
    expect(ok.body).toMatchObject({ email: "helper@example.com", settings: {
      reportHideThreshold: 3, strikeSuspendThreshold: 3, aiMode: "backlog", aiBacklogThreshold: 20,
    } });
  });

  it("answers CORS preflight and responses only for the website origin on admin paths", async () => {
    const preflight = await call("OPTIONS", "/admin/reports", { origin: ORIGIN, token: false });
    expect(preflight.status).toBe(204);
    expect(preflight.headers["access-control-allow-origin"]).toBe(ORIGIN);
    expect(preflight.headers["access-control-allow-headers"]).toContain("authorization");
    const other = await call("OPTIONS", "/admin/reports", { origin: "https://evil.example", token: false });
    expect(other.headers["access-control-allow-origin"]).toBeUndefined();
    const denied = await call("GET", "/admin/me", { origin: ORIGIN });
    expect(denied.headers["access-control-allow-origin"]).toBe(ORIGIN);
    const app = await call("GET", "/no-such-route", { origin: ORIGIN });
    expect(app.headers["access-control-allow-origin"]).toBeUndefined();
  });
});

describe("admin report queue", () => {
  it("lists pending reports with work, author, reporter count and paging", async () => {
    seedWork(workIds[0]);
    seedReport(workIds[0], reporters[0], "2026-11-25T01:00:00.000Z");
    seedReport(workIds[0], reporters[1], "2026-11-25T02:00:00.000Z", {
      aiTriage: { status: "ok", severity: "low", recommendedAction: "keep", triagedAt: "x" },
    });
    const first = await call("GET", "/admin/reports", { query: { status: "pending", limit: "1" } });
    expect(first.status).toBe(200);
    expect(first.body.reports).toHaveLength(1);
    expect(first.body.reports[0]).toMatchObject({
      status: "pending", targetType: "work", workId: workIds[0], reason: "不適切です",
      reporterCount: 2, openReportCount: 2,
      work: { title: `Title ${workIds[0]}`, description: `About ${workIds[0]}`, tags: ["tag"],
        youtubeVideoId: workIds[0], authorId: author, moderationHidden: false, autoHidden: false },
      author: { userId: author, displayName: "Author Channel", strikeCount: 0, postingSuspended: false },
      aiTriage: null,
    });
    expect(first.body.nextCursor).toEqual(expect.any(String));
    const second = await call("GET", "/admin/reports", {
      query: { status: "pending", limit: "1", cursor: first.body.nextCursor },
    });
    expect(second.body.reports[0].aiTriage).toMatchObject({ severity: "low" });
    expect((await call("GET", "/admin/reports", { query: { status: "bogus" } })).status).toBe(400);
  });

  it("marks a report as reviewing and shows the related reports", async () => {
    seedWork(workIds[0]);
    const report = seedReport(workIds[0], reporters[0], "2026-11-25T01:00:00.000Z");
    seedReport(workIds[0], reporters[1], "2026-11-25T02:00:00.000Z");
    const id = encodeReportId(report);
    expect(decodeReportId(id)).toEqual({ pk: report.pk, sk: report.sk });
    const reviewed = await call("POST", `/admin/reports/${id}/review`);
    expect(reviewed.body.report.status).toBe("reviewing");
    expect(fake.get(report.pk, report.sk)).toMatchObject({
      status: "reviewing", gsi7pk: "REPORT_STATUS#reviewing", reviewedBy: "owner@example.com",
    });
    const detail = await call("GET", `/admin/reports/${id}`);
    expect(detail.body.relatedReports).toHaveLength(2);
    expect((await call("GET", "/admin/reports/not-a-report")).status).toBe(404);
  });

  it("dismisses every open report on the work and restores a work the system hid", async () => {
    seedWork(workIds[0], {
      moderationHidden: true, moderationAutoHidden: true,
      moderationAutoHiddenReason: "reporters", moderationAutoHiddenAt: "2026-11-25T03:00:00.000Z",
    });
    const report = seedReport(workIds[0], reporters[0], "2026-11-25T01:00:00.000Z");
    seedReport(workIds[0], reporters[1], "2026-11-25T02:00:00.000Z");
    const response = await call("POST", `/admin/reports/${encodeReportId(report)}/dismiss`,
      { body: { note: "問題なし" } });
    expect(response.body).toMatchObject({ ok: true, resolved: 2, unhidden: true });
    const work = fake.get(`WORK#${workIds[0]}`, "META")!;
    expect(work.moderationHidden).toBeUndefined();
    expect(work.moderationAutoHidden).toBeUndefined();
    for (const item of fake.items.values()) {
      if (item.itemType === "REPORT") {
        expect(item).toMatchObject({ status: "resolved", decision: "dismiss", gsi7pk: "REPORT_STATUS#resolved" });
      }
    }
    expect((await call("POST", `/admin/reports/${encodeReportId(report)}/dismiss`)).body.code)
      .toBe("REPORT_RESOLVED");
  });

  it("keeps a moderator's hide when a later report is dismissed", async () => {
    seedWork(workIds[0], { moderationHidden: true, moderationHiddenBy: "owner@example.com" });
    const report = seedReport(workIds[0], reporters[0], "2026-11-25T01:00:00.000Z");
    const response = await call("POST", `/admin/reports/${encodeReportId(report)}/dismiss`);
    expect(response.body.unhidden).toBe(false);
    expect(fake.get(`WORK#${workIds[0]}`, "META")!.moderationHidden).toBe(true);
  });
});

describe("strikes and posting suspension", () => {
  it("adds one strike per hidden work and suspends posting at the third", async () => {
    for (const [i, workId] of workIds.slice(0, 3).entries()) {
      seedWork(workId, i === 0 ? { moderationHidden: true, moderationAutoHidden: true } : {});
      const report = seedReport(workId, reporters[i], `2026-11-25T0${i}:00:00.000Z`);
      const response = await call("POST", `/admin/reports/${encodeReportId(report)}/hide`);
      expect(response.body).toMatchObject({
        ok: true, workId, strikeAdded: true, strikeCount: i + 1, suspendedNow: i === 2,
      });
      const work = fake.get(`WORK#${workId}`, "META")!;
      expect(work).toMatchObject({ moderationHidden: true, moderationHiddenBy: "owner@example.com" });
      expect(work.moderationAutoHidden).toBeUndefined();
      expect(work.moderationStrikeAt).toEqual(expect.any(String));
      expect(fake.get(report.pk, report.sk)).toMatchObject({ status: "resolved", decision: "hide" });
    }
    expect(fake.get(`USER#${author}`, "META")).toMatchObject({
      moderationStrikeCount: 3, postingSuspended: true, postingSuspendedBy: "auto",
    });

    // The same work never counts twice.
    const again = seedReport(workIds[0], reporters[3], "2026-11-25T09:00:00.000Z");
    const repeat = await call("POST", `/admin/reports/${encodeReportId(again)}/hide`);
    expect(repeat.body).toMatchObject({ strikeAdded: false, strikeCount: 3 });

    // Posting is refused with a stable code, before YouTube and the quota.
    mocks.authenticate.mockResolvedValue({ niarimUserId: author, membershipTier: "free" });
    const post = { headers: {}, body: JSON.stringify({ youtubeVideoId: "Q".repeat(11), youtubeAccessToken: "t" }) };
    await expect(createWork(post as never)).rejects.toMatchObject({ statusCode: 403, code: "POSTING_SUSPENDED" });
    expect(mocks.reservePostQuota).not.toHaveBeenCalled();
    expect(mocks.getVideoSnippet).not.toHaveBeenCalled();

    // Re-publishing a hidden-by-owner work is refused too; hiding stays allowed.
    seedWork(workIds[3], { isNiarimPublished: false });
    const publish = { headers: {}, body: JSON.stringify({ isNiarimPublished: true }) };
    await expect(updateWork(publish as never, workIds[3])).rejects.toMatchObject({ code: "POSTING_SUSPENDED" });
    const hide = { headers: {}, body: JSON.stringify({ isNiarimPublished: false }) };
    expect((await updateWork(hide as never, workIds[3])).statusCode).toBe(200);
  });

  it("needs the work id for an account report and checks its author", async () => {
    seedWork(workIds[0], { authorId: reporters[3] });
    const report = seedReport(undefined, reporters[0], "2026-11-25T01:00:00.000Z");
    const id = encodeReportId(report);
    expect((await call("POST", `/admin/reports/${id}/hide`)).body.code).toBe("WORK_ID_REQUIRED");
    expect((await call("POST", `/admin/reports/${id}/hide`, { body: { workId: workIds[0] } })).body.code)
      .toBe("WORK_AUTHOR_MISMATCH");
    seedWork(workIds[1]);
    const done = await call("POST", `/admin/reports/${id}/hide`, { body: { workId: workIds[1] } });
    expect(done.body).toMatchObject({ ok: true, strikeAdded: true, workId: workIds[1] });
  });

  it("unhides a work, removes its strike and lifts an automatic suspension", async () => {
    seedUser(author, { moderationStrikeCount: 3, postingSuspended: true, postingSuspendedBy: "auto",
      postingSuspendedAt: "2026-11-25T00:00:00.000Z", postingSuspendedReason: "auto" });
    seedWork(workIds[0], { moderationHidden: true, moderationStrikeAt: "2026-11-25T00:00:00.000Z" });
    const response = await call("POST", `/admin/works/${workIds[0]}/unhide`, { body: { note: "異議を認めた" } });
    expect(response.body).toMatchObject({
      ok: true, unhidden: true, strikeRemoved: true, strikeCount: 2, suspensionLifted: true,
      work: { moderationHidden: false, strikeRecorded: false },
    });
    expect(fake.get(`USER#${author}`, "META")).toMatchObject({ moderationStrikeCount: 2 });
    expect(fake.get(`USER#${author}`, "META")!.postingSuspended).toBeUndefined();
  });

  it("suspends and lifts posting by hand, optionally resetting strikes", async () => {
    const suspended = await call("POST", `/admin/users/${author}/suspend`, { body: { reason: "スパム" } });
    expect(suspended.body.user).toMatchObject({
      postingSuspended: true, postingSuspendedReason: "スパム", postingSuspendedBy: "owner@example.com",
    });
    expect((await call("POST", `/admin/users/${author}/suspend`, { body: {} })).status).toBe(400);
    seedUser(author, { moderationStrikeCount: 4, postingSuspended: true, postingSuspendedBy: "x" });
    const lifted = await call("POST", `/admin/users/${author}/unsuspend`, { body: { resetStrikes: true } });
    expect(lifted.body.user).toMatchObject({ postingSuspended: false, strikeCount: 0 });
    expect((await call("GET", `/admin/users/${author}`)).body.user.displayName).toBe("Author Channel");
    expect((await call("GET", `/admin/users/N${"0".repeat(32)}`)).status).toBe(404);
  });
});

describe("automatic temporary hiding", () => {
  async function report(reporter: string, workId = workIds[0]) {
    mocks.authenticate.mockResolvedValue({ niarimUserId: reporter });
    return createReport({ headers: {}, body: JSON.stringify({ workId, reason: "不適切" }) } as never);
  }

  it("hides a work once three distinct accounts have open reports on it", async () => {
    seedWork(workIds[0]);
    await report(reporters[0]);
    await report(reporters[0]);
    await report(reporters[1]);
    expect(fake.get(`WORK#${workIds[0]}`, "META")!.moderationHidden).toBeUndefined();
    expect((await report(reporters[2])).statusCode).toBe(201);
    expect(fake.get(`WORK#${workIds[0]}`, "META")).toMatchObject({
      moderationHidden: true, moderationAutoHidden: true, moderationAutoHiddenReason: "reporters",
    });
    // Hidden works are no longer public, so they cannot be reported further.
    await expect(report(reporters[3])).rejects.toMatchObject({ statusCode: 404 });
  });

  it("never fails the reporter's request when the threshold check fails", async () => {
    seedWork(workIds[0]);
    const send = fake.send;
    vi.mocked(ddb.send).mockImplementation((async (command: unknown) => {
      if (command instanceof QueryCommand) throw new Error("throttled");
      return send(command);
    }) as never);
    try {
      expect((await report(reporters[0])).statusCode).toBe(201);
    } finally {
      vi.mocked(ddb.send).mockImplementation(fake.send as never);
    }
  });
});

describe("report mail", () => {
  const config = () => ({ ...moderationConfig(), mailDailyCap: 2 });
  const facts = { target: "work" as const, reason: "r", createdAt: "2026-11-25T00:00:00.000Z",
    workTitle: "T", youtubeUrl: "https://www.youtube.com/watch?v=x", reporterCount: 1 };

  it("sends at most one mail per target per hour and one flood notice a day", async () => {
    const sent: string[] = [];
    const sender = vi.fn(async (mail: { subject: string }) => { sent.push(mail.subject); return true; });
    const now = Date.parse("2026-11-25T03:00:00.000Z");
    expect(await notifyNewReport("WORK#a", facts, config(), sender, now)).toBe("sent");
    expect(await notifyNewReport("WORK#a", facts, config(), sender, now + 60_000)).toBe("throttled");
    expect(await notifyNewReport("WORK#b", facts, config(), sender, now)).toBe("sent");
    expect(await notifyNewReport("WORK#c", facts, config(), sender, now)).toBe("flood-notice");
    expect(await notifyNewReport("WORK#d", facts, config(), sender, now)).toBe("capped");
    expect(await notifyNewReport("WORK#a", facts, config(), sender, now + 3_600_001)).toBe("capped");
    expect(sent).toHaveLength(3);
    expect(sent.every((subject) => subject.startsWith(SUBJECT_PREFIX))).toBe(true);
    expect(sent[2]).toBe(`${SUBJECT_PREFIX}多数の通報があります`);
    expect(await notifyNewReport("WORK#e", facts, config(), undefined, now)).toBe("disabled");
  });

  it("writes a Japanese body with the link, count, state and AI result", () => {
    const mail = reportMail({ ...facts, reporterCount: 3, autoHidden: "reporters", aiTriage: {
      status: "ok", severity: "critical", category: "violence", recommendedAction: "hide",
      rationale: "流血の描写", triagedAt: "x",
    } }, moderationConfig());
    expect(mail.subject).toBe(`${SUBJECT_PREFIX}【重大】作品「T」への通報（3人）`);
    expect(mail.text).toContain("https://www.youtube.com/watch?v=x");
    expect(mail.text).toContain("https://niarim.miranima-studio.com/admin/");
    expect(mail.text).toContain("自動で非掲載");
    expect(mail.text).toContain("流血の描写");
    expect(mail.text).not.toContain(reporters[0]);
  });
});

describe("AI triage", () => {
  const input = { target: "work" as const, reportReason: "暴力的", work: {
    title: "T", description: "D", tags: ["a"], thumbnailUrl: "https://i.ytimg.com/vi/x/hqdefault.jpg",
  } };
  const reply = (text: string, stop: string = "end_turn") => ({
    content: [{ type: "text", text }], stop_reason: stop, stop_details: null, model: "claude-opus-5-5",
  }) as never;

  it("asks Claude Opus 5.5 for structured JSON with the server-side refusal fallback", () => {
    const request = buildTriageRequest(input);
    expect(request).toMatchObject({
      model: "claude-opus-5-5", betas: ["server-side-fallback-2026-07-01"], fallbacks: "default",
      thinking: { type: "adaptive" },
      output_config: { effort: "low", format: { type: "json_schema" } },
    });
    const content = request.messages[0].content as { type: string; source?: { type: string; url: string } }[];
    expect(content[0]).toEqual({ type: "image", source: { type: "url", url: input.work.thumbnailUrl } });
    expect(JSON.stringify(request)).not.toMatch(/N[0-9a-f]{32}/);
    const otherHost = buildTriageRequest({ ...input, work: { ...input.work, thumbnailUrl: "http://example.com/a.jpg" } });
    expect((otherHost.messages[0].content as { type: string }[]).map((b) => b.type)).toEqual(["text"]);
  });

  it("parses results, refusals and broken replies", () => {
    expect(parseTriageResponse(reply(JSON.stringify({
      severity: "high", category: "sexual", recommendedAction: "review", rationale: "露出",
    })))).toMatchObject({ status: "ok", severity: "high", category: "sexual", recommendedAction: "review" });
    expect(parseTriageResponse({ content: [], stop_reason: "refusal",
      stop_details: { type: "refusal", category: "bio", explanation: null }, model: "m" } as never))
      .toMatchObject({ status: "refused", recommendedAction: "review", refusalCategory: "bio" });
    expect(parseTriageResponse(reply("not json"))).toMatchObject({ status: "failed" });
    expect(parseTriageResponse(reply('{"severity":"high"', "max_tokens"))).toMatchObject({ status: "failed" });
    expect(parseTriageResponse(reply(JSON.stringify({
      severity: "severe", category: "x", recommendedAction: "hide", rationale: "",
    })))).toMatchObject({ status: "failed" });
  });

  it("retries once without the thumbnail when the image cannot be fetched", async () => {
    const create = vi.fn()
      .mockRejectedValueOnce(new Anthropic.BadRequestError(400, {}, "image", new Headers()))
      .mockResolvedValueOnce(reply(JSON.stringify({
        severity: "none", category: "none", recommendedAction: "keep", rationale: "問題なし",
      })));
    const result = await triageReport(input, { beta: { messages: { create } } } as TriageClient);
    expect(result.status).toBe("ok");
    expect((create.mock.calls[1][0].messages[0].content as { type: string }[]).map((b) => b.type))
      .toEqual(["text"]);
    const failing = vi.fn().mockRejectedValue(new Error("network"));
    expect((await triageReport(input, { beta: { messages: { create: failing } } } as TriageClient)).status)
      .toBe("failed");
  });
});

describe("moderation worker", () => {
  const criticalClient = (create = vi.fn(async () => ({
    content: [{ type: "text", text: JSON.stringify({
      severity: "critical", category: "violence", recommendedAction: "hide", rationale: "重大",
    }) }], stop_reason: "end_turn", stop_details: null, model: "claude-opus-5-5",
  }))) => ({ create, client: { beta: { messages: { create } } } as unknown as TriageClient });

  it("triages once, hides a critical work and mails with the AI result", async () => {
    vi.stubEnv("MODERATION_AI_MODE", "always");
    params[AI_PARAM] = "sk-test";
    params[RESEND_PARAM] = "re-test";
    seedWork(workIds[0]);
    const report = seedReport(workIds[0], reporters[0], "2026-11-25T01:00:00.000Z");
    const { create, client } = criticalClient();
    const mails: { subject: string; text: string }[] = [];
    const deps = {
      createTriageClient: () => client,
      createSender: () => async (mail: { subject: string; text: string }) => { mails.push(mail); return true; },
    };
    await processNewReport(report, deps);
    await processNewReport(report, deps);
    expect(create).toHaveBeenCalledTimes(1);
    expect(fake.get(report.pk, report.sk)!.aiTriage).toMatchObject({ status: "ok", severity: "critical" });
    expect(fake.get(`WORK#${workIds[0]}`, "META")).toMatchObject({
      moderationHidden: true, moderationAutoHidden: true, moderationAutoHiddenReason: "ai",
    });
    expect(mails).toHaveLength(1);
    expect(mails[0].subject).toContain("【重大】");
    expect(mails[0].text).toContain("AIが重大と判定");
    const sentText = JSON.stringify(create.mock.calls[0]);
    expect(sentText).not.toContain(reporters[0]);
    expect(sentText).not.toContain(author);
  });

  it("in backlog mode skips the AI while few reports are pending, and without a key", async () => {
    params[AI_PARAM] = "sk-test";
    seedWork(workIds[0]);
    const report = seedReport(workIds[0], reporters[0], "2026-11-25T01:00:00.000Z");
    const { create, client } = criticalClient();
    await processNewReport(report, { createTriageClient: () => client });
    expect(create).not.toHaveBeenCalled();
    vi.stubEnv("MODERATION_AI_BACKLOG_THRESHOLD", "1");
    delete params[AI_PARAM];
    await processNewReport(report, { createTriageClient: () => client });
    expect(create).not.toHaveBeenCalled();
    params[AI_PARAM] = "sk-test";
    await processNewReport(report, { createTriageClient: () => client });
    expect(create).toHaveBeenCalledTimes(1);
  });

  it("never throws when the AI and the mail fail", async () => {
    vi.stubEnv("MODERATION_AI_MODE", "always");
    params[AI_PARAM] = "sk-test";
    params[RESEND_PARAM] = "re-test";
    seedWork(workIds[0]);
    const report = seedReport(workIds[0], reporters[0], "2026-11-25T01:00:00.000Z");
    await expect(processNewReport(report, {
      createTriageClient: () => ({ beta: { messages: { create: async () => { throw new Error("down"); } } } }),
      createSender: () => async () => { throw new Error("mail down"); },
    })).resolves.toBeUndefined();
    expect(fake.get(report.pk, report.sk)!.aiTriage).toMatchObject({ status: "failed" });
    expect(fake.get(`WORK#${workIds[0]}`, "META")!.moderationHidden).toBeUndefined();
  });

  it("still mails once when a work becomes hidden within the hourly limit", async () => {
    params[RESEND_PARAM] = "re-test";
    seedWork(workIds[0]);
    const mails: { subject: string; text: string }[] = [];
    const deps = {
      createSender: () => async (mail: { subject: string; text: string }) => { mails.push(mail); return true; },
    };
    for (const [i, reporter] of reporters.slice(0, 3).entries()) {
      const report = seedReport(workIds[0], reporter, `2026-11-25T0${i}:00:00.000Z`);
      await processNewReport(report, deps);
    }
    expect(mails.map((mail) => mail.subject)).toEqual([
      `${SUBJECT_PREFIX}作品「Title ${workIds[0]}」への通報（1人）`,
      `${SUBJECT_PREFIX}作品「Title ${workIds[0]}」への通報（3人）`,
    ]);
    expect(mails[1].text).toContain("通報が3人に達したため");
    expect(fake.get(`WORK#${workIds[0]}`, "META")!.moderationAutoHidden).toBe(true);
  });

  it("only handles inserted reports from the stream", async () => {
    const result = await workerHandler({ Records: [
      { eventName: "MODIFY", dynamodb: { NewImage: { itemType: { S: "REPORT" } } } },
      { eventName: "INSERT", dynamodb: { NewImage: { itemType: { S: "WORK" } } } },
    ] } as never);
    expect(result.batchItemFailures).toEqual([]);
    expect(fake.calls).toHaveLength(0);
  });
});
