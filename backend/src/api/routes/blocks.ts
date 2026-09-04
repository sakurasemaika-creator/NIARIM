import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { PutCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate } from "../../lib/auth";
import { badRequest, created } from "../../lib/response";
import { parseJsonObject } from "../../lib/request";
import type { BlockItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";

interface CreateBlockRequestBody {
  blockedUserId: string;
}

/**
 * `POST /blocks`（9章）。ブロックはログイン必須。ブロックした相手の
 * 作品をNIARIM内の一覧・ランキングから自分に対してのみ非表示にする
 * （相手への通知・メッセージ送信は発生しない、端末/アカウント側の
 * ローカルなフィルタリング。22.2節の届出義務の境界の内側）。
 *
 * 実際のフィルタリングは各一覧系エンドポイント（ranking.ts・
 * worksLatest.ts等）で、呼び出し元が自分のブロック一覧を別途取得し
 * クライアント側で除外するか、`GET`系エンドポイントに
 * `blockerId`クエリパラメータを付けてLambda側で除外する方式のいずれか
 * を想定する（初期実装ではクライアント側フィルタで十分。ブロック件数は
 * 通常少数のため一覧取得APIのレスポンスサイズへの影響は小さい）。
 */
export async function createBlock(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const body = parseBody(event.body);

  if (body.blockedUserId === auth.niarimUserId) {
    badRequest("自分自身をブロックすることはできません");
  }

  const now = new Date().toISOString();
  const block: BlockItem = {
    itemType: TABLE_ITEM_TYPE.Block,
    ...Keys.block(auth.niarimUserId, body.blockedUserId),
    blockerId: auth.niarimUserId,
    blockedId: body.blockedUserId,
    createdAt: now,
  };

  await ddb.send(new PutCommand({ TableName: tableName(), Item: block }));
  return created({ ok: true });
}

function parseBody(raw: string | undefined): CreateBlockRequestBody {
  const body = parseJsonObject(raw);
  if (
    typeof body.blockedUserId !== "string" ||
    !/^N[0-9a-f]{32}$/.test(body.blockedUserId)
  ) {
    badRequest("blockedUserIdの形式が不正です");
  }
  return { blockedUserId: body.blockedUserId };
}
