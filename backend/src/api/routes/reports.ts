import type { APIGatewayProxyEventV2 } from 'aws-lambda';
import { PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName, Keys } from '../../lib/dynamo';
import { authenticate } from '../../lib/auth';
import { badRequest, created, conflict } from '../../lib/response';
import { parseJsonObject } from '../../lib/request';
import type { ReportItem } from '../../lib/types';
import { TABLE_ITEM_TYPE } from '../../lib/types';

interface CreateReportRequestBody {
  workId: string;
  reason: string;
}

const RATE_LIMIT_WINDOW_MINUTES = 10;
const RATE_LIMIT_MAX_REPORTS = 5;

/**
 * `POST /reports`（9章）。通報はログイン必須。通報者のNIARIM User ID
 * を付けて保存し、運営が確認できるようにする（YouTube動画自体は
 * 削除しない。除外はNIARIM内の掲載可否のみ）。
 *
 * 20章の課題「同一ユーザーからの連続通報に対する簡易なレート制限」を
 * 満たすため、直近`RATE_LIMIT_WINDOW_MINUTES`分の通報件数を確認する
 * （PK=`WORK#{workId}`ではなく通報者単位で見る必要があるため、GSI7
 * （REPORT_STATUSインデックス）を`gsi7pk = "REPORT_STATUS#pending"`で
 * 引いた上でreporterIdフィルタする簡易実装。通報数がごく少ない前提の
 * 初期実装であり、大規模化した場合は通報者ごとの別カウンターに
 * 切り替えることを検討する）。
 */
export async function createReport(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(event.headers['authorization'] ?? event.headers['Authorization']);
  const body = parseBody(event.body);

  await checkRateLimit(auth.niarimUserId);

  const now = new Date().toISOString();
  const report: ReportItem = {
    itemType: TABLE_ITEM_TYPE.Report,
    ...Keys.report(body.workId, auth.niarimUserId, now),
    workId: body.workId,
    reporterId: auth.niarimUserId,
    reason: body.reason,
    status: 'pending',
    createdAt: now,
    gsi7pk: 'REPORT_STATUS#pending',
    gsi7sk: now,
  };

  await ddb.send(new PutCommand({ TableName: tableName(), Item: report }));
  return created({ ok: true });
}

async function checkRateLimit(reporterId: string): Promise<void> {
  const since = new Date(Date.now() - RATE_LIMIT_WINDOW_MINUTES * 60 * 1000).toISOString();
  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      IndexName: 'GSI7',
      KeyConditionExpression: 'gsi7pk = :pk AND gsi7sk > :since',
      ExpressionAttributeValues: { ':pk': 'REPORT_STATUS#pending', ':since': since },
    }),
  );
  const recentByReporter = (result.Items ?? []).filter(
    (item) => (item as ReportItem).reporterId === reporterId,
  );
  if (recentByReporter.length >= RATE_LIMIT_MAX_REPORTS) {
    conflict(
      `通報が短時間に集中しています。しばらく時間をおいてから再度お試しください。`,
      'REPORT_RATE_LIMITED',
    );
  }
}

function parseBody(raw: string | undefined): CreateReportRequestBody {
  const body = parseJsonObject(raw);
  if (typeof body.workId !== 'string' || !/^[A-Za-z0-9_-]{11}$/.test(body.workId)) {
    badRequest('workIdの形式が不正です');
  }
  if (!body.reason || typeof body.reason !== 'string' || !body.reason.trim()) {
    badRequest('reasonは必須です');
  }
  const reason = body.reason.trim();
  if (reason.length > 1000) badRequest('reasonは1000文字以内で指定してください');
  return { workId: body.workId, reason };
}
