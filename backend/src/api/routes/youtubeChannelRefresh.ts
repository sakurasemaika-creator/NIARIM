import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate, getUser } from "../../lib/auth";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { getOwnChannelInfo } from "../../lib/youtube";
import { parseJsonObject } from "../../lib/request";
import { ApiError, badRequest, conflict, forbidden, ok } from "../../lib/response";
import { TABLE_ITEM_TYPE } from "../../lib/types";

/**
 * YouTubeチャンネル名・アイコンを所有者が手動で更新する。
 *
 * 投稿時に保存したchannelIdと一致するOAuthアカウントだけ更新可能。
 * JST日付あたり成功1回まで（DynamoDB条件付き更新で並列競合防止）。
 * 失敗したリクエストは成功回数へ数えない。
 */
export async function refreshMyYoutubeChannel(event: APIGatewayProxyEventV2) {
  const caller = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const body = parseJsonObject(event.body);
  const token = body.youtubeAccessToken;
  if (typeof token !== "string" || token.length === 0 || token.length > 4096) {
    badRequest("YouTubeアクセストークンを指定してください", "INVALID_YOUTUBE_TOKEN");
  }
  const user = await getUser(caller.niarimUserId);
  if (!user?.youtubeChannelId) {
    forbidden("最初にYouTubeへの投稿を行って連携してください", "CHANNEL_NOT_LINKED");
  }
  const todayJst = new Date(Date.now() + 9 * 3600_000)
    .toISOString().slice(0, 10);
  if (user.channelInfoManualUpdatedJstDay === todayJst) {
    throw new ApiError(429, "チャンネル情報の更新は日本時間で1日1回です", "CHANNEL_REFRESH_DAILY_LIMIT");
  }

  const info = await getOwnChannelInfo(token);
  if (!info || info.channelId !== user.youtubeChannelId) {
    forbidden("現在のYouTubeアカウントが連携先と一致しません", "CHANNEL_MISMATCH");
  }
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: Keys.user(caller.niarimUserId),
      ConditionExpression:
        "itemType = :userType AND youtubeChannelId = :channelId AND " +
        "(attribute_not_exists(channelInfoManualUpdatedJstDay) OR channelInfoManualUpdatedJstDay <> :day)",
      UpdateExpression:
        "SET channelName = :name, channelAvatarUrl = :avatar, " +
        "channelInfoCachedAt = :now, channelInfoManualUpdatedJstDay = :day",
      ExpressionAttributeValues: {
        ":userType": TABLE_ITEM_TYPE.User,
        ":channelId": info.channelId,
        ":name": info.channelName,
        ":avatar": info.channelAvatarUrl,
        ":now": new Date().toISOString(),
        ":day": todayJst,
      },
    }));
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) {
      conflict("本日はすでに更新済みか、連携先が変更されました", "CHANNEL_REFRESH_CONFLICT");
    }
    throw error;
  }
  return ok({
    channelName: info.channelName,
    channelAvatarUrl: info.channelAvatarUrl,
    lastRefreshedJstDay: todayJst,
  });
}
