import { badRequest } from "./response";

/** Cursor is tied to the query it was issued for; never reuse it across filters/accounts. */
export function decodePageCursor(
  raw: string | undefined,
  scope: string,
): Record<string, unknown> | undefined {
  if (!raw) return undefined;
  if (raw.length > 2048 || !/^[A-Za-z0-9_-]+$/.test(raw)) {
    badRequest("ページカーソルが不正です", "INVALID_PAGE_CURSOR");
  }
  try {
    const value: unknown = JSON.parse(Buffer.from(raw, "base64url").toString("utf8"));
    if (
      !value ||
      typeof value !== "object" ||
      Array.isArray(value) ||
      (value as Record<string, unknown>).scope !== scope
    ) {
      badRequest("ページカーソルが一致しません", "INVALID_PAGE_CURSOR");
    }
    const key = (value as Record<string, unknown>).key;
    if (!key || typeof key !== "object" || Array.isArray(key)) {
      badRequest("ページカーソルが不正です", "INVALID_PAGE_CURSOR");
    }
    const fields = key as Record<string, unknown>;
    if (typeof fields.pk !== "string" || typeof fields.sk !== "string") {
      badRequest("ページカーソルが不正です", "INVALID_PAGE_CURSOR");
    }
    return fields;
  } catch {
    badRequest("ページカーソルが不正です", "INVALID_PAGE_CURSOR");
  }
}

export function encodePageCursor(
  key: Record<string, unknown> | undefined,
  scope: string,
): string | null {
  return key ? Buffer.from(JSON.stringify({ scope, key })).toString("base64url") : null;
}

export function requestedPageSize(raw: string | undefined): number {
  if (raw == null) return 25;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > 25) {
    badRequest("取得件数は1〜25件で指定してください", "INVALID_PAGE_SIZE");
  }
  return value;
}
