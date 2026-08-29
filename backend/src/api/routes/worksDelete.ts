import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { DeleteCommand, GetCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName, Keys } from '../../lib/dynamo';
import { authenticate } from '../../lib/auth';
import { deleteVideo } from '../../lib/youtube';
import { forbidden, notFound, noContent, badRequest } from '../../lib/response';
import type { WorkItem } from '../../lib/types';

interface DeleteWorkRequestBody {
  deleteYoutubeVideo?: boolean;
  youtubeAccessToken?: string; // deleteYoutubeVideo=trueのときのみ必須
}

/**
 * `DELETE /works/{id}`（13章）。NIARIM側の紐付けを解除する。
 * `deleteYoutubeVideo: true`が指定された場合のみYouTube側も削除する
 * （13章の機能表「NIARIM内からYouTube動画を削除」に対応。ユーザーの
 * 明示的な希望が無い限りYouTube動画本体は残す）。
 *
 * 投稿枠は戻らない（12.1節：削除しても消費済みの投稿枠は復活しない）。
 */
export async function deleteWork(event: APIGatewayProxyEventV2, workId: string) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  const body = parseBody(event.body);

  const existing = await ddb.send(new GetCommand({ TableName: tableName(), Key: Keys.work(workId) }));
  const work = existing.Item as WorkItem | undefined;
  if (!work) notFound('作品が見つかりません');
  if (work.authorId !== auth.niarimUserId) forbidden('この作品の投稿者本人のみ削除できます');

  if (body.deleteYoutubeVideo) {
    if (!body.youtubeAccessToken) badRequest('YouTube動画も削除する場合はyoutubeAccessTokenが必要です');
    await deleteVideo(work.youtubeVideoId, body.youtubeAccessToken);
  }

  await ddb.send(new DeleteCommand({ TableName: tableName(), Key: Keys.work(workId) }));

  return noContent();
}

function parseBody(raw: string | undefined): DeleteWorkRequestBody {
  if (!raw) return {};
  try {
    return JSON.parse(raw) as DeleteWorkRequestBody;
  } catch {
    badRequest('リクエストボディがJSONとして不正です');
  }
}
