import type { Context } from "aws-lambda";
import { ConditionalCheckFailedException, TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import {
  DeleteCommand, GetCommand, QueryCommand, ScanCommand, TransactWriteCommand, UpdateCommand,
} from "@aws-sdk/lib-dynamodb";
import type { TransactWriteCommandInput } from "@aws-sdk/lib-dynamodb";
import { ddb, Keys, tableName } from "../lib/dynamo";
import { PERIOD_SCORE_VERSION, periodBookmarkWrites, periodScoreKey, periodsStillInWindow } from "../lib/periodBookmarkRanking";
import { TABLE_ITEM_TYPE } from "../lib/types";

type Key = { pk: string; sk: string };
type Row = Record<string, unknown> & Key;
type Writes = NonNullable<TransactWriteCommandInput["TransactItems"]>;

const scanPageSize = 25;
const drainMs = 45_000;
const leaseMs = 55_000;
const jobType = "ACCOUNT_ERASURE_JOB";
const userIdFormat = /^N[0-9a-f]{32}$/;

function rowKey(row: Row): Key {
  return { pk: row.pk, sk: row.sk };
}

async function get(key: Key) {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: key, ConsistentRead: true,
  }));
  return result.Item;
}

async function remove(key: Key, field: string, value: unknown) {
  try {
    await ddb.send(new DeleteCommand({
      TableName: tableName(), Key: key,
      ConditionExpression: "#field = :value",
      ExpressionAttributeNames: { "#field": field },
      ExpressionAttributeValues: { ":value": value },
    }));
  } catch (error) {
    if (!(error instanceof ConditionalCheckFailedException)) throw error;
  }
}

async function removeWith(key: Key, changes: Writes) {
  if (!changes.length) {
    await remove(key, "sk", key.sk);
    return;
  }
  try {
    await ddb.send(new TransactWriteCommand({ TransactItems: [
      { Delete: {
        TableName: tableName(), Key: key,
        ConditionExpression: "attribute_exists(pk)",
      } },
      ...changes,
    ] }));
  } catch (error) {
    // A retried scan page must not decrement the same counters twice.
    if (!(error instanceof TransactionCanceledException) || await get(key)) {
      throw error;
    }
  }
}

async function removeWork(row: Row, accountId: string) {
  if (typeof row.workId !== "string" || row.pk !== Keys.work(row.workId).pk) {
    throw new Error("Invalid work key in account erasure");
  }
  const TableName = tableName();
  try {
    await ddb.send(new TransactWriteCommand({ TransactItems: [
      { Put: {
        TableName, Item: { ...rowKey(row), itemType: "WORK_TOMBSTONE", workId: row.workId },
        ConditionExpression: "itemType = :work AND authorId = :owner",
        ExpressionAttributeValues: { ":work": TABLE_ITEM_TYPE.Work, ":owner": accountId },
      } },
      { Delete: { TableName, Key: Keys.workDetail(row.workId) } },
    ] }));
  } catch (error) {
    if (!(error instanceof TransactionCanceledException) ||
        (await get(rowKey(row)))?.authorId === accountId) throw error;
  }
}

async function removeReaction(row: Row, accountId: string) {
  const workId = row.workId;
  if (typeof workId !== "string") throw new Error("Invalid reaction in account erasure");
  const bookmark = row.itemType === TABLE_ITEM_TYPE.Bookmark;
  const workKey = Keys.work(workId);
  const count = bookmark ? "bookmarkCount" : "repostCount";
  const work = await get(workKey);
  const changes: Writes = [];
  if (work?.itemType === TABLE_ITEM_TYPE.Work && work.authorId !== accountId &&
      typeof work[count] === "number" && work[count] > 0) {
    const hasIndex = bookmark && typeof work.gsi2pk === "string" && typeof work.gsi2sk === "number";
    changes.push({ Update: {
      TableName: tableName(), Key: workKey,
      UpdateExpression: hasIndex ? "ADD #count :delta, gsi2sk :delta" : "ADD #count :delta",
      ConditionExpression: "itemType = :work AND #count > :zero AND " +
        (bookmark ? (hasIndex ? "attribute_exists(gsi2sk)" : "attribute_not_exists(gsi2sk)") : "attribute_exists(pk)"),
      ExpressionAttributeNames: { "#count": count },
      ExpressionAttributeValues: { ":delta": -1, ":zero": 0, ":work": TABLE_ITEM_TYPE.Work },
    } });
    if (bookmark && row.periodScoreVersion === PERIOD_SCORE_VERSION &&
        typeof row.periodScoreRecordedAt === "string") {
      const now = new Date();
      const periods = periodsStillInWindow(row.periodScoreRecordedAt, now);
      // Older or manually repaired counts may have no corresponding score.
      for (const period of periods) {
        const score = await get(periodScoreKey(workId, period, now));
        if (typeof score?.score === "number" && score.score > 0) {
          changes.push(...periodBookmarkWrites(workId, [period], -1, now));
        }
      }
    }
  }
  await removeWith(rowKey(row), changes);
}

async function removeFollowMirror(row: Row, accountId: string) {
  const otherId = row.pk.slice("USER#".length);
  if (!userIdFormat.test(otherId) || otherId === accountId) {
    throw new Error("Invalid mirror key in account erasure");
  }
  const account = Keys.user(otherId);
  const person = await get(account);
  const count = row.sk.startsWith("FOLLOWER#") ? "followerCount" : "followingCount";
  const changes: Writes = person?.itemType === TABLE_ITEM_TYPE.User &&
      typeof person[count] === "number" && person[count] > 0 ? [{ Update: {
    TableName: tableName(), Key: account, UpdateExpression: "ADD #count :delta",
    ConditionExpression: "itemType = :user AND #count > :zero",
    ExpressionAttributeNames: { "#count": count },
    ExpressionAttributeValues: { ":delta": -1, ":zero": 0, ":user": TABLE_ITEM_TYPE.User },
  } }] : [];
  await removeWith(rowKey(row), changes);
}

async function eraseRow(row: Row, accountId: string) {
  const ownPartition = row.pk === Keys.user(accountId).pk;
  const ownedWork = row.authorId === accountId && row.itemType === TABLE_ITEM_TYPE.Work;
  if (ownedWork) return removeWork(row, accountId);

  if (ownPartition && row.sk !== "META") {
    if (row.itemType === TABLE_ITEM_TYPE.Bookmark || row.itemType === TABLE_ITEM_TYPE.Repost) {
      return removeReaction(row, accountId);
    }
    return remove(rowKey(row), "pk", row.pk);
  }

  if (row.pk.startsWith("USER#") && !ownPartition &&
      ((row.sk === `FOLLOWER#${accountId}` && row.itemType === TABLE_ITEM_TYPE.FollowerRecord) ||
       (row.sk === `FOLLOWING#${accountId}` && row.itemType === TABLE_ITEM_TYPE.FollowingRecord))) {
    return removeFollowMirror(row, accountId);
  }

  if (row.itemType === "WORK_DETAIL" && row.authorId === accountId) {
    return remove(rowKey(row), "authorId", accountId);
  }
  if (row.itemType === "DEVICE_OWNER_V1" && row.owner === accountId) {
    return remove(rowKey(row), "owner", accountId);
  }
  if (row.itemType === TABLE_ITEM_TYPE.Block && row.blockedId === accountId) {
    return remove(rowKey(row), "blockedId", accountId);
  }
  if (row.itemType === TABLE_ITEM_TYPE.Block && row.blockerId === accountId) {
    return remove(rowKey(row), "blockerId", accountId);
  }
  if (row.itemType === TABLE_ITEM_TYPE.Report && row.targetId === accountId) {
    return remove(rowKey(row), "targetId", accountId);
  }
  if ((row.itemType === TABLE_ITEM_TYPE.Report || row.itemType === TABLE_ITEM_TYPE.ReportCounter) &&
      row.reporterId === accountId) {
    return remove(rowKey(row), "reporterId", accountId);
  }
  if ((row.itemType === TABLE_ITEM_TYPE.DailyCounter || row.itemType === "PLAY_PURCHASE_TOKEN") &&
      row.niarimUserId === accountId) {
    return remove(rowKey(row), "niarimUserId", accountId);
  }
  if (row.itemType === "REWARDED_AD_RECEIPT" && row.niarimUserId === accountId) {
    // The expiring transaction key still prevents duplicate callbacks. Strip
    // account and session identifiers and keep the existing expiry.
    try {
      await ddb.send(new UpdateCommand({
        TableName: tableName(), Key: rowKey(row),
        UpdateExpression: "REMOVE niarimUserId, sessionNonce, offerVersion, earnedCoins, adUnitSuffix, receivedAtMs",
        ConditionExpression: "itemType = :type AND niarimUserId = :id",
        ExpressionAttributeValues: { ":type": "REWARDED_AD_RECEIPT", ":id": accountId },
      }));
    } catch (error) {
      if (!(error instanceof ConditionalCheckFailedException)) throw error;
    }
  }
}

async function completeDeletion(receipt: string, sub: string, accountId: string, lease: number) {
  const TableName = tableName();
  const now = Math.floor(Date.now() / 1000);
  await ddb.send(new TransactWriteCommand({ TransactItems: [
    { Delete: {
      TableName, Key: Keys.accountErasureJob(receipt),
      ConditionExpression: "leaseUntil = :lease",
      ExpressionAttributeValues: { ":lease": lease },
    } },
    { Delete: {
      TableName, Key: Keys.googleSubLookup(sub),
      ConditionExpression: "erasureReceipt = :receipt AND niarimUserId = :id",
      ExpressionAttributeValues: { ":receipt": receipt, ":id": accountId },
    } },
    { Delete: {
      TableName, Key: Keys.user(accountId),
      ConditionExpression: "erasureReceipt = :receipt AND googleSub = :sub",
      ExpressionAttributeValues: { ":receipt": receipt, ":sub": sub },
    } },
    { Put: {
      TableName, Item: {
        ...Keys.accountErasureBoundary(sub), rejectIssuedAtOrBefore: now,
        ttl: now + 2 * 60 * 60,
      },
    } },
    { Put: {
      TableName, Item: {
        ...Keys.accountErasureReceipt(receipt), itemType: "ACCOUNT_ERASURE_COMPLETE",
        ttl: now + 24 * 60 * 60,
      },
    } },
  ] }));
}

/** A short lease and a durable scan cursor make restarts and throttle retries safe. */
export async function handler(_event: unknown, context: Context): Promise<void> {
  const TableName = tableName();
  const queued = await ddb.send(new QueryCommand({
    TableName, ConsistentRead: true,
    KeyConditionExpression: "pk = :queue",
    ExpressionAttributeValues: { ":queue": Keys.accountErasureJob("").pk },
    Limit: 1,
  }));
  const job = queued.Items?.[0];
  const now = Date.now();
  if (!job || job.enqueuedAt > now - drainMs || job.leaseUntil > now) return;
  const { sk: receipt, accountId, sub } = job;
  if (job.itemType !== jobType || !userIdFormat.test(accountId) ||
      typeof sub !== "string" || typeof receipt !== "string" ||
      !/^[a-f0-9]{64}$/.test(receipt)) throw new Error("Invalid account erasure job");

  const Key = Keys.accountErasureJob(receipt);
  const lease = now + leaseMs;
  try {
    await ddb.send(new UpdateCommand({
      TableName, Key, UpdateExpression: "SET leaseUntil = :lease",
      ConditionExpression: "itemType = :type AND (attribute_not_exists(leaseUntil) OR leaseUntil <= :now)",
      ExpressionAttributeValues: { ":lease": lease, ":now": now, ":type": jobType },
    }));
  } catch (error) {
    if (error instanceof ConditionalCheckFailedException) return;
    throw error;
  }

  let cursor = job.cursor;
  for (let page = 0; page < 4 && context.getRemainingTimeInMillis() > 6000; page++) {
    const batch = await ddb.send(new ScanCommand({
      TableName, ConsistentRead: true, Limit: scanPageSize,
      ExclusiveStartKey: cursor,
      FilterExpression:
        "pk = :userKey OR niarimUserId = :id OR authorId = :id OR " +
        "#owner = :id OR reporterId = :id OR blockedId = :id OR blockerId = :id OR targetId = :id OR followerId = :id",
      ExpressionAttributeNames: { "#owner": "owner" },
      ExpressionAttributeValues: { ":userKey": Keys.user(accountId).pk, ":id": accountId },
    }));
    for (const row of (batch.Items ?? []) as Row[]) {
      if (context.getRemainingTimeInMillis() < 4000) return;
      await eraseRow(row, accountId);
    }
    cursor = batch.LastEvaluatedKey;
    if (!cursor) {
      await completeDeletion(receipt, sub, accountId, lease);
      return;
    }
    await ddb.send(new UpdateCommand({
      TableName, Key, UpdateExpression: "SET #cursor = :cursor",
      ConditionExpression: "leaseUntil = :lease",
      ExpressionAttributeNames: { "#cursor": "cursor" },
      ExpressionAttributeValues: { ":cursor": cursor, ":lease": lease },
    }));
  }
}
