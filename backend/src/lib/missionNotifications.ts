import {
  TransactionCanceledException,
} from "@aws-sdk/client-dynamodb";
import {
  GetCommand, TransactWriteCommand,
} from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "./dynamo";

/**
 * User-owned, chronological, durable mission notifications.
 * A single DynamoDB transaction atomically creates an immutable once-only
 * marker and an ordered activity row. Retried, concurrent and cross-device
 * events cannot create duplicate rows. NO coin wallet writes occur here.
 *
 * The marker deliberately has no TTL: old milestones never reappear after a
 * notification has been read. The event also has no TTL so achievements
 * remain available in the user's personal history.
 */
export type MissionActivityKind =
  | "workPublished" | "workBookmarks" | "qualifiedWorks" | "followers"
  | "loginMilestone";

export type MissionAchievement = {
  kind: MissionActivityKind;
  missionId: string;
  workId?: string;
  workTitle?: string;
  required: number;
  eachWorkBookmarks?: number;
  occurredAt: string;
  // True for milestone discovered by a later scan, not an exact crossing date.
  dateIsObserved?: boolean;
};
const safeEventId = /^[A-Za-z0-9_-]{1,11}$/;
const allowedMissionId = /^[a-z0-9_]{1,64}$/;

export function missionEventId(event: MissionAchievement): string {
  if (!allowedMissionId.test(event.missionId)) {
    throw new Error("Invalid mission event id");
  }
  if (event.kind !== "qualifiedWorks" && event.kind !== "followers" &&
      event.kind !== "loginMilestone") {
    if (!event.workId || !safeEventId.test(event.workId)) {
      throw new Error("Mission activity needs a valid work id");
    }
    return `work_${event.workId}_${event.missionId}`;
  }
  return `account_${event.missionId}`;
}

export async function recordMissionAchievement(
  userId: string,
  event: MissionAchievement,
): Promise<boolean> {
  const id = missionEventId(event);
  const epochMs = Date.parse(event.occurredAt);
  if (!Number.isSafeInteger(epochMs) || epochMs <= 0 ||
      epochMs > Date.now() + 86_400_000) {
    throw new Error("Invalid achievement timestamp");
  }
  const marker = Keys.missionNoticeDedupe(userId, id);
  const entry = Keys.missionActivity(userId, epochMs, id);
  const now = new Date().toISOString();
  try {
    await ddb.send(new TransactWriteCommand({
      TransactItems: [
        {Put: {
          TableName: tableName(),
          Item: {
            ...marker, itemType: "MISSION_NOTICE_DEDUPE_V1",
            eventId: id, createdAt: now,
          },
          ConditionExpression: "attribute_not_exists(pk)",
        }},
        {Put: {
          TableName: tableName(),
          Item: {
            ...entry, itemType: "MISSION_ACTIVITY_V1",
            eventId: id, kind: event.kind, missionId: event.missionId,
            ...(event.workId ? {workId: event.workId} : {}),
            ...(event.workTitle ? {workTitle: event.workTitle} : {}),
            required: event.required,
            ...(event.eachWorkBookmarks !== undefined
              ? {eachWorkBookmarks: event.eachWorkBookmarks} : {}),
            occurredAt: event.occurredAt,
            observedAt: now,
            dateIsObserved: event.dateIsObserved === true,
            targetRoute: "/creator-missions",
            read: false,
          },
          ConditionExpression: "attribute_not_exists(pk)",
        }},
      ],
    }));
    return true;
  } catch (error) {
    if (error instanceof TransactionCanceledException) {
      const existing = await ddb.send(new GetCommand({
        TableName: tableName(), Key: marker, ConsistentRead: true,
      }));
      if (existing.Item?.itemType === "MISSION_NOTICE_DEDUPE_V1" &&
          existing.Item.eventId === id) {
        return false; // Retried event, already recorded.
      }
    }
    throw error;
  }
}
