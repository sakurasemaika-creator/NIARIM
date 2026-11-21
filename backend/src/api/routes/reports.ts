import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "../../lib/dynamo";
import { authenticate, getUser } from "../../lib/auth";
import { badRequest, created, notFound } from "../../lib/response";
import { reserveReportQuota } from "../../lib/reportQuota";
import { parseJsonObject } from "../../lib/request";
import type { ReportItem, WorkItem } from "../../lib/types";
import { TABLE_ITEM_TYPE } from "../../lib/types";

interface CreateReportRequestBody {
  workId?: string;
  authorId?: string;
  reason: string;
}

function isWorkPublic(work: WorkItem): boolean {
  return (
    work.itemType === TABLE_ITEM_TYPE.Work &&
    work.isNiarimPublished && !work.moderationHidden &&
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

  let targetId = body.authorId;
  if (body.workId) {
    const workResult = await ddb.send(new GetCommand({
      TableName: tableName(), Key: Keys.work(body.workId), ConsistentRead: true,
    }));
    const work = workResult.Item as WorkItem | undefined;
    if (!work || !isWorkPublic(work)) {
      notFound("作品が見つかりません");
    }
    if (work.authorId === auth.niarimUserId) {
      badRequest("自分の作品は通報できません");
    }
    targetId = work.authorId;
  } else if (!targetId || !await getUser(targetId)) {
    notFound("アカウントが見つかりません");
  }
  if (!targetId) notFound("アカウントが見つかりません");
  if (targetId === auth.niarimUserId) badRequest("自分自身は通報できません");
  await reserveReportQuota(auth.niarimUserId);

  const now = new Date().toISOString();
  const report: ReportItem = {
    itemType: TABLE_ITEM_TYPE.Report,
    ...(body.workId ? Keys.report(body.workId, auth.niarimUserId, now) : {
      pk: Keys.user(targetId).pk,
      sk: `REPORT#${auth.niarimUserId}#${now}`,
    }),
    workId: body.workId,
    targetId,
    reporterId: auth.niarimUserId,
    reason: body.reason,
    status: "pending",
    createdAt: now,
    gsi7pk: "REPORT_STATUS#pending",
    gsi7sk: now,
  };

  const TableName = tableName();
  await ddb.send(new TransactWriteCommand({ TransactItems: [
    ...[auth.niarimUserId, targetId].map(id => ({
      ConditionCheck: {
        TableName, Key: Keys.user(id),
        ConditionExpression: "itemType = :type AND attribute_not_exists(erasureReceipt)",
        ExpressionAttributeValues: { ":type": TABLE_ITEM_TYPE.User },
      },
    })),
    { Put: { TableName, Item: report } },
  ] }));
  return created({ ok: true });
}

function parseBody(raw: string | undefined): CreateReportRequestBody {
  const body = parseJsonObject(raw);
  const { workId, authorId } = body;
  const isWork = typeof workId === "string" && /^[A-Za-z0-9_-]{11}$/.test(workId);
  const isAuthor = typeof authorId === "string" && /^N[0-9a-f]{32}$/.test(authorId);
  if (!((isWork && authorId === undefined) || (isAuthor && workId === undefined))) {
    badRequest("有効な通報対象を1件指定してください");
  }
  if (!body.reason || typeof body.reason !== "string" || !body.reason.trim()) {
    badRequest("reasonは必須です");
  }
  const reason = body.reason.trim();
  if (reason.length > 1000)
    badRequest("reasonは1000文字以内で指定してください");
  return { workId: isWork ? workId : undefined, authorId: isAuthor ? authorId : undefined, reason };
}
