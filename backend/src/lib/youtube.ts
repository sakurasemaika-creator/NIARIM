/**
 * YouTube Data API v3 ラッパー（10章のクォータ表に対応する3メソッド＋
 * 23章のchannels.list＋動画削除用のvideos.delete）。
 *
 * このLambdaはユーザーの代わりに動画をアップロードしない（6章のとおり
 * `videos.insert`はアプリからYouTubeへ直接行う）。ここで呼ぶのは
 * 読み取り系（list/batchGetStats）と、ユーザー自身の希望による
 * `videos.delete`のみ。いずれもユーザーのOAuthアクセストークンを
 * そのまま使う（サーバー側に秘匿のAPIキーは持たない。動画の所有者本人
 * にしかできない操作のため、サービスアカウント等は不要）。
 *
 * 【要確認】`videos.batchGetStats`は本仕様書10章に「2026年6月3日追加」と
 * 記録している比較的新しいエンドポイントである。デプロイ前に必ず
 * Google公式ドキュメント（https://developers.google.com/youtube/v3/docs）
 * でリクエスト形式・レスポンス形式を最新版に照らして確認すること
 * （本ファイルのURL・パラメータ名は仕様書の記述に基づく best-effort の
 * 実装であり、実際のAPI呼び出しで検証していない）。
 */

const API_BASE = "https://www.googleapis.com/youtube/v3";

export interface YoutubeVideoSnippet {
  id: string;
  channelId: string;
  publishedAt: string; // ISO8601
  title: string;
  thumbnailUrl: string;
  privacyStatus: "public" | "unlisted" | "private";
}

export interface YoutubeVideoStats {
  id: string;
  viewCount: number;
  likeCount: number;
  commentCount: number;
  privacyStatus: "public" | "unlisted" | "private";
}

async function callYoutubeApi<T>(
  path: string,
  params: Record<string, string>,
  accessToken: string,
): Promise<T> {
  const url = new URL(`${API_BASE}/${path}`);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(
      `YouTube API呼び出しに失敗しました（${path}, status=${res.status}）: ${body}`,
    );
  }
  return (await res.json()) as T;
}

/**
 * `videos.list`（6章のvideoId所有者検証・13章の状態確認で使用）。
 * `part=snippet,status`。クォータ消費は通常枠で軽微（10章）。
 */
export async function getVideoSnippet(
  videoId: string,
  accessToken: string,
): Promise<YoutubeVideoSnippet | null> {
  const data = await callYoutubeApi<{
    items: Array<{
      id: string;
      snippet: {
        channelId: string;
        publishedAt: string;
        title: string;
        thumbnails: { high?: { url: string }; default: { url: string } };
      };
      status: { privacyStatus: "public" | "unlisted" | "private" };
    }>;
  }>("videos", { part: "snippet,status", id: videoId }, accessToken);

  const item = data.items[0];
  if (!item) return null;
  return {
    id: item.id,
    channelId: item.snippet.channelId,
    publishedAt: item.snippet.publishedAt,
    title: item.snippet.title,
    thumbnailUrl:
      item.snippet.thumbnails.high?.url ?? item.snippet.thumbnails.default.url,
    privacyStatus: item.status.privacyStatus,
  };
}

/**
 * `videos.batchGetStats`（8.1節の統計更新バッチで使用。専用バケット
 * 10,000ユニット/日、10章）。一度に最大50件程度まとめて取得する想定
 * （実際の上限は公式ドキュメントで確認すること。取得できなかった動画は
 * 削除済みとみなす）。
 *
 * サーバー側の統計更新バッチはAPIキー（アプリ用のプロジェクトAPIキー）
 * を使う想定とし、個々の投稿者のOAuthトークンには依存しない
 * （投稿者が後からアプリを削除・トークン失効しても統計取得を継続する
 * ため）。
 */
export async function batchGetVideoStats(
  videoIds: string[],
  apiKey: string,
): Promise<Map<string, YoutubeVideoStats>> {
  if (videoIds.length === 0) return new Map();

  const url = new URL(`${API_BASE}/videos/batchGetStats`);
  url.searchParams.set("id", videoIds.join(","));
  url.searchParams.set("key", apiKey);

  const res = await fetch(url);
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(
      `videos.batchGetStats呼び出しに失敗しました（status=${res.status}）: ${body}`,
    );
  }
  const data = (await res.json()) as {
    items: Array<{
      id: string;
      statistics: {
        viewCount: string;
        likeCount?: string;
        commentCount?: string;
      };
      status?: { privacyStatus: "public" | "unlisted" | "private" };
    }>;
  };

  const result = new Map<string, YoutubeVideoStats>();
  for (const item of data.items) {
    result.set(item.id, {
      id: item.id,
      viewCount: Number(item.statistics.viewCount ?? 0),
      likeCount: Number(item.statistics.likeCount ?? 0),
      commentCount: Number(item.statistics.commentCount ?? 0),
      privacyStatus: item.status?.privacyStatus ?? "public",
    });
  }
  return result;
}

/** `videos.delete`（13章：ユーザーが希望した場合のYouTube側削除）。 */
export async function deleteVideo(
  videoId: string,
  accessToken: string,
): Promise<void> {
  const url = new URL(`${API_BASE}/videos`);
  url.searchParams.set("id", videoId);
  const res = await fetch(url, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok && res.status !== 404) {
    const body = await res.text().catch(() => "");
    throw new Error(
      `videos.deleteに失敗しました（status=${res.status}）: ${body}`,
    );
  }
}

export interface YoutubeChannelInfo {
  channelId: string;
  channelName: string;
  channelAvatarUrl: string;
}

/**
 * `channels.list`（23章：公開プロフィール用のチャンネル名・アイコン
 * 取得。連携時・投稿時にのみ呼び、結果をUserItemへキャッシュする。
 * 23.2節のとおり閲覧のたびには呼ばない）。
 */
export async function getOwnChannelInfo(
  accessToken: string,
): Promise<YoutubeChannelInfo | null> {
  const data = await callYoutubeApi<{
    items: Array<{
      id: string;
      snippet: { title: string; thumbnails: { default: { url: string } } };
    }>;
  }>("channels", { part: "snippet", mine: "true" }, accessToken);

  const item = data.items[0];
  if (!item) return null;
  return {
    channelId: item.id,
    channelName: item.snippet.title,
    channelAvatarUrl: item.snippet.thumbnails.default.url,
  };
}

/**
 * 6章のvideoId検証：`snippet.channelId`が連携済みチャンネルIDと一致し、
 * `snippet.publishedAt`が直近（既定15分以内）であることを確認する。
 */
export function verifyVideoOwnership(
  snippet: YoutubeVideoSnippet,
  expectedChannelId: string,
  now: Date = new Date(),
  maxAgeMinutes = 15,
): { ok: true } | { ok: false; reason: string } {
  if (snippet.channelId !== expectedChannelId) {
    return {
      ok: false,
      reason: "この動画は連携済みチャンネルの投稿ではありません",
    };
  }
  const publishedAt = new Date(snippet.publishedAt).getTime();
  const ageMs = now.getTime() - publishedAt;
  if (
    Number.isNaN(publishedAt) ||
    ageMs < 0 ||
    ageMs > maxAgeMinutes * 60 * 1000
  ) {
    return {
      ok: false,
      reason:
        "投稿直後の動画ではないため登録できません（過去動画の使い回し防止）",
    };
  }
  return { ok: true };
}
