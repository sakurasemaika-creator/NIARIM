import { randomUUID } from "node:crypto";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { badRequest, conflict, forbidden, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import {
  boundedCandidateEditSeconds,
  EDIT_CHECKPOINT_INTERVAL_SECONDS,
  EDIT_CHECKPOINT_MAX_GAP_SECONDS,
  EDIT_DAILY_CANDIDATE_MAX_SECONDS,
  utcEditDay,
  validEditSession,
  type CandidateEditSession,
} from "../../lib/editSessionPolicy";

/**
 * Disabled-by-default measurement PILOT.
 *
 * This endpoint NEVER increases verifiedEditSeconds or the coin wallet.
 * Even a valid Play Integrity token (not yet integrated) cannot be inferred
 * from local mutation counters. Reported events remain UNVERIFIED candidates.
 *
 * Only 1 small DynamoDB item per user; 1 read + at most 1 conditional write
 * on start or checkpoint (target every 15 min), no per-stroke uploads.
 */
function pilotEnabled(): boolean {
  return process.env.CREATOR_EDIT_SESSION_PILOT_ENABLED === "true";
}
const sessionKey = (userId: string) => Keys.creatorMissionState(userId);

function requiredUuid(raw: unknown, field: string): string {
  if (typeof raw !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(raw)) {
    badRequest(`${field}が不正です`, "EDIT_SESSION_INVALID_ID");
  }
  return raw;
}
function requiredInt(raw: unknown, field: string, max: number): number {
  if (typeof raw !== "number" || !Number.isSafeInteger(raw) ||
      raw < 0 || raw > max) {
    badRequest(`${field}が不正です`, "EDIT_SESSION_INVALID_COUNT");
  }
  return raw;
}
function nonNegativeRecordNumber(raw: unknown): number {
  return typeof raw === "number" &&
    Number.isSafeInteger(raw) && raw >= 0 ? raw : 0;
}
function currentRevision(raw: Record<string, unknown> | undefined): number {
  return nonNegativeRecordNumber(raw?.revision);
}
function conditionalConflict(err: unknown): never {
  if (err instanceof ConditionalCheckFailedException) {
    conflict("別の端末または操作で編集セッションが更新されました。再取得してください",
      "EDIT_SESSION_CHANGED");
  }
  throw err;
}

export async function editSessionAction(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (!pilotEnabled()) {
    forbidden("制作時間のサーバー計測は準備中です", "EDIT_SESSION_PILOT_DISABLED");
  }
  const body = parseJsonObject(event.body);
  const action = body.action;
  if (action !== "start" && action !== "checkpoint") {
    badRequest("actionはstartまたはcheckpointを指定してください",
      "EDIT_SESSION_INVALID_ACTION");
  }
  const now = Date.now();
  const key = sessionKey(auth.niarimUserId);
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: key, ConsistentRead: true,
  }));
  const state = result.Item as Record<string, unknown> | undefined;
  const revision = currentRevision(state);
  const active = validEditSession(state?.editSession)
    ? state!.editSession as CandidateEditSession : null;

  if (action === "start") {
    // User supplied nonce enables safe retry after a lost start response.
    const nonce = requiredUuid(body.startNonce, "startNonce");
    if (active && now >= active.lastAtMs &&
        now - active.lastAtMs <= EDIT_CHECKPOINT_MAX_GAP_SECONDS * 1000) {
      if (state?.editSessionStartNonce === nonce) {
        return ok({
          sessionId: active.id,
          nextSequence: active.lastSequence + 1,
          checkpointIntervalSeconds: EDIT_CHECKPOINT_INTERVAL_SECONDS,
          verifiedEditSeconds: nonNegativeRecordNumber(state?.verifiedEditSeconds),
          candidateEditSeconds: nonNegativeRecordNumber(state?.candidateEditSeconds),
          verified: false,
          replay: true,
        });
      }
      conflict("別の制作セッションが有効です", "EDIT_SESSION_ALREADY_ACTIVE");
    }
    const fresh: CandidateEditSession = {
      id: randomUUID(), startedAtMs: now, lastAtMs: now, lastSequence: 0,
    };
    try {
      await ddb.send(new UpdateCommand({
        TableName: tableName(),
        Key: key,
        UpdateExpression:
          "SET itemType = if_not_exists(itemType,:type), " +
          "claimedMask = if_not_exists(claimedMask,:zero), " +
          "verifiedEditSeconds = if_not_exists(verifiedEditSeconds,:zero), " +
          "candidateEditSeconds = if_not_exists(candidateEditSeconds,:zero), " +
          "totalMissionCoins = if_not_exists(totalMissionCoins,:zero), " +
          "editSession = :session, editSessionStartNonce = :nonce " +
          "ADD revision :one",
        ConditionExpression:
          "attribute_not_exists(revision) OR revision = :rev",
        ExpressionAttributeValues: {
          ":type": "CREATOR_MISSIONS_V1",
          ":zero": 0, ":one": 1, ":rev": revision,
          ":session": fresh, ":nonce": nonce,
        },
      }));
    } catch (err) { conditionalConflict(err); }
    return ok({
      sessionId: fresh.id, nextSequence: 1,
      checkpointIntervalSeconds: EDIT_CHECKPOINT_INTERVAL_SECONDS,
      verifiedEditSeconds: nonNegativeRecordNumber(state?.verifiedEditSeconds),
      candidateEditSeconds: nonNegativeRecordNumber(state?.candidateEditSeconds),
      verified: false, replay: false,
    });
  }

  const sessionId = requiredUuid(body.sessionId, "sessionId");
  const sequence = requiredInt(body.sequence, "sequence", 1_000_000_000);
  const activeSeconds = requiredInt(body.activeSeconds, "activeSeconds", 3600);
  const meaningfulMutations = requiredInt(
    body.meaningfulMutations, "meaningfulMutations", 100000,
  );
  if (typeof body.stop !== "boolean") {
    badRequest("stopは真偽値で指定してください", "EDIT_SESSION_INVALID_STOP");
  }
  if (!active || active.id !== sessionId) {
    // An acknowledged stop may have been applied even if its HTTP response
    // was lost. Keep only one tiny completion receipt, not a session log.
    const closed = state?.lastEditStop;
    if (body.stop === true && closed && typeof closed === "object" &&
        (closed as Record<string, unknown>).id === sessionId &&
        (closed as Record<string, unknown>).sequence === sequence) {
      return ok({
        replay: true, stopped: true, acceptedCandidateSeconds: 0,
        candidateEditSeconds:
          nonNegativeRecordNumber(state?.candidateEditSeconds),
        verified: false, nextSequence: null,
      });
    }
    conflict("計測セッションが無効または期限切れです", "EDIT_SESSION_MISSING");
  }
  if (sequence === active.lastSequence) {
    // Exactly-once update with lost-response retry. No DynamoDB write.
    return ok({
      replay: true, acceptedCandidateSeconds: 0,
      candidateEditSeconds: nonNegativeRecordNumber(state?.candidateEditSeconds),
      verified: false, nextSequence: active.lastSequence + 1,
    });
  }
  if (sequence !== active.lastSequence + 1 || now < active.lastAtMs) {
    conflict("制作時間の記録順序が不正です", "EDIT_SESSION_SEQUENCE");
  }
  const elapsedMs = now - active.lastAtMs;
  if (elapsedMs > EDIT_CHECKPOINT_MAX_GAP_SECONDS * 1000) {
    conflict("制作時間の確認期限を過ぎました。再開始してください",
      "EDIT_SESSION_EXPIRED");
  }
  const day = utcEditDay(now);
  const yesterdayAmount = state?.editDay === day
    ? nonNegativeRecordNumber(state?.editDailyCandidateSeconds) : 0;
  const candidate = boundedCandidateEditSeconds({
    serverElapsedMs: elapsedMs,
    reportedActiveSeconds: activeSeconds,
    meaningfulMutations,
    alreadyCreditedToday: yesterdayAmount,
  });
  const candidateEditSeconds =
    nonNegativeRecordNumber(state?.candidateEditSeconds) + candidate;
  if (!Number.isSafeInteger(candidateEditSeconds)) {
    forbidden("制作時間の累計が上限に達しました", "EDIT_SESSION_OVERFLOW");
  }
  const nextSession: CandidateEditSession = {
    ...active, lastAtMs: now, lastSequence: sequence,
  };
  const stop = body.stop;
  try {
    await ddb.send(new UpdateCommand({
      TableName: tableName(),
      Key: key,
      UpdateExpression:
        "SET candidateEditSeconds = :candidate, editDay = :day, " +
        "editDailyCandidateSeconds = :daily " +
        (stop
          ? ", lastEditStop = :closed REMOVE editSession, editSessionStartNonce "
          : ", editSession = :session ") +
        "ADD revision :one",
      ConditionExpression:
        "revision = :rev AND editSession.id = :sid " +
        "AND editSession.lastSequence = :prev",
      ExpressionAttributeValues: {
        ":candidate": candidateEditSeconds,
        ":day": day, ":daily": yesterdayAmount + candidate,
        ":rev": revision, ":sid": sessionId,
        ":prev": active.lastSequence, ":one": 1,
        ...(!stop ? { ":session": nextSession } :
          { ":closed": { id: sessionId, sequence, atMs: now } }),
      },
    }));
  } catch (err) { conditionalConflict(err); }
  return ok({
    replay: false,
    acceptedCandidateSeconds: candidate,
    candidateEditSeconds,
    maxDailyCandidateSeconds: EDIT_DAILY_CANDIDATE_MAX_SECONDS,
    verified: false,
    stopped: stop,
    nextSequence: stop ? null : sequence + 1,
  });
}
