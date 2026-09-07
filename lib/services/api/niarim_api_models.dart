import '../../models/community_work.dart';

/// バックエンドが返す作品1件（`backend/src/api/routes/_publicWork.ts`の
/// `toPublicWork`と1対1で対応する）。
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

  /// Owner-list responses include the current YouTube privacy state so the app
  /// can distinguish a NIARIM-hidden work from a work forced hidden by YouTube.
  /// Public list responses intentionally omit it.
  final String? youtubePrivacyStatus;

  final int projectFps;
  final int projectFrameCount;
  final int projectWorkSeconds;
  final DateTime? projectCreatedAt;
  final int projectCanvasWidth;
  final int projectCanvasHeight;

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
    this.youtubePrivacyStatus,
    this.projectFps = 0,
    this.projectFrameCount = 0,
    this.projectWorkSeconds = 0,
    this.projectCreatedAt,
    this.projectCanvasWidth = 0,
    this.projectCanvasHeight = 0,
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
    isNiarimPublished: json['isNiarimPublished'] != false,
    youtubePrivacyStatus: json['youtubePrivacyStatus'] as String?,
    projectFps: _int(json['projectFps']),
    projectFrameCount: _int(json['projectFrameCount']),
    projectWorkSeconds: _int(json['projectWorkSeconds']),
    projectCreatedAt: _nullableDateTime(json['projectCreatedAt']),
    projectCanvasWidth: _int(json['projectCanvasWidth']),
    projectCanvasHeight: _int(json['projectCanvasHeight']),
  );

  int get _derivedDurationSeconds =>
      projectFps > 0 && projectFrameCount > 0
          ? projectFrameCount ~/ projectFps
          : 0;

  CommunityWork toCommunityWork() => CommunityWork(
    id: workId,
    title: title,
    authorId: authorId,
    authorName: channelName,
    viewCount: viewCount,
    likeCount: likeCount,
    bookmarkCount: bookmarkCount,
    postedAt: postedAt,
    durationSeconds: _derivedDurationSeconds,
    thumbnailColorIndex: workId.hashCode.abs() % 6,
    projectFps: projectFps,
    projectFrameCount: projectFrameCount,
    projectWorkSeconds: projectWorkSeconds,
    projectCreatedAt: projectCreatedAt,
    projectCanvasWidth: projectCanvasWidth,
    projectCanvasHeight: projectCanvasHeight,
    tags: tags,
    lockedTags: lockedTags,
    isNiarimPublished: isNiarimPublished,
    isShort: isShort,
  );
}

class ApiUserRef {
  final String niarimUserId;
  final String? channelName;
  final String? channelAvatarUrl;
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

  String get displayName => (channelName == null || channelName!.isEmpty)
      ? niarimUserId
      : channelName!;
}

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

DateTime _dateTime(Object? raw) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _nullableDateTime(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
