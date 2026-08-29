import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { GetCommand, TransactWriteCommand } from '@aws-sdk/lib-dynamodb';
import { TransactionCanceledException } from '@aws-sdk/client-dynamodb';
import { ddb, tableName, Keys } from '../../lib/dynamo';
import { authenticate } from '../../lib/auth';
import { notFound, ok } from '../../lib/response';
import type { RepostItem } from '../../lib/types';
import { TABLE_ITEM_TYPE } from '../../lib/types';

/**
 * `POST /works/{id}/repost`（8.5bis節）。ブックマークと同じ
 * `TransactWriteItems`パターンで「リポスト記録の作成/削除」と
 * 「作品側repostCountの±1」をアトミックに行う。
 *
 * 自分自身が投稿した作品もリポスト可能（Task#134継続の仕様変更。
 * フォロワーへ改めて周知する用途を想定し、投稿者本人にも制限しない）。
 */
export async function toggleRepost(event: APIGatewayProxyEventV2, workId: string) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  const repostKey = Keys.repost(auth.niarimUserId, workId);
  const workKey = Keys.work(workId);

  const [existingRepost, existingWork] = await Promise.all([
    ddb.send(new GetCommand({ TableName: tableName(), Key: repostKey })),
    ddb.send(new GetCommand({ TableName: tableName(), Key: workKey })),
  ]);
  if (!existingWork.Item) notFound('作品が見つかりません');

  const isReposted = Boolean(existingRepost.Item);
  const now = new Date().toISOString();

  try {
    if (isReposted) {
      await ddb.send(
        new TransactWriteCommand({
          TransactItems: [
            { Delete: { TableName: tableName(), Key: repostKey, ConditionExpression: 'attribute_exists(pk)' } },
            {
              Update: {
                TableName: tableName(),
                Key: workKey,
                UpdateExpression: 'ADD repostCount :minus',
                ConditionExpression: 'repostCount > :zero',
                ExpressionAttributeValues: { ':minus': -1, ':zero': 0 },
              },
            },
          ],
        }),
      );
    } else {
      const repost: RepostItem = {
        itemType: TABLE_ITEM_TYPE.Repost,
        ...repostKey,
        niarimUserId: auth.niarimUserId,
        workId,
        repostedAt: now,
      };
      await ddb.send(
        new TransactWriteCommand({
          TransactItems: [
            { Put: { TableName: tableName(), Item: repost, ConditionExpression: 'attribute_not_exists(pk)' } },
            {
              Update: {
                TableName: tableName(),
                Key: workKey,
                UpdateExpression: 'ADD repostCount :plus',
                ExpressionAttributeValues: { ':plus': 1 },
              },
            },
          ],
        }),
      );
    }
  } catch (err) {
    if (err instanceof TransactionCanceledException) {
      return ok({ reposted: isReposted, conflict: true });
    }
    throw err;
  }

  return ok({ reposted: !isReposted });
}
