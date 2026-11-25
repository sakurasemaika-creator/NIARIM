import { ConditionalCheckFailedException, TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import {
  GetCommand,
  PutCommand,
  QueryCommand,
  TransactWriteCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "./dynamo";
import { conflict, forbidden, notFound } from "./response";
import type { ReportItem, ReportStatus, UserItem, WorkItem } from "./types";
import { TABLE_ITEM_TYPE } from "./types";

/**
 * Work Plaza moderation: automatic temporary hiding, strikes, posting
 * suspension and the decisions a moderator takes on reports.
 *
 * Everything lives on existing items and key patterns of the single table
 * (no new GSI): reports stay under `WORK#{id}` / `USER#{id}` with GSI7 for the
 * status queues, the moderation state is a few attributes on the work and
 * user META items, and the throttling counters are small TTL items.
 *
 * Hidden works keep using the existing `moderationHidden` flag, which every
 * public listing and lookup already filters out.
 */

export type AiMode = "off" | "always" | "backlog";

export interface ModerationConfig {
  /** Distinct reporters with open reports that hide a work pending review (0 = never). */
  reportHideThreshold: number;
  /** Strikes (works hidden by a moderator) that suspend posting (0 = never). */
  strikeSuspendThreshold: number;
  aiMode: AiMode;
  /** In `backlog` mode, triage only while at least this many reports are pending. */
  aiBacklogThreshold: number;
  aiDailyCap: number;
  mailDailyCap: number;
  /** One report mail per target within this window. */
  mailPerTargetIntervalMs: number;
  notifyTo: string;
  notifyFrom: string;
  adminPageUrl: string;
  adminEmailsParameter?: string;
  resendApiKeyParameter?: string;
  anthropicApiKeyParameter?: string;
}

function nonNegativeInt(raw: string | undefined, fallback: number, max: number): number {
  if (raw === undefined || raw.trim() === "") return fallback;
  const value = Number(raw);
  return Number.isSafeInteger(value) && value >= 0 && value <= max ? value : fallback;
}

export function moderationConfig(): ModerationConfig {
  const mode = (process.env.MODERATION_AI_MODE ?? "").trim();
  return {
    reportHideThreshold: nonNegativeInt(process.env.MODERATION_REPORT_HIDE_THRESHOLD, 3, 1000),
    strikeSuspendThreshold: nonNegativeInt(process.env.MODERATION_STRIKE_SUSPEND_THRESHOLD, 3, 1000),
    aiMode: mode === "off" || mode === "always" || mode === "backlog" ? mode : "backlog",
    aiBacklogThreshold: nonNegativeInt(process.env.MODERATION_AI_BACKLOG_THRESHOLD, 20, 1000),
    aiDailyCap: nonNegativeInt(process.env.MODERATION_AI_DAILY_CAP, 50, 10_000),
    mailDailyCap: nonNegativeInt(process.env.MODERATION_MAIL_DAILY_CAP, 30, 10_000),
    mailPerTargetIntervalMs: 60 * 60_000,
    notifyTo: process.env.MODERATION_NOTIFY_TO?.trim() || "support@miranima-studio.com",
    notifyFrom: process.env.MODERATION_NOTIFY_FROM?.trim() || "NIARIM <support@miranima-studio.com>",
    adminPageUrl: process.env.MODERATION_ADMIN_PAGE_URL?.trim() ||
      "https://niarim.miranima-studio.com/admin/",
    adminEmailsParameter: process.env.MODERATION_ADMIN_EMAILS_PARAMETER || undefined,
    resendApiKeyParameter: process.env.MODERATION_RESEND_API_KEY_PARAMETER || undefined,
    anthropicApiKeyParameter: process.env.MODERATION_ANTHROPIC_API_KEY_PARAMETER || undefined,
  };
}

/**
 * The AI triage mode chosen on the admin page overrides the deploy default
 * (MODERATION_AI_MODE). Stored in one small item; read at most once a minute
 * per container so a report burst costs no extra reads.
 */
export const AI_MODES: readonly AiMode[] = ["off", "always", "backlog"];
let storedAiModeCache: { at: number; mode?: AiMode } | undefined;
const STORED_AI_MODE_TTL_MS = 60_000;

export function resetStoredAiModeCacheForTest(): void {
  storedAiModeCache = undefined;
}

async function readStoredAiMode(): Promise<AiMode | undefined> {
  const now = Date.now();
  if (storedAiModeCache && now - storedAiModeCache.at < STORED_AI_MODE_TTL_MS) {
    return storedAiModeCache.mode;
  }
  let mode: AiMode | undefined;
  try {
    const result = await ddb.send(new GetCommand({
      TableName: tableName(), Key: Keys.moderationSettings(),
    }));
    const raw = result.Item?.aiMode;
    mode = AI_MODES.includes(raw as AiMode) ? raw as AiMode : undefined;
  } catch {
    // A failed read keeps the deploy default; it is retried next time.
    return undefined;
  }
  storedAiModeCache = { at: now, mode };
  return mode;
}

/** The config with the admin page's AI mode, and where the mode came from. */
export async function effectiveModerationConfig(): Promise<
  ModerationConfig & { aiModeSource: "admin" | "default" }
> {
  const config = moderationConfig();
  const stored = await readStoredAiMode();
  return stored
    ? { ...config, aiMode: stored, aiModeSource: "admin" }
    : { ...config, aiModeSource: "default" };
}

/** Saves the AI triage mode chosen on the admin page. */
export async function setStoredAiMode(mode: AiMode, by: string): Promise<void> {
  await ddb.send(new PutCommand({
    TableName: tableName(),
    Item: {
      ...Keys.moderationSettings(),
      itemType: "MODERATION_SETTINGS",
      aiMode: mode,
      updatedAt: new Date().toISOString(),
      updatedBy: by,
    },
  }));
  storedAiModeCache = { at: Date.now(), mode };
}

const WORK_ID = /^[A-Za-z0-9_-]{11}$/;
const USER_ID = /^N[0-9a-f]{32}$/;

export function isWorkId(value: unknown): value is string {
  return typeof value === "string" && WORK_ID.test(value);
}

export function isUserId(value: unknown): value is string {
  return typeof value === "string" && USER_ID.test(value);
}

// --- Report identifiers -------------------------------------------------------

/** Opaque, URL-safe id of a report (its table key). */
export function encodeReportId(key: { pk: string; sk: string }): string {
  return Buffer.from(`${key.pk}\n${key.sk}`, "utf8").toString("base64url");
}

/** Decodes a report id, or returns undefined when it is not a report key. */
export function decodeReportId(raw: string): { pk: string; sk: string } | undefined {
  if (!/^[A-Za-z0-9_-]{1,256}$/.test(raw)) return undefined;
  const [pk, sk, extra] = Buffer.from(raw, "base64url").toString("utf8").split("\n");
  if (extra !== undefined || !pk || !sk) return undefined;
  const partition = /^(?:WORK#[A-Za-z0-9_-]{11}|USER#N[0-9a-f]{32})$/.test(pk);
  const sort = /^REPORT#N[0-9a-f]{32}#\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(sk);
  return partition && sort ? { pk, sk } : undefined;
}

// --- Report statistics ------------------------------------------------------------

export interface ReportStats {
  /** Distinct reporters with an open (pending/reviewing) report. */
  reporters: number;
  /** Open reports. */
  open: number;
  /** All reports found (any status). */
  total: number;
}

const MAX_TARGET_REPORT_PAGES = 10;

/** All reports stored under one target partition (`WORK#id` or `USER#id`). */
export async function reportsForTarget(targetPk: string): Promise<ReportItem[]> {
  const items: ReportItem[] = [];
  let cursor: Record<string, unknown> | undefined;
  for (let page = 0; page < MAX_TARGET_REPORT_PAGES; page++) {
    const result = await ddb.send(new QueryCommand({
      TableName: tableName(),
      KeyConditionExpression: "pk = :pk AND begins_with(sk, :prefix)",
      ExpressionAttributeValues: { ":pk": targetPk, ":prefix": "REPORT#" },
      ConsistentRead: true,
      ExclusiveStartKey: cursor,
    }));
    for (const item of result?.Items ?? []) {
      if (item.itemType === TABLE_ITEM_TYPE.Report) items.push(item as ReportItem);
    }
    cursor = result?.LastEvaluatedKey;
    if (!cursor) break;
  }
  return items;
}

export function statsOf(reports: ReportItem[]): ReportStats {
  const open = reports.filter((r) => r.status !== "resolved");
  return {
    reporters: new Set(open.map((r) => r.reporterId)).size,
    open: open.length,
    total: reports.length,
  };
}

export async function reportStatsForTarget(targetPk: string): Promise<ReportStats> {
  return statsOf(await reportsForTarget(targetPk));
}

// --- Automatic temporary hiding ---------------------------------------------------

/**
 * Hides a work pending review. Never touches a work that is already hidden
 * (a moderator's hide must not turn into an "auto" hide that dismissal would
 * reverse). Returns whether this call hid it.
 */
export async function autoHideWork(
  workId: string,
  reason: "reporters" | "ai",
  now = new Date().toISOString(),
): Promise<boolean> {
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: Keys.work(workId),
      UpdateExpression:
        "SET moderationHidden = :on, moderationAutoHidden = :on, " +
        "moderationAutoHiddenAt = :now, moderationAutoHiddenReason = :reason",
      ConditionExpression:
        "itemType = :work AND (attribute_not_exists(moderationHidden) OR moderationHidden = :off)",
      ExpressionAttributeValues: {
        ":on": true, ":off": false, ":now": now, ":reason": reason,
        ":work": TABLE_ITEM_TYPE.Work,
      },
    }));
    return true;
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) return false;
    throw error;
  }
}

/**
 * Hides a work once enough distinct accounts have open reports on it.
 * Idempotent: called after each report (and again by the moderation worker).
 */
export async function applyReporterThreshold(
  workId: string,
  config = moderationConfig(),
): Promise<{ stats: ReportStats; autoHidden: boolean }> {
  const stats = await reportStatsForTarget(Keys.work(workId).pk);
  const reached = config.reportHideThreshold > 0 &&
    stats.reporters >= config.reportHideThreshold;
  const autoHidden = reached ? await autoHideWork(workId, "reporters") : false;
  return { stats, autoHidden };
}

// --- Posting suspension --------------------------------------------------------

export const POSTING_SUSPENDED_CODE = "POSTING_SUSPENDED";

/** Rejects posting/publishing for a suspended account (stable error code). */
export function assertPostingAllowed(user: Pick<UserItem, "postingSuspended"> | undefined): void {
  if (user?.postingSuspended === true) {
    forbidden(
      "規約に反する投稿が続いたため、作品広場への投稿を停止しています",
      POSTING_SUSPENDED_CODE,
    );
  }
}

/** Reads the account and rejects when its posting is suspended. */
export async function assertUserMayPost(userId: string): Promise<void> {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.user(userId), ConsistentRead: true,
  }));
  const item = result?.Item;
  if (item?.itemType === TABLE_ITEM_TYPE.User) assertPostingAllowed(item as UserItem);
}

// --- Moderator decisions -----------------------------------------------------------

export type Decision = "dismiss" | "hide" | "unhide";

async function getWork(workId: string): Promise<WorkItem | undefined> {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.work(workId), ConsistentRead: true,
  }));
  return result?.Item?.itemType === TABLE_ITEM_TYPE.Work ? result.Item as WorkItem : undefined;
}

async function getUserItem(userId: string): Promise<UserItem | undefined> {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.user(userId), ConsistentRead: true,
  }));
  const item = result?.Item;
  return item?.itemType === TABLE_ITEM_TYPE.User && !item.erasureReceipt
    ? item as UserItem : undefined;
}

export async function getReport(key: { pk: string; sk: string }): Promise<ReportItem | undefined> {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: key, ConsistentRead: true,
  }));
  return result?.Item?.itemType === TABLE_ITEM_TYPE.Report ? result.Item as ReportItem : undefined;
}

function resolveUpdate(
  key: { pk: string; sk: string },
  decision: Decision,
  by: string,
  note: string | undefined,
  now: string,
  expectedStatus?: ReportStatus,
) {
  return {
    TableName: tableName(),
    Key: key,
    UpdateExpression:
      "SET #status = :resolved, gsi7pk = :index, decision = :decision, " +
      "reviewedAt = :now, reviewedBy = :by" + (note ? ", reviewNote = :note" : ""),
    ConditionExpression: "itemType = :report AND " + (expectedStatus
      ? "#status = :expected" : "#status IN (:pending, :reviewing)"),
    ExpressionAttributeNames: { "#status": "status" },
    ExpressionAttributeValues: {
      ":resolved": "resolved", ":index": "REPORT_STATUS#resolved",
      ":decision": decision, ":now": now, ":by": by,
      ":report": TABLE_ITEM_TYPE.Report,
      ...(note ? { ":note": note } : {}),
      ...(expectedStatus
        ? { ":expected": expectedStatus }
        : { ":pending": "pending", ":reviewing": "reviewing" }),
    },
  };
}

/** Resolves every open report under a target partition. Returns how many. */
export async function resolveOpenReportsFor(
  targetPk: string,
  decision: Decision,
  by: string,
  note: string | undefined,
  now = new Date().toISOString(),
): Promise<number> {
  let resolved = 0;
  for (const report of await reportsForTarget(targetPk)) {
    if (report.status === "resolved") continue;
    try {
      await ddb.send(new UpdateCommand(resolveUpdate(
        { pk: report.pk, sk: report.sk }, decision, by, note, now,
      )));
      resolved++;
    } catch (error) {
      if (!(error instanceof ConditionalCheckFailedException)) throw error;
    }
  }
  return resolved;
}

/** Marks a pending report as being reviewed (idempotent while reviewing). */
export async function markReviewing(key: { pk: string; sk: string }, by: string): Promise<ReportItem> {
  const report = await getReport(key);
  if (!report) notFound("通報が見つかりません");
  if (report.status === "reviewing") return report;
  if (report.status !== "pending") conflict("この通報は対応済みです", "REPORT_RESOLVED");
  try {
    const result = await ddb.send(new UpdateCommand({
      TableName: tableName(), Key: key,
      UpdateExpression: "SET #status = :reviewing, gsi7pk = :index, reviewStartedAt = :now, reviewedBy = :by",
      ConditionExpression: "itemType = :report AND #status = :pending",
      ExpressionAttributeNames: { "#status": "status" },
      ExpressionAttributeValues: {
        ":reviewing": "reviewing", ":index": "REPORT_STATUS#reviewing",
        ":now": new Date().toISOString(), ":by": by,
        ":report": TABLE_ITEM_TYPE.Report, ":pending": "pending",
      },
      ReturnValues: "ALL_NEW",
    }));
    return result.Attributes as ReportItem;
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) {
      conflict("通報の状態が変わりました。読み込み直してください", "REPORT_CHANGED");
    }
    throw error;
  }
}

function targetPkOf(report: ReportItem): string {
  return report.workId ? Keys.work(report.workId).pk : report.pk;
}

/**
 * Dismisses a report: resolves it and every other open report on the same
 * target. A work the system hid pending review becomes visible again; a
 * moderator's own hide is left as it is.
 */
export async function dismissReport(
  key: { pk: string; sk: string },
  by: string,
  note?: string,
): Promise<{ resolved: number; unhidden: boolean }> {
  const report = await getReport(key);
  if (!report) notFound("通報が見つかりません");
  if (report.status === "resolved") conflict("この通報は対応済みです", "REPORT_RESOLVED");
  const now = new Date().toISOString();
  const resolved = await resolveOpenReportsFor(targetPkOf(report), "dismiss", by, note, now);
  let unhidden = false;
  if (report.workId) {
    try {
      await ddb.send(new UpdateCommand({
        TableName: tableName(), Key: Keys.work(report.workId),
        UpdateExpression:
          "SET moderationUnhiddenAt = :now, moderationUnhiddenBy = :by " +
          "REMOVE moderationHidden, moderationAutoHidden, moderationAutoHiddenAt, moderationAutoHiddenReason",
        ConditionExpression: "itemType = :work AND moderationAutoHidden = :on",
        ExpressionAttributeValues: {
          ":work": TABLE_ITEM_TYPE.Work, ":on": true, ":now": now, ":by": by,
        },
      }));
      unhidden = true;
    } catch (error) {
      if (!(error instanceof ConditionalCheckFailedException)) throw error;
    }
  }
  return { resolved, unhidden };
}

export interface StrikeOutcome {
  strikeAdded: boolean;
  strikeCount: number;
  postingSuspended: boolean;
  suspendedNow: boolean;
}

/**
 * Hides a work as a moderator decision and records ONE strike for its author
 * (a work never counts twice). Reaching the strike threshold suspends posting
 * in the same transaction. The selected report is resolved atomically with
 * it when given.
 */
export async function hideWorkWithStrike(
  workId: string,
  by: string,
  options: {
    report?: ReportItem;
    expectedAuthorId?: string;
    note?: string;
    config?: ModerationConfig;
  } = {},
): Promise<StrikeOutcome> {
  const config = options.config ?? moderationConfig();
  for (let attempt = 0; attempt < 3; attempt++) {
    const work = await getWork(workId);
    if (!work) notFound("作品が見つかりません");
    if (options.expectedAuthorId && work.authorId !== options.expectedAuthorId) {
      conflict("指定した作品は通報されたアカウントの作品ではありません", "WORK_AUTHOR_MISMATCH");
    }
    const user = await getUserItem(work.authorId);
    const now = new Date().toISOString();
    const before = user?.moderationStrikeCount ?? 0;
    const addStrike = !work.moderationStrikeAt && user !== undefined;
    const after = addStrike ? before + 1 : before;
    const suspendNow = addStrike && user?.postingSuspended !== true &&
      config.strikeSuspendThreshold > 0 && after >= config.strikeSuspendThreshold;

    const workUpdate = {
      TableName: tableName(), Key: Keys.work(workId),
      UpdateExpression:
        "SET moderationHidden = :on, moderationHiddenAt = :now, moderationHiddenBy = :by" +
        (addStrike ? ", moderationStrikeAt = :now" : "") +
        " REMOVE moderationAutoHidden, moderationAutoHiddenAt, moderationAutoHiddenReason",
      ConditionExpression: "itemType = :work AND authorId = :author" +
        (addStrike ? " AND attribute_not_exists(moderationStrikeAt)" : ""),
      ExpressionAttributeValues: {
        ":on": true, ":now": now, ":by": by,
        ":work": TABLE_ITEM_TYPE.Work, ":author": work.authorId,
      },
    };
    const userUpdate = addStrike ? {
      TableName: tableName(), Key: Keys.user(work.authorId),
      UpdateExpression:
        "SET moderationStrikeCount = :after, moderationLastStrikeAt = :now" +
        (suspendNow
          ? ", postingSuspended = :on, postingSuspendedAt = :now, " +
            "postingSuspendedReason = :reason, postingSuspendedBy = :auto"
          : ""),
      ConditionExpression:
        "itemType = :user AND attribute_not_exists(erasureReceipt) AND " +
        (before === 0
          ? "(attribute_not_exists(moderationStrikeCount) OR moderationStrikeCount = :before)"
          : "moderationStrikeCount = :before"),
      ExpressionAttributeValues: {
        ":user": TABLE_ITEM_TYPE.User, ":before": before, ":after": after, ":now": now,
        ...(suspendNow ? {
          ":on": true, ":auto": "auto",
          ":reason": `規約に反する作品の非掲載が${after}件になったため自動で停止`,
        } : {}),
      },
    } : undefined;
    const report = options.report;
    try {
      await ddb.send(new TransactWriteCommand({ TransactItems: [
        { Update: workUpdate },
        ...(userUpdate ? [{ Update: userUpdate }] : []),
        ...(report ? [{ Update: resolveUpdate(
          { pk: report.pk, sk: report.sk }, "hide", by, options.note, now, report.status,
        ) }] : []),
      ] }));
      return {
        strikeAdded: addStrike,
        strikeCount: after,
        postingSuspended: suspendNow || user?.postingSuspended === true,
        suspendedNow: suspendNow,
      };
    } catch (error) {
      if (!(error instanceof TransactionCanceledException)) throw error;
      if (report) {
        const current = await getReport({ pk: report.pk, sk: report.sk });
        if (!current || current.status === "resolved") {
          conflict("この通報は対応済みです", "REPORT_RESOLVED");
        }
        options = { ...options, report: current };
      }
    }
  }
  conflict("作品または投稿者が同時に更新されました。もう一度お試しください", "MODERATION_CHANGED");
}

/** Hides the work named by a report (or a work by the reported account). */
export async function hideReport(
  key: { pk: string; sk: string },
  by: string,
  options: { workId?: string; note?: string } = {},
): Promise<StrikeOutcome & { workId: string; resolved: number }> {
  const report = await getReport(key);
  if (!report) notFound("通報が見つかりません");
  if (report.status === "resolved") conflict("この通報は対応済みです", "REPORT_RESOLVED");
  const workId = report.workId ?? options.workId;
  if (!workId) {
    conflict("アカウントへの通報では、非掲載にする作品のIDを指定してください", "WORK_ID_REQUIRED");
  }
  if (report.workId && options.workId && options.workId !== report.workId) {
    conflict("通報された作品と異なる作品IDです", "WORK_AUTHOR_MISMATCH");
  }
  const outcome = await hideWorkWithStrike(workId, by, {
    report, note: options.note,
    expectedAuthorId: report.workId ? undefined : report.targetId,
  });
  const now = new Date().toISOString();
  let resolved = 1 + await resolveOpenReportsFor(Keys.work(workId).pk, "hide", by, options.note, now);
  if (!report.workId) {
    resolved += await resolveOpenReportsFor(report.pk, "hide", by, options.note, now);
  }
  return { ...outcome, workId, resolved };
}

/**
 * Makes a hidden work visible again (an appeal upheld, a mistaken hide).
 * Removes the strike this work added (unless `keepStrike`) and lifts an
 * automatic suspension that no longer meets the threshold. Open reports on
 * the work are resolved as part of the decision.
 */
export async function unhideWork(
  workId: string,
  by: string,
  options: { keepStrike?: boolean; note?: string; config?: ModerationConfig } = {},
): Promise<{ unhidden: boolean; strikeRemoved: boolean; strikeCount?: number; suspensionLifted: boolean; resolved: number }> {
  const config = options.config ?? moderationConfig();
  for (let attempt = 0; attempt < 3; attempt++) {
    const work = await getWork(workId);
    if (!work) notFound("作品が見つかりません");
    const now = new Date().toISOString();
    if (!work.moderationHidden) {
      const resolved = await resolveOpenReportsFor(Keys.work(workId).pk, "unhide", by, options.note, now);
      return { unhidden: false, strikeRemoved: false, suspensionLifted: false, resolved };
    }
    const user = work.moderationStrikeAt && !options.keepStrike
      ? await getUserItem(work.authorId) : undefined;
    const removeStrike = user !== undefined;
    const before = user?.moderationStrikeCount ?? 0;
    const after = Math.max(0, before - 1);
    const liftSuspension = removeStrike && user?.postingSuspended === true &&
      user.postingSuspendedBy === "auto" &&
      (config.strikeSuspendThreshold === 0 || after < config.strikeSuspendThreshold);
    try {
      await ddb.send(new TransactWriteCommand({ TransactItems: [
        { Update: {
          TableName: tableName(), Key: Keys.work(workId),
          UpdateExpression:
            "SET moderationUnhiddenAt = :now, moderationUnhiddenBy = :by REMOVE moderationHidden, " +
            "moderationAutoHidden, moderationAutoHiddenAt, moderationAutoHiddenReason, " +
            "moderationHiddenAt, moderationHiddenBy" + (removeStrike ? ", moderationStrikeAt" : ""),
          ConditionExpression: "itemType = :work AND moderationHidden = :on" +
            (removeStrike ? " AND moderationStrikeAt = :strikeAt" : ""),
          ExpressionAttributeValues: {
            ":work": TABLE_ITEM_TYPE.Work, ":on": true, ":now": now, ":by": by,
            ...(removeStrike ? { ":strikeAt": work.moderationStrikeAt } : {}),
          },
        } },
        ...(removeStrike ? [{ Update: {
          TableName: tableName(), Key: Keys.user(work.authorId),
          UpdateExpression: "SET moderationStrikeCount = :after" + (liftSuspension
            ? " REMOVE postingSuspended, postingSuspendedAt, postingSuspendedReason, postingSuspendedBy"
            : ""),
          ConditionExpression: "itemType = :user AND " + (before === 0
            ? "(attribute_not_exists(moderationStrikeCount) OR moderationStrikeCount = :before)"
            : "moderationStrikeCount = :before"),
          ExpressionAttributeValues: {
            ":user": TABLE_ITEM_TYPE.User, ":before": before, ":after": after,
          },
        } }] : []),
      ] }));
      const resolved = await resolveOpenReportsFor(Keys.work(workId).pk, "unhide", by, options.note, now);
      return {
        unhidden: true, strikeRemoved: removeStrike,
        strikeCount: removeStrike ? after : undefined,
        suspensionLifted: liftSuspension, resolved,
      };
    } catch (error) {
      if (!(error instanceof TransactionCanceledException)) throw error;
    }
  }
  conflict("作品または投稿者が同時に更新されました。もう一度お試しください", "MODERATION_CHANGED");
}

/** Suspends posting for an account (moderator decision). */
export async function suspendPosting(userId: string, by: string, reason: string): Promise<void> {
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(), Key: Keys.user(userId),
      UpdateExpression:
        "SET postingSuspended = :on, postingSuspendedAt = :now, " +
        "postingSuspendedReason = :reason, postingSuspendedBy = :by",
      ConditionExpression: "itemType = :user AND attribute_not_exists(erasureReceipt)",
      ExpressionAttributeValues: {
        ":on": true, ":now": new Date().toISOString(), ":reason": reason, ":by": by,
        ":user": TABLE_ITEM_TYPE.User,
      },
    }));
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) notFound("アカウントが見つかりません");
    throw error;
  }
}

/** Lifts a posting suspension; optionally clears the strike count too. */
export async function liftPostingSuspension(
  userId: string,
  by: string,
  options: { resetStrikes?: boolean } = {},
): Promise<void> {
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(), Key: Keys.user(userId),
      UpdateExpression:
        "SET postingSuspensionLiftedAt = :now, postingSuspensionLiftedBy = :by" +
        (options.resetStrikes ? ", moderationStrikeCount = :zero" : "") +
        " REMOVE postingSuspended, postingSuspendedAt, postingSuspendedReason, postingSuspendedBy",
      ConditionExpression: "itemType = :user AND attribute_not_exists(erasureReceipt)",
      ExpressionAttributeValues: {
        ":now": new Date().toISOString(), ":by": by, ":user": TABLE_ITEM_TYPE.User,
        ...(options.resetStrikes ? { ":zero": 0 } : {}),
      },
    }));
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) notFound("アカウントが見つかりません");
    throw error;
  }
}

// --- Small shared helpers ------------------------------------------------------------

/** Japan-time calendar day as yyyymmdd (counters roll over at JST midnight). */
export function jstDay(now = new Date()): string {
  return new Date(now.getTime() + 9 * 3_600_000).toISOString().slice(0, 10).replace(/-/g, "");
}

export function epochSeconds(ms: number): number {
  return Math.floor(ms / 1000);
}
