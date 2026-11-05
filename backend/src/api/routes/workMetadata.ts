import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate } from "../../lib/auth";
import { badRequest, forbidden, notFound, ok, conflict } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import { TABLE_ITEM_TYPE, type WorkItem } from "../../lib/types";
import { ConditionalCheckFailedException, TransactionCanceledException } from "@aws-sdk/client-dynamodb";

/** Description lives in a non-indexed detail row, never in ProjectionType.ALL GSIs. */
export const detailKey = (id: string) => ({ ...Keys.work(id), sk: "DETAIL" });

export async function getWorkMetadata(event: APIGatewayProxyEventV2, workId: string) {
  if (!/^[A-Za-z0-9_-]{11}$/.test(workId)) notFound();
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.work(workId),
  }));
  if (result.Item?.itemType !== TABLE_ITEM_TYPE.Work) notFound();
  const work = result.Item as WorkItem;
  const accessible = work.isNiarimPublished &&
    work.youtubePrivacyStatus !== "private" &&
    work.youtubePrivacyStatus !== "deleted";
  if (!accessible) {
    if (!event.headers.authorization && !event.headers.Authorization) notFound();
    const caller = await authenticate(
      event.headers.authorization ?? event.headers.Authorization,
    );
    if (caller.niarimUserId !== work.authorId) notFound();
  }
  const details = await ddb.send(new GetCommand({
    TableName: tableName(), Key: detailKey(workId),
  }));
  return ok({ title: work.title, description:
    typeof details.Item?.description === "string" ? details.Item.description : "" });
}

/** A single atomic owner-checked edit; no YouTube videos.update call. */
export async function updateWorkMetadata(event: APIGatewayProxyEventV2, workId: string) {
  if (!/^[A-Za-z0-9_-]{11}$/.test(workId)) notFound();
  const caller = await authenticate(
    event.headers.authorization ?? event.headers.Authorization,
  );
  const body = parseJsonObject(event.body);
  if (typeof body.title !== "string" || body.title.trim().length < 1 ||
      body.title.trim().length > 100) {
    badRequest("作品タイトルは1〜100文字で入力してください", "INVALID_TITLE");
  }
  if (typeof body.description !== "string" || body.description.length > 2000) {
    badRequest("作品概要欄は2000文字以内で入力してください", "INVALID_DESCRIPTION");
  }
  const title = body.title.trim();
  const description = body.description.trim();
  const current = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.work(workId), ConsistentRead: true,
  }));
  if (current.Item?.itemType !== TABLE_ITEM_TYPE.Work) notFound();
  const work = current.Item as WorkItem;
  if (work.authorId !== caller.niarimUserId) forbidden("投稿者のみ変更できます");
  const detail = await ddb.send(new GetCommand({
    TableName: tableName(), Key: detailKey(workId), ConsistentRead: true,
  }));
  const oldDescription = typeof detail.Item?.description === "string"
    ? detail.Item.description : "";
  if (title === work.title && description === oldDescription) {
    return ok({ title, description });
  }
  const txn: any[] = [
    title === work.title
      ? {
          ConditionCheck: {
            TableName: tableName(), Key: Keys.work(workId),
            ConditionExpression: "itemType = :workType AND authorId = :owner",
            ExpressionAttributeValues: {
              ":workType": TABLE_ITEM_TYPE.Work, ":owner": caller.niarimUserId,
            },
          },
        }
      : {
          Update: {
            TableName: tableName(), Key: Keys.work(workId),
            ConditionExpression: "itemType = :workType AND authorId = :owner",
            UpdateExpression: "SET title = :title",
            ExpressionAttributeValues: {
              ":workType": TABLE_ITEM_TYPE.Work, ":owner": caller.niarimUserId,
              ":title": title,
            },
          },
        },
  ];
  if (description !== oldDescription) {
    txn.push({
      Put: {
        TableName: tableName(),
        Item: { ...detailKey(workId), itemType: "WORK_DETAIL",
          authorId: caller.niarimUserId, description, updatedAt: new Date().toISOString() },
      },
    });
  }
  try {
    await ddb.send(new TransactWriteCommand({ TransactItems: txn }));
  } catch (error) {
    if (error instanceof TransactionCanceledException ||
        error instanceof ConditionalCheckFailedException) {
      conflict("作品が変更または削除されました。更新して再試行してください", "WORK_CHANGED");
    }
    throw error;
  }
  return ok({ title, description });
}
