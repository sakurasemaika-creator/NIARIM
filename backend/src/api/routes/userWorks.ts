import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName } from "../../lib/dynamo";
import { ok } from "../../lib/response";
import { authenticate, tryAuthenticate } from "../../lib/auth";
import type { WorkItem } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

async function allWorksForAuthor(authorId: string) {
  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      IndexName: "GSI3AllStates",
      KeyConditionExpression: "gsi3AllPk = :pk",
      ExpressionAttributeValues: { ":pk": `AUTHOR#${authorId}` },
      ScanIndexForward: false,
    }),
  );
  return (result.Items ?? []) as WorkItem[];
}

/** GET /me/works. Authentication selects the NIARIM user id server-side. */
export async function getMyWorks(event: APIGatewayProxyEventV2) {
  const caller = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const works = await allWorksForAuthor(caller.niarimUserId);
  return ok({
    authorId: caller.niarimUserId,
    works: works.map(toPublicWork),
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

  const result = includeHidden
    ? await allWorksForAuthor(authorId)
    : ((
        await ddb.send(
          new QueryCommand({
            TableName: tableName(),
            IndexName: "GSI3",
            KeyConditionExpression: "gsi3pk = :pk",
            ExpressionAttributeValues: { ":pk": `AUTHOR#${authorId}` },
            ScanIndexForward: false,
          }),
        )
      ).Items ?? []) as WorkItem[];

  return ok({ authorId, works: result.map(toPublicWork) });
}
