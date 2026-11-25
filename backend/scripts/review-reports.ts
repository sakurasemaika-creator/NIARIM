import { QueryCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName } from "../src/lib/dynamo";
import {
  dismissReport,
  hideReport,
  markReviewing,
  unhideWork,
} from "../src/lib/moderation";

/**
 * Command-line fallback for the moderation admin API. It applies the same
 * decisions (src/lib/moderation.ts): `hide` records a strike for the author
 * and can suspend posting at the threshold; `dismiss` resolves every open
 * report on the same target and makes a work the system hid pending review
 * visible again; `unhide` reverses a hide.
 */
async function run(args: string[]) {
  const [command, partition, sortKey, explicitWork] = args;
  const TableName = tableName();
  const by = `cli:${process.env.AWS_PROFILE ?? "unknown"}`;
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
  if (command === "unhide" && partition && args.length === 2) {
    console.log(JSON.stringify(await unhideWork(partition, by)));
    return;
  }
  if (!["review", "dismiss", "hide"].includes(command) || !partition || !sortKey ||
      (explicitWork && command !== "hide")) {
    throw new Error("Use pending, reviewing, review|dismiss|hide <pk> <sk> [workId], or unhide <workId>");
  }
  const key = { pk: partition, sk: sortKey };
  if (command === "review") {
    await markReviewing(key, by);
    console.log("reviewing");
  } else if (command === "dismiss") {
    console.log(JSON.stringify(await dismissReport(key, by)));
  } else {
    console.log(JSON.stringify(await hideReport(key, by, { workId: explicitWork })));
  }
}

run(process.argv.slice(2)).catch(error => {
  console.error(error instanceof Error ? error.message : "Report review failed");
  process.exitCode = 1;
});
