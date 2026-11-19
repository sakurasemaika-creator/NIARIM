import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { TABLE_ITEM_TYPE, type WorkItem } from "../../lib/types";
import { ApiError, badRequest, notFound, ok } from "../../lib/response";

// Best-effort 45s cache per warm Lambda instance; no DynamoDB storage.
// This is not a quota guarantee across cold starts or multiple instances.
const defaultPageSize = 20;
const expandedPageSize = 100;
const maxCacheBytes = 8 * 1024 * 1024;
let cacheBytes = 0;
const commentCache = new Map<string, {
  expiryMs: number;
  bytes: number;
  payload: { comments: unknown[]; nextCursor: string | null; unavailable: boolean };
}>();

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
  const pageSize = qp.limit === String(expandedPageSize)
    ? expandedPageSize : defaultPageSize;
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
  const cacheKey = `${workId}:${pageSize}:${cursor}`;
  const cached = commentCache.get(cacheKey);
  if (cached) {
    if (cached.expiryMs > Date.now()) return ok(cached.payload);
    cacheBytes -= cached.bytes;
    commentCache.delete(cacheKey);
  }
  const key = process.env.YOUTUBE_API_KEY;
  if (!key || key === "REPLACE_ME") {
    throw new ApiError(503, "コメント機能を利用できません", "YOUTUBE_NOT_CONFIGURED");
  }
  const url = new URL("https://www.googleapis.com/youtube/v3/commentThreads");
  url.searchParams.set("part", "snippet,replies");
  url.searchParams.set("videoId", workId);
  url.searchParams.set("maxResults", String(pageSize));
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
  const comments = (body.items ?? []).slice(0, pageSize).map((thread) => ({
    ...safeComment(thread.snippet?.topLevelComment ?? {}),
    replies: [] as ReturnType<typeof safeComment>[],
    totalReplyCount: Math.max(0, Number(thread.snippet?.totalReplyCount ?? 0)),
  }));
  // Give primary comments priority. Bound the additional preview replies so
  // a full page fits the buffered Function URL response even for long threads.
  let remainingReplyBytes = 1024 * 1024;
  for (const [i, comment] of comments.entries()) {
    const replies = body.items?.[i]?.replies?.comments ?? [];
    for (const raw of replies.slice(0, 5)) {
      const reply = safeComment(raw);
      const bytes = Buffer.byteLength(JSON.stringify(reply)) + 1;
      if (bytes > remainingReplyBytes) break;
      comment.replies.push(reply);
      remainingReplyBytes -= bytes;
    }
  }
  const payload = {
    comments,
    nextCursor: typeof body.nextPageToken === "string"
      ? body.nextPageToken : null,
    unavailable: false,
  };
  // Bound memory and expire quickly so deleted/edited comments are refreshed.
  const bytes = Buffer.byteLength(JSON.stringify(payload));
  if (commentCache.size >= 200 || cacheBytes + bytes > maxCacheBytes) {
    commentCache.clear();
    cacheBytes = 0;
  }
  // Another invocation may have filled this cache key during the fetch.
  cacheBytes -= commentCache.get(cacheKey)?.bytes ?? 0;
  commentCache.set(cacheKey, { expiryMs: Date.now() + 45_000, bytes, payload });
  cacheBytes += bytes;
  return ok(payload);
}
