import { createHash } from "node:crypto";
import { GoogleAuth } from "google-auth-library";
import { DeleteCommand, GetCommand, QueryCommand, TransactWriteCommand } from "@aws-sdk/lib-dynamodb";
import { ddb, tableName, Keys } from "./dynamo";
import type { DeviceTokenItem } from "./types";
import { TABLE_ITEM_TYPE } from "./types";

/**
 * 真のプッシュ通知（22.7節）。FCM HTTP v1 APIで端末へ直接送る。
 *
 * ## 設計
 *
 * アプリ内通知一覧（方式A、notifications.ts）はDynamoDBに通知アイテムを
 * 積むだけで、アプリが起動していないと気付けない。ここではそれに加えて
 * FCMへ実際のプッシュを投げる。両者は独立していて、**FCMの送信が失敗
 * してもアプリ内通知は残る**ようにしてある（送信はbest-effortで、
 * 例外を呼び出し元へ伝播させない）。フォロー操作そのものがプッシュの
 * 失敗で500になるのは明らかに悪いため。
 *
 * ## 認証情報
 *
 * AWS Lambdaの実行ロールをWorkload Identity Federationで認証し、
 * Firebase Adminの長期秘密鍵を置かずにHTTP v1へ送る。
 * Project、WIF audience、送信用サービスアカウントが揃う場合のみ有効。
 */

const TOKEN_TTL_DAYS = 180;
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

/** トークン本体をキーに出さないためのハッシュ（types.tsのDeviceTokenItem参照）。 */
export function hashDeviceToken(token: string): string {
  return createHash("sha256").update(token).digest("hex").slice(0, 32);
}

/** 端末トークンを登録・更新する（同じ端末からの再登録は上書き）。 */
export async function registerDeviceToken(
  niarimUserId: string,
  token: string,
  platform: "android" | "ios",
  localizedNotifications = false,
): Promise<void> {
  const hash = hashDeviceToken(token);
  const item: DeviceTokenItem = {
    itemType: TABLE_ITEM_TYPE.DeviceToken,
    ...Keys.deviceToken(niarimUserId, hash),
    niarimUserId,
    token,
    platform,
    localizedNotifications,
    updatedAt: new Date().toISOString(),
    ttl: Math.floor(Date.now() / 1000) + TOKEN_TTL_DAYS * 24 * 60 * 60,
  };
  const table = tableName();
  // A signed-in device can be reused by a different account after a restart.
  // Atomically bind the token to its latest owner, without copying user data.
  await ddb.send(new TransactWriteCommand({ TransactItems: [
    { Put: { TableName: table, Item: item } },
    { Put: { TableName: table, Item: {
      ...Keys.deviceOwner(hash), itemType: "DEVICE_OWNER_V1",
      owner: niarimUserId, ttl: item.ttl,
    } } },
  ] }));
}

/** 端末トークンを削除する（ログアウト・通知オフ時）。 */
export async function unregisterDeviceToken(
  niarimUserId: string,
  token: string,
): Promise<void> {
  await ddb.send(
    new DeleteCommand({
      TableName: tableName(),
      Key: Keys.deviceToken(niarimUserId, hashDeviceToken(token)),
    }),
  );
}

async function listDeviceTokens(
  niarimUserId: string,
): Promise<DeviceTokenItem[]> {
  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      KeyConditionExpression: "pk = :pk AND begins_with(sk, :prefix)",
      ExpressionAttributeValues: {
        ":pk": `USER#${niarimUserId}`,
        ":prefix": "DEVICE#",
      },
    }),
  );
  const now = Math.floor(Date.now() / 1000);
  const active = ((result.Items ?? []) as DeviceTokenItem[]).filter((item) => item.ttl > now);
  const matches = await Promise.all(active.map(async (item) => {
    const { Item: binding } = await ddb.send(new GetCommand({
      TableName: tableName(), Key: Keys.deviceOwner(hashDeviceToken(item.token)),
      ConsistentRead: true,
    }));
    // Existing registrations without a reverse binding remain usable.
    return !binding || binding.owner === niarimUserId;
  }));
  return active.filter((_, index) => matches[index]);
}

// External-account credentials contain only non-secret WIF metadata. AWS Lambda
// provides short-lived AWS credentials in its execution environment. No GCP
// private key is needed or stored in CloudFormation, GitHub or Lambda.
let cachedClient: ReturnType<GoogleAuth['fromJSON']> | undefined;
let cachedProjectId: string | undefined;

function fcmClient(): { client: ReturnType<GoogleAuth['fromJSON']>; projectId: string } | undefined {
  const projectId = process.env.FCM_PROJECT_ID;
  const audience = process.env.FCM_WIF_AUDIENCE;
  const serviceAccount = process.env.FCM_SENDER_SERVICE_ACCOUNT;
  if (!projectId || !audience || !serviceAccount) return undefined;
  if (!cachedClient || cachedProjectId !== projectId) {
    const auth = new GoogleAuth({ scopes: [FCM_SCOPE] });
    // GoogleAuth.fromJSON supports credential files of type external_account;
    // using the downloaded AWS WIF configuration in memory avoids any disk key.
    const credential = {
      universe_domain: "googleapis.com",
      type: "external_account",
      audience,
      subject_token_type: "urn:ietf:params:aws:token-type:aws4_request",
      token_url: "https://sts.googleapis.com/v1/token",
      credential_source: {
        environment_id: "aws1",
        region_url: "http://169.254.169.254/latest/meta-data/placement/availability-zone",
        url: "http://169.254.169.254/latest/meta-data/iam/security-credentials",
        regional_cred_verification_url:
          "https://sts.{region}.amazonaws.com?Action=GetCallerIdentity&Version=2011-06-15",
      },
      service_account_impersonation_url:
        `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${serviceAccount}:generateAccessToken`,
    };
    // The upstream JSON credential union doesn't include every external-account
    // variant although fromJSON accepts it at runtime.
    cachedClient = auth.fromJSON(credential as any);
    cachedProjectId = projectId;
  }
  return cachedClient ? { client: cachedClient, projectId } : undefined;
}

export interface PushMessage {
  title: string;
  body: string;
  /** アプリ側で遷移先を決めるための付随データ（値は文字列のみ、FCMの仕様）。 */
  data?: Record<string, string>;
  androidBodyLocKey?: string;
}

/**
 * 指定ユーザーの全端末へプッシュを送る。
 *
 * 失敗しても例外は投げない（best-effort）。FCMが「そのトークンはもう
 * 存在しない（UNREGISTERED / INVALID_ARGUMENT）」と返した端末は、次回
 * 以降の無駄な送信を避けるためテーブルから削除する。
 */
export async function sendPushToUser(
  niarimUserId: string,
  message: PushMessage,
): Promise<void> {
  const client = fcmClient();
  if (!client) return;

  let tokens: DeviceTokenItem[];
  try {
    tokens = await listDeviceTokens(niarimUserId);
  } catch (err) {
    console.error("端末トークンの取得に失敗しました", err instanceof Error ? err.name : "UnknownError");
    return;
  }
  if (tokens.length === 0) return;

  let accessToken: string | null | undefined;
  try {
    accessToken = (await client.client.getAccessToken()).token;
  } catch (err) {
    console.error("FCMアクセストークンの取得に失敗しました", err instanceof Error ? err.name : "UnknownError");
    return;
  }
  if (!accessToken) return;

  const endpoint = `https://fcm.googleapis.com/v1/projects/${client.projectId}/messages:send`;
  await Promise.all(
    tokens.map((device) => sendOne(endpoint, accessToken!, device, message)),
  );
}

/**
 * A generic 400 INVALID_ARGUMENT can describe an invalid notification
 * payload, not an invalid token. Delete a token only when FCM's typed error
 * explicitly identifies a registration problem.
 * https://firebase.google.com/docs/cloud-messaging/error-codes
 */
export function invalidFcmRegistration(status: number, body: string): boolean {
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return false;
  }
  if (typeof parsed !== "object" || parsed === null ||
      !("error" in parsed)) return false;
  const error = parsed.error;
  if (typeof error !== "object" || error === null ||
      !("status" in error)) return false;
  const typed = (code: string) => "details" in error &&
    Array.isArray(error.details) && error.details.some((detail: unknown) => {
      if (typeof detail !== "object" || detail === null) return false;
      const d = detail as Record<string, unknown>;
      return d["@type"] === "type.googleapis.com/google.firebase.fcm.v1.FcmError" &&
        d.errorCode === code;
    });
  return (status === 404 && (error.status === "UNREGISTERED" ||
      (error.status === "NOT_FOUND" && typed("UNREGISTERED")))) ||
    (status === 400 && error.status === "INVALID_ARGUMENT" && typed("INVALID_ARGUMENT"));
}

export function fcmNotificationForDevice(device: DeviceTokenItem, message: PushMessage) {
  const localKey = device.platform === "android" && device.localizedNotifications
    ? message.androidBodyLocKey : undefined;
  return {
    token: device.token,
    notification: { title: message.title, ...(!localKey ? { body: message.body } : {}) },
    ...(message.data ? { data: message.data } : {}),
    android: {
      priority: "HIGH",
      notification: { visibility: "PRIVATE", ...(localKey ? { body_loc_key: localKey } : {}) },
    },
  };
}

async function sendOne(
  endpoint: string,
  accessToken: string,
  device: DeviceTokenItem,
  message: PushMessage,
): Promise<void> {
  try {
    const response = await fetch(endpoint, {
      method: "POST",
      signal: AbortSignal.timeout(4_000),
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message: fcmNotificationForDevice(device, message) }),
    });

    if (response.ok) {
      await response.body?.cancel();
      return;
    }

    const body = await response.text().catch(() => "");
    if (invalidFcmRegistration(response.status, body)) {
      await ddb
        .send(
          new DeleteCommand({
            TableName: tableName(),
            Key: { pk: device.pk, sk: device.sk },
          }),
        )
        .catch(() => undefined);
      return;
    }
    console.error(
      `FCM送信に失敗しました（HTTP ${response.status}）`,
    );
  } catch (err) {
    console.error("FCM送信で例外が発生しました", err instanceof Error ? err.name : "UnknownError");
  }
}
