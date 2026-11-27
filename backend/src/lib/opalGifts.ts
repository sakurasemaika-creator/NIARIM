import { randomBytes, randomInt } from "node:crypto";
import { badRequest } from "./response";

/**
 * Operator-issued opals: coupon codes typed into the app and presents shown
 * in the app's present box. Definitions live in two fixed partitions
 * (`OPAL_COUPON`, `OPAL_PRESENT`) and per-account markers live in the
 * account's own partition, so no GSI or extra capacity is needed and account
 * erasure removes the markers with the rest of the account.
 */

export const COUPON_ITEM_TYPE = "OPAL_COUPON";
export const COUPON_REDEMPTION_ITEM_TYPE = "OPAL_COUPON_REDEMPTION";
export const COUPON_ATTEMPTS_ITEM_TYPE = "OPAL_COUPON_ATTEMPTS";
export const PRESENT_ITEM_TYPE = "OPAL_PRESENT";
export const PRESENT_INDEX_ITEM_TYPE = "OPAL_PRESENT_INDEX";
export const PRESENT_CLAIM_ITEM_TYPE = "OPAL_PRESENT_CLAIM";

/** Largest amount one coupon or present can grant. */
export const MAX_GIFT_COINS = 1_000_000;
/** Longest validity window of one coupon or present. */
export const MAX_GIFT_SPAN_MS = 366 * 24 * 60 * 60 * 1000;
/** Presents that may be active at the same time (keeps the inbox read small). */
export const MAX_ACTIVE_PRESENTS = 20;
/** Account ids one targeted present may list. */
export const MAX_PRESENT_ACCOUNTS = 100;
export const MAX_NEW_ACCOUNT_DAYS = 365;
export const MAX_REDEMPTIONS_LIMIT = 10_000_000;
export const MAX_PRESENT_TITLE_CHARS = 80;
export const MAX_PRESENT_BODY_CHARS = 1000;
export const MAX_NOTE_CHARS = 500;
/** Coupon attempts (successful or not) one account may make per hour. */
export const COUPON_ATTEMPTS_PER_HOUR = 10;
/** Generated codes avoid characters that are easy to confuse (0/O, 1/I/L). */
export const COUPON_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
export const GENERATED_COUPON_LENGTH = 12;
export const PRESENT_LOCALES = ["ja", "en", "es", "fr", "ko", "zh", "zh_Hant"] as const;

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Canonical form of a typed coupon code: full-width characters folded
 * (NFKC), upper case, and spaces, hyphens, dots and long-vowel marks removed.
 * Returns null when the rest is not 4 to 32 ASCII letters and digits.
 */
export function normalizeCouponCode(raw: unknown): string | null {
  if (typeof raw !== "string" || raw.length > 128) return null;
  const folded = raw.normalize("NFKC").toUpperCase()
    .replace(/[\s\-_.‐-―−ー・－]/g, "");
  return /^[A-Z0-9]{4,32}$/.test(folded) ? folded : null;
}

/** Code shown to people: generated codes in groups of four. */
export function displayCouponCode(code: string): string {
  return code.length === GENERATED_COUPON_LENGTH &&
      [...code].every((c) => COUPON_CODE_ALPHABET.includes(c))
    ? code.match(/.{4}/g)!.join("-")
    : code;
}

export function generateCouponCode(
  pick: (max: number) => number = (max) => randomInt(0, max),
): string {
  let code = "";
  for (let i = 0; i < GENERATED_COUPON_LENGTH; i++) {
    code += COUPON_CODE_ALPHABET[pick(COUPON_CODE_ALPHABET.length)];
  }
  return code;
}

/** Present id: fixed-width base-36 creation time + 8 random hex digits. */
export function generatePresentId(now = Date.now()): string {
  return now.toString(36).padStart(9, "0") + randomBytes(4).toString("hex");
}

export function isPresentId(value: string): boolean {
  return /^[0-9a-z]{9}[0-9a-f]{8}$/.test(value);
}

export function isNiarimUserId(value: unknown): value is string {
  return typeof value === "string" && /^N[0-9a-f]{32}$/.test(value);
}

/** Hourly window for the coupon attempt counter. */
export function couponAttemptWindowId(now: number): string {
  return `H${Math.floor(now / (60 * 60 * 1000))}`;
}

/**
 * Which accounts a coupon or present is for. Every field is optional and the
 * fields combine with AND; an empty filter means every account.
 */
export interface AccountFilter {
  /** Accounts created at most this many days before the redemption/claim. */
  newAccountWithinDays?: number;
  /** Accounts created at or after this time. */
  accountCreatedFromEpochMs?: number;
  /** Accounts created at or before this time (e.g. apologies). */
  accountCreatedUntilEpochMs?: number;
  /** Only these NIARIM account ids (presents only). */
  accountIds?: string[];
}

export type IneligibleReason = "newAccountsOnly" | "accountTooNew" | "accountNotListed";

/** Why the account cannot use the gift, or null when it can. */
export function accountIneligibility(
  filter: AccountFilter,
  account: { userId: string; createdAtEpochMs: number | null },
  now: number,
): IneligibleReason | null {
  if (filter.accountIds && !filter.accountIds.includes(account.userId)) {
    return "accountNotListed";
  }
  const created = account.createdAtEpochMs;
  if (filter.newAccountWithinDays !== undefined &&
      (created === null || created < now - filter.newAccountWithinDays * DAY_MS)) {
    return "newAccountsOnly";
  }
  if (filter.accountCreatedFromEpochMs !== undefined &&
      (created === null || created < filter.accountCreatedFromEpochMs)) {
    return "newAccountsOnly";
  }
  if (filter.accountCreatedUntilEpochMs !== undefined &&
      (created === null || created > filter.accountCreatedUntilEpochMs)) {
    return "accountTooNew";
  }
  return null;
}

export function epochMsOf(iso: string | undefined): number | null {
  if (typeof iso !== "string") return null;
  const value = Date.parse(iso);
  return Number.isFinite(value) ? value : null;
}

/** Epoch milliseconds from a number or an ISO 8601 string with a zone. */
export function parseInstant(value: unknown, field: string): number {
  if (typeof value === "number" && Number.isSafeInteger(value) && value > 0) return value;
  if (typeof value === "string" && value.length <= 40 &&
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?(Z|[+-]\d{2}:\d{2})$/.test(value)) {
    const parsed = Date.parse(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  badRequest(`${field}はタイムゾーン付きのISO 8601か、エポックミリ秒で指定してください`,
    "GIFT_INVALID_TIME");
}

export function parseCoins(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) ||
      value < 1 || value > MAX_GIFT_COINS) {
    badRequest(`coinsは1〜${MAX_GIFT_COINS}の整数です`, "GIFT_INVALID_COINS");
  }
  return value;
}

export function parseWindow(
  fromRaw: unknown,
  untilRaw: unknown,
  names: [string, string],
  now: number,
): { from: number; until: number } {
  const from = fromRaw === undefined ? now : parseInstant(fromRaw, names[0]);
  const until = parseInstant(untilRaw, names[1]);
  if (until <= from) badRequest(`${names[1]}は${names[0]}より後にしてください`, "GIFT_INVALID_WINDOW");
  if (until <= now) badRequest(`${names[1]}が過ぎています`, "GIFT_INVALID_WINDOW");
  if (until - from > MAX_GIFT_SPAN_MS) {
    badRequest("有効期間は366日以内にしてください", "GIFT_INVALID_WINDOW");
  }
  return { from, until };
}

export function parseAccountFilter(
  raw: unknown,
  options: { allowAccountIds: boolean },
): AccountFilter {
  if (raw === undefined || raw === null) return {};
  if (typeof raw !== "object" || Array.isArray(raw)) {
    badRequest("eligibilityはオブジェクトで指定してください", "GIFT_INVALID_ELIGIBILITY");
  }
  const input = raw as Record<string, unknown>;
  const allowed = ["newAccountWithinDays", "accountCreatedFrom", "accountCreatedUntil",
    ...(options.allowAccountIds ? ["accountIds"] : [])];
  for (const key of Object.keys(input)) {
    if (!allowed.includes(key)) {
      badRequest(`eligibilityに使えない項目です: ${key}`, "GIFT_INVALID_ELIGIBILITY");
    }
  }
  const filter: AccountFilter = {};
  if (input.newAccountWithinDays !== undefined) {
    const days = input.newAccountWithinDays;
    if (typeof days !== "number" || !Number.isSafeInteger(days) ||
        days < 1 || days > MAX_NEW_ACCOUNT_DAYS) {
      badRequest(`newAccountWithinDaysは1〜${MAX_NEW_ACCOUNT_DAYS}の整数です`,
        "GIFT_INVALID_ELIGIBILITY");
    }
    filter.newAccountWithinDays = days;
  }
  if (input.accountCreatedFrom !== undefined) {
    filter.accountCreatedFromEpochMs = parseInstant(input.accountCreatedFrom, "accountCreatedFrom");
  }
  if (input.accountCreatedUntil !== undefined) {
    filter.accountCreatedUntilEpochMs = parseInstant(input.accountCreatedUntil, "accountCreatedUntil");
  }
  if (filter.accountCreatedFromEpochMs !== undefined &&
      filter.accountCreatedUntilEpochMs !== undefined &&
      filter.accountCreatedUntilEpochMs < filter.accountCreatedFromEpochMs) {
    badRequest("accountCreatedUntilはaccountCreatedFrom以降にしてください",
      "GIFT_INVALID_ELIGIBILITY");
  }
  if (input.accountIds !== undefined) {
    const ids = input.accountIds;
    if (!Array.isArray(ids) || ids.length < 1 || ids.length > MAX_PRESENT_ACCOUNTS ||
        !ids.every(isNiarimUserId)) {
      badRequest(`accountIdsは1〜${MAX_PRESENT_ACCOUNTS}件のNIARIM User IDです`,
        "GIFT_INVALID_ELIGIBILITY");
    }
    filter.accountIds = [...new Set(ids as string[])];
  }
  return filter;
}

/** Stored filter fields, read back defensively. */
export function storedAccountFilter(row: Record<string, unknown> | undefined): AccountFilter {
  const raw = row?.eligibility;
  if (!raw || typeof raw !== "object") return {};
  const value = raw as Record<string, unknown>;
  const filter: AccountFilter = {};
  if (Number.isSafeInteger(value.newAccountWithinDays)) {
    filter.newAccountWithinDays = value.newAccountWithinDays as number;
  }
  if (Number.isSafeInteger(value.accountCreatedFromEpochMs)) {
    filter.accountCreatedFromEpochMs = value.accountCreatedFromEpochMs as number;
  }
  if (Number.isSafeInteger(value.accountCreatedUntilEpochMs)) {
    filter.accountCreatedUntilEpochMs = value.accountCreatedUntilEpochMs as number;
  }
  if (Array.isArray(value.accountIds)) {
    filter.accountIds = value.accountIds.filter(isNiarimUserId);
  }
  return filter;
}

export function parseText(
  value: unknown,
  field: string,
  max: number,
  options: { required: boolean },
): string | undefined {
  if (value === undefined || value === null || value === "") {
    if (options.required) badRequest(`${field}を入力してください`, "GIFT_INVALID_TEXT");
    return undefined;
  }
  if (typeof value !== "string") badRequest(`${field}は文字列です`, "GIFT_INVALID_TEXT");
  const text = value.replace(/\r\n?/g, "\n").trim();
  if (!text) {
    if (options.required) badRequest(`${field}を入力してください`, "GIFT_INVALID_TEXT");
    return undefined;
  }
  if ([...text].length > max) badRequest(`${field}は${max}文字以内です`, "GIFT_INVALID_TEXT");
  // Control characters other than line breaks and tabs are refused.
  if (/[\u0000-\u0008\u000b-\u001f\u007f]/.test(text)) {
    badRequest(`${field}に使えない文字があります`, "GIFT_INVALID_TEXT");
  }
  return text;
}

export interface PresentMessage { title: string; body: string }

/**
 * Optional per-language messages of a present. The operator's own `title`
 * and `body` are the fallback for any language not listed.
 */
export function parseTranslations(raw: unknown): Record<string, PresentMessage> | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (typeof raw !== "object" || Array.isArray(raw)) {
    badRequest("translationsはオブジェクトで指定してください", "GIFT_INVALID_TEXT");
  }
  const result: Record<string, PresentMessage> = {};
  for (const [locale, value] of Object.entries(raw as Record<string, unknown>)) {
    if (!(PRESENT_LOCALES as readonly string[]).includes(locale)) {
      badRequest(`translationsに使えない言語です: ${locale}`, "GIFT_INVALID_TEXT");
    }
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      badRequest("translationsの各言語は{title, body}です", "GIFT_INVALID_TEXT");
    }
    const message = value as Record<string, unknown>;
    result[locale] = {
      title: parseText(message.title, `translations.${locale}.title`,
        MAX_PRESENT_TITLE_CHARS, { required: true })!,
      body: parseText(message.body, `translations.${locale}.body`,
        MAX_PRESENT_BODY_CHARS, { required: false }) ?? "",
    };
  }
  return Object.keys(result).length ? result : undefined;
}

export function storedTranslations(raw: unknown): Record<string, PresentMessage> | undefined {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return undefined;
  const result: Record<string, PresentMessage> = {};
  for (const [locale, value] of Object.entries(raw as Record<string, unknown>)) {
    if (!(PRESENT_LOCALES as readonly string[]).includes(locale) ||
        !value || typeof value !== "object") continue;
    const message = value as Record<string, unknown>;
    if (typeof message.title !== "string") continue;
    result[locale] = {
      title: message.title,
      body: typeof message.body === "string" ? message.body : "",
    };
  }
  return Object.keys(result).length ? result : undefined;
}

/** One entry of the active present index (no message text). */
export interface PresentIndexEntry {
  id: string;
  visibleFromEpochMs: number;
  claimUntilEpochMs: number;
  eligibility: Omit<AccountFilter, "accountIds">;
  targeted: boolean;
}

export function storedIndexEntries(row: Record<string, unknown> | undefined): PresentIndexEntry[] {
  if (row?.itemType !== PRESENT_INDEX_ITEM_TYPE || !Array.isArray(row.entries)) return [];
  const entries: PresentIndexEntry[] = [];
  for (const raw of row.entries) {
    if (!raw || typeof raw !== "object") continue;
    const entry = raw as Record<string, unknown>;
    if (typeof entry.id !== "string" || !isPresentId(entry.id) ||
        !Number.isSafeInteger(entry.visibleFromEpochMs) ||
        !Number.isSafeInteger(entry.claimUntilEpochMs)) continue;
    const { accountIds: _ignored, ...eligibility } = storedAccountFilter(entry);
    entries.push({
      id: entry.id,
      visibleFromEpochMs: entry.visibleFromEpochMs as number,
      claimUntilEpochMs: entry.claimUntilEpochMs as number,
      eligibility,
      targeted: entry.targeted === true,
    });
  }
  return entries;
}
