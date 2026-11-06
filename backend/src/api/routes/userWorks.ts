import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { ok, notFound } from "../../lib/response";
import { decodePageCursor, encodePageCursor, requestedPageSize } from "../../lib/pagination";
import { authenticate, tryAuthenticate } from "../../lib/auth";
import type { WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

async function allWorksForAuthor(authorId: string, event: APIGatewayProxyEventV2) {
  const qp = event.queryStringParameters ?? {};
  const scope = `author|${authorId}|owner`;
  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      IndexName: "GSI3AllStates",
      KeyConditionExpression: "gsi3AllPk = :pk",
      ExpressionAttributeValues: { ":pk": `AUTHOR#${authorId}` },
      ScanIndexForward: false,
      Limit: requestedPageSize(qp.limit),
      ExclusiveStartKey: decodePageCursor(qp.cursor, scope),
    }),
  );
  return {
    works: (result.Items ?? []) as WorkItem[],
    nextCursor: encodePageCursor(result.LastEvaluatedKey, scope),
  };
}

/**
 * Owner-only representation. The YouTube privacy state is intentionally exposed
 * only on owner list responses so the app can explain why a NIARIM-published work
 * is temporarily hidden when YouTube is private/deleted.
 */
function toOwnerWork(work: WorkItem) {
  return {
    ...toPublicWork(work),
    youtubePrivacyStatus: work.youtubePrivacyStatus,
    scheduledPublishAt: work.scheduledPublishAt,
  };
}

/** Exact owner-only lookup, including private and scheduled videos.
 * Used when a local notification deep-links into a cold app session.
 * Never expose the returned private thumbnail/title to other accounts.
 */
export async function getMyWork(
  event: APIGatewayProxyEventV2,
  workId: string,
) {
  const caller = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const item = await ddb.send(new GetCommand({
    TableName: tableName(),
    Key: Keys.work(workId),
    ConsistentRead: true,
  }));
  const work = item.Item as WorkItem | undefined;
  if (!work || work.itemType !== TABLE_ITEM_TYPE.Work ||
      work.authorId !== caller.niarimUserId) {
    notFound("作品が見つかりません");
  }
  return ok({ work: toOwnerWork(work) });
}

/** GET /me/works. Authentication selects the NIARIM user id server-side. */
export async function getMyWorks(event: APIGatewayProxyEventV2) {
  const caller = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const page = await allWorksForAuthor(caller.niarimUserId, event);
  return ok({
    authorId: caller.niarimUserId,
    works: page.works.map(toOwnerWork),
    nextCursor: page.nextCursor,
  });
}

/**
 * GET /users/{id}/works. Public callers only see discoverable works; the owner
 * receives hidden works too when a valid Authorization header belongs to {id}.
 */
export async function getAuthorWorks(
  event: APIGatewayProxyEventV2,
  authorId: string,
) {
  const caller = await tryAuthenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const includeHidden = caller?.niarimUserId === authorId;

  const qp = event.queryStringParameters ?? {};
  const scope = `author|${authorId}|public`;
  const result = includeHidden
    ? await allWorksForAuthor(authorId, event)
    : await ddb.send(
        new QueryCommand({
          TableName: tableName(),
          IndexName: "GSI3",
          KeyConditionExpression: "gsi3pk = :pk",
          ExpressionAttributeValues: { ":pk": `AUTHOR#${authorId}` },
          ScanIndexForward: false,
          Limit: requestedPageSize(qp.limit),
          ExclusiveStartKey: decodePageCursor(qp.cursor, scope),
        }),
      );
  const works = includeHidden ? (result as { works: WorkItem[] }).works : (result as { Items?: Record<string, unknown>[] }).Items as WorkItem[] | undefined ?? [];
  return ok({
    authorId,
    works: includeHidden ? works.map(toOwnerWork) : works.map(toPublicWork),
    nextCursor: includeHidden
      ? (result as { nextCursor: string | null }).nextCursor
      : encodePageCursor((result as { LastEvaluatedKey?: Record<string, unknown> }).LastEvaluatedKey, scope),
  });
}
