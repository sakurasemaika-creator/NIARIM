import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { TABLE_ITEM_TYPE, type WorkItem } from "../../lib/types";
import { ApiError, badRequest, notFound, ok } from "../../lib/response";

interface YoutubeCommentSnippet {
  authorDisplayName?: string;
  authorProfileImageUrl?: string;
  textDisplay?: string;
  publishedAt?: string;
}
interface YoutubeComment {
  id?: string;
  snippet?: YoutubeCommentSnippet;
}
interface YoutubeThread {
  id?: string;
  snippet?: { topLevelComment?: YoutubeComment; totalReplyCount?: number };
  replies?: { comments?: YoutubeComment[] };
}
function safeComment(comment: YoutubeComment) {
  const s = comment.snippet ?? {};
  return {
    id: String(comment.id ?? "").slice(0, 150),
    author: String(s.authorDisplayName ?? "").slice(0, 150),
    avatar: /^https:\/\//.test(s.authorProfileImageUrl ?? "")
      ? String(s.authorProfileImageUrl).slice(0, 500) : "",
    text: String(s.textDisplay ?? "").slice(0, 5000),
    publishedAt: String(s.publishedAt ?? "").slice(0, 50),
  };
}

/** User-triggered, read-only YouTube comments. No DynamoDB comment storage. */
export async function getYoutubeComments(event: APIGatewayProxyEventV2, workId: string) {
  if (!/^[A-Za-z0-9_-]{11}$/.test(workId)) notFound();
  const qp = event.queryStringParameters ?? {};
  const cursor = qp.cursor ?? "";
  if (cursor.length > 1024 || (cursor && !/^[A-Za-z0-9_\-=]+$/.test(cursor))) {
    badRequest("コメントのページ指定が不正です", "INVALID_COMMENT_CURSOR");
  }
  const workRes = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.work(workId),
  }));
  if (workRes.Item?.itemType !== TABLE_ITEM_TYPE.Work) notFound();
  const work = workRes.Item as WorkItem;
  if (!work.isNiarimPublished ||
      work.youtubePrivacyStatus === "private" ||
      work.youtubePrivacyStatus === "deleted") {
    notFound();
  }
  const key = process.env.YOUTUBE_API_KEY;
  if (!key || key === "REPLACE_ME") {
    throw new ApiError(503, "コメント機能を利用できません", "YOUTUBE_NOT_CONFIGURED");
  }
  const url = new URL("https://www.googleapis.com/youtube/v3/commentThreads");
  url.searchParams.set("part", "snippet,replies");
  url.searchParams.set("videoId", workId);
  url.searchParams.set("maxResults", "20");
  url.searchParams.set("textFormat", "plainText");
  url.searchParams.set("order", "time");
  url.searchParams.set("key", key);
  if (cursor) url.searchParams.set("pageToken", cursor);
  let response: Response;
  try {
    response = await fetch(url, { signal: AbortSignal.timeout(8000) });
  } catch {
    throw new ApiError(503, "コメントの読み込みに失敗しました", "COMMENT_READ_UNAVAILABLE");
  }
  if (!response.ok) {
    if (response.status === 403 || response.status === 404) {
      return ok({ comments: [], nextCursor: null, unavailable: true });
    }
    throw new ApiError(503, "コメントを取得できませんでした", "COMMENT_READ_UNAVAILABLE");
  }
  const body = await response.json() as {
    items?: YoutubeThread[]; nextPageToken?: string;
  };
  return ok({
    comments: (body.items ?? []).slice(0, 20).map((thread) => ({
      ...safeComment(thread.snippet?.topLevelComment ?? {}),
      replies: (thread.replies?.comments ?? []).slice(0, 5).map(safeComment),
      totalReplyCount: Math.max(0, Number(thread.snippet?.totalReplyCount ?? 0)),
    })),
    nextCursor: typeof body.nextPageToken === "string"
      ? body.nextPageToken : null,
    unavailable: false,
  });
}
