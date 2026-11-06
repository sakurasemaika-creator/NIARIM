import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate, cacheChannelInfo, getUser } from "../../lib/auth";
import { reservePostQuota, releasePostQuota } from "../../lib/quota";
import {
  getVideoSnippet,
  getOwnChannelInfo,
  verifyVideoOwnership,
} from "../../lib/youtube";
import { badRequest, conflict, created, forbidden } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import type { WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";
import type { WorkWithProjectMetadata } from "../../lib/workProjectMetadata";
import { toPublicWork } from "./_publicWork";
import { recordMissionAchievement } from "../../lib/missionNotifications";

interface CreateWorkRequestBody {
  youtubeVideoId: string;
  youtubeAccessToken: string;
  scheduledPublishAt?: string;
  title?: string;
  description?: string;
  isShort?: boolean;
  isNiarimPublished?: boolean;
  containsGenerativeAiImageOrVideo?: boolean;
  projectFps?: number;
  projectFrameCount?: number;
  projectWorkSeconds?: number;
  projectCreatedAt?: string;
  projectCanvasWidth?: number;
  projectCanvasHeight?: number;
}

function isYoutubeVisible(status: WorkItem["youtubePrivacyStatus"]) {
  return status !== "private" && status !== "deleted";
}

export async function createWork(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const body = parseBody(event.body);

  // YouTube's returned video id is the NIARIM work id / idempotency key.
  // Resolve an existing item before making any YouTube calls so a client that lost
  // the first POST response can safely retry without re-validating or consuming quota.
  // Use a strongly consistent read: an eventually consistent miss immediately after
  // a successful first POST would otherwise send the retry through YouTube/quota work
  // again and can turn a harmless lost response into a misleading conflict.
  const existingResult = await ddb.send(
    new GetCommand({
      TableName: tableName(),
      Key: Keys.work(body.youtubeVideoId),
      ConsistentRead: true,
    }),
  );
  const existingRaw = existingResult.Item;
  if (existingRaw?.itemType === "WORK_TOMBSTONE") {
    conflict(
      "この動画はNIARIMから削除済みのため再登録できません",
      "WORK_DELETED",
    );
  }
  if (existingRaw && existingRaw.itemType !== TABLE_ITEM_TYPE.Work) {
    conflict(
      "この動画IDは既に別のデータで使用されています",
      "VIDEO_REGISTRATION_CONFLICT",
    );
  }
  const existing = existingRaw as WorkWithProjectMetadata | undefined;
  if (existing) {
    if (existing.authorId !== auth.niarimUserId) {
      conflict(
        "この動画は既に別のユーザーによってNIARIMへ登録されています",
        "VIDEO_ALREADY_REGISTERED",
      );
    }
    await saveDescriptionOnce(body.youtubeVideoId, auth.niarimUserId, body.description);
    return created({ work: toPublicWork(existing) });
  }

  const user = await getUser(auth.niarimUserId);
  if (!user) forbidden("NIARIMユーザー情報を取得できませんでした");

  let quotaReserved = false;
  try {
    // First post resolves the channel name/avatar once. Later posts reuse the
    // cached channel ID and verify new video ownership via videos.list, avoiding
    // one redundant channels.list unit for each additional upload.
    // Explicit manual profile refresh will be a separate, rate-limited action.
    const channelInfo = user.youtubeChannelId
      ? null
      : await getOwnChannelInfo(body.youtubeAccessToken);
    const linkedChannelId = user.youtubeChannelId ?? channelInfo?.channelId;
    if (!linkedChannelId) {
      forbidden(
        "YouTubeチャンネル情報を取得できませんでした。YouTube投稿権限を確認してください",
      );
    }
    if (
      user.youtubeChannelId &&
      channelInfo?.channelId &&
      user.youtubeChannelId !== channelInfo.channelId
    ) {
      forbidden(
        "Googleアカウントと連携済みYouTubeチャンネルが一致しません。アカウントを切り替えてください",
      );
    }

    const snippet = await getVideoSnippet(
      body.youtubeVideoId,
      body.youtubeAccessToken,
    );
    if (!snippet) {
      badRequest("指定されたYouTube動画が見つかりません", "VIDEO_NOT_FOUND");
    }

    const verification = verifyVideoOwnership(snippet, linkedChannelId);
    if (!verification.ok) forbidden(verification.reason);

    // A private video is only scheduled if YouTube confirms publishAt.
    // Never expose a fabricated client-supplied release date as fact.
    const youtubeSchedule = snippet.publishAt;
    if (body.scheduledPublishAt &&
        (snippet.privacyStatus !== "private" ||
         !youtubeSchedule ||
         Math.abs(Date.parse(youtubeSchedule) -
                  Date.parse(body.scheduledPublishAt)) > 1000)) {
      badRequest("YouTube側の予約公開日時が一致しません", "SCHEDULE_MISMATCH");
    }
    const scheduledPublishAt = youtubeSchedule &&
      snippet.privacyStatus === "private"
      ? new Date(youtubeSchedule).toISOString() : undefined;

    await reservePostQuota(auth.niarimUserId, user.membershipTier);
    quotaReserved = true;

    if (channelInfo) {
      await cacheChannelInfo(auth.niarimUserId, {
        youtubeChannelId: channelInfo.channelId,
        channelName: channelInfo.channelName,
        channelAvatarUrl: channelInfo.channelAvatarUrl,
      });
    }

    const now = new Date().toISOString();
    const isNiarimPublished = body.isNiarimPublished ?? true;
    const isVisible =
      isNiarimPublished && isYoutubeVisible(snippet.privacyStatus);
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
      title: body.title ?? snippet.title,
      postedAt: now,
      youtubeUrl: `https://www.youtube.com/watch?v=${body.youtubeVideoId}`,
      thumbnailUrl: snippet.thumbnailUrl,
      viewCount: 0,
      likeCount: 0,
      commentCount: 0,
      lastFetchedAt: now,
      bookmarkCount: 0,
      bookmarkScore: isVisible ? 0 : undefined,
      repostCount: 0,
      isNiarimPublished,
      youtubePrivacyStatus: snippet.privacyStatus,
      scheduledPublishAt,
      isShort: body.isShort ?? false,
      containsGenerativeAiImageOrVideo:
        body.containsGenerativeAiImageOrVideo ?? false,
      tags: [],
      lockedTags: [],
      createdAt: now,
      projectFps: body.projectFps,
      projectFrameCount: body.projectFrameCount,
      projectWorkSeconds: body.projectWorkSeconds,
      projectCreatedAt: body.projectCreatedAt,
      projectCanvasWidth: body.projectCanvasWidth,
      projectCanvasHeight: body.projectCanvasHeight,
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
        // Another request may have completed between our initial read and conditional
        // put. Re-read strongly and treat the same author's winning write exactly like
        // any other idempotent retry instead of surfacing a false conflict. The losing
        // request already reserved quota, so release only that reservation before
        // returning the canonical stored work.
        const racedResult = await ddb.send(
          new GetCommand({
            TableName: tableName(),
            Key: Keys.work(body.youtubeVideoId),
            ConsistentRead: true,
          }),
        );
        const racedRaw = racedResult.Item;
        if (racedRaw?.itemType === TABLE_ITEM_TYPE.Work) {
          const racedWork = racedRaw as WorkWithProjectMetadata;
          if (racedWork.authorId === auth.niarimUserId) {
            await releasePostQuota(auth.niarimUserId);
            quotaReserved = false;
            await saveDescriptionOnce(body.youtubeVideoId, auth.niarimUserId, body.description);
            return created({ work: toPublicWork(racedWork) });
          }
          conflict(
            "この動画は既に別のユーザーによってNIARIMへ登録されています",
            "VIDEO_ALREADY_REGISTERED",
          );
        }
        if (racedRaw?.itemType === "WORK_TOMBSTONE") {
          conflict(
            "この動画はNIARIMから削除済みのため再登録できません",
            "WORK_DELETED",
          );
        }
        conflict(
          "この動画IDは同時に別の登録処理で使用されました。作品一覧を更新してもう一度お試しください",
          "VIDEO_REGISTRATION_CONFLICT",
        );
      }
      throw error;
    }

    // Work row is now committed; a detail write failure must not undo quota.
    quotaReserved = false;
    await saveDescriptionOnce(body.youtubeVideoId, auth.niarimUserId, body.description);
    if (isVisible) {
      // The publication operation already committed. A notification failure
      // MUST NOT roll back the work or release the user's posting quota.
      try {
        await recordMissionAchievement(auth.niarimUserId, {
          kind: "workPublished", missionId: "work_posted",
          workId: work.workId, workTitle: work.title,
          required: 0, occurredAt: work.postedAt,
        });
      } catch (noticeError) {
        console.warn("Mission publication notice could not be recorded",
          noticeError);
      }
    }
    return created({ work: toPublicWork(work) });
  } catch (err) {
    if (quotaReserved) {
      await releasePostQuota(auth.niarimUserId).catch(() => {});
    }
    throw err;
  }
}

/**
 * A separate non-GSI detail record keeps descriptions out of seven ALL-projected
 * indexes. On a lost response an idempotent POST retries just this missing item.
 */
async function saveDescriptionOnce(workId: string, authorId: string, description?: string) {
  if (!description) return;
  try {
    await ddb.send(new PutCommand({
      TableName: tableName(),
      Item: {
        ...Keys.workDetail(workId), itemType: "WORK_DETAIL",
        authorId, description, updatedAt: new Date().toISOString(),
      },
      ConditionExpression: "attribute_not_exists(pk)",
    }));
  } catch (error) {
    if (!(error instanceof ConditionalCheckFailedException)) throw error;
  }
}

function parseBody(raw: string | undefined): CreateWorkRequestBody {
  const body = parseJsonObject(raw);
  if (body.title !== undefined &&
      (typeof body.title !== "string" ||
       !body.title.trim() || body.title.trim().length > 100)) {
    badRequest("作品タイトルは1〜100文字で入力してください", "INVALID_TITLE");
  }
  if (body.description !== undefined &&
      (typeof body.description !== "string" || body.description.length > 2000)) {
    badRequest("概要欄は2000文字以内で入力してください", "INVALID_DESCRIPTION");
  }
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
  if (body.scheduledPublishAt !== undefined) {
    if (typeof body.scheduledPublishAt !== "string" ||
        !/\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}/.test(body.scheduledPublishAt) ||
        !Number.isFinite(Date.parse(body.scheduledPublishAt)) ||
        Date.parse(body.scheduledPublishAt) <= Date.now() + 60_000) {
      badRequest("予約公開日時は1分以上先の有効なISO日時にしてください", "INVALID_SCHEDULE");
    }
  }
  if (body.isShort !== undefined && typeof body.isShort !== "boolean") {
    badRequest("isShortは真偽値である必要があります");
  }
  if (
    body.containsGenerativeAiImageOrVideo !== undefined &&
    typeof body.containsGenerativeAiImageOrVideo !== "boolean"
  ) {
    badRequest("containsGenerativeAiImageOrVideoは真偽値である必要があります");
  }
  if (
    body.isNiarimPublished !== undefined &&
    typeof body.isNiarimPublished !== "boolean"
  ) {
    badRequest("isNiarimPublishedは真偽値である必要があります");
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
    scheduledPublishAt: body.scheduledPublishAt as string | undefined,
    title: typeof body.title === "string" ? body.title.trim() : undefined,
    description: typeof body.description === "string" ? body.description.trim() : undefined,
    isShort: body.isShort,
    isNiarimPublished: body.isNiarimPublished,
    containsGenerativeAiImageOrVideo:
      body.containsGenerativeAiImageOrVideo as boolean | undefined,
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
