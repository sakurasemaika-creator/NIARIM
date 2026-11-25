import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "./dynamo";
import { MODERATION_SETTINGS_ITEM_TYPE } from "./moderation";
import { forbidden, unauthorized } from "./response";

/**
 * Bearer token of the triage bot: a scheduled Claude session on the owner's
 * Claude subscription that reads pending reports (`GET /triage-bot/reports`)
 * and writes advisory judgments back. No Anthropic API key is involved.
 *
 * The token is created on the admin page and shown there once. Only its
 * SHA-256 hash is stored, on the moderation settings item (the same item as
 * the admin page's AI mode, so every write here is an update, never a put).
 * Replacing or revoking it on the admin page cuts the old token off; other
 * warm Lambda containers notice within the settings cache (30 s).
 */
export const TRIAGE_BOT_TOKEN_PREFIX = "nrtb_";

export interface TriageBotStatus {
  configured: boolean;
  createdAt: string | null;
  createdBy: string | null;
  lastUsedAt: string | null;
}

interface StoredBotSettings {
  tokenHash?: string;
  createdAt?: string;
  createdBy?: string;
  lastUsedAt?: string;
}

const SETTINGS_CACHE_TTL_MS = 30_000;
const LAST_USED_INTERVAL_MS = 10 * 60_000;
const MAX_TOKEN_CHARS = 200;

let settingsCache: { at: number; settings: StoredBotSettings } | undefined;
let lastTouch: { hash: string; at: number } | undefined;

export function resetTriageBotCacheForTest(): void {
  settingsCache = undefined;
  lastTouch = undefined;
}

export function hashTriageBotToken(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value ? value : undefined;
}

async function readBotSettings(): Promise<StoredBotSettings> {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.moderationSettings(), ConsistentRead: true,
  }));
  const item = result?.Item;
  const settings: StoredBotSettings = {
    tokenHash: optionalString(item?.triageBotTokenHash),
    createdAt: optionalString(item?.triageBotTokenCreatedAt),
    createdBy: optionalString(item?.triageBotTokenCreatedBy),
    lastUsedAt: optionalString(item?.triageBotLastUsedAt),
  };
  settingsCache = { at: Date.now(), settings };
  return settings;
}

async function cachedBotSettings(): Promise<StoredBotSettings> {
  if (settingsCache && Date.now() - settingsCache.at < SETTINGS_CACHE_TTL_MS) {
    return settingsCache.settings;
  }
  return readBotSettings();
}

function statusOf(settings: StoredBotSettings): TriageBotStatus {
  return {
    configured: settings.tokenHash !== undefined,
    createdAt: settings.tokenHash ? settings.createdAt ?? null : null,
    createdBy: settings.tokenHash ? settings.createdBy ?? null : null,
    lastUsedAt: settings.tokenHash ? settings.lastUsedAt ?? null : null,
  };
}

/** The token's state for the admin page (always read fresh). */
export async function triageBotStatus(): Promise<TriageBotStatus> {
  return statusOf(await readBotSettings());
}

/**
 * Creates the bot token, replacing any earlier one. The plain token is
 * returned only here; it is never stored or logged.
 */
export async function createTriageBotToken(by: string): Promise<{ token: string; createdAt: string }> {
  const token = TRIAGE_BOT_TOKEN_PREFIX + randomBytes(32).toString("base64url");
  const tokenHash = hashTriageBotToken(token);
  const createdAt = new Date().toISOString();
  await ddb.send(new UpdateCommand({
    TableName: tableName(),
    Key: Keys.moderationSettings(),
    UpdateExpression:
      "SET itemType = :type, triageBotTokenHash = :hash, " +
      "triageBotTokenCreatedAt = :now, triageBotTokenCreatedBy = :by " +
      "REMOVE triageBotLastUsedAt",
    ExpressionAttributeValues: {
      ":type": MODERATION_SETTINGS_ITEM_TYPE, ":hash": tokenHash, ":now": createdAt, ":by": by,
    },
  }));
  settingsCache = { at: Date.now(), settings: { tokenHash, createdAt, createdBy: by } };
  lastTouch = undefined;
  return { token, createdAt };
}

/** Revokes the bot token (idempotent). */
export async function revokeTriageBotToken(by: string): Promise<void> {
  await ddb.send(new UpdateCommand({
    TableName: tableName(),
    Key: Keys.moderationSettings(),
    UpdateExpression:
      "SET itemType = :type, triageBotTokenRevokedAt = :now, triageBotTokenRevokedBy = :by " +
      "REMOVE triageBotTokenHash, triageBotTokenCreatedAt, triageBotTokenCreatedBy, triageBotLastUsedAt",
    ExpressionAttributeValues: {
      ":type": MODERATION_SETTINGS_ITEM_TYPE, ":now": new Date().toISOString(), ":by": by,
    },
  }));
  settingsCache = { at: Date.now(), settings: {} };
  lastTouch = undefined;
}

function headerValue(event: APIGatewayProxyEventV2, name: string): string | undefined {
  for (const [key, value] of Object.entries(event.headers ?? {})) {
    if (key.toLowerCase() === name && typeof value === "string") return value;
  }
  return undefined;
}

function sameHash(presentedHex: string, storedHex: string): boolean {
  const presented = Buffer.from(presentedHex, "hex");
  const stored = Buffer.from(storedHex, "hex");
  return presented.length === stored.length && presented.length > 0 &&
    timingSafeEqual(presented, stored);
}

/** Records when the bot last called, at most once per 10 minutes. Never throws. */
async function touchLastUsed(settings: StoredBotSettings, hash: string): Promise<void> {
  const now = Date.now();
  const stored = settings.lastUsedAt ? Date.parse(settings.lastUsedAt) : NaN;
  const last = Math.max(
    Number.isFinite(stored) ? stored : 0,
    lastTouch?.hash === hash ? lastTouch.at : 0,
  );
  if (now - last < LAST_USED_INTERVAL_MS) return;
  lastTouch = { hash, at: now };
  const at = new Date(now).toISOString();
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: Keys.moderationSettings(),
      UpdateExpression: "SET triageBotLastUsedAt = :now",
      ConditionExpression: "triageBotTokenHash = :hash",
      ExpressionAttributeValues: { ":now": at, ":hash": hash },
    }));
    if (settingsCache?.settings.tokenHash === hash) {
      settingsCache.settings = { ...settingsCache.settings, lastUsedAt: at };
    }
  } catch {
    // Best effort: a failed note never fails the bot's request.
  }
}

/**
 * Authenticates the triage bot by `Authorization: Bearer nrtb_…`.
 * No token configured → 403 TRIAGE_BOT_DISABLED; a missing or wrong token
 * → 401 UNAUTHORIZED.
 */
export async function authenticateTriageBot(event: APIGatewayProxyEventV2): Promise<void> {
  const settings = await cachedBotSettings();
  if (!settings.tokenHash) {
    forbidden("判定用のトークンが設定されていません", "TRIAGE_BOT_DISABLED");
  }
  const match = /^Bearer\s+(\S+)\s*$/i.exec(headerValue(event, "authorization") ?? "");
  const token = match?.[1];
  if (!token || token.length > MAX_TOKEN_CHARS) unauthorized();
  const hash = hashTriageBotToken(token);
  if (!sameHash(hash, settings.tokenHash)) unauthorized();
  await touchLastUsed(settings, hash);
}
