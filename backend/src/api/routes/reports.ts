import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand, PutCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate } from "../../lib/auth";
import { badRequest, created, notFound } from "../../lib/response";
import { reserveReportQuota } from "../../lib/reportQuota";
import { parseJsonObject } from "../../lib/request";
import type { ReportItem, WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";

interface CreateReportRequestBody {
  workId: string;
  reason: string;
}

function isWorkPublic(work: WorkItem): boolean {
  return (
    work.itemType === TABLE_ITEM_TYPE.Work &&
    work.isNiarimPublished &&
    work.youtubePrivacyStatus !== "private" &&
    work.youtubePrivacyStatus !== "deleted"
  );
}

/**
 * `POST /reports`（9章）。通報はログイン必須。通報者のNIARIM User ID
 * を付けて保存し、運営が確認できるようにする（YouTube動画自体は
 * 削除しない。除外はNIARIM内の掲載可否のみ）。
 *
 * 通報対象は現在公開中の実在作品に限定する。存在しないworkIdや、既に
 * 非公開/削除済みの作品へ任意の通報レコードを作成できると、ストレージを
 * 増やすだけでなく利用者の通報枠まで無意味に消費するため、対象確認を
 * レート制限の予約より先に行う。
 *
 * 20章の課題「同一ユーザーからの連続通報に対するレート制限」は、
 * 通報者ごと・時間窓ごとの専用カウンター（reportQuota.ts）へ委譲して
 * いる。通報件数に関係なく1回のUpdateItemで判定できる。
 */
export async function createReport(event: APIGatewayProxyEventV2) {
  const auth = await authenticate(
    event.headers["authorization"] ?? event.headers["Authorization"],
  );
  const body = parseBody(event.body);

  const workResult = await ddb.send(
    new GetCommand({ TableName: tableName(), Key: Keys.work(body.workId) }),
  );
  const work = workResult.Item as WorkItem | undefined;
  if (!work || !isWorkPublic(work)) {
    notFound("作品が見つかりません");
  }

  await reserveReportQuota(auth.niarimUserId);

  const now = new Date().toISOString();
  const report: ReportItem = {
    itemType: TABLE_ITEM_TYPE.Report,
    ...Keys.report(body.workId, auth.niarimUserId, now),
    workId: body.workId,
    reporterId: auth.niarimUserId,
    reason: body.reason,
    status: "pending",
    createdAt: now,
    gsi7pk: "REPORT_STATUS#pending",
    gsi7sk: now,
  };

  await ddb.send(new PutCommand({ TableName: tableName(), Item: report }));
  return created({ ok: true });
}

function parseBody(raw: string | undefined): CreateReportRequestBody {
  const body = parseJsonObject(raw);
  if (
    typeof body.workId !== "string" ||
    !/^[A-Za-z0-9_-]{11}$/.test(body.workId)
  ) {
    badRequest("workIdの形式が不正です");
  }
  if (!body.reason || typeof body.reason !== "string" || !body.reason.trim()) {
    badRequest("reasonは必須です");
  }
  const reason = body.reason.trim();
  if (reason.length > 1000)
    badRequest("reasonは1000文字以内で指定してください");
  return { workId: body.workId, reason };
}
