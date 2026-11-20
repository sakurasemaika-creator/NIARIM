import { GetCommand, QueryCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "../src/lib/dynamo";
import { TABLE_ITEM_TYPE, type ReportItem } from "../src/lib/types";

async function run(args: string[]) {
  const [command, partition, sortKey, explicitWork] = args;
  const TableName = tableName();
  if ((command === "pending" || command === "reviewing") && args.length === 1) {
    let cursor: Record<string, unknown> | undefined;
    do {
      const page = await ddb.send(new QueryCommand({
        TableName, IndexName: "GSI7",
        KeyConditionExpression: "gsi7pk = :status",
        ExpressionAttributeValues: { ":status": `REPORT_STATUS#${command}` },
        ExclusiveStartKey: cursor,
      }));
      for (const report of page.Items ?? []) {
        console.log(JSON.stringify(report));
      }
      cursor = page.LastEvaluatedKey;
    } while (cursor);
    return;
  }
  if (!["review", "dismiss", "hide"].includes(command) || !partition || !sortKey ||
      (explicitWork && command !== "hide")) {
    throw new Error("Use pending, reviewing, or review|dismiss|hide <pk> <sk> [workId]");
  }
  const Key = { pk: partition, sk: sortKey };
  const lookup = await ddb.send(new GetCommand({ TableName, Key, ConsistentRead: true }));
  const report = lookup.Item as ReportItem | undefined;
  if (report?.itemType !== TABLE_ITEM_TYPE.Report || report.status === "resolved") {
    throw new Error("No open report matches those keys");
  }
  const status = command === "review" ? "reviewing" : "resolved";
  const workId = explicitWork ?? report.workId;
  if (command === "hide" && (!workId || !/^[A-Za-z0-9_-]{11}$/.test(workId) ||
      (report.workId ? workId !== report.workId : !report.targetId))) {
    throw new Error("Specify the reported work or a verified work by the reported creator");
  }
  await ddb.send(new TransactWriteCommand({ TransactItems: [
    { Update: {
      TableName, Key,
      ConditionExpression: "itemType = :report AND #status = :old",
      UpdateExpression: "SET #status = :status, gsi7pk = :index, decision = :decision, reviewedAt = :time",
      ExpressionAttributeNames: { "#status": "status" },
      ExpressionAttributeValues: {
        ":report": TABLE_ITEM_TYPE.Report, ":old": report.status, ":status": status,
        ":index": `REPORT_STATUS#${status}`, ":decision": command, ":time": new Date().toISOString(),
      },
    } },
    ...(command === "hide" && workId ? [{ Update: {
      TableName, Key: Keys.work(workId),
      ConditionExpression: "itemType = :work" + (report.targetId ? " AND authorId = :author" : ""),
      UpdateExpression: "SET moderationHidden = :hidden",
      ExpressionAttributeValues: {
        ":work": TABLE_ITEM_TYPE.Work, ":hidden": true,
        ...(report.targetId ? { ":author": report.targetId } : {}),
      },
    } }] : []),
  ] }));
  console.log(status);
}

run(process.argv.slice(2)).catch(error => {
  console.error(error instanceof Error ? error.message : "Report review failed");
  process.exitCode = 1;
});
