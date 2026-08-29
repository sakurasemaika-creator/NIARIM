/**
 * NIARIM作品広場バックエンドの型定義。
 *
 * DynamoDBはシングルテーブル設計（PK/SK文字列）を採用する。テーブル1本
 * （NiarimTable）に、作品・ユーザー・ブックマーク・リポスト・フォロー・
 * 通報・ブロック・通知・日次投稿カウンターの全アイテム種別を収める。
 * `29_動画投稿・ランキング機能仕様.md`（特に5章・8章・9章・11章・12章・
 * 16章・17章・22.5〜22.7節・23章）に対応する。
 *
 * ## キー設計の要点
 *
 * - **workId = youtubeVideoId** とする（17章の冪等キーそのものを主キーに
 *   採用することで、「videoIdが既に登録済みなら更新、未登録なら新規登録」
 *   という17章の要求をDynamoDBの`PutItem`一発で満たせる。6章の「NIARIM
 *   投稿作品であることの判定」もこの一意性で自然に成立する）。
 * - GSI1（RankingIndex）・GSI2（BookmarkRankingIndex）・GSI4（LatestIndex）
 *   は、13章のとおり非公開/強制非表示の作品にはソートキー属性自体を
 *   書き込まないことでGSIから除外する（8.2節の設計をLatest/Authorにも
 *   統一適用している。これは元の仕様書の「新着・作者別一覧は都度フィルタ」
 *   という記述より一歩進んだ実装だが、結果は同じで、かつQuery1回で
 *   完結するぶん効率的）。
 * - GSI3（AuthorWorksIndex）は8.4節の作者別一覧に使う。
 * - フォロー関係は「対象への被フォロー記録」と「フォロワー自身のフォロー
 *   中記録」を`TransactWriteItems`で両方書き込む二重書き込み方式にして
 *   おり、GSIを使わずどちらの向きのクエリもO(1)のPK/SK Queryで済む。
 */

export const TABLE_ITEM_TYPE = {
  Work: 'WORK',
  User: 'USER',
  GoogleSubLookup: 'GOOGLE_SUB_LOOKUP',
  Bookmark: 'BOOKMARK',
  Repost: 'REPOST',
  FollowerRecord: 'FOLLOWER_RECORD',
  FollowingRecord: 'FOLLOWING_RECORD',
  Report: 'REPORT',
  Block: 'BLOCK',
  FollowNotification: 'FOLLOW_NOTIFICATION',
  DailyCounter: 'DAILY_COUNTER',
  BatchState: 'BATCH_STATE',
} as const;

/** YouTube側の公開状態（13章の判定表に対応）。 */
export type YoutubePrivacyStatus = 'public' | 'unlisted' | 'private' | 'deleted';

/** 通報の対応状況（9章）。 */
export type ReportStatus = 'pending' | 'reviewing' | 'resolved';

/** 会員種別（11章の投稿上限に影響）。 */
export type MembershipTier = 'free' | 'premium';

/**
 * 作品アイテム（5章のメタデータ表に対応）。
 * PK = `WORK#{workId}` / SK = `META`
 */
export interface WorkItem {
  itemType: typeof TABLE_ITEM_TYPE.Work;
  pk: string;
  sk: string;

  workId: string; // = youtubeVideoId（上記の設計メモ参照）
  authorId: string; // NIARIM User ID
  youtubeChannelId: string;
  youtubeVideoId: string;

  // 23章：公開プロフィール用にキャッシュしたチャンネル情報。
  channelName: string;
  channelAvatarUrl: string;
  channelInfoCachedAt: string; // ISO8601

  title: string;
  postedAt: string; // ISO8601
  youtubeUrl: string;
  thumbnailUrl: string;

  // 7章：YouTube側の値をそのまま表示する統計。
  viewCount: number;
  likeCount: number;
  commentCount: number;
  lastFetchedAt: string; // ISO8601

  // 8.1/8.2節：累計ランキング用スコア。非公開/強制非表示のときは
  // このフィールド自体を書き込まない（GSI1から自動的に除外されるため）。
  // 計算式はrankingScore()（ranking.ts）を参照。仕様書はrankingScoreの
  // 厳密な計算式まで定義していないため、ここではview/like/commentの
  // 加重和という一般的な指標を採用している（要チューニング）。
  rankingScore?: number;

  // 8.5節：NIARIM独自のブックマーク数。0件のときも属性は残す
  // （GSI2用のbookmarkScoreのみ、非公開時に削除する）。
  bookmarkCount: number;
  bookmarkScore?: number; // = bookmarkCount（可視のときだけ存在。GSI2のソートキー）

  // 8.5bis節：リポスト数。
  repostCount: number;

  // 13章：NIARIM側の独立した公開/非公開設定。
  isNiarimPublished: boolean;
  // 13章：YouTube側の状態。強制非表示の判定に使う
  // （'private'または'deleted'のとき強制非表示）。
  youtubePrivacyStatus: YoutubePrivacyStatus;

  // 8.9節：ショート/横動画の判定結果（投稿時にクライアントから受け取る）。
  isShort: boolean;

  // 8.7節：クラウド編集タグ。
  tags: string[];
  lockedTags: string[];

  createdAt: string; // ISO8601

  // --- GSI attributes（可視のときのみ存在させる） ---
  gsi1pk?: string; // "RANKING#ALL"
  gsi1sk?: number; // rankingScore と同値
  gsi2pk?: string; // "BOOKMARK_RANKING"
  gsi2sk?: number; // bookmarkCount と同値
  gsi3pk?: string; // `AUTHOR#{authorId}`（可視のときのみ。他ユーザーが見る作者別一覧用）
  gsi3sk?: string; // postedAt
  gsi3AllPk: string; // `AUTHOR#{authorId}`（可視性を問わず常に存在。投稿者本人が自分の非公開作品も見るため）
  gsi3AllSk: string; // postedAt
  gsi4pk?: string; // "LATEST"（可視のときのみ）
  gsi4sk?: string; // postedAt
}

/**
 * ユーザー（NIARIM User ID）アイテム。4章のUser ID発行・23章の公開
 * プロフィール・8.5/22.5節の公開設定をまとめて持つ。
 * PK = `USER#{niarimUserId}` / SK = `META`
 */
export interface UserItem {
  itemType: typeof TABLE_ITEM_TYPE.User;
  pk: string;
  sk: string;

  niarimUserId: string;
  googleSub: string;
  membershipTier: MembershipTier;

  youtubeChannelId?: string;
  channelName?: string;
  channelAvatarUrl?: string;
  channelInfoCachedAt?: string;

  // 8.5節「ブックマーク一覧の公開設定」・22.5節「フォロー中/フォロワー
  // 一覧の公開設定」。いずれも既定false（非公開）。
  bookmarksPublic: boolean;
  followersPublic: boolean;

  followerCount: number; // 常時公開の集計値（22.5節）
  followingCount: number; // 常時公開の集計値（22.5節）

  createdAt: string;
}

/**
 * Google `sub` → NIARIM User ID の逆引き（4章）。
 * PK = `GOOGLESUB#{sub}` / SK = `META`
 */
export interface GoogleSubLookupItem {
  itemType: typeof TABLE_ITEM_TYPE.GoogleSubLookup;
  pk: string;
  sk: string;
  googleSub: string;
  niarimUserId: string;
}

/**
 * ブックマーク記録（8.5節）。
 * PK = `USER#{niarimUserId}` / SK = `BOOKMARK#{workId}`
 * 逆引き（被ブックマーク一覧、21.1節）用にGSI5も張る。
 */
export interface BookmarkItem {
  itemType: typeof TABLE_ITEM_TYPE.Bookmark;
  pk: string;
  sk: string;
  niarimUserId: string;
  workId: string;
  bookmarkedAt: string;
  gsi5pk: string; // `WORKBOOKMARKS#{workId}`
  gsi5sk: string; // bookmarkedAt
}

/**
 * リポスト記録（8.5bis節）。
 * PK = `USER#{niarimUserId}` / SK = `REPOST#{workId}`
 */
export interface RepostItem {
  itemType: typeof TABLE_ITEM_TYPE.Repost;
  pk: string;
  sk: string;
  niarimUserId: string;
  workId: string;
  repostedAt: string;
}

/**
 * フォロー関係（22.5節）。「targetIdのフォロワーにfollowerIdがいる」
 * ことを表す被フォロー側の記録。
 * PK = `USER#{targetId}` / SK = `FOLLOWER#{followerId}`
 */
export interface FollowerRecordItem {
  itemType: typeof TABLE_ITEM_TYPE.FollowerRecord;
  pk: string;
  sk: string;
  targetId: string;
  followerId: string;
  followedAt: string;
}

/**
 * フォロー関係のミラー記録。「followerIdはtargetIdをフォロー中」を
 * 表すフォロー側の記録（followingIdsOfをO(1)クエリにするための
 * 二重書き込み。FollowerRecordItemと同じTransactWriteItemsで作成/削除）。
 * PK = `USER#{followerId}` / SK = `FOLLOWING#{targetId}`
 */
export interface FollowingRecordItem {
  itemType: typeof TABLE_ITEM_TYPE.FollowingRecord;
  pk: string;
  sk: string;
  followerId: string;
  targetId: string;
  followedAt: string;
}

/**
 * 通報記録（9章）。
 * PK = `WORK#{workId}` / SK = `REPORT#{reporterId}#{createdAt}`
 * 運営の対応状況一覧用にGSI7も張る。
 */
export interface ReportItem {
  itemType: typeof TABLE_ITEM_TYPE.Report;
  pk: string;
  sk: string;
  workId: string;
  reporterId: string;
  reason: string;
  status: ReportStatus;
  createdAt: string;
  gsi7pk: string; // `REPORT_STATUS#{status}`
  gsi7sk: string; // createdAt
}

/**
 * ブロック記録（9章）。
 * PK = `USER#{blockerId}` / SK = `BLOCK#{blockedId}`
 */
export interface BlockItem {
  itemType: typeof TABLE_ITEM_TYPE.Block;
  pk: string;
  sk: string;
  blockerId: string;
  blockedId: string;
  createdAt: string;
}

/**
 * フォロー通知（22.6節：アプリ内通知一覧、方式A）。TTLで自動失効
 * （21.3節の推奨に合わせ30日）。
 * PK = `USER#{targetId}` / SK = `NOTIF#{createdAt}#{notifId}`
 */
export interface FollowNotificationItem {
  itemType: typeof TABLE_ITEM_TYPE.FollowNotification;
  pk: string;
  sk: string;
  targetId: string;
  fromUserId: string;
  fromUserName: string;
  read: boolean;
  createdAt: string;
  ttl: number; // epoch seconds
}

/**
 * 日次投稿カウンター（11章・12章）。ユーザー単位・全体単位の両方に使う
 * （全体単位はniarimUserId="GLOBAL"として同じ形で扱う）。
 * PK = `COUNTER#{niarimUserId}#{yyyymmdd}` / SK = `META`
 */
export interface DailyCounterItem {
  itemType: typeof TABLE_ITEM_TYPE.DailyCounter;
  pk: string;
  sk: string;
  niarimUserId: string;
  date: string; // yyyymmdd
  count: number;
  ttl: number; // 数日で自動失効させ、テーブルを肥大化させない
}

/**
 * 統計更新バッチの進行状態（8.1節：自己再帰呼び出しの引き継ぎ・
 * 完了印）。
 * PK = `BATCHSTATE#STATS_UPDATE` / SK = `META`
 */
export interface BatchStateItem {
  itemType: typeof TABLE_ITEM_TYPE.BatchState;
  pk: string;
  sk: string;
  lastCompletedAt?: string; // 8.1節の「最終更新完了日時」
  inProgress: boolean;
}
