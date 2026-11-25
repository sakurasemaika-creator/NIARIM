import type { DynamoDBBatchResponse, DynamoDBStreamEvent } from "aws-lambda";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { GetCommand, QueryCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "../lib/dynamo";
import {
  applyReporterThreshold,
  autoHideWork,
  effectiveModerationConfig,
  getReport,
  reportStatsForTarget,
  type ModerationConfig,
} from "../lib/moderation";
import {
  createTriageClient,
  triageReport,
  type TriageClient,
} from "../lib/moderationAi";
import {
  notifyNewReport,
  resendSender,
  takeDailyUnit,
  type MailSender,
} from "../lib/moderationNotify";
import { readSecureParameter } from "../lib/ssmParameters";
import type { AiTriageRecord, ReportItem, WorkItem } from "../lib/types";
import { TABLE_ITEM_TYPE } from "../lib/types";

/**
 * Moderation worker for newly stored reports.
 *
 * It is a second consumer of the table's DynamoDB stream, filtered to REPORT
 * inserts, so POST /reports returns as soon as the report is written and the
 * slow parts (AI triage, mail) happen afterwards. Stream processing is one
 * batch at a time per shard, so a flood of reports is handled in order
 * instead of taking the account's small Lambda concurrency away from the API.
 * Every record is idempotent: one AI call per report (claim marker) and at
 * most one mail per target per hour.
 */
export interface WorkerDeps {
  createTriageClient?: (apiKey: string) => TriageClient;
  createSender?: (apiKey: string, config: ModerationConfig) => MailSender;
}

async function getWork(workId: string): Promise<WorkItem | undefined> {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.work(workId), ConsistentRead: true,
  }));
  return result?.Item?.itemType === TABLE_ITEM_TYPE.Work ? result.Item as WorkItem : undefined;
}

async function getDescription(workId: string): Promise<string | undefined> {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.workDetail(workId),
  }));
  const description = result?.Item?.description;
  return typeof description === "string" ? description : undefined;
}

/** Whether at least `threshold` reports are pending (reads at most that many). */
export async function pendingReportsAtLeast(threshold: number): Promise<boolean> {
  if (threshold <= 0) return true;
  const result = await ddb.send(new QueryCommand({
    TableName: tableName(),
    IndexName: "GSI7",
    KeyConditionExpression: "gsi7pk = :status",
    ExpressionAttributeValues: { ":status": "REPORT_STATUS#pending" },
    Select: "COUNT",
    Limit: threshold,
  }));
  return (result?.Count ?? 0) >= threshold;
}

async function claimTriage(report: ReportItem, now: string): Promise<boolean> {
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(), Key: { pk: report.pk, sk: report.sk },
      UpdateExpression: "SET aiTriageClaimedAt = :now",
      ConditionExpression: "itemType = :report AND attribute_not_exists(aiTriageClaimedAt)",
      ExpressionAttributeValues: { ":now": now, ":report": TABLE_ITEM_TYPE.Report },
    }));
    return true;
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) return false;
    throw error;
  }
}

async function storeTriage(report: ReportItem, triage: AiTriageRecord): Promise<void> {
  await ddb.send(new UpdateCommand({
    TableName: tableName(), Key: { pk: report.pk, sk: report.sk },
    UpdateExpression: "SET aiTriage = :triage",
    ConditionExpression: "itemType = :report",
    ExpressionAttributeValues: { ":triage": triage, ":report": TABLE_ITEM_TYPE.Report },
  }));
}

/** Runs the AI triage when the mode, the key and the daily cap allow it. */
async function maybeTriage(
  report: ReportItem,
  work: WorkItem | undefined,
  config: ModerationConfig,
  deps: WorkerDeps,
): Promise<AiTriageRecord | undefined> {
  if (report.aiTriage) return report.aiTriage;
  if (config.aiMode === "off" || report.aiTriageClaimedAt) return undefined;
  const apiKey = await readSecureParameter(config.anthropicApiKeyParameter);
  if (!apiKey) return undefined;
  if (config.aiMode === "backlog" && !await pendingReportsAtLeast(config.aiBacklogThreshold)) {
    return undefined;
  }
  if (!await takeDailyUnit("aiCount", config.aiDailyCap)) return undefined;
  if (!await claimTriage(report, new Date().toISOString())) return undefined;
  const description = work ? await getDescription(work.workId) : undefined;
  const triage = await triageReport({
    target: report.workId ? "work" : "account",
    reportReason: report.reason,
    work: work ? {
      title: work.title,
      description,
      tags: work.tags ?? [],
      thumbnailUrl: work.thumbnailUrl,
    } : undefined,
  }, (deps.createTriageClient ?? createTriageClient)(apiKey));
  await storeTriage(report, triage);
  return triage;
}

export async function processNewReport(
  key: { pk: string; sk: string },
  deps: WorkerDeps = {},
): Promise<void> {
  const config = await effectiveModerationConfig();
  const report = await getReport(key);
  if (!report || report.status === "resolved") return;

  // Backstop for the check POST /reports already made right after writing.
  const stats = report.workId
    ? (await applyReporterThreshold(report.workId, config)).stats
    : await reportStatsForTarget(report.pk);
  let work = report.workId ? await getWork(report.workId) : undefined;

  const triage = await maybeTriage(report, work, config, deps);
  let autoHidden: "reporters" | "ai" | undefined =
    work?.moderationAutoHidden ? work.moderationAutoHiddenReason ?? "reporters" : undefined;
  if (report.workId && triage?.status === "ok" && triage.severity === "critical" &&
      !work?.moderationHidden) {
    if (await autoHideWork(report.workId, "ai")) {
      autoHidden = "ai";
      work = await getWork(report.workId) ?? work;
    }
  }

  const resendKey = await readSecureParameter(config.resendApiKeyParameter);
  const send = resendKey
    ? (deps.createSender ?? resendSender)(resendKey, config)
    : undefined;
  // A work that is now hidden pending review gets its own hourly mail slot,
  // so the mail that says it was hidden is not swallowed by the throttle.
  const targetPk = report.workId ? Keys.work(report.workId).pk : report.pk;
  const outcome = await notifyNewReport(
    autoHidden ? `${targetPk}#AUTO_HIDDEN` : targetPk,
    {
      target: report.workId ? "work" : "account",
      reason: report.reason,
      createdAt: report.createdAt,
      workTitle: work?.title,
      youtubeUrl: work?.youtubeUrl,
      reporterCount: stats.reporters,
      autoHidden,
      aiTriage: triage,
    },
    config,
    send,
  );
  console.log("Report processed", JSON.stringify({
    triage: triage?.status ?? "skipped", autoHidden: autoHidden ?? null, mail: outcome,
  }));
}

export async function handler(event: DynamoDBStreamEvent): Promise<DynamoDBBatchResponse> {
  const batchItemFailures: { itemIdentifier: string }[] = [];
  for (const record of event.Records ?? []) {
    const image = record.dynamodb?.NewImage;
    if (record.eventName !== "INSERT" || image?.itemType?.S !== TABLE_ITEM_TYPE.Report) continue;
    const pk = image.pk?.S;
    const sk = image.sk?.S;
    if (!pk || !sk) continue;
    try {
      await processNewReport({ pk, sk });
    } catch (error) {
      // Only storage errors reach here (AI and mail never throw). Retry the
      // record; the claim markers keep the retry from repeating finished work.
      console.error("Report moderation failed", error instanceof Error ? error.name : "UnknownError");
      const id = record.dynamodb?.SequenceNumber;
      if (id) batchItemFailures.push({ itemIdentifier: id });
    }
  }
  return { batchItemFailures };
}
