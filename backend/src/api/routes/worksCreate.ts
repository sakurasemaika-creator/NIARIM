import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { GetCommand, PutCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate, cacheChannelInfo, getUser } from "../../lib/auth";
import { reservePostQuota, releasePostQuota } from "../../lib/quota";
import {
  getVideoSnippet,
  getOwnChannelInfo,
  verifyVideoOwnership,
} from "../../lib/youtube";
import { computeRankingScore } from "../../lib/ranking";
import { badRequest, conflict, created, forbidden } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import type { WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";
import type { WorkWithProjectMetadata } from "../../lib/workProjectMetadata";
import { toPublicWork } from "./_publicWork";

interface CreateWorkRequestBody {
  youtubeVideoId: string;
  youtubeAccessToken: string;
  isShort?: boolean;
  projectFps?: number;
  projectFrameCount?: number;
  projectWorkSeconds?: number;
  projectCreatedAt?: string;
  projectCanvasWidth?: number;
  projectCanvasHeight?: number;
}

/** YouTube側の状態だけを見た公開可否。NIARIM側の公開設定とは別に扱う。 */
function isYoutubeVisible(status: WorkItem["youtubePrivacyStatus"]) {
  return status !== "private" && status !== "deleted";
}

export async function createWork(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );

  const body = parseBody(event.body);

  const user = await getUser(auth.niarimUserId);
  if (!user?.youtubeChannelId) {
    forbidden(
      "YouTubeチャンネルとの連携が完了していません（3章の連携フローを先に行ってください）",
    );
  }

  // workId = youtubeVideoId は冪等キー。同じ作者が同じ動画を再登録した場合は
  // 新規投稿として数えない。別作者の動画を上書きすることも許可しない。
  const existingResult = await ddb.send(
    new GetCommand({
      TableName: tableName(),
      Key: Keys.work(body.youtubeVideoId),
    }),
  );
  const existing = existingResult.Item as WorkWithProjectMetadata | undefined;
  if (existing && existing.authorId !== auth.niarimUserId) {
    conflict(
      "この動画は既に別のユーザーによってNIARIMへ登録されています",
      "VIDEO_ALREADY_REGISTERED",
    );
  }

  const isNewWork = existing == null;
  let quotaReserved = false;
  if (isNewWork) {
    await reservePostQuota(auth.niarimUserId, user.membershipTier);
    quotaReserved = true;
  }

  try {
    const snippet = await getVideoSnippet(
      body.youtubeVideoId,
      body.youtubeAccessToken,
    );
    if (!snippet) {
      badRequest("指定されたYouTube動画が見つかりません", "VIDEO_NOT_FOUND");
    }

    if (existing) {
      // 初回登録時に「投稿直後であること」まで検証済みの作品は、後日の
      // 通信再送・制作情報更新でも冪等に再登録できるよう、再登録時は
      // チャンネル所有者の一致だけを再確認する。15分制限を再適用すると、
      // 正規に登録済みの作品まで時間経過だけで更新不能になってしまう。
      if (snippet.channelId !== user.youtubeChannelId) {
        forbidden("この動画は連携済みチャンネルの投稿ではありません");
      }
    } else {
      const verification = verifyVideoOwnership(snippet, user.youtubeChannelId);
      if (!verification.ok) {
        forbidden(verification.reason);
      }
    }

    const channelInfo = await getOwnChannelInfo(body.youtubeAccessToken);
    if (channelInfo) {
      await cacheChannelInfo(auth.niarimUserId, {
        youtubeChannelId: channelInfo.channelId,
        channelName: channelInfo.channelName,
        channelAvatarUrl: channelInfo.channelAvatarUrl,
      });
    }

    const now = new Date().toISOString();

    if (existing) {
      // 再登録はPutで作品アイテム全体を書き戻さない。タグ・ロックタグ・
      // ブックマーク・リポスト・統計更新が同時に発生していても、それらの
      // 属性を古いGet結果で上書きしないよう、YouTube/制作メタデータだけを
      // UpdateExpressionで部分更新する。
      const values: Record<string, unknown> = {
        ":authorId": auth.niarimUserId,
        ":youtubeChannelId": snippet.channelId,
        ":title": snippet.title,
        ":youtubeUrl": `https://www.youtube.com/watch?v=${body.youtubeVideoId}`,
        ":thumbnailUrl": snippet.thumbnailUrl,
        ":privacy": snippet.privacyStatus,
      };
      const sets = [
        "youtubeChannelId = :youtubeChannelId",
        "title = :title",
        "youtubeUrl = :youtubeUrl",
        "thumbnailUrl = :thumbnailUrl",
        "youtubePrivacyStatus = :privacy",
      ];

      if (channelInfo) {
        values[":channelName"] = channelInfo.channelName;
        values[":channelAvatarUrl"] = channelInfo.channelAvatarUrl;
        values[":channelInfoCachedAt"] = now;
        sets.push(
          "channelName = :channelName",
          "channelAvatarUrl = :channelAvatarUrl",
          "channelInfoCachedAt = :channelInfoCachedAt",
        );
      }
      if (body.isShort !== undefined) {
        values[":isShort"] = body.isShort;
        sets.push("isShort = :isShort");
      }
      if (body.projectFps !== undefined) {
        values[":projectFps"] = body.projectFps;
        sets.push("projectFps = :projectFps");
      }
      if (body.projectFrameCount !== undefined) {
        values[":projectFrameCount"] = body.projectFrameCount;
        sets.push("projectFrameCount = :projectFrameCount");
      }
      if (body.projectWorkSeconds !== undefined) {
        values[":projectWorkSeconds"] = body.projectWorkSeconds;
        sets.push("projectWorkSeconds = :projectWorkSeconds");
      }
      if (body.projectCreatedAt !== undefined) {
        values[":projectCreatedAt"] = body.projectCreatedAt;
        sets.push("projectCreatedAt = :projectCreatedAt");
      }
      if (body.projectCanvasWidth !== undefined) {
        values[":projectCanvasWidth"] = body.projectCanvasWidth;
        sets.push("projectCanvasWidth = :projectCanvasWidth");
      }
      if (body.projectCanvasHeight !== undefined) {
        values[":projectCanvasHeight"] = body.projectCanvasHeight;
        sets.push("projectCanvasHeight = :projectCanvasHeight");
      }

      // 公開→公開の再登録ではランキング/GSIを触らない。統計更新バッチが
      // 同時に走っていても、再登録前のGetで得た古いスコアへ巻き戻さないため。
      // 非公開化では必ずGSIを除去し、公開復帰時（または不完全な旧データで
      // インデックスが欠けている場合）だけ現在スナップショットから復元する。
      const visible =
        existing.isNiarimPublished && isYoutubeVisible(snippet.privacyStatus);
      const hasPublicIndexes =
        existing.gsi1pk != null &&
        existing.gsi1sk != null &&
        existing.gsi2pk != null &&
        existing.gsi2sk != null &&
        existing.gsi3pk != null &&
        existing.gsi3sk != null &&
        existing.gsi4pk != null &&
        existing.gsi4sk != null;
      const removes: string[] = [];
      if (visible && !hasPublicIndexes) {
        const score = computeRankingScore({
          viewCount: existing.viewCount,
          likeCount: existing.likeCount,
          commentCount: existing.commentCount,
        });
        values[":rankingPk"] = "RANKING#ALL";
        values[":rankingScore"] = score;
        values[":bookmarkPk"] = "BOOKMARK_RANKING";
        values[":bookmarkScore"] = existing.bookmarkCount;
        values[":authorPk"] = `AUTHOR#${auth.niarimUserId}`;
        values[":postedAt"] = existing.postedAt;
        values[":latestPk"] = "LATEST";
        sets.push(
          "rankingScore = :rankingScore",
          "bookmarkScore = :bookmarkScore",
          "gsi1pk = :rankingPk",
          "gsi1sk = :rankingScore",
          "gsi2pk = :bookmarkPk",
          "gsi2sk = :bookmarkScore",
          "gsi3pk = :authorPk",
          "gsi3sk = :postedAt",
          "gsi4pk = :latestPk",
          "gsi4sk = :postedAt",
        );
      } else if (!visible) {
        removes.push(
          "rankingScore",
          "bookmarkScore",
          "gsi1pk",
          "gsi1sk",
          "gsi2pk",
          "gsi2sk",
          "gsi3pk",
          "gsi3sk",
          "gsi4pk",
          "gsi4sk",
        );
      }

      try {
        const result = await ddb.send(
          new UpdateCommand({
            TableName: tableName(),
            Key: Keys.work(body.youtubeVideoId),
            UpdateExpression: `SET ${sets.join(", ")}${
              removes.length > 0 ? ` REMOVE ${removes.join(", ")}` : ""
            }`,
            ConditionExpression: "authorId = :authorId",
            ExpressionAttributeValues: values,
            ReturnValues: "ALL_NEW",
          }),
        );
        return created({
          work: toPublicWork(result.Attributes as WorkWithProjectMetadata),
        });
      } catch (error) {
        if (error instanceof ConditionalCheckFailedException) {
          conflict(
            "作品の所有者情報が変更されています。作品一覧を更新してもう一度お試しください",
            "VIDEO_REGISTRATION_CONFLICT",
          );
        }
        throw error;
      }
    }

    const isVisible = isYoutubeVisible(snippet.privacyStatus);
    const rankingScore = computeRankingScore({
      viewCount: 0,
      likeCount: 0,
      commentCount: 0,
    });

    const work: WorkWithProjectMetadata = {
      itemType: TABLE_ITEM_TYPE.Work,
      ...Keys.work(body.youtubeVideoId),
      workId: body.youtubeVideoId,
      authorId: auth.niarimUserId,
      youtubeChannelId: snippet.channelId,
      youtubeVideoId: body.youtubeVideoId,
      channelName: channelInfo?.channelName ?? user.channelName ?? "",
      channelAvatarUrl:
        channelInfo?.channelAvatarUrl ?? user.channelAvatarUrl ?? "",
      channelInfoCachedAt: now,
      title: snippet.title,
      postedAt: now,
      youtubeUrl: `https://www.youtube.com/watch?v=${body.youtubeVideoId}`,
      thumbnailUrl: snippet.thumbnailUrl,
      viewCount: 0,
      likeCount: 0,
      commentCount: 0,
      lastFetchedAt: now,
      rankingScore: isVisible ? rankingScore : undefined,
      bookmarkCount: 0,
      bookmarkScore: isVisible ? 0 : undefined,
      repostCount: 0,
      isNiarimPublished: true,
      youtubePrivacyStatus: snippet.privacyStatus,
      isShort: body.isShort ?? false,
      tags: [],
      lockedTags: [],
      createdAt: now,
      projectFps: body.projectFps,
      projectFrameCount: body.projectFrameCount,
      projectWorkSeconds: body.projectWorkSeconds,
      projectCreatedAt: body.projectCreatedAt,
      projectCanvasWidth: body.projectCanvasWidth,
      projectCanvasHeight: body.projectCanvasHeight,
      gsi1pk: isVisible ? "RANKING#ALL" : undefined,
      gsi1sk: isVisible ? rankingScore : undefined,
      gsi2pk: isVisible ? "BOOKMARK_RANKING" : undefined,
      gsi2sk: isVisible ? 0 : undefined,
      gsi3pk: isVisible ? `AUTHOR#${auth.niarimUserId}` : undefined,
      gsi3sk: isVisible ? now : undefined,
      gsi3AllPk: `AUTHOR#${auth.niarimUserId}`,
      gsi3AllSk: now,
      gsi4pk: isVisible ? "LATEST" : undefined,
      gsi4sk: isVisible ? now : undefined,
    };

    try {
      await ddb.send(
        new PutCommand({
          TableName: tableName(),
          Item: work,
          ConditionExpression: "attribute_not_exists(pk)",
        }),
      );
    } catch (error) {
      if (error instanceof ConditionalCheckFailedException) {
        conflict(
          "この動画は同時に登録処理されています。作品一覧を更新してもう一度お試しください",
          "VIDEO_REGISTRATION_CONFLICT",
        );
      }
      throw error;
    }

    return created({ work: toPublicWork(work) });
  } catch (err) {
    if (quotaReserved) {
      await releasePostQuota(auth.niarimUserId).catch(() => {});
    }
    throw err;
  }
}

function parseBody(raw: string | undefined): CreateWorkRequestBody {
  const body = parseJsonObject(raw);
  if (
    typeof body.youtubeVideoId !== "string" ||
    !/^[A-Za-z0-9_-]{11}$/.test(body.youtubeVideoId)
  ) {
    badRequest("youtubeVideoIdの形式が不正です");
  }
  if (
    typeof body.youtubeAccessToken !== "string" ||
    body.youtubeAccessToken.length === 0 ||
    body.youtubeAccessToken.length > 4096
  ) {
    badRequest("youtubeAccessTokenは必須です");
  }
  if (body.isShort !== undefined && typeof body.isShort !== "boolean") {
    badRequest("isShortは真偽値である必要があります");
  }

  const projectFps = optionalNonNegativeInt(body.projectFps, "projectFps", 240);
  const projectFrameCount = optionalNonNegativeInt(
    body.projectFrameCount,
    "projectFrameCount",
    10_000_000,
  );
  const projectWorkSeconds = optionalNonNegativeInt(
    body.projectWorkSeconds,
    "projectWorkSeconds",
    1_000_000_000,
  );
  const projectCanvasWidth = optionalNonNegativeInt(
    body.projectCanvasWidth,
    "projectCanvasWidth",
    100_000,
  );
  const projectCanvasHeight = optionalNonNegativeInt(
    body.projectCanvasHeight,
    "projectCanvasHeight",
    100_000,
  );

  let projectCreatedAt: string | undefined;
  if (body.projectCreatedAt !== undefined) {
    if (
      typeof body.projectCreatedAt !== "string" ||
      body.projectCreatedAt.length > 64 ||
      Number.isNaN(Date.parse(body.projectCreatedAt))
    ) {
      badRequest("projectCreatedAtの形式が不正です");
    }
    projectCreatedAt = new Date(body.projectCreatedAt).toISOString();
  }

  return {
    youtubeVideoId: body.youtubeVideoId,
    youtubeAccessToken: body.youtubeAccessToken,
    isShort: body.isShort,
    projectFps,
    projectFrameCount,
    projectWorkSeconds,
    projectCreatedAt,
    projectCanvasWidth,
    projectCanvasHeight,
  };
}

function optionalNonNegativeInt(
  value: unknown,
  fieldName: string,
  max: number,
): number | undefined {
  if (value === undefined) return undefined;
  if (
    typeof value !== "number" ||
    !Number.isSafeInteger(value) ||
    value < 0 ||
    value > max
  ) {
    badRequest(`${fieldName}の値が不正です`);
  }
  return value;
}
