import { randomUUID } from 'node:crypto';
import { OAuth2Client } from 'google-auth-library';
import { GetCommand, PutCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { ddb, tableName, Keys } from './dynamo';
import type { GoogleSubLookupItem, MembershipTier, UserItem } from './types';
import { TABLE_ITEM_TYPE } from './types';
import { unauthorized } from './response';

/**
 * Google IDトークンの検証＋NIARIM User IDの発行・再利用（4章）。
 *
 * 書き込み系エンドポイント（投稿・通報・ブロック・ブックマーク・
 * フォロー等）はすべてこの関数を通し、`Authorization: Bearer <IDトークン>`
 * ヘッダーからGoogleの`sub`を取り出してNIARIM User IDへ変換する。
 *
 * NIARIM_GOOGLE_CLIENT_ID環境変数は、15章のOAuth審査で確定するWebまたは
 * モバイル向けOAuthクライアントIDを設定する（audience検証に使う）。
 */
const oauthClient = new OAuth2Client();

export interface AuthenticatedUser {
  niarimUserId: string;
  googleSub: string;
  membershipTier: MembershipTier;
}

export async function authenticate(authorizationHeader: string | undefined): Promise<AuthenticatedUser> {
  if (!authorizationHeader?.startsWith('Bearer ')) {
    unauthorized('Authorizationヘッダーが不正です');
  }
  const idToken = authorizationHeader.slice('Bearer '.length);

  const clientId = process.env.GOOGLE_CLIENT_ID;
  if (!clientId) throw new Error('GOOGLE_CLIENT_ID環境変数が設定されていません');

  let sub: string;
  try {
    const ticket = await oauthClient.verifyIdToken({ idToken, audience: clientId });
    const payload = ticket.getPayload();
    if (!payload?.sub) unauthorized('IDトークンの検証に失敗しました');
    sub = payload.sub;
  } catch {
    unauthorized('IDトークンの検証に失敗しました');
  }

  const user = await findOrCreateUser(sub);
  return { niarimUserId: user.niarimUserId, googleSub: sub, membershipTier: user.membershipTier };
}

/**
 * `sub`からNIARIM User IDを引く。未登録なら新規発行する
 * （4章の「初回投稿時：Google sub → 未登録 → NIARIM User ID発行」）。
 * 会員種別（membershipTier）は課金基盤（未実装）と連携するまでの間、
 * 既定で'free'とする。
 */
async function findOrCreateUser(sub: string): Promise<UserItem> {
  const lookupKey = Keys.googleSubLookup(sub);
  const lookup = await ddb.send(
    new GetCommand({ TableName: tableName(), Key: lookupKey }),
  );

  if (lookup.Item) {
    const niarimUserId = (lookup.Item as GoogleSubLookupItem).niarimUserId;
    const userResult = await ddb.send(
      new GetCommand({ TableName: tableName(), Key: Keys.user(niarimUserId) }),
    );
    if (userResult.Item) return userResult.Item as UserItem;
    // ユーザーレコードだけ何らかの理由で欠落していた場合は作り直す。
  }

  const niarimUserId = generateNiarimUserId();
  const now = new Date().toISOString();

  const newUser: UserItem = {
    itemType: TABLE_ITEM_TYPE.User,
    ...Keys.user(niarimUserId),
    niarimUserId,
    googleSub: sub,
    membershipTier: 'free',
    bookmarksPublic: false,
    followersPublic: false,
    followerCount: 0,
    followingCount: 0,
    createdAt: now,
  };
  const newLookup: GoogleSubLookupItem = {
    itemType: TABLE_ITEM_TYPE.GoogleSubLookup,
    ...lookupKey,
    googleSub: sub,
    niarimUserId,
  };

  // 同時に2件PutするだけなのでTransactWriteItemsまでは不要。ただし
  // 同一subからの同時初回リクエスト（レアケース）で二重発行され得る
  // 点は許容する（後続リクエストは新しいlookupを見つけて上書きされる
  // ため実害は小さい。気になる場合はlookup側にConditionExpression
  // attribute_not_exists(pk)を付けて片方を失敗させる運用にする）。
  await ddb.send(new PutCommand({ TableName: tableName(), Item: newLookup }));
  await ddb.send(new PutCommand({ TableName: tableName(), Item: newUser }));
  return newUser;
}

function generateNiarimUserId(): string {
  return `N${randomUUID().replace(/-/g, '')}`;
}

/** 23章：投稿・連携時にYouTubeチャンネル情報をUserItemへキャッシュする。 */
export async function cacheChannelInfo(
  niarimUserId: string,
  info: { youtubeChannelId: string; channelName: string; channelAvatarUrl: string },
): Promise<void> {
  await ddb.send(
    new UpdateCommand({
      TableName: tableName(),
      Key: Keys.user(niarimUserId),
      UpdateExpression:
        'SET youtubeChannelId = :cid, channelName = :name, channelAvatarUrl = :avatar, channelInfoCachedAt = :now',
      ExpressionAttributeValues: {
        ':cid': info.youtubeChannelId,
        ':name': info.channelName,
        ':avatar': info.channelAvatarUrl,
        ':now': new Date().toISOString(),
      },
    }),
  );
}

/**
 * 読み取り系エンドポイント用の任意認証。Authorizationヘッダーが無い、
 * または検証に失敗した場合はnullを返す（401にはしない。16章の
 * 「読み取り系は匿名利用を許可する」方針に従いつつ、ログイン済みなら
 * 本人限定の情報（例：自分の非公開作品）を追加で見せるために使う）。
 */
export async function tryAuthenticate(
  authorizationHeader: string | undefined,
): Promise<AuthenticatedUser | null> {
  if (!authorizationHeader) return null;
  try {
    return await authenticate(authorizationHeader);
  } catch {
    return null;
  }
}

export async function getUser(niarimUserId: string): Promise<UserItem | undefined> {
  const result = await ddb.send(new GetCommand({ TableName: tableName(), Key: Keys.user(niarimUserId) }));
  return result.Item as UserItem | undefined;
}
