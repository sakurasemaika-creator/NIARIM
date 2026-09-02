import { badRequest } from './response';

/** JSON本文をオブジェクトとして厳密に読む。配列・null・プリミティブは拒否する。 */
export function parseJsonObject(
  raw: string | undefined,
  options: { allowEmpty?: boolean } = {},
): Record<string, unknown> {
  if (!raw) {
    if (options.allowEmpty) return {};
    badRequest('リクエストボディが空です');
  }

  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    badRequest('リクエストボディがJSONとして不正です');
  }
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    badRequest('リクエストボディはJSONオブジェクトである必要があります');
  }
  return value as Record<string, unknown>;
}
