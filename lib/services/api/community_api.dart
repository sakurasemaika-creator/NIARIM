import 'niarim_api_client.dart';
import 'niarim_api_models.dart';

/// ランキングの集計期間（`GET /ranking/{period}`のパス要素）。
///
/// 文字列はバックエンドの`backend/src/api/routes/ranking.ts`が受け付ける
/// 値と一致させること。
enum RankingPeriod {
  /// 累計（その場でGSI1をQueryする）。
  all('all'),

  /// 年間・月間・週間・デイリー（統計更新バッチが事前計算した
  /// スナップショットを返す）。
  year('year'),
  month('month'),
  week('week'),
  day('day'),

  /// NIARIM独自のブックマーク数ランキング（その場でGSI2をQueryする）。
  bookmarks('bookmarks');

  const RankingPeriod(this.pathValue);
  final String pathValue;
}

/// 作品広場バックエンドの全エンドポイントを型付きで呼ぶ層。
///
/// `backend/src/api/handler.ts`のルーティング表と1対1に対応させてある
/// （メソッド・パス・パラメータの並びまで含めて）。片方を変えたら
/// もう片方も必ず合わせること。対応は
/// `test/community_api_test.dart`が実際のリクエストを検査して守っている。
///
/// この層は**HTTPの都合だけ**を扱い、アプリ内の状態は持たない
/// （キャッシュ・楽観更新・ダミーデータへのフォールバックは、これを使う
/// `CommunityService`側の責務）。
class CommunityApi {
  final NiarimApiClient _client;

  const CommunityApi(this._client);

  // ─── 読み取り系（ログイン不要） ─────────────────────────────────

  /// 新着一覧。`GET /works/latest`
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

  /// ランキング。`GET /ranking/{period}`
  Future<ApiRankingPage> ranking(RankingPeriod period) async {
    final json = await _client.getJson('/ranking/${period.pathValue}');
    return ApiRankingPage.fromJson(json);
  }

  /// 作者別の投稿一覧。`GET /users/{id}/works`
  ///
  /// 本人が自分の一覧を見るときは非公開作品も返るため、
  /// [asOwner]をtrueにしてIDトークンを添える。
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

  /// この作品をブックマークした人の一覧。`GET /works/{id}/bookmarkers`
  Future<ApiBookmarkers> bookmarkers(String workId) async {
    final json = await _client.getJson(
      '/works/${Uri.encodeComponent(workId)}/bookmarkers',
    );
    return ApiBookmarkers.fromJson(json);
  }

  /// あるユーザーのブックマーク一覧。`GET /users/{id}/bookmarks`
  ///
  /// 非公開設定のユーザーの一覧は本人以外403になるので、自分の一覧を
  /// 取るときは[asOwner]をtrueにする。
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

  /// フォロワー一覧。`GET /users/{id}/followers`
  Future<ApiFollowers> followers(String userId, {bool asOwner = false}) async {
    final json = await _client.getJson(
      '/users/${Uri.encodeComponent(userId)}/followers',
      authenticated: asOwner,
    );
    return ApiFollowers.fromJson(json);
  }

  /// フォロー中一覧。`GET /users/{id}/following`
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

  // ─── 作品CRUD（要ログイン） ────────────────────────────────────

  /// 投稿する。`POST /works`
  ///
  /// [youtubeAccessToken]はYouTubeへのアップロードに使ったのと同じ
  /// アクセストークン。サーバーはこれで「その動画が本当に投稿者本人の
  /// チャンネルのものか」を確認する（なりすまし投稿の防止）。
  /// workId＝youtubeVideoIdなので、同じ動画を二度投稿しても
  /// 重複登録にはならない（サーバー側の冪等キー）。
  Future<ApiWork> createWork({
    required String youtubeVideoId,
    required String youtubeAccessToken,
    bool isShort = false,
  }) async {
    final json = await _client.postJson(
      '/works',
      body: {
        'youtubeVideoId': youtubeVideoId,
        'youtubeAccessToken': youtubeAccessToken,
        'isShort': isShort,
      },
    );
    return ApiWork.fromJson(_work(json));
  }

  /// 作品広場での公開/非公開を切り替える。`PATCH /works/{id}`
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

  /// 作品広場から取り下げる。`DELETE /works/{id}`
  /// （YouTube側の動画は消えない。作品広場の登録だけを消す）
  Future<void> deleteWork(String workId) =>
      _client.deleteJson('/works/${Uri.encodeComponent(workId)}');

  /// クラウド編集タグを更新する。`PATCH /works/{id}/tags`
  ///
  /// タグの追加・削除は誰でもでき、[lockedTags]（他人に消させないタグ）の
  /// 変更は投稿者本人だけがサーバー側で許可される。
  Future<ApiWork> updateTags(
    String workId, {
    required List<String> tags,
    Set<String>? lockedTags,
  }) async {
    final json = await _client.patchJson(
      '/works/${Uri.encodeComponent(workId)}/tags',
      body: {
        'tags': tags,
        if (lockedTags != null) 'lockedTags': lockedTags.toList(),
      },
    );
    return ApiWork.fromJson(_work(json));
  }

  // ─── エンゲージメント（要ログイン） ──────────────────────────────

  /// ブックマークをトグルする。`POST /works/{id}/bookmark`
  /// 戻り値は**操作後**の状態（trueならブックマーク済み）。
  Future<bool> toggleBookmark(String workId) async {
    final json = await _client.postJson(
      '/works/${Uri.encodeComponent(workId)}/bookmark',
    );
    return json['bookmarked'] == true;
  }

  /// リポストをトグルする。`POST /works/{id}/repost`
  Future<bool> toggleRepost(String workId) async {
    final json = await _client.postJson(
      '/works/${Uri.encodeComponent(workId)}/repost',
    );
    return json['reposted'] == true;
  }

  /// フォローをトグルする。`POST /users/{id}/follow`
  Future<bool> toggleFollow(String targetUserId) async {
    final json = await _client.postJson(
      '/users/${Uri.encodeComponent(targetUserId)}/follow',
    );
    return json['following'] == true;
  }

  /// 自分のブックマーク一覧を公開するかどうか。
  /// `PATCH /users/{id}/bookmarks-visibility`
  Future<bool> setBookmarksPublic(String userId, bool public) async {
    final json = await _client.patchJson(
      '/users/${Uri.encodeComponent(userId)}/bookmarks-visibility',
      body: {'public': public},
    );
    return json['bookmarksPublic'] == true;
  }

  /// 自分のフォロワー/フォロー中一覧を公開するかどうか。
  /// `PATCH /users/{id}/follow-visibility`
  Future<bool> setFollowersPublic(String userId, bool public) async {
    final json = await _client.patchJson(
      '/users/${Uri.encodeComponent(userId)}/follow-visibility',
      body: {'public': public},
    );
    return json['followersPublic'] == true;
  }

  // ─── 通報・ブロック（要ログイン） ───────────────────────────────

  /// 通報する。`POST /reports`
  /// [reason]は必須（UI側でも空欄では送信させない）。
  Future<void> reportWork({required String workId, required String reason}) =>
      _client.postJson('/reports', body: {'workId': workId, 'reason': reason});

  /// ユーザーをブロックする。`POST /blocks`
  Future<void> blockUser(String targetUserId) =>
      _client.postJson('/blocks', body: {'targetUserId': targetUserId});

  // ─── 通知（要ログイン） ────────────────────────────────────────

  /// 自分宛ての通知一覧。`GET /users/{id}/notifications`
  Future<ApiNotifications> notifications(String userId) async {
    final json = await _client.getJson(
      '/users/${Uri.encodeComponent(userId)}/notifications',
      authenticated: true,
    );
    return ApiNotifications.fromJson(json);
  }

  /// 通知を全部既読にする。`POST /users/{id}/notifications/mark-read`
  /// 戻り値は既読にした件数。
  Future<int> markNotificationsRead(String userId) async {
    final json = await _client.postJson(
      '/users/${Uri.encodeComponent(userId)}/notifications/mark-read',
    );
    final marked = json['markedCount'];
    return marked is int ? marked : 0;
  }

  /// プッシュ通知の宛先トークンを登録する。`PUT /users/{id}/push-token`
  /// 戻り値は登録できたかどうか（未対応プラットフォームではfalse）。
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

  /// 作品CRUD系の応答は`{work: {...}}`と作品オブジェクト直返しの両方が
  /// ありうるので、どちらでも読めるようにしておく。
  Map<String, dynamic> _work(Map<String, dynamic> json) {
    final nested = json['work'];
    return nested is Map<String, dynamic> ? nested : json;
  }
}
