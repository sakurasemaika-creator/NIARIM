import { GetCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { TABLE_ITEM_TYPE, type WorkItem } from "../../lib/types";
import { ok } from "../../lib/response";

/**
 * Cheap, metadata-free preflight before opening a video. Public YouTube API
 * cannot reliably distinguish a deleted video from a private one: when the
 * ID disappears from videos.list, say unavailable rather than guessing.
 * Network/quota failures are unknown, NEVER "deleted".
 */
export async function getPlaybackStatus(workId: string) {
  if (!/^[a-zA-Z0-9_-]{1,64}$/.test(workId)) {
    return ok({ status: "unavailable" });
  }
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.work(workId), ConsistentRead: true,
  }));
  const raw = result.Item;
  if (raw?.itemType === "WORK_TOMBSTONE") {
    return ok({ status: "deleted" });
  }
  if (raw?.itemType !== TABLE_ITEM_TYPE.Work) {
    return ok({ status: "unavailable" });
  }
  const work = raw as WorkItem;
  if (work.youtubePrivacyStatus === "deleted") return ok({ status: "deleted" });
  if (!work.isNiarimPublished || work.youtubePrivacyStatus === "private") {
    return ok({ status: "private" });
  }

  // A stale cached 'public' flag is insufficient: check YouTube on opening,
  // so removals between ranking fetches do not lead into a player error.
  const apiKey = process.env.YOUTUBE_API_KEY;
  if (!apiKey || apiKey === "REPLACE_ME") return ok({ status: "unknown" });
  try {
    const url = new URL("https://www.googleapis.com/youtube/v3/videos");
    url.searchParams.set("part", "status");
    url.searchParams.set("id", work.youtubeVideoId);
    url.searchParams.set("key", apiKey);
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return ok({ status: "unknown" });
    const data = (await res.json()) as {
      items?: Array<{ id: string; status?: { privacyStatus?: string } }>;
    };
    if (!Array.isArray(data.items)) return ok({ status: "unknown" });
    const item = data.items.find((x) => x.id === work.youtubeVideoId);
    if (!item) return ok({ status: "unavailable" });
    if (item.status?.privacyStatus === "private") {
      return ok({ status: "private" });
    }
    if (item.status?.privacyStatus === "public" ||
        item.status?.privacyStatus === "unlisted") {
      return ok({ status: "available" });
    }
    return ok({ status: "unknown" });
  } catch {
    return ok({ status: "unknown" });
  }
}
