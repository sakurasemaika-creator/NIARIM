import { createHash } from 'node:crypto';
import { JWT } from 'google-auth-library';
import { DeleteCommand, PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName, Keys } from './dynamo';
import type { DeviceTokenItem } from './types';
import { TABLE_ITEM_TYPE } from './types';

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
 * FCM HTTP v1はサービスアカウントのOAuth2アクセストークンを要求する。
 * `FCM_SERVICE_ACCOUNT_JSON`環境変数（サービスアカウントJSONそのもの）と
 * `FCM_PROJECT_ID`を読む。**未設定の場合は何もしない**（ログだけ出す）。
 * これはアプリ側のmonetization_gate.dartと同じ考え方で、鍵が用意できて
 * いない段階でもデプロイ・動作するようにするため。Firebaseコンソールで
 * サービスアカウント鍵を発行してから設定すればそのまま有効になる。
 *
 * $0方針との関係：FCM自体は無料。Secrets Managerは月額課金が発生する
 * ため、YOUTUBE_API_KEYと同じくLambda環境変数（AWS管理キーで暗号化）に
 * 留めている。
 */

const TOKEN_TTL_DAYS = 180;
const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

/** トークン本体をキーに出さないためのハッシュ（types.tsのDeviceTokenItem参照）。 */
export function hashDeviceToken(token: string): string {
  return createHash('sha256').update(token).digest('hex').slice(0, 32);
}

/** 端末トークンを登録・更新する（同じ端末からの再登録は上書き）。 */
export async function registerDeviceToken(
  niarimUserId: string,
  token: string,
  platform: 'android' | 'ios',
): Promise<void> {
  const item: DeviceTokenItem = {
    itemType: TABLE_ITEM_TYPE.DeviceToken,
    ...Keys.deviceToken(niarimUserId, hashDeviceToken(token)),
    niarimUserId,
    token,
    platform,
    updatedAt: new Date().toISOString(),
    ttl: Math.floor(Date.now() / 1000) + TOKEN_TTL_DAYS * 24 * 60 * 60,
  };
  await ddb.send(new PutCommand({ TableName: tableName(), Item: item }));
}

/** 端末トークンを削除する（ログアウト・通知オフ時）。 */
export async function unregisterDeviceToken(niarimUserId: string, token: string): Promise<void> {
  await ddb.send(
    new DeleteCommand({
      TableName: tableName(),
      Key: Keys.deviceToken(niarimUserId, hashDeviceToken(token)),
    }),
  );
}

async function listDeviceTokens(niarimUserId: string): Promise<DeviceTokenItem[]> {
  const result = await ddb.send(
    new QueryCommand({
      TableName: tableName(),
      KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
      ExpressionAttributeValues: { ':pk': `USER#${niarimUserId}`, ':prefix': 'DEVICE#' },
    }),
  );
  return (result.Items ?? []) as DeviceTokenItem[];
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id?: string;
}

let cachedJwt: JWT | undefined;
let cachedProjectId: string | undefined;

/**
 * FCMの設定が揃っているかを見る。揃っていなければundefinedを返し、
 * 呼び出し元は「プッシュは送らないがアプリ内通知は残す」動作になる。
 */
function fcmClient(): { jwt: JWT; projectId: string } | undefined {
  const raw = process.env.FCM_SERVICE_ACCOUNT_JSON;
  if (!raw || raw === 'REPLACE_ME') return undefined;

  if (!cachedJwt || !cachedProjectId) {
    let account: ServiceAccount;
    try {
      account = JSON.parse(raw) as ServiceAccount;
    } catch {
      console.error('FCM_SERVICE_ACCOUNT_JSONがJSONとして読めません。プッシュ通知は送信しません。');
      return undefined;
    }
    const projectId = process.env.FCM_PROJECT_ID || account.project_id;
    if (!account.client_email || !account.private_key || !projectId) {
      console.error('FCMサービスアカウントに必要な項目が足りません。プッシュ通知は送信しません。');
      return undefined;
    }
    cachedJwt = new JWT({
      email: account.client_email,
      key: account.private_key,
      scopes: [FCM_SCOPE],
    });
    cachedProjectId = projectId;
  }
  return { jwt: cachedJwt, projectId: cachedProjectId };
}

export interface PushMessage {
  title: string;
  body: string;
  /** アプリ側で遷移先を決めるための付随データ（値は文字列のみ、FCMの仕様）。 */
  data?: Record<string, string>;
}

/**
 * 指定ユーザーの全端末へプッシュを送る。
 *
 * 失敗しても例外は投げない（best-effort）。FCMが「そのトークンはもう
 * 存在しない（UNREGISTERED / INVALID_ARGUMENT）」と返した端末は、次回
 * 以降の無駄な送信を避けるためテーブルから削除する。
 */
export async function sendPushToUser(niarimUserId: string, message: PushMessage): Promise<void> {
  const client = fcmClient();
  if (!client) return;

  let tokens: DeviceTokenItem[];
  try {
    tokens = await listDeviceTokens(niarimUserId);
  } catch (err) {
    console.error('端末トークンの取得に失敗しました', err);
    return;
  }
  if (tokens.length === 0) return;

  let accessToken: string | null | undefined;
  try {
    accessToken = (await client.jwt.getAccessToken()).token;
  } catch (err) {
    console.error('FCMアクセストークンの取得に失敗しました', err);
    return;
  }
  if (!accessToken) return;

  const endpoint = `https://fcm.googleapis.com/v1/projects/${client.projectId}/messages:send`;
  await Promise.all(
    tokens.map((device) => sendOne(endpoint, accessToken!, device, message)),
  );
}

async function sendOne(
  endpoint: string,
  accessToken: string,
  device: DeviceTokenItem,
  message: PushMessage,
): Promise<void> {
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: device.token,
          notification: { title: message.title, body: message.body },
          ...(message.data ? { data: message.data } : {}),
          android: { priority: 'HIGH' },
        },
      }),
    });

    if (response.ok) return;

    const text = await response.text().catch(() => '');
    // 404 UNREGISTERED / 400 INVALID_ARGUMENT は「そのトークンは死んでいる」。
    if (response.status === 404 || (response.status === 400 && text.includes('INVALID_ARGUMENT'))) {
      await ddb
        .send(new DeleteCommand({ TableName: tableName(), Key: { pk: device.pk, sk: device.sk } }))
        .catch(() => undefined);
      return;
    }
    console.error(`FCM送信に失敗しました（HTTP ${response.status}）: ${text.slice(0, 300)}`);
  } catch (err) {
    console.error('FCM送信で例外が発生しました', err);
  }
}
