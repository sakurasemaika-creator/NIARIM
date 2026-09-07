import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate } from "../../lib/auth";
import { badRequest, forbidden, notFound, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import type { WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

interface UpdateWorkRequestBody {
  isNiarimPublished?: boolean;
  title?: string;
}

/**
 * `PATCH /works/{id}`（13章：NIARIM側の公開/非公開切り替え・メタデータ
 * 編集）。投稿枠は消費しない（`videos.insert`を使わないため）。
 *
 * 公開/非公開の切り替えは、GSI1/2/3/4のソートキー属性
 * （gsi1sk/gsi2sk/gsi3sk/gsi4sk）を書き込む/削除することで、8.2節の
 * 「GSIにソートキー属性が無ければそのGSIから除外される」性質を使う。
 * ただしYouTube側が非公開・削除の場合（youtubePrivacyStatusが
 * 'private'/'deleted'）は、NIARIM側の設定に関わらず強制非表示のままに
 * する（13章の状態表）。
 */
export async function updateWork(
  event: APIGatewayProxyEventV2,
  workId: string,
) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const body = parseBody(event.body);

  // Visibility PATCH is safely retried by the app when the response is lost.
  // Use a strongly consistent read so a retry always converges from the latest Work
  // state instead of rebuilding public indexes from a potentially stale snapshot.
  const existing = await ddb.send(
    new GetCommand({
      TableName: tableName(),
      Key: Keys.work(workId),
      ConsistentRead: true,
    }),
  );
  const raw = existing.Item;
  if (!raw || raw.itemType !== TABLE_ITEM_TYPE.Work) {
    notFound("作品が見つかりません");
  }
  const work = raw as WorkItem;
  if (work.authorId !== auth.niarimUserId)
    forbidden("この作品の投稿者本人のみ編集できます");

  const nextPublished = body.isNiarimPublished ?? work.isNiarimPublished;
  const forcedHidden =
    work.youtubePrivacyStatus === "private" ||
    work.youtubePrivacyStatus === "deleted";
  const nowVisible = nextPublished && !forcedHidden;

  const updates: string[] = ["isNiarimPublished = :pub"];
  const values: Record<string, unknown> = {
    ":pub": nextPublished,
    ":workType": TABLE_ITEM_TYPE.Work,
    ":authorId": auth.niarimUserId,
  };
  const removes: string[] = [];

  if (body.title !== undefined) {
    updates.push("title = :title");
    values[":title"] = body.title;
  }

  if (nowVisible) {
    updates.push(
      "gsi1pk = :rankPk, gsi1sk = :score, gsi2pk = :bmPk, gsi2sk = :bm, gsi3pk = :authorPk, gsi3sk = :postedAt, gsi4pk = :latestPk, gsi4sk = :postedAt2",
    );
    values[":rankPk"] = "RANKING#ALL";
    values[":score"] = work.rankingScore ?? 0;
    values[":bmPk"] = "BOOKMARK_RANKING";
    values[":bm"] = work.bookmarkCount;
    values[":authorPk"] = `AUTHOR#${work.authorId}`;
    values[":postedAt"] = work.postedAt;
    values[":latestPk"] = "LATEST";
    values[":postedAt2"] = work.postedAt;
  } else {
    removes.push(
      "gsi1pk",
      "gsi1sk",
      "gsi2pk",
      "gsi2sk",
      "gsi3pk",
      "gsi3sk",
      "gsi4pk",
      "gsi4sk",
    );
  }

  const updateExpression =
    `SET ${updates.join(", ")}` +
    (removes.length ? ` REMOVE ${removes.join(", ")}` : "");

  try {
    const result = await ddb.send(
      new UpdateCommand({
        TableName: tableName(),
        Key: Keys.work(workId),
        UpdateExpression: updateExpression,
        ConditionExpression: "itemType = :workType AND authorId = :authorId",
        ExpressionAttributeValues: values,
        ReturnValues: "ALL_NEW",
      }),
    );

    return ok({ work: toPublicWork(result.Attributes as WorkItem) });
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) {
      notFound("作品が見つかりません");
    }
    throw error;
  }
}

function parseBody(raw: string | undefined): UpdateWorkRequestBody {
  const body = parseJsonObject(raw, { allowEmpty: true });
  if (
    body.isNiarimPublished !== undefined &&
    typeof body.isNiarimPublished !== "boolean"
  ) {
    badRequest("isNiarimPublishedは真偽値である必要があります");
  }
  if (
    body.title !== undefined &&
    (typeof body.title !== "string" ||
      !body.title.trim() ||
      body.title.trim().length > 200)
  ) {
    badRequest("titleは1〜200文字である必要があります");
  }
  return {
    isNiarimPublished: body.isNiarimPublished as boolean | undefined,
    title: typeof body.title === "string" ? body.title.trim() : undefined,
  };
}
