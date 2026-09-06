import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { ConditionalCheckFailedException } from "@aws-sdk/client-dynamodb";
import { GetCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate } from "../../lib/auth";
import { badRequest, forbidden, notFound, ok } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import type { WorkItem } from "../../lib/types";
import { toPublicWork } from "./_publicWork";

type TagAction =
  | { action: "add"; tag: string }
  | { action: "remove"; tag: string }
  | { action: "lock"; tag: string }
  | { action: "unlock"; tag: string };

const MAX_TAG_LENGTH = 30;
const MAX_TAGS_PER_WORK = 10;
const MAX_CONFLICT_RETRIES = 3;

/**
 * `PATCH /works/{id}/tags`。
 *
 * 追加/未ロックタグ削除はログイン済みユーザーなら誰でも可能。
 * lock/unlockは作者本人のみ。ロック済みタグは作者を含め直接削除できない。
 *
 * 誰でも編集できるため、単純な「Get → 配列全体SET」では同時操作時に
 * 後勝ちで片方の編集を消してしまう。そこで取得時のtags/lockedTagsを
 * ConditionExpressionで比較し、競合した場合だけ最新状態を再取得して
 * 最大3回再試行する。通常時のリクエスト数は従来と同じで、競合時だけ
 * 追加のGet/Updateが発生する。
 */
export async function updateTags(
  event: APIGatewayProxyEventV2,
  workId: string,
) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const body = parseBody(event.body);

  for (let attempt = 0; attempt < MAX_CONFLICT_RETRIES; attempt++) {
    const existing = await ddb.send(
      new GetCommand({ TableName: tableName(), Key: Keys.work(workId) }),
    );
    const work = existing.Item as WorkItem | undefined;
    if (!work) notFound("作品が見つかりません");

    const isOwner = work.authorId === auth.niarimUserId;
    if ((body.action === "lock" || body.action === "unlock") && !isOwner) {
      forbidden("タグのロック操作は投稿者本人のみ行えます");
    }
    if (body.action === "remove" && work.lockedTags.includes(body.tag)) {
      forbidden("ロックされているタグは削除できません");
    }

    let tags = work.tags;
    let lockedTags = work.lockedTags;

    switch (body.action) {
      case "add":
        if (!tags.includes(body.tag)) {
          if (tags.length >= MAX_TAGS_PER_WORK) {
            badRequest(
              `タグは1作品につき${MAX_TAGS_PER_WORK}件までです`,
              "TAG_LIMIT_EXCEEDED",
            );
          }
          tags = [...tags, body.tag];
        }
        break;
      case "remove":
        tags = tags.filter((t) => t !== body.tag);
        lockedTags = lockedTags.filter((t) => t !== body.tag);
        break;
      case "lock":
        if (!tags.includes(body.tag)) {
          badRequest("存在しないタグはロックできません");
        }
        if (!lockedTags.includes(body.tag)) {
          lockedTags = [...lockedTags, body.tag];
        }
        break;
      case "unlock":
        lockedTags = lockedTags.filter((t) => t !== body.tag);
        break;
    }

    try {
      const result = await ddb.send(
        new UpdateCommand({
          TableName: tableName(),
          Key: Keys.work(workId),
          UpdateExpression: "SET tags = :tags, lockedTags = :lockedTags",
          ConditionExpression:
            "tags = :expectedTags AND lockedTags = :expectedLockedTags",
          ExpressionAttributeValues: {
            ":tags": tags,
            ":lockedTags": lockedTags,
            ":expectedTags": work.tags,
            ":expectedLockedTags": work.lockedTags,
          },
          ReturnValues: "ALL_NEW",
        }),
      );

      return ok({ work: toPublicWork(result.Attributes as WorkItem) });
    } catch (error) {
      if (
        error instanceof ConditionalCheckFailedException &&
        attempt + 1 < MAX_CONFLICT_RETRIES
      ) {
        continue;
      }
      throw error;
    }
  }

  // ループ上は到達しないが、TypeScriptに全経路のreturnを明示する。
  throw new Error("タグ更新の競合再試行に失敗しました");
}

function parseBody(raw: string | undefined): TagAction {
  const body = parseJsonObject(raw);
  if (!body.tag || typeof body.tag !== "string" || !body.tag.trim()) {
    badRequest("tagは必須です");
  }
  if (body.tag.trim().length > MAX_TAG_LENGTH) {
    badRequest(`タグは${MAX_TAG_LENGTH}文字以内にしてください`, "TAG_TOO_LONG");
  }
  if (
    typeof body.action !== "string" ||
    !["add", "remove", "lock", "unlock"].includes(body.action)
  ) {
    badRequest("actionはadd/remove/lock/unlockのいずれかである必要があります");
  }
  const tag = body.tag.trim();
  return { action: body.action, tag } as TagAction;
}
