import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand, QueryCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate } from "../../lib/auth";
import { badRequest, created, notFound, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import type { BlockItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";

const readViewer = (event: APIGatewayProxyEventV2) => {
  const header = event.headers?.authorization ?? event.headers?.Authorization;
  return header ? authenticate(header) : null;
};

function inboundKey(blockerId: string, blockedId: string) {
  return { pk: Keys.user(blockedId).pk, sk: `BLOCKED_BY#${blockerId}` };
}

export async function blockedFromViewer(event: APIGatewayProxyEventV2): Promise<Set<string>> {
  const viewer = await readViewer(event);
  const ids = new Set<string>();
  if (!viewer) return ids;
  let cursor: Record<string, unknown> | undefined;
  do {
    const page = await ddb.send(new QueryCommand({
      TableName: tableName(),
      ConsistentRead: true,
      KeyConditionExpression: "pk = :pk AND begins_with(sk, :prefix)",
      ExpressionAttributeValues: { ":pk": Keys.user(viewer.niarimUserId).pk, ":prefix": "BLOCK" },
      ExclusiveStartKey: cursor,
    }));
    for (const row of (page.Items ?? []) as BlockItem[]) {
      if (row.itemType !== TABLE_ITEM_TYPE.Block) continue;
      if (row.blockerId === viewer.niarimUserId) ids.add(row.blockedId);
      if (row.blockedId === viewer.niarimUserId) ids.add(row.blockerId);
    }
    cursor = page.LastEvaluatedKey;
  } while (cursor);
  return ids;
}

// Direct reads also recognize older outbound records that had no mirror row.
export async function isBlockedBetween(first: string, second: string): Promise<boolean> {
  if (first === second) return false;
  const rows = await Promise.all([
    Keys.block(first, second), Keys.block(second, first),
  ].map(Key => ddb.send(new GetCommand({ TableName: tableName(), Key, ConsistentRead: true }))));
  return rows.some(row => row.Item?.itemType === TABLE_ITEM_TYPE.Block);
}

export async function isBlockedForViewer(event: APIGatewayProxyEventV2, authorId: string) {
  const viewer = await readViewer(event);
  return viewer ? isBlockedBetween(viewer.niarimUserId, authorId) : false;
}

function userId(value: unknown): string {
  if (typeof value !== "string" || !/^N[0-9a-f]{32}$/.test(value)) {
    badRequest("blockedUserIdの形式が不正です");
  }
  return value;
}

export async function createBlock(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(event.headers?.authorization ?? event.headers?.Authorization);
  const blockedId = userId(parseJsonObject(event.body).blockedUserId);
  const blockerId = auth.niarimUserId;
  if (blockerId === blockedId) badRequest("自分自身をブロックすることはできません");
  const TableName = tableName();
  const target = await ddb.send(new GetCommand({
    TableName, Key: Keys.user(blockedId), ConsistentRead: true,
  }));
  if (target.Item?.itemType !== TABLE_ITEM_TYPE.User || target.Item.erasureReceipt) {
    notFound("アカウントが見つかりません");
  }
  const record = { itemType: TABLE_ITEM_TYPE.Block, blockerId, blockedId, createdAt: new Date().toISOString() };
  await ddb.send(new TransactWriteCommand({
    TransactItems: [
      ...[blockerId, blockedId].map(id => ({
        ConditionCheck: {
          TableName, Key: Keys.user(id),
          ConditionExpression: "itemType = :type AND attribute_not_exists(erasureReceipt)",
          ExpressionAttributeValues: { ":type": TABLE_ITEM_TYPE.User },
        },
      })),
      ...[Keys.block(blockerId, blockedId), inboundKey(blockerId, blockedId)].map(Key => ({
        Put: { TableName, Item: { ...Key, ...record } },
      })),
    ],
  }));
  // No notifications are emitted for either write.
  return created({ ok: true });
}

export async function deleteBlock(event: APIGatewayProxyEventV2, target: string) {
  const auth = await authenticate(event.headers?.authorization ?? event.headers?.Authorization);
  const blockedId = userId(target);
  const blockerId = auth.niarimUserId;
  const TableName = tableName();
  await ddb.send(new TransactWriteCommand({
    TransactItems: [Keys.block(blockerId, blockedId), inboundKey(blockerId, blockedId)]
      .map(Key => ({ Delete: { TableName, Key } })),
  }));
  return ok({ ok: true });
}

export async function getMyBlocks(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(event.headers?.authorization ?? event.headers?.Authorization);
  const blockedUserIds: string[] = [];
  let cursor: Record<string, unknown> | undefined;
  do {
    const page = await ddb.send(new QueryCommand({
      TableName: tableName(),
      ConsistentRead: true,
      KeyConditionExpression: "pk = :pk AND begins_with(sk, :prefix)",
      ExpressionAttributeValues: { ":pk": Keys.user(auth.niarimUserId).pk, ":prefix": "BLOCK#" },
      ExclusiveStartKey: cursor,
    }));
    for (const row of (page.Items ?? []) as BlockItem[]) {
      if (row.itemType === TABLE_ITEM_TYPE.Block) blockedUserIds.push(row.blockedId);
    }
    cursor = page.LastEvaluatedKey;
  } while (cursor);
  return ok({ blockedUserIds });
}
