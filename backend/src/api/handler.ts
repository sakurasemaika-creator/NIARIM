import type {
  APIGatewayProxyEventV2,
  APIGatewayProxyStructuredResultV2,
  DynamoDBBatchResponse,
  DynamoDBStreamEvent,
} from "aws-lambda";
import {
  badRequest,
  errorToResponse,
  json,
  payloadTooLarge,
} from "../lib/response";
import { handleNotificationStream } from "../lib/communityNotifications";
import { getAccountDeletionStatus, startAccountDeletion, verifyAccountDeletion } from "./routes/accountDeletion";
import { getRanking, getRankingVisibility } from "./routes/ranking";
import { refreshMyYoutubeChannel } from "./routes/youtubeChannelRefresh";
import { getLatestWorks } from "./routes/worksLatest";
import { getPlaybackStatus } from "./routes/worksPlaybackStatus";
import { getWorkMetadata, updateWorkMetadata } from "./routes/workMetadata";
import { getYoutubeComments } from "./routes/youtubeComments";
import { getAuthorWorks, getMyWorks, getMyWork } from "./routes/userWorks";
import { createWork } from "./routes/worksCreate";
import { getMyRewardState, getMyCoinHistory } from "./routes/rewardState";
import {
  startRewardedAdSession, receiveRewardedAdSsv, getRewardedAdStatus,
} from "./routes/rewardedAd";
import { getCoinRedemptionQuote, redeemCoins } from "./routes/coinRedemption";
import { getMyCreatorMissions, claimCreatorMission } from "./routes/creatorMissions";
import { scanMyQualifiedWorks } from "./routes/creatorQualifiedWorksScan";
import { getMyWorkMissionAchievements } from "./routes/creatorWorkAchievements";
import { getMyWorkCountMissionGrid } from "./routes/creatorWorkCountGrid";
import { getMyCreatorMissionAttention } from "./routes/creatorMissionAttention";
import { getMyMissionActivity } from "./routes/creatorMissionActivity";
import { syncMyMissionActivity } from "./routes/creatorMissionActivitySync";
import { visitMyLoginBonus, getMyLoginBonus, claimMyLoginBonus } from "./routes/loginBonus";
import { getMyRecurringMissions, claimMyRecurringMission } from "./routes/recurringMissions";
import { editSessionAction } from "./routes/creatorEditSession";
import { getMyPlazaMissions, pulseMyPlazaMissions, claimMyPlazaMission }
  from "./routes/plazaMissions";
import { verifyMyPlayPremium, getPlayPurchaseAvailability } from "./routes/playPremium";
import { updateWork } from "./routes/worksUpdate";
import { deleteWork } from "./routes/worksDelete";
import { updateTags } from "./routes/tags";
import { createReport } from "./routes/reports";
import { createBlock, deleteBlock, getMyBlocks } from "./routes/blocks";
import {
  toggleBookmark,
  getUserBookmarks,
} from "./routes/bookmarks";
import { getUserReposts, toggleRepost } from "./routes/reposts";
import {
  toggleFollow,
  getFollowing,
  getFollowers,
  getSocialCounts,
} from "./routes/follows";
import { putPushToken } from "./routes/notifications";
import {
  dismissAdminReport,
  getAdminMe,
  updateAdminSettings,
  getAdminReport,
  getAdminUser,
  hideAdminReport,
  listAdminReports,
  reviewAdminReport,
  suspendAdminUser,
  unhideAdminWork,
  unsuspendAdminUser,
} from "./routes/admin";
import {
  createAdminTriageToken,
  getAdminTriagePrompt,
  listTriageBotReports,
  revokeAdminTriageToken,
  submitAdminTriageResults,
  submitTriageBotJudgment,
} from "./routes/triage";

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
  route("GET", "/ranking/visibility", (e) => getRankingVisibility(e)),
  route("GET", "/ranking/{period}", (e, p) => getRanking(e, p.period)),
  route("GET", "/works/latest", (e) => getLatestWorks(e)),
  route("GET", "/works/{id}/playback-status", (e, p) => getPlaybackStatus(p.id, e)),
  route("GET", "/works/{id}/metadata", (e, p) => getWorkMetadata(e, p.id)),
  route("PATCH", "/works/{id}/metadata", (e, p) => updateWorkMetadata(e, p.id)),
  route("GET", "/works/{id}/youtube-comments", (e, p) => getYoutubeComments(e, p.id)),
  route("GET", "/users/{id}/works", (e, p) => getAuthorWorks(e, p.id)),
  route("GET", "/users/{id}/bookmarks", (e, p) => getUserBookmarks(e, p.id)),
  route("GET", "/users/{id}/social-counts", (e, p) => getSocialCounts(e, p.id)),
  route("GET", "/users/{id}/following", (e, p) => getFollowing(e, p.id)),
  route("GET", "/users/{id}/followers", (e, p) => getFollowers(e, p.id)),
  route("GET", "/users/{id}/reposts", (e, p) => getUserReposts(e, p.id)),

  // Authenticated owner read. This keeps account switching simple on clients:
  // callers do not need to know or persist the generated NIARIM user id.
  route("GET", "/me/works", (e) => getMyWorks(e)),
  route("POST", "/account-deletion/verify", (e) => verifyAccountDeletion(e)),
  route("POST", "/account-deletion/submit", (e) => startAccountDeletion(e)),
  route("POST", "/account-deletion/status", (e) => getAccountDeletionStatus(e)),
  route("GET", "/me/works/{id}", (e, p) => getMyWork(e, p.id)),
  route("POST", "/me/youtube-channel/refresh", (e) => refreshMyYoutubeChannel(e)),
  route("GET", "/me/rewards", (e) => getMyRewardState(e)),
  route("POST", "/me/premium/play/verify", (e) => verifyMyPlayPremium(e)),
  route("GET", "/me/premium/play/availability", (e) => getPlayPurchaseAvailability(e)),
  route("GET", "/me/rewards/history", (e) => getMyCoinHistory(e)),
  route("POST", "/me/rewards/ad-session", (e) => startRewardedAdSession(e)),
  route("GET", "/me/rewards/ad-status", (e) => getRewardedAdStatus(e)),
  route("GET", "/me/rewards/quote", (e) => getCoinRedemptionQuote(e)),
  route("POST", "/me/rewards/redeem", (e) => redeemCoins(e)),
  // Public Google-to-server callback; signature and one-time nonce mandatory.
  route("GET", "/admob/ssv", (e) => receiveRewardedAdSsv(e)),
  route("POST", "/me/login-bonus/visit", (e) => visitMyLoginBonus(e)),
  route("GET", "/me/login-bonus", (e) => getMyLoginBonus(e)),
  route("POST", "/me/login-bonus/claim", (e) => claimMyLoginBonus(e)),
  route("GET", "/me/missions/recurring", (e) => getMyRecurringMissions(e)),
  route("GET", "/me/missions/plaza", (e) => getMyPlazaMissions(e)),
  route("POST", "/me/missions/plaza/pulse", (e) => pulseMyPlazaMissions(e)),
  route("POST", "/me/missions/plaza/claim", (e) => claimMyPlazaMission(e)),
  route("POST", "/me/missions/recurring/claim", (e) => claimMyRecurringMission(e)),
  route("GET", "/me/missions", (e) => getMyCreatorMissions(e)),
  route("GET", "/me/missions/grid", (e) => getMyWorkCountMissionGrid(e)),
  route("GET", "/me/missions/attention", (e) => getMyCreatorMissionAttention(e)),
  route("GET", "/me/missions/activity", (e) => getMyMissionActivity(e)),
  route("POST", "/me/missions/activity/sync", (e) => syncMyMissionActivity(e)),
  route("GET", "/me/missions/work-achievements", (e) => getMyWorkMissionAchievements(e)),
  route("POST", "/me/missions/claim", (e) => claimCreatorMission(e)),
  route("POST", "/me/missions/qualified-works/scan", (e) => scanMyQualifiedWorks(e)),
  route("POST", "/me/missions/edit-session", (e) => editSessionAction(e)),

  // Authenticated mutations.
  route("POST", "/works", (e) => createWork(e)),
  route("PATCH", "/works/{id}", (e, p) => updateWork(e, p.id)),
  route("DELETE", "/works/{id}", (e, p) => deleteWork(e, p.id)),
  route("PATCH", "/works/{id}/tags", (e, p) => updateTags(e, p.id)),
  route("POST", "/reports", (e) => createReport(e)),
  route("GET", "/me/blocks", (e) => getMyBlocks(e)),
  route("POST", "/blocks", (e) => createBlock(e)),
  route("DELETE", "/blocks/{id}", (e, p) => deleteBlock(e, p.id)),
  route("POST", "/works/{id}/bookmark", (e, p) => toggleBookmark(e, p.id)),
  route("POST", "/works/{id}/repost", (e, p) => toggleRepost(e, p.id)),
  route("POST", "/users/{id}/follow", (e, p) => toggleFollow(e, p.id)),
  route("PUT", "/users/{id}/push-token", (e, p) => putPushToken(e, p.id)),

  // Moderation admin API (browser admin page). Google ID token + allowlisted
  // email from SSM; CORS for the website origin is added below.
  route("GET", "/admin/me", (e) => getAdminMe(e)),
  route("POST", "/admin/settings", (e) => updateAdminSettings(e)),
  route("GET", "/admin/reports", (e) => listAdminReports(e)),
  route("GET", "/admin/reports/{id}", (e, p) => getAdminReport(e, p.id)),
  route("POST", "/admin/reports/{id}/review", (e, p) => reviewAdminReport(e, p.id)),
  route("POST", "/admin/reports/{id}/dismiss", (e, p) => dismissAdminReport(e, p.id)),
  route("POST", "/admin/reports/{id}/hide", (e, p) => hideAdminReport(e, p.id)),
  route("POST", "/admin/works/{id}/unhide", (e, p) => unhideAdminWork(e, p.id)),
  route("GET", "/admin/users/{id}", (e, p) => getAdminUser(e, p.id)),
  route("POST", "/admin/users/{id}/suspend", (e, p) => suspendAdminUser(e, p.id)),
  route("POST", "/admin/users/{id}/unsuspend", (e, p) => unsuspendAdminUser(e, p.id)),
  route("POST", "/admin/triage/token", (e) => createAdminTriageToken(e)),
  route("POST", "/admin/triage/token/revoke", (e) => revokeAdminTriageToken(e)),
  route("GET", "/admin/triage/prompt", (e) => getAdminTriagePrompt(e)),
  route("POST", "/admin/triage/results", (e) => submitAdminTriageResults(e)),

  // Report triage bot: a scheduled Claude session on the owner's subscription,
  // with the bearer token created on the admin page. Server to server, no CORS.
  route("GET", "/triage-bot/reports", (e) => listTriageBotReports(e)),
  route("POST", "/triage-bot/reports/{id}/triage", (e, p) => submitTriageBotJudgment(e, p.id)),
];

/**
 * CORS only for the moderation admin API, only for the website origin(s) in
 * ADMIN_ALLOWED_ORIGINS. The Function URL has no CORS configuration of its
 * own, so Lambda passes preflight OPTIONS requests to this handler. Every
 * other route keeps sending no CORS headers (app-only, as before).
 */
const DEFAULT_ADMIN_ORIGINS = "https://niarim.miranima-studio.com";

function isAdminPath(path: string): boolean {
  return path === "/admin" || path.startsWith("/admin/");
}

function adminCorsHeaders(event: APIGatewayProxyEventV2): Record<string, string> | undefined {
  const origin = event.headers?.["origin"] ?? event.headers?.["Origin"];
  if (!origin) return undefined;
  const allowed = (process.env.ADMIN_ALLOWED_ORIGINS ?? DEFAULT_ADMIN_ORIGINS)
    .split(",").map((value) => value.trim()).filter(Boolean);
  if (!allowed.includes(origin)) return undefined;
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET, POST, OPTIONS",
    "access-control-allow-headers": "authorization, content-type",
    "access-control-max-age": "600",
  };
}

function withAdminCors(
  event: APIGatewayProxyEventV2,
  response: APIGatewayProxyStructuredResultV2,
): APIGatewayProxyStructuredResultV2 {
  const cors = adminCorsHeaders(event);
  return {
    ...response,
    headers: { ...response.headers, vary: "origin", ...(cors ?? {}) },
  };
}

export function handler(event: APIGatewayProxyEventV2): Promise<APIGatewayProxyStructuredResultV2>;
export function handler(event: DynamoDBStreamEvent): Promise<DynamoDBBatchResponse>;
export async function handler(
  event: APIGatewayProxyEventV2 | DynamoDBStreamEvent,
): Promise<APIGatewayProxyStructuredResultV2 | DynamoDBBatchResponse> {
  // Lambda URL wraps an HTTP body as a string; only the AWS stream invocation
  // supplies top-level Records. Never dispatch a parsed client body here.
  if ("Records" in event) return handleNotificationStream(event.Records);
  const rawPath = event.requestContext?.http?.path ?? "";
  if (isAdminPath(normalizePath(rawPath))) {
    if (event.requestContext.http.method.toUpperCase() === "OPTIONS") {
      return withAdminCors(event, { statusCode: 204, headers: {}, body: "" });
    }
    return withAdminCors(event, await dispatch(event));
  }
  return dispatch(event);
}

async function dispatch(
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
