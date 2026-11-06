import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import { authenticate } from "../../lib/auth";
import { ddb, tableName } from "../../lib/dynamo";
import { badRequest, ok } from "../../lib/response";

/** Read the author's durable mission activity, newest first, 1–50 per page. */
export async function getMyMissionActivity(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const limitText = event.queryStringParameters?.limit;
  const limit = limitText === undefined ? 30 : Number(limitText);
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 50) {
    badRequest("取得件数が不正です", "MISSION_ACTIVITY_INVALID_LIMIT");
  }
  const rawCursor = event.queryStringParameters?.cursor;
  let cursor: Record<string, string> | undefined;
  if (rawCursor !== undefined) {
    if (rawCursor.length < 1 || rawCursor.length > 2048 ||
        !/^[a-zA-Z0-9_-]+$/.test(rawCursor)) {
      badRequest("通知カーソルが不正です", "MISSION_ACTIVITY_INVALID_CURSOR");
    }
    try {
      const obj = JSON.parse(Buffer.from(rawCursor, "base64url").toString());
      if (obj && !Array.isArray(obj) && typeof obj === "object" &&
          obj.pk === `USER#${auth.niarimUserId}` &&
          typeof obj.sk === "string" &&
          /^MISSION_ACTIVITY#[0-9]{13}#/.test(obj.sk)) {
        cursor = {pk:obj.pk,sk:obj.sk};
      }
    } catch { /* Reject tampered cursor. */ }
    if (!cursor) {
      badRequest("通知カーソルが不正です", "MISSION_ACTIVITY_INVALID_CURSOR");
    }
  }
  const result = await ddb.send(new QueryCommand({
    TableName: tableName(),
    KeyConditionExpression:"pk = :owner AND begins_with(sk, :prefix)",
    ExpressionAttributeValues:{
      ":owner":`USER#${auth.niarimUserId}`,":prefix":"MISSION_ACTIVITY#",
    },
    Limit:limit,ScanIndexForward:true,ExclusiveStartKey:cursor,
    ConsistentRead:true,
  }));
  return ok({
    events: (result.Items ?? [])
      .filter(x=>x.itemType==="MISSION_ACTIVITY_V1")
      .map(x=>({
        eventId:x.eventId,kind:x.kind,missionId:x.missionId,
        workId:x.workId ?? null,workTitle:x.workTitle ?? null,
        required:x.required,eachWorkBookmarks:x.eachWorkBookmarks ?? null,
        occurredAt:x.occurredAt,dateIsObserved:x.dateIsObserved===true,
        targetRoute:"/creator-missions",
      })),
    nextCursor:result.LastEvaluatedKey
      ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString("base64url")
      : null,
  });
}
