import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { GetCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName, Keys } from '../../lib/dynamo';
import { authenticate } from '../../lib/auth';
import { badRequest, forbidden, notFound, ok } from '../../lib/response';
import type { WorkItem } from '../../lib/types';
import { toPublicWork } from './_publicWork';

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
export async function updateWork(event: APIGatewayProxyEventV2, workId: string) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  const body = parseBody(event.body);

  const existing = await ddb.send(new GetCommand({ TableName: tableName(), Key: Keys.work(workId) }));
  const work = existing.Item as WorkItem | undefined;
  if (!work) notFound('作品が見つかりません');
  if (work.authorId !== auth.niarimUserId) forbidden('この作品の投稿者本人のみ編集できます');

  const nextPublished = body.isNiarimPublished ?? work.isNiarimPublished;
  const forcedHidden = work.youtubePrivacyStatus === 'private' || work.youtubePrivacyStatus === 'deleted';
  const nowVisible = nextPublished && !forcedHidden;

  const updates: string[] = ['isNiarimPublished = :pub'];
  const names: Record<string, string> = {};
  const values: Record<string, unknown> = { ':pub': nextPublished };
  const removes: string[] = [];

  if (body.title !== undefined) {
    updates.push('title = :title');
    values[':title'] = body.title;
  }

  if (nowVisible) {
    updates.push(
      'gsi1pk = :rankPk, gsi1sk = :score, gsi2pk = :bmPk, gsi2sk = :bm, gsi3pk = :authorPk, gsi3sk = :postedAt, gsi4pk = :latestPk, gsi4sk = :postedAt2',
    );
    values[':rankPk'] = 'RANKING#ALL';
    values[':score'] = work.rankingScore ?? 0;
    values[':bmPk'] = 'BOOKMARK_RANKING';
    values[':bm'] = work.bookmarkCount;
    values[':authorPk'] = `AUTHOR#${work.authorId}`;
    values[':postedAt'] = work.postedAt;
    values[':latestPk'] = 'LATEST';
    values[':postedAt2'] = work.postedAt;
  } else {
    removes.push('gsi1pk', 'gsi1sk', 'gsi2pk', 'gsi2sk', 'gsi3pk', 'gsi3sk', 'gsi4pk', 'gsi4sk');
  }

  const updateExpression =
    `SET ${updates.join(', ')}` + (removes.length ? ` REMOVE ${removes.join(', ')}` : '');

  const result = await ddb.send(
    new UpdateCommand({
      TableName: tableName(),
      Key: Keys.work(workId),
      UpdateExpression: updateExpression,
      ExpressionAttributeValues: values,
      ExpressionAttributeNames: Object.keys(names).length ? names : undefined,
      ReturnValues: 'ALL_NEW',
    }),
  );

  return ok({ work: toPublicWork(result.Attributes as WorkItem) });
}

function parseBody(raw: string | undefined): UpdateWorkRequestBody {
  if (!raw) return {};
  try {
    return JSON.parse(raw) as UpdateWorkRequestBody;
  } catch {
    badRequest('リクエストボディがJSONとして不正です');
  }
}
