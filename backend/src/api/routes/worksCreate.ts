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
import { toPublicWork } from "./_publicWork";

interface CreateWorkRequestBody {
  youtubeVideoId: string;
  youtubeAccessToken: string; // クライアントが保持するYouTube OAuthアクセストークン（6章）
  isShort: boolean; // 8.9節：投稿元プロジェクトのキャンバス縦横比から判定した結果
}

/**
 * `POST /works`（6章・12章・17章）。
 *
 * ① Google認証 → ② 連携済みチャンネルID確認 → ③④⑤ 投稿枠の原子的予約
 * （quota.ts） → ⑥ videoId所有者検証（videos.list） → ⑦ 冪等登録
 * （youtubeVideoId=workIdをキーにPutItemで作成/更新）という12.2節の
 * 手順どおりに実装する。
 *
 * 動画本体のアップロード自体（`videos.insert`）はこのLambdaを経由せず
 * クライアントがYouTubeへ直接行う（6章）。ここではアップロード
 * 完了後の登録依頼のみを扱う。
 */
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

  // ③④⑤ 投稿枠の原子的な予約（未満の場合のみ枠を確保。上限超過は409）。
  await reservePostQuota(auth.niarimUserId, user.membershipTier);

  try {
    // ⑥ videoId所有者検証（クライアントの自己申告を信用しない、6章）。
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

    // 23.2節：投稿時にチャンネル情報を再取得しキャッシュを最新化する。
    const channelInfo = await getOwnChannelInfo(body.youtubeAccessToken);
    if (channelInfo) {
      await cacheChannelInfo(auth.niarimUserId, {
        youtubeChannelId: channelInfo.channelId,
        channelName: channelInfo.channelName,
        channelAvatarUrl: channelInfo.channelAvatarUrl,
      });
    }

    // ⑦ 冪等登録（17章）：youtubeVideoId = workId をキーにPutItemする
    // ため、通信エラー等でクライアントが同じリクエストを再試行しても
    // 二重登録にならない。
    const now = new Date().toISOString();
    const isVisible = true; // 新規投稿は既定でNIARIM側も公開（13章）
    const rankingScore = computeRankingScore({
      viewCount: 0,
      likeCount: 0,
      commentCount: 0,
    });

    const work: WorkItem = {
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

    // 既に同じvideoIdで登録済みなら（冪等リトライ）上書きするだけで、
    // 二重登録にはならない。ただし他人のNIARIM User IDで既登録済みの
    // videoIdを奪う形の上書きは防ぐ（authorIdが一致する場合のみ許可）。
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
    // ⑥以降で失敗した場合は、⑤で確保した投稿枠を解放する（12.2節）。
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
  return {
    youtubeVideoId: body.youtubeVideoId,
    youtubeAccessToken: body.youtubeAccessToken,
    isShort: body.isShort ?? false,
  };
}
