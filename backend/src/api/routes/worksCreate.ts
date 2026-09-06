import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
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
  isShort: boolean;
  projectFps?: number;
  projectFrameCount?: number;
  projectWorkSeconds?: number;
  projectCreatedAt?: string;
  projectCanvasWidth?: number;
  projectCanvasHeight?: number;
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

  await reservePostQuota(auth.niarimUserId, user.membershipTier);

  try {
    const snippet = await getVideoSnippet(
      body.youtubeVideoId,
      body.youtubeAccessToken,
    );
    if (!snippet) {
      badRequest("指定されたYouTube動画が見つかりません", "VIDEO_NOT_FOUND");
    }
    const verification = verifyVideoOwnership(snippet, user.youtubeChannelId);
    if (!verification.ok) {
      forbidden(verification.reason);
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
    const isVisible = true;
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
      isShort: body.isShort,
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

    const existing = await ddb.send(
      new GetCommand({
        TableName: tableName(),
        Key: Keys.work(body.youtubeVideoId),
      }),
    );
    if (
      existing.Item &&
      (existing.Item as WorkItem).authorId !== auth.niarimUserId
    ) {
      conflict(
        "この動画は既に別のユーザーによってNIARIMへ登録されています",
        "VIDEO_ALREADY_REGISTERED",
      );
    }

    await ddb.send(new PutCommand({ TableName: tableName(), Item: work }));

    return created({ work: toPublicWork(work) });
  } catch (err) {
    await releasePostQuota(auth.niarimUserId).catch(() => {});
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
    isShort: body.isShort ?? false,
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
