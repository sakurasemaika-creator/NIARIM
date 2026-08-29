import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { QueryCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName } from '../../lib/dynamo';
import { authenticate } from '../../lib/auth';
import { forbidden, ok } from '../../lib/response';
import type { FollowNotificationItem } from '../../lib/types';

/**
 * `GET /users/{id}/notifications`（22.6節：アプリ内通知一覧、方式A）。
 * 本人のみ取得できる。TTL属性（ttl）により30日で自動失効する
 * （21.3節の推奨に合わせた設計。DynamoDBのTTLはCDKスタック側で
 * `ttl`属性名を指定している）。
 */
export async function getNotifications(event: APIGatewayProxyEventV2, targetId: string) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  if (auth.niarimUserId !== targetId) forbidden('本人の通知のみ取得できます');

  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: { ':pk': `USER#${targetId}`, ':prefix': 'NOTIF#' },
      ScanIndexForward: false, // 新着順
      Limit: 100,
    }),
  );
  const notifications = (result.Items ?? []) as FollowNotificationItem[];
  const unreadCount = notifications.filter((n) => !n.read).length;

  return ok({
    notifications: notifications.map((n) => ({
      fromUserId: n.fromUserId,
      fromUserName: n.fromUserName,
      createdAt: n.createdAt,
      read: n.read,
    })),
    unreadCount,
  });
}

/**
 * `POST /users/{id}/notifications/mark-read`（22.6節）。通知一覧画面を
 * 開いたタイミングで全既読にする想定。件数が多くない前提のシンプルな
 * 実装（1件ずつUpdateItem。将来件数が増える場合はBatchWriteItemへの
 * 切り替えを検討）。
 */
export async function markNotificationsRead(event: APIGatewayProxyEventV2, targetId: string) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  if (auth.niarimUserId !== targetId) forbidden('本人の通知のみ操作できます');

  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      FilterExpression: '#r = :false',
      ExpressionAttributeNames: { '#r': 'read' },
      ExpressionAttributeValues: { ':pk': `USER#${targetId}`, ':prefix': 'NOTIF#', ':false': false },
    }),
  );
  const unread = (result.Items ?? []) as FollowNotificationItem[];

  await Promise.all(
    unread.map((n) =>
      ddb.send(
        new UpdateCommand({
          TableName: tableName(),
          Key: { pk: n.pk, sk: n.sk },
          UpdateExpression: 'SET #r = :true',
          ExpressionAttributeNames: { '#r': 'read' },
          ExpressionAttributeValues: { ':true': true },
        }),
      ),
    ),
  );

  return ok({ markedCount: unread.length });
}
