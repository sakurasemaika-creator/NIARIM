import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate } from "../../lib/auth";
import { deleteVideo } from "../../lib/youtube";
import { forbidden, notFound, noContent, badRequest } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import type { WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";

interface DeleteWorkRequestBody {
  deleteYoutubeVideo?: boolean;
  youtubeAccessToken?: string; // deleteYoutubeVideo=trueのときのみ必須
}

/**
 * `DELETE /works/{id}`（13章）。NIARIM側の作品を削除する。
 * `deleteYoutubeVideo: true`が指定された場合のみYouTube側も削除する
 * （13章の機能表「NIARIM内からYouTube動画を削除」に対応。ユーザーの
 * 明示的な希望が無い限りYouTube動画本体は残す）。
 *
 * WorkItemを物理削除すると、ユーザー側PKに残るブックマーク/リポスト記録が
 * 後日同じyoutubeVideoIdを再登録した作品へ再接続し、削除前の状態が復活して
 * しまう。リポストには作品→利用者の逆引きGSIが無いため、全関連記録をScan
 * してカスケード削除するより、同じWORKキーを小さな墓標へ置換する。
 * 墓標はitemTypeがWORKではなくGSI属性も持たないので、一覧・ランキング・
 * 統計更新からは除外される。一方workIdは占有し続け、再登録を防げる。
 *
 * 投稿枠は戻らない（12.1節：削除しても消費済みの投稿枠は復活しない）。
 */
export async function deleteWork(
  event: APIGatewayProxyEventV2,
  workId: string,
) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const body = parseBody(event.body);

  const existing = await ddb.send(
    new GetCommand({ TableName: tableName(), Key: Keys.work(workId) }),
  );
  const raw = existing.Item;
  if (!raw || raw.itemType !== TABLE_ITEM_TYPE.Work) {
    notFound("作品が見つかりません");
  }
  const work = raw as WorkItem;
  if (work.authorId !== auth.niarimUserId)
    forbidden("この作品の投稿者本人のみ削除できます");

  if (body.deleteYoutubeVideo) {
    if (!body.youtubeAccessToken)
      badRequest("YouTube動画も削除する場合はyoutubeAccessTokenが必要です");
    await deleteVideo(work.youtubeVideoId, body.youtubeAccessToken);
  }

  const key = Keys.work(workId);
  try {
    await ddb.send(
      new PutCommand({
        TableName: tableName(),
        Item: {
          ...key,
          itemType: "WORK_TOMBSTONE",
          workId,
          deletedAt: new Date().toISOString(),
        },
        // Get後に別処理で既に削除/置換されていた場合、古い操作で墓標を
        // 上書きし直さない。作者本人の現在のWorkItemであることも再確認する。
        ConditionExpression: "itemType = :workType AND authorId = :authorId",
        ExpressionAttributeValues: {
          ":workType": TABLE_ITEM_TYPE.Work,
          ":authorId": auth.niarimUserId,
        },
      }),
    );
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) {
      notFound("作品が見つかりません");
    }
    throw error;
  }

  return noContent();
}

function parseBody(raw: string | undefined): DeleteWorkRequestBody {
  const body = parseJsonObject(raw, { allowEmpty: true });
  if (
    body.deleteYoutubeVideo !== undefined &&
    typeof body.deleteYoutubeVideo !== "boolean"
  ) {
    badRequest("deleteYoutubeVideoは真偽値である必要があります");
  }
  if (
    body.youtubeAccessToken !== undefined &&
    (typeof body.youtubeAccessToken !== "string" ||
      body.youtubeAccessToken.length > 4096)
  ) {
    badRequest("youtubeAccessTokenの形式が不正です");
  }
  return {
    deleteYoutubeVideo: body.deleteYoutubeVideo as boolean | undefined,
    youtubeAccessToken: body.youtubeAccessToken as string | undefined,
  };
}
