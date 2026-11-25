import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "./dynamo";
import { epochSeconds, jstDay, type ModerationConfig } from "./moderation";

/**
 * Mail to the support mailbox about new Work Plaza reports, sent with the
 * Resend HTTP API. Every subject starts with SUBJECT_PREFIX so the owner can
 * filter the mails into their own folder.
 *
 * Throttled so a flood of reports cannot send hundreds of mails: at most one
 * mail per target (work or account) per hour, and at most `mailDailyCap`
 * mails per Japan-time day; the first report over the cap sends a single
 * "多数の通報があります" mail instead. The counters are small TTL items.
 */
export const SUBJECT_PREFIX = "[NIARIM通報]";
const RESEND_ENDPOINT = "https://api.resend.com/emails";
const DAY_TTL_SECONDS = 3 * 24 * 3600;

export interface ReportMailFacts {
  target: "work" | "account";
  reason: string;
  createdAt: string;
  workTitle?: string;
  youtubeUrl?: string;
  /** Distinct reporters with open reports on the same target. */
  reporterCount: number;
  autoHidden?: "reporters" | "ai";
}

function jstTime(iso: string): string {
  const time = Date.parse(iso);
  if (!Number.isFinite(time)) return iso;
  return new Date(time + 9 * 3_600_000).toISOString().slice(0, 16).replace("T", " ");
}

/** One line, no control characters (the title and reason are user text). */
function oneLine(text: string, max: number): string {
  const flat = text.replace(/[\u0000-\u001f\u007f]+/g, " ").trim();
  return flat.length > max ? `${flat.slice(0, max)}…` : flat;
}

export function reportMail(facts: ReportMailFacts, config: ModerationConfig) {
  const subject = SUBJECT_PREFIX + (facts.target === "work"
    ? `作品「${oneLine(facts.workTitle ?? "", 40)}」への通報（${facts.reporterCount}人）`
    : `アカウントへの通報（${facts.reporterCount}人）`);
  const status = facts.autoHidden === "reporters"
    ? `状態：通報が${facts.reporterCount}人に達したため、確認まで自動で非掲載にしています。`
    : facts.autoHidden === "ai"
      ? "状態：AIが重大と判定したため、確認まで自動で非掲載にしています。"
      : "状態：掲載中（確認待ち）";
  const text = [
    "作品広場に新しい通報がありました。",
    "",
    `対象：${facts.target === "work" ? "作品" : "アカウント"}`,
    ...(facts.target === "work" ? [
      `作品名：${oneLine(facts.workTitle ?? "", 200)}`,
      `YouTube：${facts.youtubeUrl ?? ""}`,
    ] : []),
    `通報の理由：${facts.reason}`,
    `未対応の通報をした人数：${facts.reporterCount}人`,
    ...(facts.target === "work" ? [status] : []),
    "",
    `受付日時：${jstTime(facts.createdAt)}（日本時間）`,
    `管理ページ：${config.adminPageUrl}`,
    "目安：10営業日以内に対応してください。",
  ].join("\n");
  return { subject, text };
}

export function floodMail(config: ModerationConfig) {
  return {
    subject: `${SUBJECT_PREFIX}多数の通報があります`,
    text: [
      "本日（日本時間）の通報のお知らせが上限に達したため、これ以降の通報はメールでお知らせしません。",
      "通報は受け付けて保存しています。管理ページで確認してください。",
      "",
      `管理ページ：${config.adminPageUrl}`,
    ].join("\n"),
  };
}

export type MailSender = (mail: { subject: string; text: string }) => Promise<boolean>;

export function resendSender(apiKey: string, config: ModerationConfig): MailSender {
  return async ({ subject, text }) => {
    try {
      const response = await fetch(RESEND_ENDPOINT, {
        method: "POST",
        signal: AbortSignal.timeout(8_000),
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: config.notifyFrom,
          to: [config.notifyTo],
          subject,
          text,
        }),
      });
      if (!response.ok) console.warn("Report mail was not accepted", response.status);
      return response.ok;
    } catch (error) {
      console.warn("Report mail failed", error instanceof Error ? error.name : "UnknownError");
      return false;
    }
  };
}

/** Claims this target's hourly mail slot. False when a mail went out recently. */
async function claimTargetSlot(targetPk: string, config: ModerationConfig, now: number): Promise<boolean> {
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: Keys.moderationNotice(targetPk),
      UpdateExpression: "SET itemType = :type, lastMailAt = :now, #ttl = :ttl",
      ConditionExpression: "attribute_not_exists(lastMailAt) OR lastMailAt <= :since",
      ExpressionAttributeNames: { "#ttl": "ttl" },
      ExpressionAttributeValues: {
        ":type": "MODERATION_NOTICE", ":now": now,
        ":since": now - config.mailPerTargetIntervalMs,
        ":ttl": epochSeconds(now + config.mailPerTargetIntervalMs) + 3600,
      },
    }));
    return true;
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) return false;
    throw error;
  }
}

/** Takes one unit of a daily counter on the JST-day item. False at the cap. */
export async function takeDailyUnit(
  counter: "mailCount",
  cap: number,
  now = Date.now(),
): Promise<boolean> {
  if (cap <= 0) return false;
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: Keys.moderationDaily(jstDay(new Date(now))),
      UpdateExpression: "SET itemType = :type, #ttl = :ttl ADD #counter :one",
      ConditionExpression: "attribute_not_exists(#counter) OR #counter < :cap",
      ExpressionAttributeNames: { "#ttl": "ttl", "#counter": counter },
      ExpressionAttributeValues: {
        ":type": "MODERATION_DAILY", ":one": 1, ":cap": cap,
        ":ttl": epochSeconds(now) + DAY_TTL_SECONDS,
      },
    }));
    return true;
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) return false;
    throw error;
  }
}

async function claimFloodNotice(now: number): Promise<boolean> {
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: Keys.moderationDaily(jstDay(new Date(now))),
      UpdateExpression: "SET itemType = :type, floodNoticeSentAt = :now, #ttl = :ttl",
      ConditionExpression: "attribute_not_exists(floodNoticeSentAt)",
      ExpressionAttributeNames: { "#ttl": "ttl" },
      ExpressionAttributeValues: {
        ":type": "MODERATION_DAILY", ":now": now, ":ttl": epochSeconds(now) + DAY_TTL_SECONDS,
      },
    }));
    return true;
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) return false;
    throw error;
  }
}

export type NotifyOutcome = "sent" | "throttled" | "flood-notice" | "capped" | "failed" | "disabled";

/**
 * Sends the mail for one new report, within the throttles. Never throws.
 * `send` is undefined when no Resend key is configured (mail is skipped).
 */
export async function notifyNewReport(
  targetPk: string,
  facts: ReportMailFacts,
  config: ModerationConfig,
  send: MailSender | undefined,
  now = Date.now(),
): Promise<NotifyOutcome> {
  if (!send) return "disabled";
  try {
    if (!await claimTargetSlot(targetPk, config, now)) return "throttled";
    if (!await takeDailyUnit("mailCount", config.mailDailyCap, now)) {
      if (!await claimFloodNotice(now)) return "capped";
      return await send(floodMail(config)) ? "flood-notice" : "failed";
    }
    return await send(reportMail(facts, config)) ? "sent" : "failed";
  } catch (error) {
    console.warn("Report mail skipped", error instanceof Error ? error.name : "UnknownError");
    return "failed";
  }
}
