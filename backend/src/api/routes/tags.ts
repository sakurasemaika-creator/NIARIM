import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { GetCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName, Keys } from '../../lib/dynamo';
import { authenticate } from '../../lib/auth';
import { badRequest, forbidden, notFound, ok } from '../../lib/response';
import type { WorkItem } from '../../lib/types';
import { toPublicWork } from './_publicWork';

type TagAction =
  | { action: 'add'; tag: string }
  | { action: 'remove'; tag: string }
  | { action: 'lock'; tag: string }
  | { action: 'unlock'; tag: string };

/**
 * `PATCH /works/{id}/tags`（8.7節）。誰でもタグを追加・削除できるが、
 * ロック中のタグは削除できない。ロック/解除の操作は投稿者本人のみ
 * （書き込み系エンドポイント共通のNIARIM User ID検証、16章）。
 *
 * 楽観的な二重更新対策として、DynamoDBの`ConditionExpression`は使わず
 * `UpdateItem`の`list_append`/フィルタで冪等に処理する（8.7節の
 * 「リアルタイム同期は必須としない」という方針どおり、最終的な状態が
 * 正しければよい設計）。
 */
export async function updateTags(event: APIGatewayProxyEventV2, workId: string) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  const body = parseBody(event.body);

  const existing = await ddb.send(new GetCommand({ TableName: tableName(), Key: Keys.work(workId) }));
  const work = existing.Item as WorkItem | undefined;
  if (!work) notFound('作品が見つかりません');

  const isOwner = work.authorId === auth.niarimUserId;
  if ((body.action === 'lock' || body.action === 'unlock') && !isOwner) {
    forbidden('タグのロック操作は投稿者本人のみ行えます');
  }
  if (body.action === 'remove' && work.lockedTags.includes(body.tag)) {
    forbidden('ロックされているタグは削除できません');
  }

  let tags = work.tags;
  let lockedTags = work.lockedTags;

  switch (body.action) {
    case 'add':
      if (!tags.includes(body.tag)) tags = [...tags, body.tag];
      break;
    case 'remove':
      tags = tags.filter((t) => t !== body.tag);
      lockedTags = lockedTags.filter((t) => t !== body.tag);
      break;
    case 'lock':
      if (!tags.includes(body.tag)) badRequest('存在しないタグはロックできません');
      if (!lockedTags.includes(body.tag)) lockedTags = [...lockedTags, body.tag];
      break;
    case 'unlock':
      lockedTags = lockedTags.filter((t) => t !== body.tag);
      break;
  }

  const result = await ddb.send(
    new UpdateCommand({
      TableName: tableName(),
      Key: Keys.work(workId),
      UpdateExpression: 'SET tags = :tags, lockedTags = :lockedTags',
      ExpressionAttributeValues: { ':tags': tags, ':lockedTags': lockedTags },
      ReturnValues: 'ALL_NEW',
    }),
  );

  return ok({ work: toPublicWork(result.Attributes as WorkItem) });
}

function parseBody(raw: string | undefined): TagAction {
  if (!raw) badRequest('リクエストボディが空です');
  let body: Partial<TagAction>;
  try {
    body = JSON.parse(raw);
  } catch {
    badRequest('リクエストボディがJSONとして不正です');
  }
  if (!body.tag || typeof body.tag !== 'string' || !body.tag.trim()) {
    badRequest('tagは必須です');
  }
  if (!body.action || !['add', 'remove', 'lock', 'unlock'].includes(body.action)) {
    badRequest('actionはadd/remove/lock/unlockのいずれかである必要があります');
  }
  return { action: body.action, tag: body.tag.trim() } as TagAction;
}
