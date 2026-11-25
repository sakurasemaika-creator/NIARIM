import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  BatchGetCommand,
  type BatchGetCommandOutput,
  GetCommand,
  QueryCommand,
} from "@aws-sdk/lib-dynamodb";
import { authenticateAdmin } from "../../lib/adminAuth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import {
  decodeReportId,
  dismissReport,
  encodeReportId,
  getReport,
  hideReport,
  isUserId,
  isWorkId,
  liftPostingSuspension,
  markReviewing,
  moderationConfig,
  reportsForTarget,
  reportStatsForTarget,
  suspendPosting,
  unhideWork,
  type ReportStats,
} from "../../lib/moderation";
import { decodePageCursor, encodePageCursor } from "../../lib/pagination";
import { parseJsonObject } from "../../lib/request";
import { badRequest, notFound, ok } from "../../lib/response";
import type { ReportItem, ReportStatus, UserItem, WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";

/**
 * Moderation admin API for the browser admin page
 * (https://niarim.miranima-studio.com/admin/). Every route authenticates with
 * `authenticateAdmin` (Google ID token + allowlisted email). CORS for the
 * website origin is added by the router for `/admin/` paths.
 */

type Row = Record<string, unknown>;
const STATUSES: ReportStatus[] = ["pending", "reviewing", "resolved"];

function keyOf(item: { pk: unknown; sk: unknown }): string {
  return `${String(item.pk)}\n${String(item.sk)}`;
}

async function batchGet(keys: { pk: string; sk: string }[]): Promise<Map<string, Row>> {
  const found = new Map<string, Row>();
  const unique = [...new Map(keys.map((k) => [keyOf(k), k])).values()];
  const TableName = tableName();
  for (let start = 0; start < unique.length; start += 100) {
    let request: Record<string, { Keys: Row[] }> | undefined = {
      [TableName]: { Keys: unique.slice(start, start + 100) },
    };
    for (let attempt = 0; request && attempt < 4; attempt++) {
      const result: BatchGetCommandOutput = await ddb.send(
        new BatchGetCommand({ RequestItems: request }));
      for (const item of result?.Responses?.[TableName] ?? []) {
        found.set(keyOf(item as { pk: unknown; sk: unknown }), item);
      }
      const rest: Row[] | undefined = result?.UnprocessedKeys?.[TableName]?.Keys;
      request = rest?.length ? { [TableName]: { Keys: rest } } : undefined;
    }
  }
  return found;
}

function workView(workId: string, work: Row | undefined, detail: Row | undefined) {
  if (!work || work.itemType !== TABLE_ITEM_TYPE.Work) {
    return { workId, available: false, deleted: work?.itemType === "WORK_TOMBSTONE" };
  }
  const w = work as unknown as WorkItem;
  return {
    workId,
    available: true,
    title: w.title,
    description: typeof detail?.description === "string" ? detail.description : "",
    tags: w.tags ?? [],
    youtubeVideoId: w.youtubeVideoId,
    youtubeUrl: w.youtubeUrl,
    thumbnailUrl: w.thumbnailUrl,
    authorId: w.authorId,
    channelName: w.channelName ?? "",
    postedAt: w.postedAt,
    isNiarimPublished: w.isNiarimPublished === true,
    youtubePrivacyStatus: w.youtubePrivacyStatus,
    moderationHidden: w.moderationHidden === true,
    autoHidden: w.moderationAutoHidden === true,
    autoHiddenReason: w.moderationAutoHiddenReason ?? null,
    autoHiddenAt: w.moderationAutoHiddenAt ?? null,
    hiddenAt: w.moderationHiddenAt ?? null,
    hiddenBy: w.moderationHiddenBy ?? null,
    strikeRecorded: typeof w.moderationStrikeAt === "string",
  };
}

function userView(userId: string, user: Row | undefined, fallbackName?: string) {
  if (!user || user.itemType !== TABLE_ITEM_TYPE.User || user.erasureReceipt) {
    return { userId, available: false };
  }
  const u = user as unknown as UserItem;
  return {
    userId,
    available: true,
    displayName: u.channelName ?? fallbackName ?? "",
    avatarUrl: u.channelAvatarUrl ?? "",
    youtubeChannelId: u.youtubeChannelId ?? null,
    strikeCount: u.moderationStrikeCount ?? 0,
    lastStrikeAt: u.moderationLastStrikeAt ?? null,
    postingSuspended: u.postingSuspended === true,
    postingSuspendedAt: u.postingSuspendedAt ?? null,
    postingSuspendedReason: u.postingSuspendedReason ?? null,
    postingSuspendedBy: u.postingSuspendedBy ?? null,
  };
}

function reportSummary(report: ReportItem) {
  return {
    reportId: encodeReportId(report),
    status: report.status,
    createdAt: report.createdAt,
    reason: report.reason,
    reporterId: report.reporterId,
    decision: report.decision ?? null,
    reviewedAt: report.reviewedAt ?? null,
    reviewedBy: report.reviewedBy ?? null,
    reviewNote: report.reviewNote ?? null,
    aiTriage: report.aiTriage ?? null,
  };
}

function targetPkOf(report: ReportItem): string {
  return report.workId ? Keys.work(report.workId).pk : report.pk;
}

/** Report rows with everything the review screen needs. */
async function reportViews(reports: ReportItem[]) {
  const keys: { pk: string; sk: string }[] = [];
  for (const report of reports) {
    if (report.workId) keys.push(Keys.work(report.workId), Keys.workDetail(report.workId));
    if (report.targetId) keys.push(Keys.user(report.targetId));
  }
  const [items, statsList] = await Promise.all([
    batchGet(keys),
    Promise.all([...new Set(reports.map(targetPkOf))].map(async (pk) =>
      [pk, await reportStatsForTarget(pk)] as const)),
  ]);
  const stats = new Map<string, ReportStats>(statsList);
  return reports.map((report) => {
    const work = report.workId ? items.get(keyOf(Keys.work(report.workId))) : undefined;
    const detail = report.workId ? items.get(keyOf(Keys.workDetail(report.workId))) : undefined;
    const authorId = (work?.itemType === TABLE_ITEM_TYPE.Work ? work.authorId as string : undefined) ??
      report.targetId;
    const s = stats.get(targetPkOf(report)) ?? { reporters: 0, open: 0, total: 0 };
    return {
      ...reportSummary(report),
      targetType: report.workId ? "work" : "account",
      workId: report.workId ?? null,
      targetUserId: report.targetId ?? null,
      reporterCount: s.reporters,
      openReportCount: s.open,
      totalReportCount: s.total,
      work: report.workId ? workView(report.workId, work, detail) : null,
      author: authorId
        ? userView(authorId, items.get(keyOf(Keys.user(authorId))),
          typeof work?.channelName === "string" ? work.channelName : undefined)
        : null,
    };
  });
}

function pageLimit(raw: string | undefined): number {
  if (raw === undefined) return 20;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > 50) {
    badRequest("limitは1〜50で指定してください", "INVALID_PAGE_SIZE");
  }
  return value;
}

function reportKeyParam(raw: string): { pk: string; sk: string } {
  const key = decodeReportId(raw);
  if (!key) notFound("通報が見つかりません");
  return key;
}

function optionalNote(body: Row): string | undefined {
  if (body.note === undefined || body.note === null) return undefined;
  if (typeof body.note !== "string" || body.note.length > 1000) {
    badRequest("noteは1000文字以内の文字列で指定してください", "INVALID_NOTE");
  }
  return body.note.trim() || undefined;
}

async function singleReportView(key: { pk: string; sk: string }) {
  const report = await getReport(key);
  if (!report) notFound("通報が見つかりません");
  return (await reportViews([report]))[0];
}

/** GET /admin/me */
export async function getAdminMe(event: APIGatewayProxyEventV2) {
  const admin = await authenticateAdmin(event);
  const config = moderationConfig();
  return ok({
    email: admin.email,
    settings: {
      reportHideThreshold: config.reportHideThreshold,
      strikeSuspendThreshold: config.strikeSuspendThreshold,
      aiMode: config.aiMode,
      aiBacklogThreshold: config.aiBacklogThreshold,
      aiDailyCap: config.aiDailyCap,
      mailDailyCap: config.mailDailyCap,
    },
  });
}

/** GET /admin/reports?status=pending|reviewing|resolved&order=oldest|newest&limit=&cursor= */
export async function listAdminReports(event: APIGatewayProxyEventV2) {
  await authenticateAdmin(event);
  const qp = event.queryStringParameters ?? {};
  const status = (qp.status ?? "pending") as ReportStatus;
  if (!STATUSES.includes(status)) {
    badRequest("statusはpending・reviewing・resolvedのいずれかです", "INVALID_STATUS");
  }
  const order = qp.order ?? (status === "resolved" ? "newest" : "oldest");
  if (order !== "oldest" && order !== "newest") {
    badRequest("orderはoldestかnewestです", "INVALID_ORDER");
  }
  const scope = `admin-reports|${status}|${order}`;
  const result = await ddb.send(new QueryCommand({
    TableName: tableName(),
    IndexName: "GSI7",
    KeyConditionExpression: "gsi7pk = :status",
    ExpressionAttributeValues: { ":status": `REPORT_STATUS#${status}` },
    ScanIndexForward: order === "oldest",
    Limit: pageLimit(qp.limit),
    ExclusiveStartKey: decodePageCursor(qp.cursor, scope),
  }));
  const reports = (result.Items ?? [])
    .filter((item) => item.itemType === TABLE_ITEM_TYPE.Report) as ReportItem[];
  return ok({
    status,
    order,
    reports: await reportViews(reports),
    nextCursor: encodePageCursor(result.LastEvaluatedKey, scope),
  });
}

/** GET /admin/reports/{reportId} */
export async function getAdminReport(event: APIGatewayProxyEventV2, reportId: string) {
  await authenticateAdmin(event);
  const key = reportKeyParam(reportId);
  const report = await getReport(key);
  if (!report) notFound("通報が見つかりません");
  const [view] = await reportViews([report]);
  const related = (await reportsForTarget(targetPkOf(report)))
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .map(reportSummary);
  return ok({ report: view, relatedReports: related });
}

/** POST /admin/reports/{reportId}/review */
export async function reviewAdminReport(event: APIGatewayProxyEventV2, reportId: string) {
  const admin = await authenticateAdmin(event);
  const key = reportKeyParam(reportId);
  await markReviewing(key, admin.email);
  return ok({ ok: true, report: await singleReportView(key) });
}

/** POST /admin/reports/{reportId}/dismiss  body: { note? } */
export async function dismissAdminReport(event: APIGatewayProxyEventV2, reportId: string) {
  const admin = await authenticateAdmin(event);
  const key = reportKeyParam(reportId);
  const note = optionalNote(parseJsonObject(event.body, { allowEmpty: true }));
  const outcome = await dismissReport(key, admin.email, note);
  return ok({ ok: true, ...outcome, report: await singleReportView(key) });
}

/** POST /admin/reports/{reportId}/hide  body: { workId? (account reports), note? } */
export async function hideAdminReport(event: APIGatewayProxyEventV2, reportId: string) {
  const admin = await authenticateAdmin(event);
  const key = reportKeyParam(reportId);
  const body = parseJsonObject(event.body, { allowEmpty: true });
  if (body.workId !== undefined && !isWorkId(body.workId)) {
    badRequest("workIdの形式が不正です", "INVALID_WORK_ID");
  }
  const outcome = await hideReport(key, admin.email, {
    workId: body.workId as string | undefined, note: optionalNote(body),
  });
  return ok({ ok: true, ...outcome, report: await singleReportView(key) });
}

async function workState(workId: string) {
  const [work, detail] = await Promise.all([
    ddb.send(new GetCommand({ TableName: tableName(), Key: Keys.work(workId), ConsistentRead: true })),
    ddb.send(new GetCommand({ TableName: tableName(), Key: Keys.workDetail(workId) })),
  ]);
  return workView(workId, work?.Item, detail?.Item);
}

async function userState(userId: string) {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.user(userId), ConsistentRead: true,
  }));
  return userView(userId, result?.Item);
}

/** POST /admin/works/{workId}/unhide  body: { keepStrike?, note? } */
export async function unhideAdminWork(event: APIGatewayProxyEventV2, workId: string) {
  const admin = await authenticateAdmin(event);
  if (!isWorkId(workId)) notFound("作品が見つかりません");
  const body = parseJsonObject(event.body, { allowEmpty: true });
  if (body.keepStrike !== undefined && typeof body.keepStrike !== "boolean") {
    badRequest("keepStrikeは真偽値です", "INVALID_KEEP_STRIKE");
  }
  const outcome = await unhideWork(workId, admin.email, {
    keepStrike: body.keepStrike === true, note: optionalNote(body),
  });
  return ok({ ok: true, ...outcome, work: await workState(workId) });
}

/** GET /admin/users/{userId} */
export async function getAdminUser(event: APIGatewayProxyEventV2, userId: string) {
  await authenticateAdmin(event);
  if (!isUserId(userId)) notFound("アカウントが見つかりません");
  const user = await userState(userId);
  if (!user.available) notFound("アカウントが見つかりません");
  return ok({ user });
}

/** POST /admin/users/{userId}/suspend  body: { reason } */
export async function suspendAdminUser(event: APIGatewayProxyEventV2, userId: string) {
  const admin = await authenticateAdmin(event);
  if (!isUserId(userId)) notFound("アカウントが見つかりません");
  const body = parseJsonObject(event.body);
  if (typeof body.reason !== "string" || !body.reason.trim() || body.reason.length > 500) {
    badRequest("reasonは1〜500文字で指定してください", "INVALID_REASON");
  }
  await suspendPosting(userId, admin.email, body.reason.trim());
  return ok({ ok: true, user: await userState(userId) });
}

/** POST /admin/users/{userId}/unsuspend  body: { resetStrikes? } */
export async function unsuspendAdminUser(event: APIGatewayProxyEventV2, userId: string) {
  const admin = await authenticateAdmin(event);
  if (!isUserId(userId)) notFound("アカウントが見つかりません");
  const body = parseJsonObject(event.body, { allowEmpty: true });
  if (body.resetStrikes !== undefined && typeof body.resetStrikes !== "boolean") {
    badRequest("resetStrikesは真偽値です", "INVALID_RESET_STRIKES");
  }
  await liftPostingSuspension(userId, admin.email, { resetStrikes: body.resetStrikes === true });
  return ok({ ok: true, user: await userState(userId) });
}
