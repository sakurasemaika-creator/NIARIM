import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { randomUUID } from 'node:crypto';
import { GetCommand, QueryCommand, TransactWriteCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { TransactionCanceledException } from '@aws-sdk/client-dynamodb';
import { ddb, tableName, Keys } from '../../lib/dynamo';
import { authenticate, tryAuthenticate, getUser } from '../../lib/auth';
import { badRequest, forbidden, ok } from '../../lib/response';
import { parseJsonObject } from '../../lib/request';
import { sendPushToUser } from '../../lib/push';
import type { FollowerRecordItem, FollowingRecordItem, FollowNotificationItem, UserItem } from '../../lib/types';
import { TABLE_ITEM_TYPE } from '../../lib/types';

const NOTIFICATION_TTL_DAYS = 30; // 21.3節の推奨に合わせる

/**
 * `POST /users/{id}/follow`（22.5節）。フォロー/解除の操作ごとに
 * `TransactWriteItems`で「被フォロー側記録（FollowerRecord）」
 * 「フォロー側記録（FollowingRecord、二重書き込みでO(1)クエリ可能に
 * する）」「両ユーザーのfollowerCount/followingCountカウンター」を
 * まとめて更新する。フォロー時のみ、対象ユーザー宛てのフォロー通知
 * （22.6節：アプリ内通知、方式A）を同じトランザクションで作成する。
 */
export async function toggleFollow(event: APIGatewayProxyEventV2, targetId: string) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  if (auth.niarimUserId === targetId) badRequest('自分自身をフォローすることはできません');

  const followerKey = Keys.followerRecord(targetId, auth.niarimUserId);
  const existing = await ddb.send(new GetCommand({ TableName: tableName(), Key: followerKey }));
  const isFollowing = Boolean(existing.Item);
  const now = new Date().toISOString();

  try {
    if (isFollowing) {
      await ddb.send(
        new TransactWriteCommand({
          TransactItems: [
            { Delete: { TableName: tableName(), Key: followerKey, ConditionExpression: 'attribute_exists(pk)' } },
            { Delete: { TableName: tableName(), Key: Keys.followingRecord(auth.niarimUserId, targetId) } },
            {
              Update: {
                TableName: tableName(),
                Key: Keys.user(targetId),
                UpdateExpression: 'ADD followerCount :minus',
                ConditionExpression: 'followerCount > :zero',
                ExpressionAttributeValues: { ':minus': -1, ':zero': 0 },
              },
            },
            {
              Update: {
                TableName: tableName(),
                Key: Keys.user(auth.niarimUserId),
                UpdateExpression: 'ADD followingCount :minus',
                ConditionExpression: 'followingCount > :zero',
                ExpressionAttributeValues: { ':minus': -1, ':zero': 0 },
              },
            },
          ],
        }),
      );
    } else {
      const followerRecord: FollowerRecordItem = {
        itemType: TABLE_ITEM_TYPE.FollowerRecord,
        ...followerKey,
        targetId,
        followerId: auth.niarimUserId,
        followedAt: now,
      };
      const followingRecord: FollowingRecordItem = {
        itemType: TABLE_ITEM_TYPE.FollowingRecord,
        ...Keys.followingRecord(auth.niarimUserId, targetId),
        followerId: auth.niarimUserId,
        targetId,
        followedAt: now,
      };

      const follower = await getUser(auth.niarimUserId);
      const notifId = randomUUID();
      const notification: FollowNotificationItem = {
        itemType: TABLE_ITEM_TYPE.FollowNotification,
        ...Keys.followNotification(targetId, now, notifId),
        targetId,
        fromUserId: auth.niarimUserId,
        fromUserName: follower?.channelName ?? auth.niarimUserId,
        read: false,
        createdAt: now,
        ttl: Math.floor(Date.now() / 1000) + NOTIFICATION_TTL_DAYS * 24 * 60 * 60,
      };

      await ddb.send(
        new TransactWriteCommand({
          TransactItems: [
            { Put: { TableName: tableName(), Item: followerRecord, ConditionExpression: 'attribute_not_exists(pk)' } },
            { Put: { TableName: tableName(), Item: followingRecord } },
            {
              Update: {
                TableName: tableName(),
                Key: Keys.user(targetId),
                UpdateExpression: 'ADD followerCount :plus',
                ExpressionAttributeValues: { ':plus': 1 },
              },
            },
            {
              Update: {
                TableName: tableName(),
                Key: Keys.user(auth.niarimUserId),
                UpdateExpression: 'ADD followingCount :plus',
                ExpressionAttributeValues: { ':plus': 1 },
              },
            },
            { Put: { TableName: tableName(), Item: notification } },
          ],
        }),
      );

      // 22.7節：アプリ内通知に加えて、実際のプッシュも送る。送信は
      // best-effortで、失敗してもフォロー操作自体は成功扱いにする
      // （push.ts側で例外を握り潰している）。FCMの鍵が未設定の環境では
      // 何もしないため、鍵が揃うまでこのままデプロイできる。
      await sendPushToUser(targetId, {
        title: 'NIARIM作品広場',
        body: `${notification.fromUserName}さんにフォローされました`,
        data: { type: 'follow', fromUserId: auth.niarimUserId },
      });
    }
  } catch (err) {
    if (err instanceof TransactionCanceledException) {
      return ok({ following: isFollowing, conflict: true });
    }
    throw err;
  }

  return ok({ following: !isFollowing });
}

/**
 * `GET /users/{id}/followers`（22.5・22.7節）。一覧を開けるのは本人か、
 * 対象ユーザーが公開設定にした場合のみ。さらに22.7節の対応：各
 * フォロワー自身が自分のフォロー中/フォロワー一覧を非公開にしている
 * 場合、そのフォロワーだけは一覧から除外する（本人の意思を優先。
 * targetの公開設定を上書きしない）。
 */
export async function getFollowers(event: APIGatewayProxyEventV2, targetId: string) {
  const caller = await tryAuthenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  await ensureCanViewList(caller?.niarimUserId, targetId);

  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: { ':pk': `USER#${targetId}`, ':prefix': 'FOLLOWER#' },
    }),
  );
  const records = (result.Items ?? []) as FollowerRecordItem[];

  const followerUsers = await Promise.all(
    records.map((r) => ddb.send(new GetCommand({ TableName: tableName(), Key: Keys.user(r.followerId) }))),
  );
  const visibleFollowers = followerUsers
    .map((u) => u.Item as UserItem | undefined)
    .filter((u): u is UserItem => u != null && u.followersPublic)
    .map((u) => ({ niarimUserId: u.niarimUserId, channelName: u.channelName, channelAvatarUrl: u.channelAvatarUrl }));

  return ok({
    targetId,
    totalCount: records.length, // 22.7節：数字は実数のまま公開する
    visibleFollowers,
    hiddenCount: records.length - visibleFollowers.length,
  });
}

/** `GET /users/{id}/following`（22.5節）。フォロー中一覧はこの修正の対象外（22.7節）。 */
export async function getFollowing(event: APIGatewayProxyEventV2, followerId: string) {
  const caller = await tryAuthenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  await ensureCanViewList(caller?.niarimUserId, followerId);

  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: { ':pk': `USER#${followerId}`, ':prefix': 'FOLLOWING#' },
    }),
  );
  const records = (result.Items ?? []) as FollowingRecordItem[];

  const targets = await Promise.all(
    records.map((r) => ddb.send(new GetCommand({ TableName: tableName(), Key: Keys.user(r.targetId) }))),
  );
  const following = targets
    .map((u) => u.Item as UserItem | undefined)
    .filter((u): u is UserItem => Boolean(u))
    .map((u) => ({ niarimUserId: u.niarimUserId, channelName: u.channelName, channelAvatarUrl: u.channelAvatarUrl }));

  return ok({ followerId, following });
}

async function ensureCanViewList(callerId: string | undefined, targetId: string): Promise<void> {
  if (callerId === targetId) return;
  const target = await getUser(targetId);
  if (!target?.followersPublic) forbidden('このユーザーはフォロー中/フォロワー一覧を公開していません');
}

/** `PATCH /users/{id}/follow-visibility`（22.5節）。本人のみ変更可。 */
export async function updateFollowVisibility(event: APIGatewayProxyEventV2, targetUserId: string) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  if (auth.niarimUserId !== targetUserId) forbidden('本人のみ変更できます');

  const body = parseJsonObject(event.body, { allowEmpty: true });
  if (typeof body.public !== 'boolean') badRequest('publicは真偽値で指定してください');
  await ddb.send(
    new UpdateCommand({
      TableName: tableName(),
      Key: Keys.user(targetUserId),
      UpdateExpression: 'SET followersPublic = :v',
      ExpressionAttributeValues: { ':v': body.public },
    }),
  );
  return ok({ followersPublic: body.public });
}
