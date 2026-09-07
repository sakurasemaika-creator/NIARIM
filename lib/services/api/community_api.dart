import 'niarim_api_client.dart';
import 'niarim_api_models.dart';

enum RankingPeriod {
  all('all'),
  year('yearly'),
  month('monthly'),
  week('weekly'),
  day('daily'),
  bookmarks('bookmarks');

  const RankingPeriod(this.pathValue);
  final String pathValue;
}

enum CommunityTagAction { add, remove, lock, unlock }

class CommunityApi {
  final NiarimApiClient _client;

  const CommunityApi(this._client);

  Future<List<ApiWork>> latestWorks({int? limit, String? cursor}) async {
    final json = await _client.getJson(
      '/works/latest',
      query: {if (limit != null) 'limit': '$limit', 'cursor': ?cursor},
    );
    return (json['works'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ApiWork.fromJson)
        .toList();
  }

  Future<ApiRankingPage> ranking(RankingPeriod period) async {
    final json = await _client.getJson('/ranking/${period.pathValue}');
    return ApiRankingPage.fromJson(json);
  }

  /// The signed-in account's works, including NIARIM-hidden works.
  /// The backend resolves the generated NIARIM user id from the Google ID token,
  /// so changing Google accounts immediately changes the owner list without a local
  /// author-id cache.
  Future<List<ApiWork>> myWorks() async {
    final json = await _client.getJson('/me/works', authenticated: true);
    return (json['works'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ApiWork.fromJson)
        .toList();
  }

  Future<List<ApiWork>> worksByAuthor(
    String authorId, {
    bool asOwner = false,
  }) async {
    final json = await _client.getJson(
      '/users/${Uri.encodeComponent(authorId)}/works',
      authenticated: asOwner,
    );
    return (json['works'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ApiWork.fromJson)
        .toList();
  }

  Future<ApiBookmarkers> bookmarkers(String workId) async {
    final json = await _client.getJson(
      '/works/${Uri.encodeComponent(workId)}/bookmarkers',
    );
    return ApiBookmarkers.fromJson(json);
  }

  Future<List<ApiWork>> bookmarksOf(
    String userId, {
    bool asOwner = false,
  }) async {
    final json = await _client.getJson(
      '/users/${Uri.encodeComponent(userId)}/bookmarks',
      authenticated: asOwner,
    );
    return (json['works'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ApiWork.fromJson)
        .toList();
  }

  Future<ApiFollowers> followers(String userId, {bool asOwner = false}) async {
    final json = await _client.getJson(
      '/users/${Uri.encodeComponent(userId)}/followers',
      authenticated: asOwner,
    );
    return ApiFollowers.fromJson(json);
  }

  Future<List<ApiUserRef>> following(
    String userId, {
    bool asOwner = false,
  }) async {
    final json = await _client.getJson(
      '/users/${Uri.encodeComponent(userId)}/following',
      authenticated: asOwner,
    );
    return (json['following'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ApiUserRef.fromJson)
        .toList();
  }

  Future<ApiWork> createWork({
    required String youtubeVideoId,
    required String youtubeAccessToken,
    bool isShort = false,
    bool isNiarimPublished = true,
    int? projectFps,
    int? projectFrameCount,
    int? projectWorkSeconds,
    DateTime? projectCreatedAt,
    int? projectCanvasWidth,
    int? projectCanvasHeight,
  }) async {
    // POST /works is intentionally special: youtubeVideoId is the backend workId and
    // idempotency key. Retrying once on a timeout/5xx cannot create a second NIARIM
    // work, and lets the client recover when the server committed the first request but
    // its response was lost. Other mutating API calls keep the client's retries=0.
    final json = await _client.postJson(
      '/works',
      retries: 1,
      body: {
        'youtubeVideoId': youtubeVideoId,
        'youtubeAccessToken': youtubeAccessToken,
        'isShort': isShort,
        'isNiarimPublished': isNiarimPublished,
        if (projectFps != null) 'projectFps': projectFps,
        if (projectFrameCount != null) 'projectFrameCount': projectFrameCount,
        if (projectWorkSeconds != null) 'projectWorkSeconds': projectWorkSeconds,
        if (projectCreatedAt != null)
          'projectCreatedAt': projectCreatedAt.toUtc().toIso8601String(),
        if (projectCanvasWidth != null) 'projectCanvasWidth': projectCanvasWidth,
        if (projectCanvasHeight != null) 'projectCanvasHeight': projectCanvasHeight,
      },
    );
    return ApiWork.fromJson(_work(json));
  }

  Future<ApiWork> updateWorkVisibility(
    String workId, {
    required bool isNiarimPublished,
  }) async {
    final json = await _client.patchJson(
      '/works/${Uri.encodeComponent(workId)}',
      body: {'isNiarimPublished': isNiarimPublished},
    );
    return ApiWork.fromJson(_work(json));
  }

  Future<void> deleteWork(String workId) =>
      _client.deleteJson('/works/${Uri.encodeComponent(workId)}');

  Future<ApiWork> updateTag(
    String workId, {
    required CommunityTagAction action,
    required String tag,
  }) async {
    final json = await _client.patchJson(
      '/works/${Uri.encodeComponent(workId)}/tags',
      body: {'action': action.name, 'tag': tag},
    );
    return ApiWork.fromJson(_work(json));
  }

  Future<bool> toggleBookmark(String workId) async {
    final json = await _client.postJson(
      '/works/${Uri.encodeComponent(workId)}/bookmark',
    );
    return json['bookmarked'] == true;
  }

  Future<bool> toggleRepost(String workId) async {
    final json = await _client.postJson(
      '/works/${Uri.encodeComponent(workId)}/repost',
    );
    return json['reposted'] == true;
  }

  Future<bool> toggleFollow(String targetUserId) async {
    final json = await _client.postJson(
      '/users/${Uri.encodeComponent(targetUserId)}/follow',
    );
    return json['following'] == true;
  }

  Future<bool> setBookmarksPublic(String userId, bool public) async {
    final json = await _client.patchJson(
      '/users/${Uri.encodeComponent(userId)}/bookmarks-visibility',
      body: {'public': public},
    );
    return json['bookmarksPublic'] == true;
  }

  Future<bool> setFollowersPublic(String userId, bool public) async {
    final json = await _client.patchJson(
      '/users/${Uri.encodeComponent(userId)}/follow-visibility',
      body: {'public': public},
    );
    return json['followersPublic'] == true;
  }

  Future<void> reportWork({required String workId, required String reason}) =>
      _client.postJson('/reports', body: {'workId': workId, 'reason': reason});

  Future<void> blockUser(String targetUserId) =>
      _client.postJson('/blocks', body: {'targetUserId': targetUserId});

  Future<ApiNotifications> notifications(String userId) async {
    final json = await _client.getJson(
      '/users/${Uri.encodeComponent(userId)}/notifications',
      authenticated: true,
    );
    return ApiNotifications.fromJson(json);
  }

  Future<int> markNotificationsRead(String userId) async {
    final json = await _client.postJson(
      '/users/${Uri.encodeComponent(userId)}/notifications/mark-read',
    );
    final marked = json['markedCount'];
    return marked is int ? marked : 0;
  }

  Future<bool> putPushToken(
    String userId, {
    required String token,
    required String platform,
  }) async {
    final json = await _client.putJson(
      '/users/${Uri.encodeComponent(userId)}/push-token',
      body: {'token': token, 'platform': platform},
    );
    return json['registered'] == true;
  }

  Map<String, dynamic> _work(Map<String, dynamic> json) {
    final nested = json['work'];
    return nested is Map<String, dynamic> ? nested : json;
  }
}
