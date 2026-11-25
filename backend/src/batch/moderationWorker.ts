import type { DynamoDBBatchResponse, DynamoDBStreamEvent } from "aws-lambda";
import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "../lib/dynamo";
import {
  applyReporterThreshold,
  getReport,
  moderationConfig,
  reportStatsForTarget,
  type ModerationConfig,
} from "../lib/moderation";
import { notifyNewReport, resendSender, type MailSender } from "../lib/moderationNotify";
import { readSecureParameter } from "../lib/ssmParameters";
import type { WorkItem } from "../lib/types";
import { TABLE_ITEM_TYPE } from "../lib/types";

/**
 * Moderation worker for newly stored reports.
 *
 * It is a second consumer of the table's DynamoDB stream, filtered to REPORT
 * inserts, so POST /reports returns as soon as the report is written and the
 * mail is sent afterwards. Stream processing is one batch at a time per
 * shard, so a flood of reports is handled in order instead of taking the
 * account's small Lambda concurrency away from the API. Every record is
 * idempotent: at most one mail per target per hour.
 *
 * The worker never calls an AI. Claude judges reports later on the owner's
 * subscription (moderationTriage.ts), not through an Anthropic API key.
 */
export interface WorkerDeps {
  createSender?: (apiKey: string, config: ModerationConfig) => MailSender;
}

async function getWork(workId: string): Promise<WorkItem | undefined> {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.work(workId), ConsistentRead: true,
  }));
  return result?.Item?.itemType === TABLE_ITEM_TYPE.Work ? result.Item as WorkItem : undefined;
}

export async function processNewReport(
  key: { pk: string; sk: string },
  deps: WorkerDeps = {},
): Promise<void> {
  const config = moderationConfig();
  const report = await getReport(key);
  if (!report || report.status === "resolved") return;

  // Backstop for the check POST /reports already made right after writing.
  const stats = report.workId
    ? (await applyReporterThreshold(report.workId, config)).stats
    : await reportStatsForTarget(report.pk);
  const work = report.workId ? await getWork(report.workId) : undefined;
  const autoHidden: "reporters" | "ai" | undefined =
    work?.moderationAutoHidden ? work.moderationAutoHiddenReason ?? "reporters" : undefined;

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
    },
    config,
    send,
  );
  console.log("Report processed", JSON.stringify({
    autoHidden: autoHidden ?? null, mail: outcome,
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
      // Only storage errors reach here (mail never throws). Retry the
      // record; the mail throttle keeps the retry from mailing twice.
      console.error("Report moderation failed", error instanceof Error ? error.name : "UnknownError");
      const id = record.dynamodb?.SequenceNumber;
      if (id) batchItemFailures.push({ itemIdentifier: id });
    }
  }
  return { batchItemFailures };
}
