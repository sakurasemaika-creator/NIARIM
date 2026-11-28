import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { authenticate, getUser } from "../../lib/auth";
import { assertPostingAllowed } from "../../lib/moderation";
import { postingMembershipTier, readPostQuota } from "../../lib/quota";
import { forbidden, ok } from "../../lib/response";

/**
 * `GET /me/post-quota`：今日あといくつ作品広場へ投稿できるか（読むだけ）。
 *
 * アプリはYouTubeへアップロードする前にこれを呼ぶ。`POST /works`と同じ順で
 * 確かめる：利用者の記録を読み、投稿を停止しているアカウントは
 * `POSTING_SUSPENDED`（403）、それ以外は保存している会員種別から
 * `reservePostQuota`と同じ上限・カウンターで残りを返す。
 */
export async function getMyPostQuota(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const user = await getUser(auth.niarimUserId);
  if (!user) forbidden("NIARIMユーザー情報を取得できませんでした");
  assertPostingAllowed(user);
  return ok(
    await readPostQuota(
      auth.niarimUserId,
      postingMembershipTier(auth.membershipTier, user.membershipTier),
    ),
  );
}
