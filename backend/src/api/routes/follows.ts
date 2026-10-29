import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  GetCommand,
  QueryCommand,
  TransactWriteCommand,
} from "@aws-sdk/lib-dynamodb";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate, getUser } from "../../lib/auth";
import { badRequest, forbidden, ok } from "../../lib/response";
import type {
  FollowerRecordItem,
  FollowingRecordItem,
} from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";

/**
 * `POST /users/{id}/follow`（22.5節）。フォロー/解除の操作ごとに
 * `TransactWriteItems`で「被フォロー側記録（FollowerRecord）」
 * 「フォロー側記録（FollowingRecord、二重書き込みでO(1)クエリ可能に
 * する）」「両ユーザーのfollowerCount/followingCountカウンター」を
 * まとめて更新する。通知用の個別フォローイベントは保存しない。
 */
export async function toggleFollow(
  event: APIGatewayProxyEventV2,
  targetId: string,
) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (auth.niarimUserId === targetId)
    badRequest("自分自身をフォローすることはできません");

  const followerKey = Keys.followerRecord(targetId, auth.niarimUserId);
  const existing = await ddb.send(
    new GetCommand({ TableName: tableName(), Key: followerKey }),
  );
  const isFollowing = Boolean(existing.Item);
  const now = new Date().toISOString();

  try {
    if (isFollowing) {
      await ddb.send(
        new TransactWriteCommand({
          TransactItems: [
            {
              Delete: {
                TableName: tableName(),
                Key: followerKey,
                ConditionExpression: "attribute_exists(pk)",
              },
            },
            {
              Delete: {
                TableName: tableName(),
                Key: Keys.followingRecord(auth.niarimUserId, targetId),
              },
            },
            {
              Update: {
                TableName: tableName(),
                Key: Keys.user(targetId),
                UpdateExpression: "ADD followerCount :minus",
                ConditionExpression: "followerCount > :zero",
                ExpressionAttributeValues: { ":minus": -1, ":zero": 0 },
              },
            },
            {
              Update: {
                TableName: tableName(),
                Key: Keys.user(auth.niarimUserId),
                UpdateExpression: "ADD followingCount :minus",
                ConditionExpression: "followingCount > :zero",
                ExpressionAttributeValues: { ":minus": -1, ":zero": 0 },
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

      await ddb.send(
        new TransactWriteCommand({
          TransactItems: [
            {
              Put: {
                TableName: tableName(),
                Item: followerRecord,
                ConditionExpression: "attribute_not_exists(pk)",
              },
            },
            { Put: { TableName: tableName(), Item: followingRecord } },
            {
              Update: {
                TableName: tableName(),
                Key: Keys.user(targetId),
                UpdateExpression: "ADD followerCount :plus",
                ExpressionAttributeValues: { ":plus": 1 },
              },
            },
            {
              Update: {
                TableName: tableName(),
                Key: Keys.user(auth.niarimUserId),
                UpdateExpression: "ADD followingCount :plus",
                ExpressionAttributeValues: { ":plus": 1 },
              },
            },
          ],
        }),
      );


    }
  } catch (err) {
    if (err instanceof TransactionCanceledException) {
      return ok({ following: isFollowing, conflict: true });
    }
    throw err;
  }

  return ok({ following: !isFollowing });
}

/** Public numerical counts only: never return follower or following identities. */
export async function getSocialCounts(
  _event: APIGatewayProxyEventV2,
  targetId: string,
) {
  const user = await getUser(targetId);
  return ok({
    followerCount: user?.followerCount ?? 0,
    followingCount: user?.followingCount ?? 0,
  });
}

/** `GET /users/{id}/following`（22.5節）。フォロー中一覧はこの修正の対象外（22.7節）。 */
export async function getFollowing(
  event: APIGatewayProxyEventV2,
  followerId: string,
) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (auth.niarimUserId !== followerId) {
    forbidden("自分がフォロー中のデータのみ取得できます");
  }

  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      KeyConditionExpression: "pk = :pk AND begins_with(sk, :prefix)",
      ExpressionAttributeValues: {
        ":pk": `USER#${followerId}`,
        ":prefix": "FOLLOWING#",
      },
    }),
  );
  const records = (result.Items ?? []) as FollowingRecordItem[];

  const targets = await Promise.all(
    records.map((r) =>
      ddb.send(
        new GetCommand({ TableName: tableName(), Key: Keys.user(r.targetId) }),
      ),
    ),
  );
  const following = targets
    .map((u) => u.Item as UserItem | undefined)
    .filter((u): u is UserItem => Boolean(u))
    .map((u) => ({
      niarimUserId: u.niarimUserId,
      channelName: u.channelName,
      channelAvatarUrl: u.channelAvatarUrl,
    }));

  return ok({ followerId, following });
}

