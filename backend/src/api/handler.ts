import type { APIGatewayProxyEventV2, APIGatewayProxyStructuredResultV2 } from 'aws-lambda';
import { errorToResponse, json } from '../lib/response';
import { getRanking } from './routes/ranking';
import { getLatestWorks } from './routes/worksLatest';
import { getAuthorWorks } from './routes/userWorks';
import { createWork } from './routes/worksCreate';
import { updateWork } from './routes/worksUpdate';
import { deleteWork } from './routes/worksDelete';
import { updateTags } from './routes/tags';
import { createReport } from './routes/reports';
import { createBlock } from './routes/blocks';
import { toggleBookmark, getUserBookmarks, updateBookmarksVisibility } from './routes/bookmarks';
import { toggleRepost } from './routes/reposts';
import {
  toggleFollow,
  getFollowers,
  getFollowing,
  updateFollowVisibility,
} from './routes/follows';
import { getNotifications, markNotificationsRead } from './routes/notifications';

/**
 * 16章「1つのLambda内にAPIルーター（method + pathで振り分け）」。
 * Lambda Function URL（AuthType: NONE）から呼ばれるエントリポイント。
 *
 * ルートの追加は、下記のディスパッチテーブルへの1行追加で完結する。
 * パスパラメータ（`{id}`）は簡易的な正規表現マッチで抽出している
 * （API Gatewayを使わないためルーティングは自前実装。16章の設計判断
 * どおりAPI Gatewayの使用量プラン等は将来の追加候補に留める）。
 */

type Handler = (event: APIGatewayProxyEventV2, params: Record<string, string>) => Promise<APIGatewayProxyStructuredResultV2>;

interface Route {
  method: string;
  pattern: RegExp;
  paramNames: string[];
  handler: Handler;
}

function route(method: string, path: string, handler: Handler): Route {
  const paramNames: string[] = [];
  const patternSrc = path
    .split('/')
    .map((segment) => {
      if (segment.startsWith('{') && segment.endsWith('}')) {
        paramNames.push(segment.slice(1, -1));
        return '([^/]+)';
      }
      return segment.replace(/[.*+?^$()|[\]\\]/g, '\\$&');
    })
    .join('/');
  return { method, pattern: new RegExp(`^${patternSrc}$`), paramNames, handler };
}

const routes: Route[] = [
  // --- 読み取り系（匿名利用可、16章） ---
  route('GET', '/ranking/{period}', (e, p) => getRanking(e, p.period)),
  route('GET', '/works/latest', (e) => getLatestWorks(e)),
  route('GET', '/users/{id}/works', (e, p) => getAuthorWorks(e, p.id)),
  route('GET', '/users/{id}/bookmarks', (e, p) => getUserBookmarks(e, p.id)),
  route('GET', '/users/{id}/followers', (e, p) => getFollowers(e, p.id)),
  route('GET', '/users/{id}/following', (e, p) => getFollowing(e, p.id)),

  // --- 書き込み系（要ログイン。各ハンドラ内でauthenticate()を呼ぶ） ---
  route('POST', '/works', (e) => createWork(e)),
  route('PATCH', '/works/{id}', (e, p) => updateWork(e, p.id)),
  route('DELETE', '/works/{id}', (e, p) => deleteWork(e, p.id)),
  route('PATCH', '/works/{id}/tags', (e, p) => updateTags(e, p.id)),
  route('POST', '/reports', (e) => createReport(e)),
  route('POST', '/blocks', (e) => createBlock(e)),
  route('POST', '/works/{id}/bookmark', (e, p) => toggleBookmark(e, p.id)),
  route('PATCH', '/users/{id}/bookmarks-visibility', (e, p) => updateBookmarksVisibility(e, p.id)),
  route('POST', '/works/{id}/repost', (e, p) => toggleRepost(e, p.id)),
  route('POST', '/users/{id}/follow', (e, p) => toggleFollow(e, p.id)),
  route('PATCH', '/users/{id}/follow-visibility', (e, p) => updateFollowVisibility(e, p.id)),
  route('GET', '/users/{id}/notifications', (e, p) => getNotifications(e, p.id)),
  route('POST', '/users/{id}/notifications/mark-read', (e, p) => markNotificationsRead(e, p.id)),
];

export async function handler(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyStructuredResultV2> {
  try {
    const method = event.requestContext.http.method.toUpperCase();
    const path = normalizePath(event.requestContext.http.path);

    for (const r of routes) {
      if (r.method !== method) continue;
      const match = r.pattern.exec(path);
      if (!match) continue;
      const params: Record<string, string> = {};
      r.paramNames.forEach((name, i) => {
        params[name] = decodeURIComponent(match[i + 1]);
      });
      return await r.handler(event, params);
    }

    return json(404, { error: `該当するルートがありません: ${method} ${path}` });
  } catch (err) {
    return errorToResponse(err);
  }
}

function normalizePath(path: string): string {
  if (path.length > 1 && path.endsWith('/')) return path.slice(0, -1);
  return path;
}
