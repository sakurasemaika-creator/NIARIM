import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName } from "../../lib/dynamo";
import { ok } from "../../lib/response";
import { tryAuthenticate } from "../../lib/auth";
import type { WorkItem } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

/**
 * `GET /users/{id}/works`（8.4節）。GSI3（AuthorWorksIndex）へのQuery
 * 1回で完結する。ただしGSI3は「可視の作品のみ」を含む設計（ranking.ts
 * ・worksLatest.tsと統一）のため、投稿者本人が自分の非公開作品も
 * 含めて確認したい場合（8.5節・13章）は、別途メインテーブルを
 * `authorId`で直接Query（GSIを介さない）して全件取得する。
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
    ? await ddb.send(
        new QueryCommand({
          TableName: tableName(),
          IndexName: "GSI3AllStates",
          KeyConditionExpression: "gsi3AllPk = :pk",
          ExpressionAttributeValues: { ":pk": `AUTHOR#${authorId}` },
          ScanIndexForward: false,
        }),
      )
    : await ddb.send(
        new QueryCommand({
          TableName: tableName(),
          IndexName: "GSI3",
          KeyConditionExpression: "gsi3pk = :pk",
          ExpressionAttributeValues: { ":pk": `AUTHOR#${authorId}` },
          ScanIndexForward: false,
        }),
      );

  const works = (result.Items ?? []) as WorkItem[];
  return ok({ authorId, works: works.map(toPublicWork) });
}
