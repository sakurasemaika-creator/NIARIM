import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { QueryCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../lib/dynamo";
import type { WorkItem } from "../lib/types";
import { TABLE_ITEM_TYPE } from "../lib/types";

/**
 * EventBridge minute tick: retrieve ONLY due scheduled works through the
 * dedicated sparse GSI, confirm public status with YouTube, then publish to
 * NIARIM's discovery indexes. Never trust the clock alone to reveal private
 * work. Retries use a short index-only backoff to protect quota.
 */
export async function handler(): Promise<void> {
  const apiKey = process.env.YOUTUBE_API_KEY;
  if (!apiKey || apiKey === "REPLACE_ME") {
    console.warn("Scheduled release disabled: YouTube API key not configured");
    return;
  }
  const now = new Date();
  const query = await ddb.send(new QueryCommand({
    TableName: tableName(),
    IndexName: "GSI6Scheduled",
    KeyConditionExpression: "gsi6pk = :pending AND gsi6sk <= :now",
    ExpressionAttributeValues: {
      ":pending": "SCHEDULED",
      ":now": now.toISOString(),
    },
    Limit: 25,
    ScanIndexForward: true,
  }));
  const due = (query.Items ?? []).filter((item) =>
    item.itemType === TABLE_ITEM_TYPE.Work &&
    item.youtubePrivacyStatus === "private" &&
    item.scheduledPublishAt &&
    Date.parse(item.scheduledPublishAt as string) <= now.getTime(),
  ) as WorkItem[];
  if (!due.length) return;

  // A single videos.list call covers up to 25 due videos, not 25 calls.
  const url = new URL("https://www.googleapis.com/youtube/v3/videos");
  url.searchParams.set("part", "status");
  url.searchParams.set("id", due.map((item) => item.youtubeVideoId).join(","));
  url.searchParams.set("key", apiKey);
  const response = await fetch(url, { signal: AbortSignal.timeout(15_000) });
  if (!response.ok) {
    throw new Error(`Scheduled YouTube status query returned ${response.status}`);
  }
  const result = await response.json() as {
    items?: Array<{
      id: string;
      status?: { privacyStatus?: string };
    }>;
  };
  const publicIds = new Set(
    (result.items ?? []).filter((item) =>
      item.status?.privacyStatus === "public").map((item) => item.id),
  );
  await Promise.all(due.map(async (work) => {
    if (publicIds.has(work.youtubeVideoId)) {
      await releaseWork(work);
    } else {
      // Private or temporarily unavailable: never publish on a time guess.
      // This stores only the next attempt time in the sparse scheduler GSI.
      await retryLater(work, new Date(now.getTime() + 5 * 60_000));
    }
  }));
}

async function releaseWork(work: WorkItem): Promise<void> {
  const schedule = work.scheduledPublishAt!;
  const visible = work.isNiarimPublished;
  const updates = [
    "youtubePrivacyStatus = :public",
    "postedAt = :releasedAt",
    "gsi3AllSk = :releasedAt",
  ];
  const removes = ["gsi6pk", "gsi6sk"];
  const values: Record<string, unknown> = {
    ":workType": TABLE_ITEM_TYPE.Work,
    ":private": "private",
    ":public": "public",
    ":scheduled": schedule,
    ":published": visible,
    ":releasedAt": schedule,
    ":bookmarkCount": work.bookmarkCount,
  };
  if (visible) {
    updates.push(
      "gsi2pk = :bmPk", "gsi2sk = :bm",
      "gsi3pk = :authorPk", "gsi3sk = :releasedAt",
      "gsi4pk = :latestPk", "gsi4sk = :releasedAt",
    );
    Object.assign(values, {
      ":bmPk": "BOOKMARK_RANKING",
      ":bm": work.bookmarkCount,
      ":authorPk": `AUTHOR#${work.authorId}`,
      ":latestPk": "LATEST",
    });
  } else {
    removes.push("gsi2pk", "gsi2sk", "gsi3pk", "gsi3sk",
      "gsi4pk", "gsi4sk");
  }

  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: Keys.work(work.workId),
      UpdateExpression: `SET ${updates.join(", ")} REMOVE ${removes.join(", ")}`,
      ConditionExpression:
        "itemType = :workType AND youtubePrivacyStatus = :private " +
        "AND scheduledPublishAt = :scheduled " +
        "AND isNiarimPublished = :published AND bookmarkCount = :bookmarkCount",
      ExpressionAttributeValues: values,
    }));
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) {
      // Concurrent owner privacy edit or stats update: retry on next tick.
      return;
    }
    throw error;
  }
}

async function retryLater(work: WorkItem, time: Date): Promise<void> {
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: Keys.work(work.workId),
      UpdateExpression: "SET gsi6sk = :next",
      ConditionExpression:
        "itemType = :type AND youtubePrivacyStatus = :private " +
        "AND scheduledPublishAt = :schedule AND gsi6sk = :previous",
      ExpressionAttributeValues: {
        ":type": TABLE_ITEM_TYPE.Work,
        ":private": "private",
        ":schedule": work.scheduledPublishAt,
        ":previous": work.gsi6sk,
        ":next": time.toISOString(),
      },
    }));
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) return;
    throw error;
  }
}
