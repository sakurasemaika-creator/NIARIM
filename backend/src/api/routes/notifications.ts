import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { authenticate } from "../../lib/auth";
import { badRequest, forbidden, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import { registerDeviceToken, unregisterDeviceToken } from "../../lib/push";

/** Compatibility response for older apps after follow notifications were retired. */
export async function getNotifications(
  event: APIGatewayProxyEventV2,
  targetId: string,
) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (auth.niarimUserId !== targetId) forbidden("本人の通知のみ取得できます");

  return ok({ notifications: [], unreadCount: 0 });
}

export async function markNotificationsRead(
  event: APIGatewayProxyEventV2,
  targetId: string,
) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (auth.niarimUserId !== targetId) forbidden("本人の通知のみ操作できます");

  return ok({ markedCount: 0 });
}

/**
 * `PUT /users/{id}/push-token`（22.7節：真のプッシュ通知）。
 * アプリがFCMから受け取った端末トークンを登録する。本人のみ。
 * `enabled: false`を送ると、その端末のトークンを削除する
 * （通知オフ・ログアウト時）。
 */
export async function putPushToken(
  event: APIGatewayProxyEventV2,
  targetId: string,
) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (auth.niarimUserId !== targetId) forbidden("本人のみ登録できます");

  const body = parseJsonObject(event.body);
  if (typeof body.token !== "string" || !body.token.trim()) {
    badRequest("tokenは必須です");
  }
  const token = body.token.trim();
  // FCMの登録トークンは概ね150〜200文字程度。桁外れの入力を弾く。
  if (token.length > 1024) badRequest("tokenが長すぎます");

  if (body.enabled === false) {
    await unregisterDeviceToken(targetId, token);
    return ok({ registered: false });
  }

  const platform = body.platform === "ios" ? "ios" : "android";
  await registerDeviceToken(targetId, token, platform, body.localizedNotifications === true, body.deviceHandledNotices === true);
  return ok({ registered: true, platform });
}
