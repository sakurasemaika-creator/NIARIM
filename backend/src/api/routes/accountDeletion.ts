import { randomBytes } from "node:crypto";
import type { APIGatewayProxyEventV2 } from "aws-lambda";
import { TransactionCanceledException } from "@aws-sdk/client-dynamodb";
import { GetCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { verifyGoogleIdentity } from "../../lib/auth";
import { ddb, Keys, tableName } from "../../lib/dynamo";
import { parseJsonObject } from "../../lib/request";
import { badRequest, conflict, json, unauthorized } from "../../lib/response";
import { TABLE_ITEM_TYPE } from "../../lib/types";

const NONCE_OR_RECEIPT = /^[a-f0-9]{64}$/;
const MAX_IDENTITY_AGE_SECONDS = 5 * 60;

async function identity(event: APIGatewayProxyEventV2, nonce: unknown) {
  if (typeof nonce !== "string" || !NONCE_OR_RECEIPT.test(nonce)) {
    badRequest("本人確認の情報が無効です");
  }
  const google = await verifyGoogleIdentity(
    event.headers.authorization ?? event.headers.Authorization,
  );
  const now = Math.floor(Date.now() / 1000);
  if (!("nonce" in google) || google.nonce !== nonce ||
      !Number.isInteger(google.iat) || google.iat < now - MAX_IDENTITY_AGE_SECONDS ||
      google.iat > now + 30 || google.email_verified !== true ||
      typeof google.email !== "string" || !google.email) {
    unauthorized("Googleで本人確認をやり直してください");
  }
  return google;
}

async function lookupFor(sub: string) {
  const result = await ddb.send(new GetCommand({
    TableName: tableName(), Key: Keys.googleSubLookup(sub), ConsistentRead: true,
  }));
  const lookup = result.Item;
  return lookup?.itemType === TABLE_ITEM_TYPE.GoogleSubLookup &&
    typeof lookup.niarimUserId === "string" && /^N[0-9a-f]{32}$/.test(lookup.niarimUserId) &&
    lookup.googleSub === sub
    ? lookup : null;
}

export async function verifyAccountDeletion(event: APIGatewayProxyEventV2) {
  const body = parseJsonObject(event.body);
  const google = await identity(event, body.nonce);
  const lookup = await lookupFor(google.sub);
  return json(200, {
    email: google.email,
    state: !lookup ? "no-account" : lookup.erasureReceipt ? "pending" : "ready",
    ...(typeof lookup?.erasureReceipt === "string" ? { receipt: lookup.erasureReceipt } : {}),
  });
}

export async function startAccountDeletion(event: APIGatewayProxyEventV2) {
  const body = parseJsonObject(event.body);
  if (body.confirm !== true) badRequest("削除するには確認が必要です");
  const { sub, iat } = await identity(event, body.nonce);
  const lookup = await lookupFor(sub);
  if (!lookup) return json(200, { state: "no-account" });
  if (typeof lookup.erasureReceipt === "string") {
    return json(202, { state: "pending", receipt: lookup.erasureReceipt });
  }

  // A token issued before this account existed cannot remove a later signup.
  const receipt = randomBytes(32).toString("hex");
  const now = Date.now();
  const accountId: string = lookup.niarimUserId;
  const TableName = tableName();
  try {
    await ddb.send(new TransactWriteCommand({ TransactItems: [
      { Update: {
        TableName, Key: Keys.googleSubLookup(sub),
        UpdateExpression: "SET erasureReceipt = :receipt",
        ConditionExpression: "niarimUserId = :owner AND attribute_not_exists(erasureReceipt)",
        ExpressionAttributeValues: { ":receipt": receipt, ":owner": accountId },
      } },
      { Update: {
        TableName, Key: Keys.user(accountId),
        UpdateExpression: "SET erasureReceipt = :receipt",
        ConditionExpression:
          "itemType = :type AND googleSub = :subject AND createdAt < :identityTime",
        ExpressionAttributeValues: {
          ":receipt": receipt, ":type": TABLE_ITEM_TYPE.User, ":subject": sub,
          ":identityTime": new Date((iat + 1) * 1000).toISOString(),
        },
      } },
      { Put: {
        TableName,
        Item: {
          ...Keys.accountErasureJob(receipt), itemType: "ACCOUNT_ERASURE_JOB",
          accountId, sub, enqueuedAt: now,
        },
        ConditionExpression: "attribute_not_exists(pk)",
      } },
    ] }));
  } catch (error) {
    if (!(error instanceof TransactionCanceledException)) throw error;
    const current = await lookupFor(sub);
    if (typeof current?.erasureReceipt === "string") {
      return json(202, { state: "pending", receipt: current.erasureReceipt });
    }
    conflict("アカウントの状態が変わりました。再度ログインしてください", "ACCOUNT_ERASURE_CONFLICT");
  }
  return json(202, { state: "pending", receipt });
}

export async function getAccountDeletionStatus(event: APIGatewayProxyEventV2) {
  const { receipt } = parseJsonObject(event.body);
  if (typeof receipt !== "string" || !NONCE_OR_RECEIPT.test(receipt)) {
    badRequest("受付番号が無効です");
  }
  const TableName = tableName();
  const job = await ddb.send(new GetCommand({
    TableName, Key: Keys.accountErasureJob(receipt), ConsistentRead: true,
  }));
  if (job.Item?.itemType === "ACCOUNT_ERASURE_JOB") return json(200, { state: "pending" });
  const result = await ddb.send(new GetCommand({
    TableName, Key: Keys.accountErasureReceipt(receipt), ConsistentRead: true,
  }));
  return result.Item?.itemType === "ACCOUNT_ERASURE_COMPLETE" && result.Item.ttl > Date.now() / 1000
    ? json(200, { state: "complete" })
    : json(404, { state: "unknown" });
}
