import '../../models/community_work.dart';

/// バックエンドが返す作品1件（`backend/src/api/routes/_publicWork.ts`の
/// `toPublicWork`と1対1で対応する）。
///
/// 画面が使う[CommunityWork]へは[toCommunityWork]で変換する。
/// [CommunityWork]はダミーデータ時代の名残でサムネイルURL等を持たない
/// フィールド構成なので、変換で落ちる情報（`youtubeUrl`・`thumbnailUrl`・
/// `channelAvatarUrl`・`commentCount`・`repostCount`）はこのDTOのまま
/// 保持して、必要な画面がDTO側を参照できるようにしてある。
class ApiWork {
  final String workId;
  final String authorId;
  final String channelName;
  final String channelAvatarUrl;
  final String title;
  final DateTime postedAt;
  final String youtubeUrl;
  final String thumbnailUrl;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int bookmarkCount;
  final int repostCount;
  final bool isShort;
  final List<String> tags;
  final Set<String> lockedTags;
  final bool isNiarimPublished;

  const ApiWork({
    required this.workId,
    required this.authorId,
    required this.channelName,
    required this.channelAvatarUrl,
    required this.title,
    required this.postedAt,
    required this.youtubeUrl,
    required this.thumbnailUrl,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.bookmarkCount,
    required this.repostCount,
    required this.isShort,
    required this.tags,
    required this.lockedTags,
    required this.isNiarimPublished,
  });

  factory ApiWork.fromJson(Map<String, dynamic> json) => ApiWork(
    workId: _string(json['workId']),
    authorId: _string(json['authorId']),
    channelName: _string(json['channelName']),
    channelAvatarUrl: _string(json['channelAvatarUrl']),
    title: _string(json['title']),
    postedAt: _dateTime(json['postedAt']),
    youtubeUrl: _string(json['youtubeUrl']),
    thumbnailUrl: _string(json['thumbnailUrl']),
    viewCount: _int(json['viewCount']),
    likeCount: _int(json['likeCount']),
    commentCount: _int(json['commentCount']),
    bookmarkCount: _int(json['bookmarkCount']),
    repostCount: _int(json['repostCount']),
    isShort: json['isShort'] == true,
    tags: _stringList(json['tags']),
    lockedTags: _stringList(json['lockedTags']).toSet(),
    // 未指定は「公開」とみなす（一覧APIは公開作品しか返さないため）。
    isNiarimPublished: json['isNiarimPublished'] != false,
  );

  /// 画面が使うモデルへ変換する。
  ///
  /// `durationSeconds`はバックエンドが返さない（YouTube側の情報で、
  /// 統計更新バッチも取得していない）ため0にする。表示側は0を
  /// 「尺は不明」として扱うこと。`thumbnailColorIndex`はサムネイルURLが
  /// 無かった時代のプレースホルダー配色用なので、URLがある本番データでは
  /// workIdから安定した値を導出するだけにしてある（同じ作品なら常に同じ色）。
  CommunityWork toCommunityWork() => CommunityWork(
    id: workId,
    title: title,
    authorId: authorId,
    authorName: channelName,
    viewCount: viewCount,
    likeCount: likeCount,
    bookmarkCount: bookmarkCount,
    postedAt: postedAt,
    durationSeconds: 0,
    thumbnailColorIndex: workId.hashCode.abs() % 6,
    tags: tags,
    lockedTags: lockedTags,
    isNiarimPublished: isNiarimPublished,
    isShort: isShort,
  );
}

/// 一覧APIに出てくるユーザーの最小情報（フォロワー一覧・被ブックマーク
/// 一覧などで共通）。
class ApiUserRef {
  final String niarimUserId;
  final String? channelName;
  final String? channelAvatarUrl;

  /// 被ブックマーク一覧でのみ入る「いつブックマークしたか」。
  final DateTime? bookmarkedAt;

  const ApiUserRef({
    required this.niarimUserId,
    this.channelName,
    this.channelAvatarUrl,
    this.bookmarkedAt,
  });

  factory ApiUserRef.fromJson(Map<String, dynamic> json) => ApiUserRef(
    niarimUserId: _string(json['niarimUserId']),
    channelName: json['channelName'] as String?,
    channelAvatarUrl: json['channelAvatarUrl'] as String?,
    bookmarkedAt: json['bookmarkedAt'] == null
        ? null
        : _dateTime(json['bookmarkedAt']),
  );

  /// 表示名（チャンネル名が未取得ならIDで代用する）。
  String get displayName => (channelName == null || channelName!.isEmpty)
      ? niarimUserId
      : channelName!;
}

/// ランキング1ページ（`GET /ranking/{period}`）。
///
/// 累計（`all`）とブックマーク数（`bookmarks`）はその場で集計するため
/// [computedAt]・[windowId]がnullになる。期間別（year/month/week/day）は
/// バッチが事前計算したスナップショットを返すので、いつ時点の集計かを
/// [computedAt]で画面に出せる。
class ApiRankingPage {
  final String period;
  final List<ApiWork> works;
  final DateTime? computedAt;
  final String? windowId;

  const ApiRankingPage({
    required this.period,
    required this.works,
    this.computedAt,
    this.windowId,
  });

  factory ApiRankingPage.fromJson(Map<String, dynamic> json) => ApiRankingPage(
    period: _string(json['period']),
    works: _works(json['works']),
    computedAt: json['computedAt'] == null
        ? null
        : _dateTime(json['computedAt']),
    windowId: json['windowId'] as String?,
  );
}

/// 被ブックマーク一覧（`GET /works/{id}/bookmarkers`）。
///
/// [totalCount]は非公開設定の人も含んだ総数、[users]は一覧公開を許可した
/// 人だけ。「集計」と「表示」を分けるという22.7節の設計がそのまま出ている。
class ApiBookmarkers {
  final String workId;
  final int totalCount;
  final List<ApiUserRef> users;

  const ApiBookmarkers({
    required this.workId,
    required this.totalCount,
    required this.users,
  });

  factory ApiBookmarkers.fromJson(Map<String, dynamic> json) => ApiBookmarkers(
    workId: _string(json['workId']),
    totalCount: _int(json['totalCount']),
    users: _users(json['users']),
  );
}

/// フォロワー一覧（`GET /users/{id}/followers`）。
/// [visibleFollowers]は一覧公開を許可した人だけで、[hiddenCount]が
/// 「非公開にしているため出していない人数」。
class ApiFollowers {
  final String targetId;
  final int totalCount;
  final List<ApiUserRef> visibleFollowers;
  final int hiddenCount;

  const ApiFollowers({
    required this.targetId,
    required this.totalCount,
    required this.visibleFollowers,
    required this.hiddenCount,
  });

  factory ApiFollowers.fromJson(Map<String, dynamic> json) => ApiFollowers(
    targetId: _string(json['targetId']),
    totalCount: _int(json['totalCount']),
    visibleFollowers: _users(json['visibleFollowers']),
    hiddenCount: _int(json['hiddenCount']),
  );
}

/// フォロー通知1件（`GET /users/{id}/notifications`）。
class ApiFollowNotification {
  final String fromUserId;
  final String fromUserName;
  final DateTime createdAt;
  final bool read;

  const ApiFollowNotification({
    required this.fromUserId,
    required this.fromUserName,
    required this.createdAt,
    required this.read,
  });

  factory ApiFollowNotification.fromJson(Map<String, dynamic> json) =>
      ApiFollowNotification(
        fromUserId: _string(json['fromUserId']),
        fromUserName: _string(json['fromUserName']),
        createdAt: _dateTime(json['createdAt']),
        read: json['read'] == true,
      );
}

/// 通知一覧（`GET /users/{id}/notifications`）。
class ApiNotifications {
  final List<ApiFollowNotification> notifications;
  final int unreadCount;

  const ApiNotifications({
    required this.notifications,
    required this.unreadCount,
  });

  factory ApiNotifications.fromJson(Map<String, dynamic> json) =>
      ApiNotifications(
        notifications: (json['notifications'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ApiFollowNotification.fromJson)
            .toList(),
        unreadCount: _int(json['unreadCount']),
      );
}

// ─── JSONの読み取りヘルパー ────────────────────────────────────────
// サーバーは型を守って返すが、通信の途中でプロキシに書き換えられる等の
// 想定外に対しても**画面が落ちない**ことを優先し、型が違えば既定値へ
// 倒す（例外にしない）。落ちた値は表示が空になるだけで済む。

List<ApiWork> _works(Object? raw) => (raw as List? ?? const [])
    .whereType<Map<String, dynamic>>()
    .map(ApiWork.fromJson)
    .toList();

List<ApiUserRef> _users(Object? raw) => (raw as List? ?? const [])
    .whereType<Map<String, dynamic>>()
    .map(ApiUserRef.fromJson)
    .toList();

String _string(Object? raw) => raw is String ? raw : '';

int _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}

List<String> _stringList(Object? raw) =>
    (raw as List? ?? const []).whereType<String>().toList();

/// ISO8601をパースする。解釈できない場合はエポックにする
/// （並び替えで最後尾へ落ちるだけで、画面は壊れない）。
DateTime _dateTime(Object? raw) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
