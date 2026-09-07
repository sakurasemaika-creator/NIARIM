import type {
  APIGatewayProxyEventV2,
  APIGatewayProxyStructuredResultV2,
} from "aws-lambda";
import {
  badRequest,
  errorToResponse,
  json,
  payloadTooLarge,
} from "../lib/response";
import { getRanking } from "./routes/ranking";
import { getLatestWorks } from "./routes/worksLatest";
import { getAuthorWorks, getMyWorks } from "./routes/userWorks";
import { createWork } from "./routes/worksCreate";
import { updateWork } from "./routes/worksUpdate";
import { deleteWork } from "./routes/worksDelete";
import { updateTags } from "./routes/tags";
import { createReport } from "./routes/reports";
import { createBlock } from "./routes/blocks";
import {
  toggleBookmark,
  getUserBookmarks,
  getWorkBookmarkers,
  updateBookmarksVisibility,
} from "./routes/bookmarks";
import { toggleRepost } from "./routes/reposts";
import {
  toggleFollow,
  getFollowers,
  getFollowing,
  updateFollowVisibility,
} from "./routes/follows";
import {
  getNotifications,
  markNotificationsRead,
  putPushToken,
} from "./routes/notifications";

type Handler = (
  event: APIGatewayProxyEventV2,
  params: Record<string, string>,
) => Promise<APIGatewayProxyStructuredResultV2>;

interface Route {
  method: string;
  pattern: RegExp;
  paramNames: string[];
  handler: Handler;
}

const MAX_REQUEST_BODY_BYTES = 64 * 1024;
const MAX_REQUEST_PATH_CHARS = 2048;
const MAX_PATH_PARAMETER_CHARS = 256;

function route(method: string, path: string, handler: Handler): Route {
  const paramNames: string[] = [];
  const patternSrc = path
    .split("/")
    .map((segment) => {
      if (segment.startsWith("{") && segment.endsWith("}")) {
        paramNames.push(segment.slice(1, -1));
        return "([^/]+)";
      }
      return segment.replace(/[.*+?^$()|[\]\\]/g, "\\$&");
    })
    .join("/");
  return {
    method,
    pattern: new RegExp(`^${patternSrc}$`),
    paramNames,
    handler,
  };
}

const routes: Route[] = [
  // Public/optionally authenticated reads.
  route("GET", "/ranking/{period}", (e, p) => getRanking(e, p.period)),
  route("GET", "/works/latest", (e) => getLatestWorks(e)),
  route("GET", "/users/{id}/works", (e, p) => getAuthorWorks(e, p.id)),
  route("GET", "/works/{id}/bookmarkers", (e, p) =>
    getWorkBookmarkers(e, p.id),
  ),
  route("GET", "/users/{id}/bookmarks", (e, p) => getUserBookmarks(e, p.id)),
  route("GET", "/users/{id}/followers", (e, p) => getFollowers(e, p.id)),
  route("GET", "/users/{id}/following", (e, p) => getFollowing(e, p.id)),

  // Authenticated owner read. This keeps account switching simple on clients:
  // callers do not need to know or persist the generated NIARIM user id.
  route("GET", "/me/works", (e) => getMyWorks(e)),

  // Authenticated mutations.
  route("POST", "/works", (e) => createWork(e)),
  route("PATCH", "/works/{id}", (e, p) => updateWork(e, p.id)),
  route("DELETE", "/works/{id}", (e, p) => deleteWork(e, p.id)),
  route("PATCH", "/works/{id}/tags", (e, p) => updateTags(e, p.id)),
  route("POST", "/reports", (e) => createReport(e)),
  route("POST", "/blocks", (e) => createBlock(e)),
  route("POST", "/works/{id}/bookmark", (e, p) => toggleBookmark(e, p.id)),
  route("PATCH", "/users/{id}/bookmarks-visibility", (e, p) =>
    updateBookmarksVisibility(e, p.id),
  ),
  route("POST", "/works/{id}/repost", (e, p) => toggleRepost(e, p.id)),
  route("POST", "/users/{id}/follow", (e, p) => toggleFollow(e, p.id)),
  route("PATCH", "/users/{id}/follow-visibility", (e, p) =>
    updateFollowVisibility(e, p.id),
  ),
  route("GET", "/users/{id}/notifications", (e, p) =>
    getNotifications(e, p.id),
  ),
  route("POST", "/users/{id}/notifications/mark-read", (e, p) =>
    markNotificationsRead(e, p.id),
  ),
  route("PUT", "/users/{id}/push-token", (e, p) => putPushToken(e, p.id)),
];

export async function handler(
  event: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyStructuredResultV2> {
  try {
    const normalizedEvent = normalizeRequestBody(event);
    const method = event.requestContext.http.method.toUpperCase();
    const path = normalizePath(event.requestContext.http.path);

    if (path.length > MAX_REQUEST_PATH_CHARS) {
      badRequest("リクエストパスが長すぎます", "PATH_TOO_LONG");
    }

    for (const r of routes) {
      if (r.method !== method) continue;
      const match = r.pattern.exec(path);
      if (!match) continue;
      const params: Record<string, string> = {};
      r.paramNames.forEach((name, i) => {
        let value: string;
        try {
          value = decodeURIComponent(match[i + 1]);
        } catch {
          badRequest(
            "パスパラメータのURLエンコードが不正です",
            "INVALID_PATH_ENCODING",
          );
        }
        if (value.length > MAX_PATH_PARAMETER_CHARS) {
          badRequest("パスパラメータが長すぎます", "PATH_PARAMETER_TOO_LONG");
        }
        params[name] = value;
      });
      return await r.handler(normalizedEvent, params);
    }

    return json(404, {
      error: `該当するルートがありません: ${method} ${path}`,
    });
  } catch (err) {
    return errorToResponse(err);
  }
}

function normalizeRequestBody(
  event: APIGatewayProxyEventV2,
): APIGatewayProxyEventV2 {
  if (event.body === undefined) return event;

  let bytes: Buffer;
  if (event.isBase64Encoded) {
    const base64 = event.body;
    const validBase64 =
      base64.length % 4 === 0 &&
      /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(
        base64,
      );
    if (!validBase64)
      badRequest("リクエストボディのBase64が不正です", "INVALID_BASE64");
    bytes = Buffer.from(base64, "base64");
  } else {
    bytes = Buffer.from(event.body, "utf8");
  }

  if (bytes.length > MAX_REQUEST_BODY_BYTES) payloadTooLarge();
  if (!event.isBase64Encoded) return event;
  return { ...event, body: bytes.toString("utf8"), isBase64Encoded: false };
}

function normalizePath(path: string): string {
  if (path.length > 1 && path.endsWith("/")) return path.slice(0, -1);
  return path;
}
