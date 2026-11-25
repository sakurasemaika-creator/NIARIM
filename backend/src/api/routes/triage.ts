import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { authenticateAdmin } from "../../lib/adminAuth";
import { decodeReportId } from "../../lib/moderation";
import { TRIAGE_GUIDELINES } from "../../lib/moderationAi";
import {
  applyTriageJudgment,
  buildChatTriagePrompt,
  listUntriagedReports,
  parseTriageJudgment,
  TRIAGE_OUTPUT_FORMAT,
  triageReportViews,
} from "../../lib/moderationTriage";
import { parseJsonObject } from "../../lib/request";
import { ApiError, badRequest, notFound, ok } from "../../lib/response";
import {
  authenticateTriageBot,
  createTriageBotToken,
  revokeTriageBotToken,
} from "../../lib/triageBot";
import { adminSettings, pageLimit } from "./admin";

/**
 * Report triage on the owner's Claude subscription (moderationTriage.ts).
 *
 * `/triage-bot/...` is called server to server by the scheduled Claude
 * session with the bot token (no CORS). `/admin/triage/...` is the admin
 * page: the token, and the copy/paste flow for Claude chat.
 */

const MAX_RESULTS = 50;

// --- Triage bot ---------------------------------------------------------------

/** GET /triage-bot/reports?limit= */
export async function listTriageBotReports(event: APIGatewayProxyEventV2) {
  await authenticateTriageBot(event);
  const limit = pageLimit(event.queryStringParameters?.limit);
  const reports = await triageReportViews(await listUntriagedReports(limit));
  return ok({ guidelines: TRIAGE_GUIDELINES, outputFormat: TRIAGE_OUTPUT_FORMAT, reports });
}

/** POST /triage-bot/reports/{reportId}/triage  body: {severity, category, recommendedAction, rationale} */
export async function submitTriageBotJudgment(event: APIGatewayProxyEventV2, reportId: string) {
  await authenticateTriageBot(event);
  const key = decodeReportId(reportId);
  if (!key) notFound("通報が見つかりません");
  const body = parseJsonObject(event.body);
  const judgment = parseTriageJudgment(body);
  if (!judgment || (body.reportId !== undefined && body.reportId !== reportId)) {
    badRequest(
      "severity・category・recommendedActionは決まった値、rationaleは1〜300文字で指定してください",
      "INVALID_TRIAGE",
    );
  }
  const { autoHidden } = await applyTriageJudgment(key, judgment, "subscription");
  return ok({ ok: true, autoHidden });
}

// --- Admin page ---------------------------------------------------------------

/** POST /admin/triage/token — creates or replaces the bot token (shown only here). */
export async function createAdminTriageToken(event: APIGatewayProxyEventV2) {
  const admin = await authenticateAdmin(event);
  const { token, createdAt } = await createTriageBotToken(admin.email);
  return ok({ token, createdAt, settings: await adminSettings() });
}

/** POST /admin/triage/token/revoke */
export async function revokeAdminTriageToken(event: APIGatewayProxyEventV2) {
  const admin = await authenticateAdmin(event);
  await revokeTriageBotToken(admin.email);
  return ok({ ok: true, settings: await adminSettings() });
}

/** GET /admin/triage/prompt?limit= — the prompt to paste into Claude chat. */
export async function getAdminTriagePrompt(event: APIGatewayProxyEventV2) {
  await authenticateAdmin(event);
  const limit = pageLimit(event.queryStringParameters?.limit);
  const views = await triageReportViews(await listUntriagedReports(limit));
  return ok({
    prompt: buildChatTriagePrompt(views),
    reportCount: views.length,
    reportIds: views.map((view) => view.reportId),
  });
}

type ResultOutcome =
  | { reportId: string | null; ok: true; autoHidden: boolean }
  | { reportId: string | null; ok: false; code: string };

async function applyChatResult(raw: unknown): Promise<ResultOutcome> {
  const item = raw !== null && typeof raw === "object" && !Array.isArray(raw)
    ? raw as Record<string, unknown> : undefined;
  const reportId = typeof item?.reportId === "string" ? item.reportId : null;
  const judgment = parseTriageJudgment(item);
  if (!reportId || !judgment) return { reportId, ok: false, code: "INVALID_TRIAGE" };
  const key = decodeReportId(reportId);
  if (!key) return { reportId, ok: false, code: "NOT_FOUND" };
  try {
    const { autoHidden } = await applyTriageJudgment(key, judgment, "chat");
    return { reportId, ok: true, autoHidden };
  } catch (error) {
    if (error instanceof ApiError && error.code) return { reportId, ok: false, code: error.code };
    throw error;
  }
}

/**
 * POST /admin/triage/results  body: {results: [{reportId, severity, category, recommendedAction, rationale}]}
 * Applies Claude chat's answer one item at a time; always 200 with a result per item.
 */
export async function submitAdminTriageResults(event: APIGatewayProxyEventV2) {
  await authenticateAdmin(event);
  const body = parseJsonObject(event.body);
  const results = body.results;
  if (!Array.isArray(results) || results.length < 1 || results.length > MAX_RESULTS) {
    badRequest(`resultsは1〜${MAX_RESULTS}件の配列で指定してください`, "INVALID_RESULTS");
  }
  const outcomes: ResultOutcome[] = [];
  for (const raw of results) outcomes.push(await applyChatResult(raw));
  return ok({ results: outcomes });
}
