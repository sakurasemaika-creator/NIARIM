import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { GetCommand, QueryCommand, TransactWriteCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { TransactionCanceledException } from '@aws-sdk/client-dynamodb';
import { ddb, tableName, Keys } from '../../lib/dynamo';
import { authenticate, tryAuthenticate, getUser } from '../../lib/auth';
import { badRequest, forbidden, notFound, ok } from '../../lib/response';
import { parseJsonObject } from '../../lib/request';
import type { BookmarkItem, WorkItem } from '../../lib/types';
import { TABLE_ITEM_TYPE } from '../../lib/types';
import { toPublicWork } from './_publicWork';

/**
 * `POST /works/{id}/bookmark`（8.5節）。ブックマーク/解除の操作ごとに
 * `TransactWriteItems`で「ユーザー別ブックマーク記録の作成/削除」と
 * 「作品側bookmarkCountの±1」をアトミックに行う。記録の存在チェック
 * （ConditionExpression）により、同一ユーザーが同じ作品を二重に
 * ブックマークしてカウントがずれることを防ぐ。
 */
export async function toggleBookmark(event: APIGatewayProxyEventV2, workId: string) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  const bookmarkKey = Keys.bookmark(auth.niarimUserId, workId);
  const workKey = Keys.work(workId);

  const [existingBookmark, existingWork] = await Promise.all([
    ddb.send(new GetCommand({ TableName: tableName(), Key: bookmarkKey })),
    ddb.send(new GetCommand({ TableName: tableName(), Key: workKey })),
  ]);
  const work = existingWork.Item as WorkItem | undefined;
  if (!work) notFound('作品が見つかりません');
  const isVisible = Boolean(work.gsi2pk);

  const now = new Date().toISOString();
  const isBookmarked = Boolean(existingBookmark.Item);

  try {
    if (isBookmarked) {
      await ddb.send(
        new TransactWriteCommand({
          TransactItems: [
            {
              Delete: {
                TableName: tableName(),
                Key: bookmarkKey,
                ConditionExpression: 'attribute_exists(pk)',
              },
            },
            {
              Update: {
                TableName: tableName(),
                Key: workKey,
                UpdateExpression: isVisible
                  ? 'ADD bookmarkCount :minus, gsi2sk :minus'
                  : 'ADD bookmarkCount :minus',
                ConditionExpression: 'bookmarkCount > :zero',
                ExpressionAttributeValues: { ':minus': -1, ':zero': 0 },
              },
            },
          ],
        }),
      );
    } else {
      const bookmark: BookmarkItem = {
        itemType: TABLE_ITEM_TYPE.Bookmark,
        ...bookmarkKey,
        niarimUserId: auth.niarimUserId,
        workId,
        bookmarkedAt: now,
        gsi5pk: `WORKBOOKMARKS#${workId}`,
        gsi5sk: now,
      };
      await ddb.send(
        new TransactWriteCommand({
          TransactItems: [
            {
              Put: {
                TableName: tableName(),
                Item: bookmark,
                ConditionExpression: 'attribute_not_exists(pk)',
              },
            },
            {
              Update: {
                TableName: tableName(),
                Key: workKey,
                UpdateExpression: isVisible
                  ? 'ADD bookmarkCount :plus, gsi2sk :plus'
                  : 'ADD bookmarkCount :plus',
                ExpressionAttributeValues: { ':plus': 1 },
              },
            },
          ],
        }),
      );
    }
  } catch (err) {
    if (err instanceof TransactionCanceledException) {
      // 直前のGetCommandと実際の書き込みの間に競合が起きたケース
      // （同時に二重タップされた等）。呼び出し元には現在の状態を
      // 返し、ユーザーには再操作を促す想定。
      return ok({ bookmarked: isBookmarked, conflict: true });
    }
    throw err;
  }

  return ok({ bookmarked: !isBookmarked });
}

const bookmarksVisibilityDefault = false;

/**
 * `GET /users/{id}/bookmarks`（8.5節・21.2節）。非公開の場合は403で
 * 拒否する。本人自身が見る場合は公開設定に関わらず常に見られる。
 */
export async function getUserBookmarks(event: APIGatewayProxyEventV2, targetUserId: string) {
  const caller = await tryAuthenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  const isSelf = caller?.niarimUserId === targetUserId;

  if (!isSelf) {
    const targetUser = await getUser(targetUserId);
    const isPublic = targetUser?.bookmarksPublic ?? bookmarksVisibilityDefault;
    if (!isPublic) forbidden('このユーザーはブックマーク一覧を公開していません');
  }

  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: { ':pk': `USER#${targetUserId}`, ':prefix': 'BOOKMARK#' },
      ScanIndexForward: false,
    }),
  );
  const bookmarks = (result.Items ?? []) as BookmarkItem[];

  const works = await Promise.all(
    bookmarks.map((b) => ddb.send(new GetCommand({ TableName: tableName(), Key: Keys.work(b.workId) }))),
  );
  const publicWorks = works
    .map((w) => w.Item as WorkItem | undefined)
    .filter((w): w is WorkItem => Boolean(w))
    .map(toPublicWork);

  return ok({ userId: targetUserId, works: publicWorks });
}

/** `PATCH /users/{id}/bookmarks-visibility`（8.5節）。本人のみ変更可。 */
export async function updateBookmarksVisibility(event: APIGatewayProxyEventV2, targetUserId: string) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  if (auth.niarimUserId !== targetUserId) forbidden('本人のみ変更できます');

  const body = parseJsonObject(event.body, { allowEmpty: true });
  if (typeof body.public !== 'boolean') badRequest('publicは真偽値で指定してください');
  await ddb.send(
    new UpdateCommand({
      TableName: tableName(),
      Key: Keys.user(targetUserId),
      UpdateExpression: 'SET bookmarksPublic = :v',
      ExpressionAttributeValues: { ':v': body.public },
    }),
  );
  return ok({ bookmarksPublic: body.public });
}
