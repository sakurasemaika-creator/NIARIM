import type { APIGatewayProxyStructuredResultV2 } from "aws-lambda";

/**
 * Lambda Function URLのレスポンス組み立てヘルパー。16章のとおり
 * AuthType: NONEの公開エンドポイントであり、CORS等は同一オリジン想定
 * （アプリからの直接呼び出しのみ）のため付与しない。
 */
export function json(
  statusCode: number,
  body: unknown,
): APIGatewayProxyStructuredResultV2 {
  return {
    statusCode,
    headers: {
      "content-type": "application/json; charset=utf-8",
      // Worker内部のエラー詳細を漏らさない・キャッシュさせない、程度の
      // 最低限のセキュリティヘッダー。
      "x-content-type-options": "nosniff",
      "cache-control": "no-store",
      "content-security-policy": "default-src 'none'; frame-ancestors 'none'",
      "referrer-policy": "no-referrer",
      "strict-transport-security": "max-age=31536000; includeSubDomains",
    },
    body: JSON.stringify(body),
  };
}

export function ok(body: unknown) {
  return json(200, body);
}

export function created(body: unknown) {
  return json(201, body);
}

export function noContent() {
  return json(204, {});
}

export class ApiError extends Error {
  constructor(
    public statusCode: number,
    message: string,
    public code?: string,
  ) {
    super(message);
  }
}

export function badRequest(message: string, code?: string): never {
  throw new ApiError(400, message, code);
}

export function unauthorized(message = "認証が必要です"): never {
  throw new ApiError(401, message, "UNAUTHORIZED");
}

export function forbidden(message = "この操作は許可されていません"): never {
  throw new ApiError(403, message, "FORBIDDEN");
}

export function notFound(message = "見つかりません"): never {
  throw new ApiError(404, message, "NOT_FOUND");
}

export function conflict(message: string, code?: string): never {
  throw new ApiError(409, message, code);
}

export function payloadTooLarge(
  message = "リクエストボディが大きすぎます",
): never {
  throw new ApiError(413, message, "PAYLOAD_TOO_LARGE");
}

export function errorToResponse(
  err: unknown,
): APIGatewayProxyStructuredResultV2 {
  if (err instanceof ApiError) {
    return json(err.statusCode, { error: err.message, code: err.code });
  }
  // Worker内部のエラー詳細をレスポンスに含めない（CloudWatch Logsにのみ出す）。
  console.error(err);
  return json(500, { error: "内部エラーが発生しました" });
}
