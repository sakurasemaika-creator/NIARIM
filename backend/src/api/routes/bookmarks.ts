import type { APIGatewayProxyEventV2 } from "aws-lambda";
import {
  GetCommand,
  QueryCommand,
  TransactWriteCommand,
  UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate, tryAuthenticate, getUser } from "../../lib/auth";
import { badRequest, forbidden, notFound, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import type { BookmarkItem, WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

/**
 * `POST /works/{id}/bookmark`（8.5節）。ブックマーク/解除の操作ごとに
 * `TransactWriteItems`で「ユーザー別ブックマーク記録の作成/削除」と
 * 「作品側bookmarkCountの±1」をアトミックに行う。記録の存在チェック
 * （ConditionExpression）により、同一ユーザーが同じ作品を二重に
 * ブックマークしてカウントがずれることを防ぐ。
 */
export async function toggleBookmark(
  event: APIGatewayProxyEventV2,
  workId: string,
) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const bookmarkKey = Keys.bookmark(auth.niarimUserId, workId);
  const workKey = Keys.work(workId);

  const [existingBookmark, existingWork] = await Promise.all([
    ddb.send(new GetCommand({ TableName: tableName(), Key: bookmarkKey })),
    ddb.send(new GetCommand({ TableName: tableName(), Key: workKey })),
  ]);
  const work = existingWork.Item as WorkItem | undefined;
  if (!work) notFound("作品が見つかりません");
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
                ConditionExpression: "attribute_exists(pk)",
              },
            },
            {
              Update: {
                TableName: tableName(),
                Key: workKey,
                UpdateExpression: isVisible
                  ? "ADD bookmarkCount :minus, gsi2sk :minus"
                  : "ADD bookmarkCount :minus",
                ConditionExpression: "bookmarkCount > :zero",
                ExpressionAttributeValues: { ":minus": -1, ":zero": 0 },
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
                ConditionExpression: "attribute_not_exists(pk)",
              },
            },
            {
              Update: {
                TableName: tableName(),
                Key: workKey,
                UpdateExpression: isVisible
                  ? "ADD bookmarkCount :plus, gsi2sk :plus"
                  : "ADD bookmarkCount :plus",
                ExpressionAttributeValues: { ":plus": 1 },
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
export async function getUserBookmarks(
  event: APIGatewayProxyEventV2,
  targetUserId: string,
) {
  const caller = await tryAuthenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const isSelf = caller?.niarimUserId === targetUserId;

  if (!isSelf) {
    const targetUser = await getUser(targetUserId);
    const isPublic = targetUser?.bookmarksPublic ?? bookmarksVisibilityDefault;
    if (!isPublic)
      forbidden("このユーザーはブックマーク一覧を公開していません");
  }

  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      KeyConditionExpression: "pk = :pk AND begins_with(sk, :prefix)",
      ExpressionAttributeValues: {
        ":pk": `USER#${targetUserId}`,
        ":prefix": "BOOKMARK#",
      },
      ScanIndexForward: false,
    }),
  );
  const bookmarks = (result.Items ?? []) as BookmarkItem[];

  const works = await Promise.all(
    bookmarks.map((b) =>
      ddb.send(
        new GetCommand({ TableName: tableName(), Key: Keys.work(b.workId) }),
      ),
    ),
  );
  const publicWorks = works
    .map((w) => w.Item as WorkItem | undefined)
    .filter((w): w is WorkItem => Boolean(w))
    .map(toPublicWork);

  return ok({ userId: targetUserId, works: publicWorks });
}

/** `PATCH /users/{id}/bookmarks-visibility`（8.5節）。本人のみ変更可。 */
export async function updateBookmarksVisibility(
  event: APIGatewayProxyEventV2,
  targetUserId: string,
) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  if (auth.niarimUserId !== targetUserId) forbidden("本人のみ変更できます");

  const body = parseJsonObject(event.body, { allowEmpty: true });
  if (typeof body.public !== "boolean")
    badRequest("publicは真偽値で指定してください");
  await ddb.send(
    new UpdateCommand({
      TableName: tableName(),
      Key: Keys.user(targetUserId),
      UpdateExpression: "SET bookmarksPublic = :v",
      ExpressionAttributeValues: { ":v": body.public },
    }),
  );
  return ok({ bookmarksPublic: body.public });
}

/**
 * `GET /works/{id}/bookmarkers`（21.1節：被ブックマーク一覧）。
 *
 * BookmarkItemに張ってあるGSI5（`WORKBOOKMARKS#{workId}`）を引き、その
 * 作品をブックマークしたユーザーを新しい順に返す。これまでGSI5は
 * 書き込むだけで誰も読んでいなかったため、CDKスタック側にもインデックス
 * 自体が作られていなかった（今回追加した）。
 *
 * プライバシーの扱い：ブックマーク一覧を非公開にしているユーザー
 * （`bookmarksPublic = false`、既定値）は、その人が誰を/何をブックマーク
 * したかを他人に見せない設定なので、この一覧からも除外する。除外しても
 * 総数（`totalCount`）には数えるため、作者は「何人にブックマークされたか」
 * は分かる。呼び出し本人は公開設定に関わらず自分自身を見られる。
 */
export async function getWorkBookmarkers(
  event: APIGatewayProxyEventV2,
  workId: string,
) {
  const caller = await tryAuthenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );

  const workResult = await ddb.send(
    new GetCommand({ TableName: tableName(), Key: Keys.work(workId) }),
  );
  const work = workResult.Item as WorkItem | undefined;
  if (!work) notFound("作品が見つかりません");

  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      IndexName: "GSI5",
      KeyConditionExpression: "gsi5pk = :pk",
      ExpressionAttributeValues: { ":pk": `WORKBOOKMARKS#${workId}` },
      ScanIndexForward: false, // 新しい順
      Limit: BOOKMARKERS_PAGE_LIMIT,
    }),
  );
  const bookmarks = (result.Items ?? []) as BookmarkItem[];

  const users = await Promise.all(
    bookmarks.map((b) => getUser(b.niarimUserId)),
  );
  const visible = bookmarks
    .map((bookmark, i) => ({ bookmark, user: users[i] }))
    .filter(({ bookmark, user }) => {
      if (caller?.niarimUserId === bookmark.niarimUserId) return true;
      return user?.bookmarksPublic ?? bookmarksVisibilityDefault;
    })
    .map(({ bookmark, user }) => ({
      userId: bookmark.niarimUserId,
      channelName: user?.channelName ?? null,
      channelAvatarUrl: user?.channelAvatarUrl ?? null,
      bookmarkedAt: bookmark.bookmarkedAt,
    }));

  return ok({
    workId,
    // 作品側が持つ集計値。非公開設定のユーザーぶんも含んだ総数。
    totalCount: work.bookmarkCount,
    // 公開設定にしているユーザーだけを並べたもの。totalCountより少なくなり得る。
    users: visible,
  });
}

/** 被ブックマーク一覧の1ページ件数。 */
const BOOKMARKERS_PAGE_LIMIT = 100;
