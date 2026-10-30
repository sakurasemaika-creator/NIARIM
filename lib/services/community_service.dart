import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'community_milestone_store.dart';
import '../models/community_repost.dart';
import '../models/community_work.dart';
import 'api/community_api.dart';
import 'api/niarim_api_exception.dart';
import 'api/niarim_api_models.dart';
import '../utils/tolerant_preferences.dart';

/// An account-scoped request finished after that account was replaced.
class CommunityAccountChangedException implements Exception {
  const CommunityAccountChangedException();
}

/// フォロー中の作者タブに表示する1件（[CommunityService.favoriteAuthorFeed]）。
/// フォロー中の作者自身の投稿か、フォロー中の作者が他者の作品をリポスト
/// したものかのいずれかを表す。[repostedByAuthorId]がnullでない場合は
/// 後者で、[feedTime]はリポスト日時（一覧の並び替えに使う「新着」の
/// 基準）になる。
class FavoriteFeedEntry {
  final CommunityWork work;
  final DateTime feedTime;
  final String? repostedByAuthorId;
  final String? repostedByAuthorName;

  const FavoriteFeedEntry({
    required this.work,
    required this.feedTime,
    this.repostedByAuthorId,
    this.repostedByAuthorName,
  });

  bool get isRepost => repostedByAuthorId != null;
}

/// 「作品広場」機能の作品一覧と、タグ・ブックマーク等の状態を
/// アプリ全体で共有するサービス。
///
/// `CommunityScreen`のState内にローカルで持っていたものを、フローティング
/// プレビューウィンドウ（画面をまたいで表示し続ける）・作品詳細画面
/// （別ルート）の両方から同じ状態を参照・編集できるように、アプリ全体で
/// 共有するProviderへ引き上げてある。
///
/// ## バックエンドとの関係
///
/// [api]を渡すと実際のバックエンド（`backend/`）から一覧を取得できる
/// （[refreshFromBackend]）。渡さない場合は従来どおり表示確認用の
/// ダミーデータで動く。どちらを使うかは
/// `NiarimApiConfig.isConfigured`（ビルド時の`--dart-define`）で決まり、
/// **デプロイ前でもアプリの画面確認・スクリーンショット・テストが一通り
/// できる状態を保つ**ようにしてある。
///
/// 書き込み系（タグ・公開設定・「AI画像・AI動画使用」・ブックマーク・
/// リポスト・フォロー）は、手元へ即座に反映してからサーバーへ送り、
/// サーバーの返事で置き換える（断られたら自分の変更だけを戻し、理由を
/// [lastError]に入れる）。IDトークンはGoogleログインから得る。
///
/// バックエンド接続時に手元へ置く作品は、サーバーが最後に確認したもの
/// だけ（新着・ランキング・自分の作品・フォロー中の作者の作品とリポスト・
/// ブックマーク・開いた作者ページ）。どの一覧も同じ1つのストアを読み、
/// 閲覧者のフィルター（AI画像・AI動画使用の非表示・ミュートタイトル・
/// ミュートタグ）を同じ判定で通す。
class CommunityService extends ChangeNotifier {
  /// バックエンドのAPIクライアント。未設定（デプロイ前）ならnull。
  final CommunityApi? api;

  CommunityService({this.api}) {
    contentFiltersReady = _loadContentFilters();
    if (api == null) {
      // No notifications about individual follows, even in demo mode.
      loadMilestones();
    }
  }

  /// Completes after persisted display filters have been restored.
  late final Future<void> contentFiltersReady;

  int _accountRevision = 0;
  bool _disposed = false;

  /// Changes whenever account-scoped results must no longer be applied.
  int get accountRevision => _accountRevision;

  bool _isCurrentAccount(int revision) =>
      !_disposed && revision == _accountRevision;

  Future<T> _awaitInAccount<T>(Future<T> pending, int revision) async {
    try {
      final value = await pending;
      if (!_isCurrentAccount(revision)) {
        throw const CommunityAccountChangedException();
      }
      return value;
    } catch (_) {
      if (!_isCurrentAccount(revision)) {
        throw const CommunityAccountChangedException();
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _accountRevision++;
    super.dispose();
  }

  /// バックエンドに接続する設定になっているか。
  bool get isBackendConnected => api != null;

  /// A fresh, metadata-free playback check. In the demo build no remote player
  /// exists; keep the preview available for Flutter UI tests.
  Future<CommunityPlaybackStatus> playbackStatus(String workId) async {
    if (api == null) return CommunityPlaybackStatus.available;
    try {
      return await api!.playbackStatus(workId);
    } catch (error) {
      debugPrint('Playback status check failed: $error');
      return CommunityPlaybackStatus.unknown;
    }
  }

  /// 直近の取得が失敗した理由（成功していればnull）。画面側で
  /// 「読み込めませんでした・再試行」を出すために使う。
  NiarimApiException? get lastError => _lastError;
  NiarimApiException? _lastError;

  /// バックエンドから一覧を取得中かどうか。
  bool get isLoading => _isLoading;
  bool _isLoading = false;
  static const int pageSize = 25;
  String? _latestCursor;
  String? _rankingCursor;
  String? _searchCursor;
  String? _ownCursor;
  final Map<String, String?> _authorCursors = {};
  final Map<String, String?> _feedAuthorCursors = {};
  final Map<String, String?> _feedRepostCursors = {};
  bool _fetchingMoreLatest = false;
  bool _fetchingMoreRanking = false;
  bool _fetchingMoreSearch = false;
  bool _fetchingMoreOwn = false;
  bool _fetchingMoreFeed = false;
  final Set<String> _fetchingMoreAuthors = {};
  int _latestEpoch = 0;
  int _rankingEpoch = 0;
  int _searchEpoch = 0;
  String _searchQuery = '';
  bool _searchTagMode = false;
  bool _searchExact = false;
  bool _searchReady = false;
  Set<String> _searchIds = {};

  bool get hasMoreLatest => _latestCursor != null;
  bool get hasMoreRanking => _rankingCursor != null;
  bool get hasMoreSearch => _searchCursor != null;
  bool get hasMoreOwn => _ownCursor != null;
  bool get hasMoreFollowing =>
      _feedAuthorCursors.values.any((v) => v != null) ||
      _feedRepostCursors.values.any((v) => v != null);
  bool hasMoreAuthor(String authorId) => _authorCursors[authorId] != null;
  bool get isFetchingMoreLatest => _fetchingMoreLatest;
  bool get isFetchingMoreRanking => _fetchingMoreRanking;
  bool get isFetchingMoreSearch => _fetchingMoreSearch;
  bool get isFetchingMoreOwn => _fetchingMoreOwn;
  bool get isFetchingMoreFollowing => _fetchingMoreFeed;
  bool get searchReady => _searchReady;
  List<CommunityWork> get searchedWorks => [
    for (final work in _works)
      if (_searchIds.contains(work.id) &&
          work.isNiarimPublished &&
          !work.isUnavailable)
        work,
  ];
  List<CommunityWork> get latestPageWorks => [
    for (final work in _works)
      if (_latestIds.contains(work.id) &&
          work.isNiarimPublished &&
          !work.isUnavailable)
        work,
  ];

  bool _isSocialLoading = false;
  bool _hasLoadedSocial = false;
  NiarimApiException? _socialError;
  Future<bool>? _socialRequest;

  /// Initial account lists are independent of public discovery/ranking and
  /// following-feed failures, which remain available through [lastError].
  bool get isSocialLoading => _isSocialLoading;
  bool get hasLoadedSocial => _hasLoadedSocial;
  NiarimApiException? get socialError => _socialError;

  /// バックエンドから新着一覧を取り直して[works]へ反映する。
  ///
  /// [api]がnull（デプロイ前）のときは何もしないでfalseを返す
  /// ＝ダミーデータのまま。失敗しても**手元の一覧は消さない**
  /// （画面が真っ白になるより、古い内容が残っているほうがましなため）。
  /// 失敗の理由は[lastError]に入る。
  Future<bool> refreshFromBackend() async {
    final client = api;
    if (client == null) return false;
    final epoch = ++_latestEpoch;
    _latestCursor = null;
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final page = await client.latestWorksPage(limit: pageSize);
      if (_disposed || epoch != _latestEpoch) return false;
      _latestCursor = page.nextCursor;
      _mergeLatest([for (final w in page.works) w.toCommunityWork()]);
      return true;
    } on NiarimApiException catch (e) {
      if (_disposed) return false;
      _lastError = e;
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Append a real next server page instead of downloading every work.
  Future<bool> loadMoreLatest() async {
    final client = api;
    final cursor = _latestCursor;
    if (client == null || cursor == null || _fetchingMoreLatest) return false;
    final epoch = _latestEpoch;
    _fetchingMoreLatest = true;
    notifyListeners();
    try {
      final page = await client.latestWorksPage(
        limit: pageSize,
        cursor: cursor,
      );
      if (_disposed || epoch != _latestEpoch) return false;
      _latestCursor = page.nextCursor;
      for (final apiWork in page.works) {
        final work = _plazaCopy(apiWork);
        _latestIds.add(work.id);
        _upsert(work);
      }
      _pruneUnconfirmed();
      notifyListeners();
      return true;
    } on NiarimApiException catch (error) {
      if (!_disposed && epoch == _latestEpoch) _lastError = error;
      return false;
    } finally {
      _fetchingMoreLatest = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> refreshSearch({
    required String query,
    required bool tagMode,
    required bool exact,
  }) async {
    final client = api;
    if (client == null) return false;
    final epoch = ++_searchEpoch;
    _searchReady = true;
    _searchQuery = query;
    _searchTagMode = tagMode;
    _searchExact = exact;
    _searchCursor = null;
    _searchIds = {};
    notifyListeners();
    try {
      final page = await client.latestWorksPage(
        limit: pageSize,
        query: query,
        tagMode: tagMode,
        exact: exact,
      );
      if (_disposed || epoch != _searchEpoch) return false;
      _searchCursor = page.nextCursor;
      _searchIds = {for (final w in page.works) w.workId};
      for (final w in page.works) {
        _upsert(_plazaCopy(w));
      }
      _pruneUnconfirmed();
      notifyListeners();
      return true;
    } on NiarimApiException catch (error) {
      if (!_disposed && epoch == _searchEpoch) _lastError = error;
      return false;
    }
  }

  Future<bool> loadMoreSearch() async {
    final client = api;
    final cursor = _searchCursor;
    if (client == null || cursor == null || _fetchingMoreSearch) return false;
    final epoch = _searchEpoch;
    _fetchingMoreSearch = true;
    notifyListeners();
    try {
      final page = await client.latestWorksPage(
        limit: pageSize,
        cursor: cursor,
        query: _searchQuery,
        tagMode: _searchTagMode,
        exact: _searchExact,
      );
      if (_disposed || epoch != _searchEpoch) return false;
      _searchCursor = page.nextCursor;
      for (final w in page.works) {
        _searchIds.add(w.workId);
        _upsert(_plazaCopy(w));
      }
      _pruneUnconfirmed();
      notifyListeners();
      return true;
    } on NiarimApiException catch (error) {
      if (!_disposed && epoch == _searchEpoch) _lastError = error;
      return false;
    } finally {
      _fetchingMoreSearch = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// ランキングを取得する（画面側がタブごとに呼ぶ）。
  /// [api]がnullなら手元のダミーデータから作った一覧を返す。
  Future<List<CommunityWork>> fetchRanking(
    RankingPeriod period, {
    bool ascending = false,
    bool sortBookmarks = false,
  }) async {
    final client = api;
    if (client == null) return discoverableWorks;
    final epoch = ++_rankingEpoch;
    _rankingCursor = null;
    try {
      final page = await client.ranking(
        period,
        ascending: ascending,
        sortBookmarks: sortBookmarks,
      );
      if (_disposed || epoch != _rankingEpoch) return const [];
      _rankingCursor = page.nextCursor;
      _lastError = null;
      final ranked = [for (final w in page.works) _plazaCopy(w)];
      // Ranked works join the one store, so their detail, tags and the
      // viewer's filters work on the same copy as every other surface.
      for (final work in ranked) {
        _upsert(work);
      }
      _rankingIds = [for (final work in ranked) work.id];
      _pruneUnconfirmed();
      notifyListeners();
      return rankedWorks;
    } on NiarimApiException catch (e) {
      if (_disposed || epoch != _rankingEpoch) return const [];
      _lastError = e;
      // The previous period's order must not stand in for this one.
      _rankingIds = const [];
      _pruneUnconfirmed();
      notifyListeners();
      return const [];
    }
  }

  Future<bool> loadMoreRanking(
    RankingPeriod period, {
    bool ascending = false,
    bool sortBookmarks = false,
  }) async {
    final client = api;
    final cursor = _rankingCursor;
    if (client == null || cursor == null || _fetchingMoreRanking) return false;
    final epoch = _rankingEpoch;
    _fetchingMoreRanking = true;
    notifyListeners();
    try {
      final page = await client.ranking(
        period,
        cursor: cursor,
        ascending: ascending,
        sortBookmarks: sortBookmarks,
      );
      if (_disposed || epoch != _rankingEpoch) return false;
      _rankingCursor = page.nextCursor;
      for (final w in page.works) {
        _rankingIds.add(w.workId);
        _upsert(_plazaCopy(w));
      }
      _pruneUnconfirmed();
      notifyListeners();
      return true;
    } on NiarimApiException catch (error) {
      if (!_disposed && epoch == _rankingEpoch) _lastError = error;
      return false;
    } finally {
      _fetchingMoreRanking = false;
      if (!_disposed) notifyListeners();
    }
  }

  // With a backend the store starts empty rather than showing dummy works
  // until the first fetch.
  late final List<CommunityWork> _works = api == null
      ? buildDummyCommunityWorks()
      : <CommunityWork>[];
  final Set<String> _bookmarkedIds = {};
  // お気に入り作者（フォロー、Task#144）のNIARIM User ID集合。
  // バックエンド接続時はサーバーのフォロー中一覧（[loadSocial]）で
  // 埋め、トグルはサーバーへ送る。未接続時はアプリ内一時状態のみ。
  final Set<String> _favoriteAuthorIds = {};
  // Followed authors' names from the server's following list, for the
  // 「○○さんがリポスト」 label of their reposts.
  final Map<String, String> _followedNames = {};

  static const _hideAiImageVideoKey = 'community.hideGenerativeAiImageVideo';
  static const _mutedWordsKey = 'community.mutedWords';
  static const _mutedTagsKey = 'community.mutedTags';
  static const _mutedAuthorsKey = 'community.mutedAuthors';
  static const _mutedWorksKey = 'community.mutedWorks.v1';
  static const _alwaysVisibleWorksKey = 'community.alwaysVisibleWorks.v1';
  bool _hideGenerativeAiImageVideo = false;
  final Set<String> _mutedWords = {};
  final Set<String> _mutedTags = {};
  final Set<String> _mutedAuthorIds = {};
  final Set<String> _mutedWorkIds = {};
  final Set<String> _alwaysVisibleWorkIds = {};
  final Set<String> _temporaryVisibleWorkIds = {};

  bool get hideGenerativeAiImageVideo => _hideGenerativeAiImageVideo;
  Set<String> get mutedWords => Set.unmodifiable(_mutedWords);
  Set<String> get mutedTags => Set.unmodifiable(_mutedTags);
  Set<String> get mutedAuthorIds => Set.unmodifiable(_mutedAuthorIds);
  bool isAuthorMuted(String authorId) => _mutedAuthorIds.contains(authorId);
  bool isWorkExplicitlyMuted(String id) => _mutedWorkIds.contains(id);

  /// Device-local view only. The server's ranking and publication remain intact.
  bool isWorkMuted(CommunityWork work) {
    if (_temporaryVisibleWorkIds.contains(work.id) ||
        _alwaysVisibleWorkIds.contains(work.id)) {
      return false;
    }
    return _mutedWorkIds.contains(work.id) || !_passesContentFilters(work);
  }

  Future<void> setWorkMuted(String id) async {
    await contentFiltersReady;
    if (_disposed || id.isEmpty) return;
    _mutedWorkIds.add(id);
    _alwaysVisibleWorkIds.remove(id);
    _temporaryVisibleWorkIds.remove(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_mutedWorksKey, _mutedWorkIds.toList()..sort());
    await prefs.setStringList(
      _alwaysVisibleWorksKey,
      _alwaysVisibleWorkIds.toList()..sort(),
    );
  }

  Future<void> unmuteWork(String id, {required bool permanently}) async {
    await contentFiltersReady;
    if (_disposed || id.isEmpty) return;
    if (permanently) {
      _mutedWorkIds.remove(id);
      _temporaryVisibleWorkIds.remove(id);
      _alwaysVisibleWorkIds.add(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_mutedWorksKey, _mutedWorkIds.toList()..sort());
      await prefs.setStringList(
        _alwaysVisibleWorksKey,
        _alwaysVisibleWorkIds.toList()..sort(),
      );
    } else {
      _temporaryVisibleWorkIds.add(id);
    }
    notifyListeners();
  }

  void clearTemporaryUnmutes() {
    if (_temporaryVisibleWorkIds.isEmpty || _disposed) return;
    _temporaryVisibleWorkIds.clear();
    notifyListeners();
  }

  /// Never completes with an error: unreadable settings fall back to
  /// showing everything, so the setters below, which wait for this, keep
  /// working.
  Future<void> _loadContentFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hideGenerativeAiImageVideo =
          prefs.readBool(_hideAiImageVideoKey) ?? false;
      _mutedWords
        ..clear()
        ..addAll(
          (prefs.readStringList(_mutedWordsKey) ?? const [])
              .map((e) => e.trim().toLowerCase())
              .where((e) => e.isNotEmpty),
        );
      _mutedTags
        ..clear()
        ..addAll(
          (prefs.readStringList(_mutedTagsKey) ?? const [])
              .map(_tagKey)
              .where((e) => e.isNotEmpty),
        );
      _mutedAuthorIds
        ..clear()
        ..addAll(
          (prefs.readStringList(_mutedAuthorsKey) ?? const []).where(
            (id) => id.isNotEmpty,
          ),
        );
      _mutedWorkIds
        ..clear()
        ..addAll(prefs.readStringList(_mutedWorksKey) ?? const []);
      _alwaysVisibleWorkIds
        ..clear()
        ..addAll(prefs.readStringList(_alwaysVisibleWorksKey) ?? const []);
    } catch (error) {
      debugPrint('Community content filters could not be restored: $error');
    }
    if (!_disposed) notifyListeners();
  }

  /// Refresh in-memory rules after importing a portable device backup.
  Future<void> reloadLocalContentFilters() => _loadContentFilters();

  Future<void> setHideGenerativeAiImageVideo(bool value) async {
    await contentFiltersReady;
    if (_disposed) return;
    _hideGenerativeAiImageVideo = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hideAiImageVideoKey, value);
  }

  /// Splits what the viewer typed into mute entries: separated by commas
  /// (ASCII or full-width), 「、」 or new lines, trimmed and lower-cased.
  static List<String> parseFilterInput(String raw) => [
    for (final part in raw.split(RegExp(r'[,，、\n]')))
      if (part.trim().toLowerCase() case final entry when entry.isNotEmpty)
        entry,
  ];

  /// A tag as compared for muting: a leading # (ASCII or full-width) is not
  /// part of it, so 「#作画」 mutes the tag 「作画」.
  static String _tagKey(String tag) =>
      tag.trim().toLowerCase().replaceFirst(RegExp(r'^[#＃]+'), '');

  Future<void> setMutedWords(Iterable<String> values) async {
    await contentFiltersReady;
    if (_disposed) return;
    _mutedWords
      ..clear()
      ..addAll(
        values.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty),
      );
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_mutedWordsKey, _mutedWords.toList()..sort());
  }

  Future<void> setMutedTags(Iterable<String> values) async {
    await contentFiltersReady;
    if (_disposed) return;
    _mutedTags
      ..clear()
      ..addAll(values.map(_tagKey).where((e) => e.isNotEmpty));
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_mutedTagsKey, _mutedTags.toList()..sort());
  }

  /// Viewer-only mute, independent of Google sign-in and of the backend block
  /// endpoint. A muted author's works disappear from discovery/search without
  /// sending a notification to that author.
  Future<void> setAuthorMuted(String authorId, bool muted) async {
    await contentFiltersReady;
    if (_disposed || authorId.isEmpty) return;
    if (muted) {
      _mutedAuthorIds.add(authorId);
    } else {
      _mutedAuthorIds.remove(authorId);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _mutedAuthorsKey,
      _mutedAuthorIds.toList()..sort(),
    );
  }

  bool _passesContentFilters(CommunityWork work) {
    if (_mutedAuthorIds.contains(work.authorId)) return false;
    if (_hideGenerativeAiImageVideo && work.containsGenerativeAiImageOrVideo) {
      return false;
    }
    // ミュートワードは作品タイトルだけを対象にする。作者名や作品広場の
    // ユーザータグへ波及させない（タグは下のミュートタグで独立判定）。
    final title = work.title.toLowerCase();
    if (_mutedWords.any(title.contains)) return false;

    // ミュートタグは作品広場で作品に設定されたタグだけが対象。
    // YouTube側のメタデータやタイトル中の #文字列 はタグ扱いしない。
    final communityTags = work.tags.map(_tagKey);
    if (communityTags.any(_mutedTags.contains)) return false;
    return true;
  }

  // リポスト（Task#145の調査を受けた新機能）。誰が・どの作品を・いつ
  // リポストしたかの記録。自分（kDummySelfAuthorId）のリポストは実際に
  // ボタン操作で追加・削除できるが、他のダミー作者のリポストは
  // 「フォロー中の作者タブに他者の作品が混ざる」見た目を最初から確認
  // できるよう、_buildDummyRepostsで固定シードの乱数によりあらかじめ
  // 何件か生成しておく。
  // Demo social data exists only without a backend: it must never be
  // attributed to real users' works.
  late final List<CommunityRepost> _reposts = api == null
      ? _buildDummyReposts(_works)
      : <CommunityRepost>[];
  // 各authorIdの「自分のブックマーク一覧を他ユーザーに公開するか」設定。
  // ユーザー別ブックマーク一覧の実現可否調査（Task#145・29_動画投稿・
  // ランキング機能仕様.md 21.2節）でプライバシー面から既定非公開を推奨
  // したため、自分（kDummySelfAuthorId）は既定false。他のダミー作者は
  // 公開/非公開どちらの見た目も確認できるよう交互に割り当てている。
  final Map<String, bool> _bookmarksPublicByAuthor =
      _buildDummyPublicVisibility();
  // 他のダミー作者（自分以外）が何をブックマークしているかの表示確認用
  // ダミーデータ。実際のマルチユーザーバックエンドが無いため、自分の
  // ブックマーク（_bookmarkedIds、実際にトグル可能）とは別に固定シードの
  // 乱数で生成する。
  late final Map<String, Set<String>> _dummyBookmarksByOtherAuthor = api == null
      ? _buildDummyBookmarksByAuthor(_works)
      : {};
  // フォロワー一覧（Task#134継続：本人選択制で公開できる妥協案。22.5節）。
  // 他のダミー作者同士が誰をフォローしているかの表示確認用ダミーデータ
  // （固定シードの乱数で生成）。表示時はここへ「自分がフォローして
  // いれば自分自身のID」を加算する（followerIdsOf参照）。
  late final Map<String, Set<String>> _dummyFollowersByAuthor = api == null
      ? _buildDummyFollowersByAuthor(_works)
      : {};
  final CommunityMilestoneStore _milestoneStore = CommunityMilestoneStore();
  List<CommunityMilestoneEvent> _milestoneEvents = [];
  final Map<String, int> _followerCounts = {};
  final Map<String, int> _followingCounts = {};

  @visibleForTesting
  void replaceWorksForTest(Iterable<CommunityWork> works) {
    _works
      ..clear()
      ..addAll(works);
  }

  List<CommunityWork> get works => List.unmodifiable(_works);
  Set<String> get bookmarkedIds => Set.unmodifiable(_bookmarkedIds);

  /// The viewer's bookmarks, newest first, as their filters allow.
  /// Their own works remain visible even when hidden from other viewers.
  List<CommunityWork> get bookmarkedWorksForViewer => [
    for (final id in bookmarkedIdsNewestFirst) ?byId(id),
  ];

  List<String> get bookmarkedIdsNewestFirst =>
      _bookmarkedIds.toList().reversed.toList();
  Set<String> get favoriteAuthorIds => Set.unmodifiable(_favoriteAuthorIds);

  /// 新着・ランキングなど「発見」用の一覧に出す作品（NIARIM側で非公開に
  /// した作品を除外する。13章：YouTube側が非公開・削除の場合も表示を
  /// 強制停止する設計だが、ダミーデータにはYouTube側状態の概念が無いため
  /// ここではNIARIM側設定のみを対象にする）。
  // Keep the raw discoverable slots, including muted works, so ranking
  // positions do not shift when a viewer mutes an author or keyword.
  // Individual feeds/author lists apply the viewer's filters separately.
  List<CommunityWork> get discoverableWorks =>
      _works.where((w) => w.isNiarimPublished && !w.isUnavailable).toList();

  /// Whether a work may appear in public discovery surfaces for the
  /// current viewer. Owner-only management screens intentionally bypass this.
  bool isDiscoverableForViewer(CommunityWork work) =>
      !work.isUnavailable && work.isNiarimPublished && !isWorkMuted(work);

  CommunityWork? byId(String workId) {
    final index = _indexOf(workId);
    return index == -1 ? null : _works[index];
  }

  /// [authorId]の投稿作品一覧。[includeHidden]がfalse（既定）の場合は
  /// NIARIM側で非公開にした作品を除外する。投稿者本人が自分の投稿者別
  /// 作品一覧を開く場合のみ[includeHidden]をtrueにして、非公開中の作品も
  /// 確認・再公開できるようにする。
  List<CommunityWork> worksByAuthor(
    String authorId, {
    bool includeHidden = false,
  }) => _works
      .where(
        (w) =>
            w.authorId == authorId &&
            (includeHidden || isDiscoverableForViewer(w)),
      )
      .toList();

  int _indexOf(String workId) => _works.indexWhere((w) => w.id == workId);

  /// The signed-in poster's NIARIM user id, from GET /me/works. Without a
  /// backend the dummy self author stands in; with one, nothing is the
  /// viewer's own until it is known.
  String? get currentUserId => _currentUserId;
  String? _currentUserId;

  // With a backend the store holds what the server last confirmed: the
  // latest page, the last ranking, the signed-in poster's own works, the
  // following feed (followed authors' works and reposts), the viewer's
  // bookmarks and the author pages opened.
  Set<String> _latestIds = {};
  List<String> _rankingIds = const [];
  final Set<String> _ownIds = {};
  Set<String> _feedIds = {};
  Set<String> _bookmarkWorkIds = {};
  final Map<String, Set<String>> _authorPageIds = {};

  /// The last fetched ranking in the server's order, as the viewer's
  /// filters allow.
  List<CommunityWork> get rankedWorks => [
    for (final id in _rankingIds)
      if (byId(id) case final work?
          when work.isNiarimPublished && !work.isUnavailable)
        work,
  ];

  void setCurrentUserId(String? id) {
    if (_currentUserId == id) return;
    if (_currentUserId != null) forgetOwner();
    _currentUserId = id;
    _milestoneEvents = [];
    loadMilestones();
    notifyListeners();
  }

  /// Whether the viewer posted [work], and so may change its settings and
  /// still sees it when it is hidden or filtered out.
  bool isOwnWork(CommunityWork work) => isOwnAuthor(work.authorId);

  bool isOwnAuthor(String authorId) => authorId == _selfId;

  /// Who the viewer is as a reposter, follower or bookmarker: the signed-in
  /// poster with a backend (null until known), the dummy self without one.
  String? get _selfId =>
      _currentUserId ?? (api == null ? kDummySelfAuthorId : null);

  static const _ownerByAccountPrefix = 'community.ownerByAccount.';

  /// Takes back the NIARIM user id this device last learned for the Google
  /// account [accountKey], so the poster is recognised as such (their own
  /// settings, their hidden works) from the start, before GET /me/works
  /// answers. A Google account always maps to the same NIARIM user, so
  /// the remembered id cannot belong to someone else.
  Future<void> restoreOwner(String accountKey) async {
    final revision = _accountRevision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.readString('$_ownerByAccountPrefix$accountKey');
      if (_isCurrentAccount(revision) && id != null && _currentUserId == null) {
        _currentUserId = id;
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Community owner could not be restored: $error');
    }
  }

  /// Learns who the signed-in poster is from GET /me/works and keeps their
  /// works, hidden ones included, in the store so their detail and author
  /// pages open. With [accountKey] (the Google account) the id is
  /// remembered for [restoreOwner]. Returns the page, or null without a
  /// backend.
  Future<ApiMyWorks?> loadOwnWorks({String? accountKey}) async {
    final client = api;
    if (client == null) return null;
    final revision = _accountRevision;
    final ApiMyWorks page;
    _ownCursor = null;
    try {
      page = await _awaitInAccount(client.myWorks(), revision);
    } on CommunityAccountChangedException {
      return null;
    }
    if (!_isCurrentAccount(revision)) return null;
    setCurrentUserId(page.authorId);
    _ownCursor = page.nextCursor;
    _ownIds.clear();
    for (final apiWork in page.works) {
      final work = _plazaCopy(apiWork);
      _ownIds.add(work.id);
      _upsert(work);
    }
    _pruneUnconfirmed();
    notifyListeners();
    await _observeOwnMilestones(
      ownWorks: [for (final id in _ownIds) ?byId(id)],
    );
    final id = page.authorId;
    if (accountKey != null && id != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_ownerByAccountPrefix$accountKey', id);
      } catch (error) {
        debugPrint('Community owner could not be remembered: $error');
      }
    }
    return page;
  }

  Future<ApiMyWorks?> loadMoreOwnWorks() async {
    final client = api;
    final cursor = _ownCursor;
    if (client == null || cursor == null || _fetchingMoreOwn) return null;
    final revision = _accountRevision;
    final owner = _currentUserId;
    _fetchingMoreOwn = true;
    try {
      final page = await _awaitInAccount(
        client.myWorks(cursor: cursor),
        revision,
      );
      if (!_isCurrentAccount(revision) || page.authorId != owner) return null;
      _ownCursor = page.nextCursor;
      for (final apiWork in page.works) {
        final work = _plazaCopy(apiWork);
        _ownIds.add(work.id);
        _upsert(work);
      }
      notifyListeners();
      return page;
    } on CommunityAccountChangedException {
      return null;
    } finally {
      _fetchingMoreOwn = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// With a backend and a known poster, takes in the viewer's bookmarks and
  /// follows from the server, then the following feed ([refreshFollowingFeed]).
  /// Returns false when there is nothing to load or it failed ([lastError]).
  Future<bool> loadSocial() {
    if (api == null || _currentUserId == null) return Future.value(false);
    if (_socialRequest case final pending?) return pending;
    final completer = Completer<bool>();
    final request = completer.future;
    _socialRequest = request;
    _loadSocial().then(
      (value) {
        if (identical(_socialRequest, request)) _socialRequest = null;
        completer.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_socialRequest, request)) _socialRequest = null;
        completer.completeError(error, stack);
      },
    );
    return request;
  }

  Future<bool> _loadSocial() async {
    final client = api;
    final me = _currentUserId;
    if (client == null || me == null) return false;
    final revision = _accountRevision;
    _isSocialLoading = true;
    _socialError = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        client.bookmarksOf(me, asOwner: true),
        client.following(me, asOwner: true),
      ]);
      if (!_isCurrentAccount(revision)) return false;
      final bookmarks = results[0] as List<ApiWork>;
      final following = results[1] as List<ApiUserRef>;
      final bookmarked = [for (final w in bookmarks) _plazaCopy(w)];
      for (final work in bookmarked) {
        _upsert(work);
      }
      _bookmarkWorkIds = {for (final w in bookmarked) w.id};
      // The server lists newest first; the set keeps oldest first.
      _bookmarkedIds
        ..clear()
        ..addAll(bookmarked.reversed.map((w) => w.id));
      _favoriteAuthorIds
        ..clear()
        ..addAll(following.map((u) => u.niarimUserId));
      _followedNames
        ..clear()
        ..addAll({for (final u in following) u.niarimUserId: ?u.channelName});
      _hasLoadedSocial = true;
      final loaded = await refreshFollowingFeed();
      if (!_isCurrentAccount(revision)) return false;
      return loaded;
    } on NiarimApiException catch (error) {
      if (!_isCurrentAccount(revision)) return false;
      _lastError = error;
      _socialError = error;
      return false;
    } finally {
      if (_isCurrentAccount(revision)) {
        _isSocialLoading = false;
        notifyListeners();
      }
    }
  }

  /// The following feed from the server: the followed authors' works and
  /// reposts, and the viewer's own reposts (so 「リポスト済み」 shows). They
  /// join the one store, so the viewer's filters apply to them like to
  /// every other surface. Without a backend the dummy feed stays.
  Future<bool> refreshFollowingFeed() async {
    final client = api;
    if (client == null) return false;
    final revision = _accountRevision;
    final me = _currentUserId;
    final authors = {..._favoriteAuthorIds};
    try {
      final pages = await Future.wait([
        for (final id in authors) client.worksByAuthorPage(id),
      ]);
      if (!_isCurrentAccount(revision)) return false;
      _feedAuthorCursors
        ..clear()
        ..addEntries(
          authors.toList().asMap().entries.map(
            (entry) => MapEntry(entry.value, pages[entry.key].nextCursor),
          ),
        );
      if (!_isCurrentAccount(revision)) return false;
      final reposters = [
        ...authors,
        if (me != null && !authors.contains(me)) me,
      ];
      final reposts = await Future.wait<ApiRepostPage>([
        for (final id in reposters)
          id == me
              ? client
                    .repostsOf(id)
                    .then((entries) => ApiRepostPage(reposts: entries))
              : client.repostsOfPage(id),
      ]);
      if (!_isCurrentAccount(revision)) return false;
      _feedRepostCursors
        ..clear()
        ..addEntries(
          reposters.asMap().entries.map(
            (entry) => MapEntry(entry.value, reposts[entry.key].nextCursor),
          ),
        );
      final feed = <String>{};
      for (final page in pages) {
        for (final apiWork in page.works) {
          final work = _plazaCopy(apiWork);
          _upsert(work);
          feed.add(work.id);
        }
      }
      _reposts.clear();
      for (var i = 0; i < reposters.length; i++) {
        final reposterId = reposters[i];
        for (final entry in reposts[i].reposts) {
          final work = _plazaCopy(entry.work);
          _upsert(work);
          feed.add(work.id);
          _reposts.add(
            CommunityRepost(
              workId: work.id,
              reposterId: reposterId,
              reposterName:
                  _followedNames[reposterId] ?? authorNameOf(reposterId) ?? '',
              repostedAt: entry.repostedAt,
            ),
          );
        }
      }
      _feedIds = feed;
      _lastError = null;
      _pruneUnconfirmed();
      notifyListeners();
      return true;
    } on NiarimApiException catch (error) {
      if (!_isCurrentAccount(revision)) return false;
      _lastError = error;
      notifyListeners();
      return false;
    }
  }

  /// Only the next 25 works of each followed author are requested.
  /// Repost pages still use the separate repost endpoint.
  Future<bool> loadMoreFollowingFeed() async {
    final client = api;
    if (client == null || _fetchingMoreFeed || !hasMoreFollowing) return false;
    final revision = _accountRevision;
    _fetchingMoreFeed = true;
    notifyListeners();
    try {
      final targets = {
        for (final entry in _feedAuthorCursors.entries)
          if (entry.value != null && _favoriteAuthorIds.contains(entry.key))
            entry.key: entry.value!,
      };
      final repostTargets = {
        for (final entry in _feedRepostCursors.entries)
          if (entry.value != null && _favoriteAuthorIds.contains(entry.key))
            entry.key: entry.value!,
      };
      if (targets.isEmpty && repostTargets.isEmpty) return false;
      final pages = await Future.wait([
        for (final entry in targets.entries)
          client.worksByAuthorPage(entry.key, cursor: entry.value),
      ]);
      final repostPages = await Future.wait([
        for (final entry in repostTargets.entries)
          client.repostsOfPage(entry.key, cursor: entry.value),
      ]);
      if (!_isCurrentAccount(revision)) return false;
      var index = 0;
      for (final authorId in targets.keys) {
        final page = pages[index++];
        _feedAuthorCursors[authorId] = page.nextCursor;
        for (final w in page.works) {
          _feedIds.add(w.workId);
          _upsert(_plazaCopy(w));
        }
      }
      index = 0;
      for (final reposterId in repostTargets.keys) {
        final page = repostPages[index++];
        _feedRepostCursors[reposterId] = page.nextCursor;
        for (final entry in page.reposts) {
          final work = _plazaCopy(entry.work);
          _feedIds.add(work.id);
          _upsert(work);
          _reposts.add(
            CommunityRepost(
              workId: work.id,
              reposterId: reposterId,
              reposterName:
                  _followedNames[reposterId] ?? authorNameOf(reposterId) ?? '',
              repostedAt: entry.repostedAt,
            ),
          );
        }
      }
      _pruneUnconfirmed();
      notifyListeners();
      return true;
    } on NiarimApiException catch (error) {
      if (_isCurrentAccount(revision)) _lastError = error;
      return false;
    } finally {
      _fetchingMoreFeed = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// An author's page from the server (the owner's own page includes their
  /// hidden works). The works join the one store; [worksByAuthor] then lists
  /// them through the viewer's filters. Without a backend nothing changes.
  Future<bool> refreshAuthorWorks(String authorId) async {
    final client = api;
    if (client == null) return false;
    final revision = _accountRevision;
    try {
      final page = await client.worksByAuthorPage(
        authorId,
        asOwner: isOwnAuthor(authorId),
      );
      if (!_isCurrentAccount(revision)) return false;
      _authorCursors[authorId] = page.nextCursor;
      final works = [for (final w in page.works) _plazaCopy(w)];
      for (final work in works) {
        _upsert(work);
      }
      _authorPageIds[authorId] = {for (final w in works) w.id};
      _lastError = null;
      _pruneUnconfirmed();
      notifyListeners();
      return true;
    } on NiarimApiException catch (error) {
      if (!_isCurrentAccount(revision)) return false;
      _lastError = error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadMoreAuthorWorks(String authorId) async {
    final client = api;
    final cursor = _authorCursors[authorId];
    if (client == null ||
        cursor == null ||
        !_fetchingMoreAuthors.add(authorId)) {
      return false;
    }
    final revision = _accountRevision;
    try {
      final page = await client.worksByAuthorPage(
        authorId,
        asOwner: isOwnAuthor(authorId),
        cursor: cursor,
      );
      if (!_isCurrentAccount(revision)) return false;
      _authorCursors[authorId] = page.nextCursor;
      final ids = _authorPageIds.putIfAbsent(authorId, () => {});
      for (final w in page.works) {
        final work = _plazaCopy(w);
        ids.add(work.id);
        _upsert(work);
      }
      notifyListeners();
      return true;
    } on NiarimApiException catch (error) {
      if (_isCurrentAccount(revision)) _lastError = error;
      return false;
    } finally {
      _fetchingMoreAuthors.remove(authorId);
      if (!_disposed) notifyListeners();
    }
  }

  /// Signing out or switching accounts: the viewer is nobody's poster until
  /// [loadOwnWorks] runs again, and their hidden works leave the store.
  void forgetOwner() {
    _accountRevision++;
    _currentUserId = null;
    _milestoneEvents = [];
    _followerCounts.clear();
    _followingCounts.clear();
    _lastError = null;
    _isSocialLoading = false;
    _hasLoadedSocial = false;
    _socialError = null;
    _socialRequest = null;
    _ownIds.clear();
    if (api != null) {
      // The signed-out viewer has no bookmarks, follows or reposts.
      _bookmarkedIds.clear();
      _bookmarkWorkIds = {};
      _favoriteAuthorIds.clear();
      _followedNames.clear();
      _reposts.clear();
      _feedIds = {};
      _authorPageIds.clear();
      _authorCursors.clear();
      _feedAuthorCursors.clear();
      _feedRepostCursors.clear();
      _ownCursor = null;
      _searchEpoch++;
      _searchIds.clear();
      _searchCursor = null;
      _searchReady = false;
      _works.removeWhere((work) => !work.isNiarimPublished);
    }
    _pruneUnconfirmed();
    notifyListeners();
  }

  /// The plaza's copy of a work the server sent: one private or deleted on
  /// YouTube is not public, whatever its own setting (the owner's API
  /// replies include such works).
  static CommunityWork _plazaCopy(ApiWork work) {
    final converted = work.toCommunityWork();
    if (converted.isUnavailable) return converted;
    final youtube = work.youtubePrivacyStatus;
    return youtube == 'private' || youtube == 'deleted'
        ? converted.copyWith(isNiarimPublished: false)
        : converted;
  }

  /// Puts the server's copy of a work in place of the local one, so every
  /// surface reading this service sees the change at once without
  /// refetching the latest list, which may not contain the work at all.
  void applyServerWork(CommunityWork work) {
    _upsert(work);
    notifyListeners();
  }

  void _upsert(CommunityWork work) {
    final index = _indexOf(work.id);
    if (index == -1) {
      final at = _works.indexWhere((w) => w.postedAt.isBefore(work.postedAt));
      _works.insert(at == -1 ? _works.length : at, work);
    } else {
      _works[index] = work;
    }
  }

  /// Takes in the latest page, in the server's order, ahead of the other
  /// works the server still confirms.
  void _mergeLatest(List<CommunityWork> page) {
    _latestIds = {for (final w in page) w.id};
    final others = [
      for (final w in _works)
        if (!_latestIds.contains(w.id)) w,
    ];
    _works
      ..clear()
      ..addAll(page)
      ..addAll(others);
    _pruneUnconfirmed();
  }

  /// Drops works the server no longer confirms (one hidden or deleted since
  /// it was fetched), so no surface keeps showing a stale public copy.
  void _pruneUnconfirmed() {
    if (api == null) return;
    final confirmed = {
      ..._latestIds,
      ..._rankingIds,
      ..._searchIds,
      ..._ownIds,
      ..._feedIds,
      ..._bookmarkWorkIds,
      for (final ids in _authorPageIds.values) ...ids,
    };
    _works.removeWhere((w) => !confirmed.contains(w.id));
  }

  /// Sets the poster's 「AI画像・AI動画使用」 declaration on [workId]. Only the
  /// poster may change it; with a backend the server checks that as well,
  /// and its reply is applied.
  Future<CommunityWork> setAiImageVideoDisclosure(
    String workId,
    bool value,
  ) async {
    final known = byId(workId);
    if (known != null && !isOwnWork(known)) {
      throw StateError('Only the poster can change $workId');
    }
    final client = api;
    if (client != null) {
      final revision = _accountRevision;
      final reply = await _awaitInAccount(
        client.updateWorkAiImageVideoDisclosure(
          workId,
          containsGenerativeAiImageOrVideo: value,
        ),
        revision,
      );
      if (!_isCurrentAccount(revision)) {
        throw const CommunityAccountChangedException();
      }
      _ownIds.add(workId);
      applyServerWork(_plazaCopy(reply));
      return reply.toCommunityWork();
    }
    if (known == null) throw StateError('Unknown work: $workId');
    final updated = known.copyWith(containsGenerativeAiImageOrVideo: value);
    _works[_indexOf(workId)] = updated;
    notifyListeners();
    return updated;
  }

  /// The poster's NIARIM visibility setting, sent and applied; used by the
  /// owner list, which knows the setting it wants rather than a toggle.
  Future<CommunityWork> setNiarimVisibility(String workId, bool value) async {
    final client = api;
    if (client == null) {
      final known = byId(workId);
      if (known == null) throw StateError('Unknown work: $workId');
      if (known.isNiarimPublished != value) {
        await toggleNiarimVisibility(workId);
      }
      return byId(workId)!;
    }
    final revision = _accountRevision;
    final reply = await _awaitInAccount(
      client.updateWorkVisibility(workId, isNiarimPublished: value),
      revision,
    );
    if (!_isCurrentAccount(revision)) {
      throw const CommunityAccountChangedException();
    }
    _ownIds.add(workId);
    applyServerWork(_plazaCopy(reply));
    return reply.toCommunityWork();
  }

  /// Deletes only the poster's NIARIM entry. The YouTube video is deliberately
  /// left untouched; removing it there requires a separate explicit action.
  Future<void> deleteOwnWork(String workId) async {
    final known = byId(workId);
    if (known == null || !isOwnWork(known)) {
      throw StateError('Only the poster can delete $workId');
    }
    final revision = _accountRevision;
    final client = api;
    if (client != null) {
      await _awaitInAccount(client.deleteWork(workId), revision);
    }
    if (!_isCurrentAccount(revision)) {
      throw const CommunityAccountChangedException();
    }
    // Personal bookmark history keeps a redacted entry; rankings omit this
    // unavailable work immediately on this device and after the next fetch.
    if (_bookmarkedIds.contains(workId)) {
      _upsert(CommunityWork.unavailable(workId));
    } else {
      _works.removeWhere((work) => work.id == workId);
    }
    _ownIds.remove(workId);
    _latestIds.remove(workId);
    // Keep bookmarked IDs so the user can still see/remove their old entry.
    // The backend tombstone prevents this deleted YouTube ID being republished.
    notifyListeners();
  }

  bool isBookmarked(String workId) => _bookmarkedIds.contains(workId);

  /// Bookmarks or un-bookmarks [workId]. Like the follow and repost toggles
  /// below: applied at once, then (with a backend) sent; the server's answer
  /// is kept, and a refused toggle is undone with [lastError] set. Returns
  /// true when it took effect and false when it was refused.
  Future<bool> toggleBookmark(String workId) => _toggleSocial(
    isOn: () => _bookmarkedIds.contains(workId),
    set: (on) {
      if (on) {
        _bookmarkedIds.add(workId);
        _bookmarkWorkIds = {..._bookmarkWorkIds, workId};
      } else {
        _bookmarkedIds.remove(workId);
      }
    },
    send: (client) => client.toggleBookmark(workId),
  );

  Future<bool> _toggleSocial({
    required bool Function() isOn,
    required void Function(bool on) set,
    required Future<bool> Function(CommunityApi client) send,
  }) async {
    final revision = _accountRevision;
    final wanted = !isOn();
    set(wanted);
    notifyListeners();
    final client = api;
    if (client == null) return true;
    _lastError = null;
    try {
      // The server toggles its own record; its answer is the truth even
      // when the local copy was out of step.
      final serverOn = await send(client);
      if (!_isCurrentAccount(revision)) return false;
      if (serverOn != isOn()) set(serverOn);
      notifyListeners();
      return true;
    } on NiarimApiException catch (error) {
      if (!_isCurrentAccount(revision)) return false;
      _lastError = error;
      if (isOn() == wanted) set(!wanted);
      notifyListeners();
      return false;
    }
  }

  /// バックエンド（backend/src/api/routes/tags.ts）と共通の1作品タグ上限。
  /// ダミーデータ利用時も同じ制約にして、開発中UIだけ11件以上追加できる
  /// 状態を防ぐ。
  static const int maxTagsPerWork = 10;

  /// Adds a community tag to [workId]. Tag edits, lock changes and the
  /// visibility toggle below apply locally at once; with a backend they are
  /// then sent and the server's copy replaces the local one. A refused edit
  /// undoes only itself on the current copy (so a change that succeeded
  /// meanwhile stays), and [lastError] says why. They return true when the
  /// edit took effect, false when it was refused, and null when there was
  /// nothing to do.
  Future<bool?> addTag(String workId, String tag) async {
    final trimmed = tag.trim();
    final current = byId(workId);
    if (trimmed.isEmpty ||
        current == null ||
        current.tags.contains(trimmed) ||
        current.tags.length >= maxTagsPerWork) {
      return null;
    }
    return _edit(
      workId,
      apply: (w) =>
          w.tags.contains(trimmed) ? w : w.copyWith(tags: [...w.tags, trimmed]),
      undo: (w) => w.copyWith(
        tags: w.tags.where((t) => t != trimmed).toList(),
        lockedTags: {...w.lockedTags}..remove(trimmed),
      ),
      send: (client) => client.updateTag(
        workId,
        action: CommunityTagAction.add,
        tag: trimmed,
      ),
    );
  }

  /// Removes a tag. A locked tag cannot be removed (the UI offers no remove
  /// button for it).
  Future<bool?> removeTag(String workId, String tag) async {
    final current = byId(workId);
    final at = current?.tags.indexOf(tag) ?? -1;
    if (current == null || at == -1 || current.lockedTags.contains(tag)) {
      return null;
    }
    return _edit(
      workId,
      apply: (w) => w.copyWith(
        tags: w.tags.where((t) => t != tag).toList(),
        lockedTags: {...w.lockedTags}..remove(tag),
      ),
      undo: (w) => w.tags.contains(tag)
          ? w
          : w.copyWith(
              tags: [...w.tags]..insert(at.clamp(0, w.tags.length), tag),
            ),
      send: (client) =>
          client.updateTag(workId, action: CommunityTagAction.remove, tag: tag),
    );
  }

  /// Locks or unlocks a tag; only the poster may (the UI offers it to them
  /// alone, and the server refuses anyone else).
  Future<bool?> toggleTagLock(String workId, String tag) async {
    final current = byId(workId);
    if (current == null) return null;
    final lock = !current.lockedTags.contains(tag);
    Set<String> locked(CommunityWork w, bool on) =>
        on ? {...w.lockedTags, tag} : ({...w.lockedTags}..remove(tag));
    return _edit(
      workId,
      apply: (w) => w.copyWith(lockedTags: locked(w, lock)),
      undo: (w) => w.copyWith(lockedTags: locked(w, !lock)),
      send: (client) => client.updateTag(
        workId,
        action: lock ? CommunityTagAction.lock : CommunityTagAction.unlock,
        tag: tag,
      ),
    );
  }

  /// Toggles the work-plaza visibility of the poster's own work
  /// (29_動画投稿・ランキング機能仕様.md, chapter 13).
  Future<bool?> toggleNiarimVisibility(String workId) async {
    final current = byId(workId);
    if (current == null) return null;
    final published = !current.isNiarimPublished;
    return _edit(
      workId,
      apply: (w) => w.copyWith(isNiarimPublished: published),
      undo: (w) => w.copyWith(isNiarimPublished: !published),
      send: (client) =>
          client.updateWorkVisibility(workId, isNiarimPublished: published),
    );
  }

  Future<bool> _edit(
    String workId, {
    required CommunityWork Function(CommunityWork work) apply,
    required CommunityWork Function(CommunityWork work) undo,
    required Future<ApiWork> Function(CommunityApi client) send,
  }) async {
    final revision = _accountRevision;
    final index = _indexOf(workId);
    _works[index] = apply(_works[index]);
    notifyListeners();
    final client = api;
    if (client == null) return true;
    _lastError = null;
    try {
      final work = await send(client);
      if (!_isCurrentAccount(revision)) return false;
      applyServerWork(_plazaCopy(work));
      return true;
    } on NiarimApiException catch (error) {
      if (!_isCurrentAccount(revision)) return false;
      _lastError = error;
      final at = _indexOf(workId);
      if (at != -1) _works[at] = undo(_works[at]);
      notifyListeners();
      return false;
    }
  }

  // ─── お気に入り作者（フォロー、Task#144） ──────────────────────────
  // 29_動画投稿・ランキング機能仕様.md 13章「フォロワー限定公開（見送り）」
  // が前提としていた「フォロー関係の保存・判定」の実体。閲覧ログイン不要
  // という設計原則を保つため、バックエンド実装時もフォロー関係の判定は
  // 「フォロワー限定作品の絞り込み」のような一覧取得の必須条件にはせず、
  // あくまで閲覧者側の任意の個人設定（お気に入り作者の新着を見やすくする
  // ためのクライアント側フィルタ）として位置づける想定。

  bool isFavoriteAuthor(String authorId) =>
      _favoriteAuthorIds.contains(authorId);

  /// Follows or unfollows [authorId] (see [toggleBookmark]). With a
  /// backend, a new follow brings the author's works and reposts into the
  /// following feed.
  Future<bool> toggleFavoriteAuthor(String authorId) async {
    final done = await _toggleSocial(
      isOn: () => _favoriteAuthorIds.contains(authorId),
      set: (on) => on
          ? _favoriteAuthorIds.add(authorId)
          : _favoriteAuthorIds.remove(authorId),
      send: (client) => client.toggleFollow(authorId),
    );
    if (done && api != null) await refreshFollowingFeed();
    return done;
  }

  /// [authorId]のフォロワーID一覧。ダミーの固定フォロワー（他の作者同士の
  /// 関係を表示確認用に生成したもの）に加え、自分がこの作者をフォロー中
  /// なら自分自身のIDも即座に反映する。
  List<String> followerIdsOf(String authorId) {
    final dummy = _dummyFollowersByAuthor[authorId] ?? const <String>{};
    if (authorId != kDummySelfAuthorId && isFavoriteAuthor(authorId)) {
      return [...dummy, kDummySelfAuthorId];
    }
    return dummy.toList();
  }

  /// [authorId]のフォロワー名一覧（新着順ではなく作者ID順。実際の
  /// マルチユーザーバックエンドが無いため並び順に意味は無い）。
  List<String> followerNamesOf(String authorId) =>
      followerIdsOf(authorId).map((id) => authorNameOf(id) ?? id).toList();

  /// [authorId]が誰をフォロー中かのID一覧。自分（kDummySelfAuthorId）に
  /// ついては実際にトグル操作した[_favoriteAuthorIds]をそのまま返す。
  /// 他のダミー作者については、フォロワー関係のダミーデータ
  /// （[_dummyFollowersByAuthor]、「誰が誰のフォロワーか」）を逆引きする
  /// ことで、フォロワー一覧と矛盾しない「その作者は誰のフォロワーか」を
  /// 導出する（新たなダミーデータを別途持つ必要が無い）。
  List<String> followingIdsOf(String authorId) {
    if (authorId == kDummySelfAuthorId) return _favoriteAuthorIds.toList();
    return _dummyFollowersByAuthor.entries
        .where((e) => e.value.contains(authorId))
        .map((e) => e.key)
        .toList();
  }

  /// [authorId]がフォロー中の相手の名前一覧。
  List<String> followingNamesOf(String authorId) =>
      followingIdsOf(authorId).map((id) => authorNameOf(id) ?? id).toList();

  /// [authorId]のフォロー中人数（数字のみ）。フォロワー数と同様、常に
  /// 公開情報として扱う（29_動画投稿・ランキング機能仕様.md 22.5節）。
  int followingCountOf(String authorId) =>
      _followingCounts[authorId] ??
      (api == null ? followingIdsOf(authorId).length : 0);

  /// 作者IDから表示名を引く（見つからなければnull）。
  String? authorNameOf(String authorId) => _works
      .where((w) => w.authorId == authorId)
      .map((w) => w.authorName)
      .firstOrNull;

  /// 作者のフォロワー数（公開するのは件数だけ）。
  int followerCountOf(String authorId) =>
      _followerCounts[authorId] ??
      (api == null ? followerIdsOf(authorId).length : 0);

  /// A person's follower count is public, but individual followers are not.
  List<CommunityMilestoneEvent> get milestoneNotifications =>
      List.unmodifiable(_milestoneEvents);

  int get unreadMilestoneCount =>
      _milestoneEvents.where((event) => !event.read).length;

  Future<void> loadMilestones() async {
    final revision = _accountRevision;
    final account = _selfId;
    if (account == null) return;
    final items = await _milestoneStore.load(account);
    if (!_isCurrentAccount(revision) || _selfId != account) return;
    _milestoneEvents = items;
    notifyListeners();
  }

  Future<void> markMilestonesRead() async {
    final revision = _accountRevision;
    final account = _selfId;
    if (account == null) return;
    final items = await _milestoneStore.markAllRead(account);
    if (!_isCurrentAccount(revision) || _selfId != account) return;
    _milestoneEvents = items;
    notifyListeners();
  }

  Future<void> _observeOwnMilestones({
    int? followers,
    Iterable<CommunityWork>? ownWorks,
  }) async {
    final revision = _accountRevision;
    final account = _selfId;
    if (account == null) return;
    final snapshots = ownWorks == null
        ? null
        : <String, (String, int)>{
            for (final work in ownWorks)
              work.id: (work.title, work.bookmarkCount),
          };
    final events = await _milestoneStore.observe(
      account,
      followers: followers,
      bookmarks: snapshots,
    );
    if (_isCurrentAccount(revision) && _selfId == account) {
      _milestoneEvents = events;
      notifyListeners();
    }
  }

  /// Read only current aggregate counts from the server; prior counts live
  /// on this device. First observation establishes a baseline.
  Future<void> refreshFollowerCount(String authorId) async {
    final client = api;
    if (client == null) {
      if (isOwnAuthor(authorId)) {
        await _observeOwnMilestones(followers: followerIdsOf(authorId).length);
      }
      return;
    }
    final revision = _accountRevision;
    try {
      final counts = await client.socialCounts(authorId);
      if (!_isCurrentAccount(revision)) return;
      _followerCounts[authorId] = counts.followers;
      _followingCounts[authorId] = counts.following;
      notifyListeners();
      if (isOwnAuthor(authorId)) {
        await _observeOwnMilestones(followers: counts.followers);
      }
    } on NiarimApiException catch (error) {
      if (_isCurrentAccount(revision)) _lastError = error;
    }
  }

  /// フォロー中の作者タブに表示する一覧（新着順）。フォロー中の作者本人が
  /// 投稿した作品に加え、フォロー中の作者が他者の作品をリポストした場合も
  /// 含める（Xのリポスト同様、「フォロー中のタイムラインに他者の投稿が
  /// 混ざる」導線）。同じ作品が両方の理由に該当する場合は、より新しい方の
  /// 日時・理由を採用する。NIARIM側で非公開にした作品は除外する
  /// （discoverableWorksと同じ扱い）。
  List<FavoriteFeedEntry> get favoriteAuthorFeed {
    final byWork = <String, FavoriteFeedEntry>{};
    for (final w in discoverableWorks) {
      if (_favoriteAuthorIds.contains(w.authorId) &&
          isDiscoverableForViewer(w) &&
          (api == null || _feedIds.contains(w.id))) {
        byWork[w.id] = FavoriteFeedEntry(work: w, feedTime: w.postedAt);
      }
    }
    for (final r in _reposts) {
      if (!_favoriteAuthorIds.contains(r.reposterId)) continue;
      final work = byId(r.workId);
      if (work == null || !isDiscoverableForViewer(work)) {
        continue;
      }
      final existing = byWork[r.workId];
      // 既にフォロー中作者本人の投稿として含まれている場合でも、
      // リポストの方が新しければそちらの日時・「誰がリポストしたか」を
      // 優先する（「なぜこの作品がここに出てきたか」として、より新しい
      // 理由の方が利用者にとって分かりやすいため）。
      if (existing == null || r.repostedAt.isAfter(existing.feedTime)) {
        byWork[r.workId] = FavoriteFeedEntry(
          work: work,
          feedTime: r.repostedAt,
          repostedByAuthorId: r.reposterId,
          repostedByAuthorName: r.reposterName,
        );
      }
    }
    // All followed posts and reposts share ONE chronological stream.
    // Tie-break by work ID for deterministic order across page fetches.
    final list = byWork.values.toList()
      ..sort((a, b) {
        final newestFirst = b.feedTime.compareTo(a.feedTime);
        return newestFirst != 0 ? newestFirst : a.work.id.compareTo(b.work.id);
      });
    return list;
  }

  /// [favoriteAuthorFeed]のうち作品部分だけを取り出した一覧（既存の
  /// CommunityWorkGrid・ショートモード等、CommunityWorkのリストのみを
  /// 要求するUIとの互換性のため）。
  List<CommunityWork> get favoriteAuthorWorks =>
      favoriteAuthorFeed.map((e) => e.work).toList();

  // ─── リポスト（Task#145の調査を受けた実装） ─────────────────────────

  /// 閲覧者自身がこの作品をリポスト済みかどうか。
  bool isRepostedBySelf(String workId) {
    final self = _selfId;
    return self != null &&
        _reposts.any((r) => r.workId == workId && r.reposterId == self);
  }

  /// この作品をリポストした人数（自分・ダミー他作者を問わない）。
  int repostCountOf(String workId) =>
      _reposts.where((r) => r.workId == workId).length;

  /// リポストの追加・取り消しを切り替える。[authorId]を省略すると閲覧者
  /// 自身としてリポストする（バックエンド接続時はサーバーへ送る。
  /// [toggleBookmark]参照）。他の作者を指定できるのはダミーデータだけ。
  /// 自分自身が投稿した作品もリポスト可能（Xの「引用リポスト」のように
  /// フォロワーへ改めて周知する用途を想定し、投稿者本人にも制限しない）。
  /// 何もしなかった（作品が無い）ときはnullを返す。
  Future<bool?> toggleRepost(String workId, {String? authorId}) async {
    final work = byId(workId);
    if (work == null) return null;
    final reposterId = authorId ?? _selfId ?? '';
    bool isOn() =>
        _reposts.any((r) => r.workId == workId && r.reposterId == reposterId);
    void set(bool on) {
      if (!on) {
        _reposts.removeWhere(
          (r) => r.workId == workId && r.reposterId == reposterId,
        );
        return;
      }
      if (isOn()) return;
      final reposterName =
          _works
              .where((w) => w.authorId == reposterId)
              .map((w) => w.authorName)
              .firstOrNull ??
          (api == null ? work.authorName : '');
      _reposts.add(
        CommunityRepost(
          workId: workId,
          reposterId: reposterId,
          reposterName: reposterName,
          repostedAt: DateTime.now(),
        ),
      );
    }

    if (authorId != null && authorId != _selfId) {
      // Someone else's repost exists only in the dummy data.
      set(!isOn());
      notifyListeners();
      return true;
    }
    return _toggleSocial(
      isOn: isOn,
      set: set,
      send: (client) => client.toggleRepost(workId),
    );
  }

  static List<CommunityRepost> _buildDummyReposts(List<CommunityWork> works) {
    final random = Random(99);
    final authorIds = works.map((w) => w.authorId).toSet().toList()..sort();
    final reposts = <CommunityRepost>[];
    for (final reposterId in authorIds) {
      // 自分の初期リポストは無し（能動的にボタンで付ける想定のため）。
      if (reposterId == kDummySelfAuthorId) continue;
      // 全作者が毎回リポストしているわけではない見た目にする。
      if (random.nextDouble() > 0.6) continue;
      final candidates = works
          .where((w) => w.authorId != reposterId && w.isNiarimPublished)
          .toList();
      if (candidates.isEmpty) continue;
      final target = candidates[random.nextInt(candidates.length)];
      final reposterName = works
          .firstWhere((w) => w.authorId == reposterId)
          .authorName;
      reposts.add(
        CommunityRepost(
          workId: target.id,
          reposterId: reposterId,
          reposterName: reposterName,
          repostedAt: DateTime.now().subtract(
            Duration(hours: random.nextInt(72)),
          ),
        ),
      );
    }
    return reposts;
  }

  // ─── ブックマークの公開設定・ユーザー別ブックマーク一覧
  //     （Task#145の調査を受けた実装） ─────────────────────────────────

  /// [authorId]が自分のブックマーク一覧を他ユーザーに公開しているか。
  bool isBookmarksPublic(String authorId) =>
      _bookmarksPublicByAuthor[authorId] ?? false;

  /// 自分のブックマーク一覧の公開設定（ユーザー設定）。
  bool get selfBookmarksPublic => isBookmarksPublic(kDummySelfAuthorId);

  /// 自分のブックマーク一覧を公開するかどうかを変更する。
  void setSelfBookmarksPublic(bool value) {
    _bookmarksPublicByAuthor[kDummySelfAuthorId] = value;
    notifyListeners();
  }

  /// [authorId]がブックマークしている作品一覧（新着順）。自分自身の場合は
  /// 実際にトグルした[_bookmarkedIds]を、それ以外のダミー作者の場合は
  /// 表示確認用に生成した固定のダミーブックマークを返す。他ユーザーの
  /// 一覧はNIARIM側で非公開にした作品を除外する（discoverableWorksと
  /// 同じ扱い。自分自身の一覧は、ホーム画面の「ブクマ済み」タブと同様に
  /// 除外しない）。公開設定に関わらずデータ自体は返すため、呼び出し側で
  /// [isBookmarksPublic]を確認してから表示するかどうかを判断すること。
  List<CommunityWork> bookmarkedWorksOf(String authorId) {
    final isSelf = isOwnAuthor(authorId);
    final ids = isSelf
        ? _bookmarkedIds
        : (_dummyBookmarksByOtherAuthor[authorId] ?? const {});
    // The viewer's own list follows their filters too; only their own
    // works stay when hidden.
    final list = _works
        .where(
          (w) =>
              ids.contains(w.id) &&
              (w.isUnavailable ||
                  (isSelf && isOwnWork(w)) ||
                  w.isNiarimPublished),
        )
        .toList();
    list.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return list;
  }

  /// 他のダミー作者同士の「誰が誰をフォローしているか」の表示確認用
  /// ダミーデータ。実際のマルチユーザーバックエンドが無いため、ダミー
  /// 作者6人（author_01〜06、自分含む）の中で固定シードの乱数により
  /// 互いのフォロー関係を割り当てる。自分（kDummySelfAuthorId）は
  /// 実際にフォローボタンで操作した分だけがfollowerIdsOfで加算される
  /// ため、ここでは自分を他作者のフォロワーとしては登録しない。
  static Map<String, Set<String>> _buildDummyFollowersByAuthor(
    List<CommunityWork> works,
  ) {
    final random = Random(21);
    final authorIds = works.map((w) => w.authorId).toSet().toList()..sort();
    final result = <String, Set<String>>{for (final id in authorIds) id: {}};
    for (final followerId in authorIds) {
      if (followerId == kDummySelfAuthorId) continue;
      for (final targetId in authorIds) {
        if (targetId == followerId) continue;
        if (random.nextDouble() < 0.4) {
          result[targetId]!.add(followerId);
        }
      }
    }
    return result;
  }

  /// 「自分の関係性データ（ブックマーク一覧・フォロワー一覧）を他ユーザーに
  /// 公開するか」の設定用ダミーデータ。両機能で同じ交互パターンを流用する
  /// （author_02, 04, 06を公開、author_03, 05を非公開にして、一覧側で
  /// 公開・非公開どちらの見た目も確認できるようにする）。
  static Map<String, bool> _buildDummyPublicVisibility() {
    final map = <String, bool>{kDummySelfAuthorId: false};
    const others = [
      'author_02',
      'author_03',
      'author_04',
      'author_05',
      'author_06',
    ];
    for (var i = 0; i < others.length; i++) {
      map[others[i]] = i.isEven;
    }
    return map;
  }

  static Map<String, Set<String>> _buildDummyBookmarksByAuthor(
    List<CommunityWork> works,
  ) {
    final random = Random(7);
    final authorIds = works.map((w) => w.authorId).toSet().toList()
      ..remove(kDummySelfAuthorId)
      ..sort();
    final result = <String, Set<String>>{};
    for (final id in authorIds) {
      final count = (2 + random.nextInt(4)).clamp(0, works.length);
      final ids = <String>{};
      while (ids.length < count) {
        ids.add(works[random.nextInt(works.length)].id);
      }
      result[id] = ids;
    }
    return result;
  }
}
