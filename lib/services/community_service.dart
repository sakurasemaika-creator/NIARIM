import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/community_follow_notification.dart';
import '../models/community_repost.dart';
import '../models/community_work.dart';
import 'api/community_api.dart';
import 'api/niarim_api_exception.dart';

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
/// 書き込み系（投稿・ブックマーク・フォロー・通報）はGoogleログインで
/// 得たIDトークンが要る。ログイン基盤自体はまだ無いため、[api]の
/// 書き込みメソッドは層としては用意済みだが、このサービスからはまだ
/// 呼んでいない（呼ぶと401になる）。ログインを実装したら、下の
/// トグル系メソッドをAPI呼び出し＋楽観更新へ差し替えること。
class CommunityService extends ChangeNotifier {
  /// バックエンドのAPIクライアント。未設定（デプロイ前）ならnull。
  final CommunityApi? api;

  CommunityService({this.api});

  /// バックエンドに接続する設定になっているか。
  bool get isBackendConnected => api != null;

  /// 直近の取得が失敗した理由（成功していればnull）。画面側で
  /// 「読み込めませんでした・再試行」を出すために使う。
  NiarimApiException? get lastError => _lastError;
  NiarimApiException? _lastError;

  /// バックエンドから一覧を取得中かどうか。
  bool get isLoading => _isLoading;
  bool _isLoading = false;

  /// バックエンドから新着一覧を取り直して[works]へ反映する。
  ///
  /// [api]がnull（デプロイ前）のときは何もしないでfalseを返す
  /// ＝ダミーデータのまま。失敗しても**手元の一覧は消さない**
  /// （画面が真っ白になるより、古い内容が残っているほうがましなため）。
  /// 失敗の理由は[lastError]に入る。
  Future<bool> refreshFromBackend() async {
    final client = api;
    if (client == null) return false;
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final fetched = await client.latestWorks();
      _works
        ..clear()
        ..addAll(fetched.map((w) => w.toCommunityWork()));
      return true;
    } on NiarimApiException catch (e) {
      _lastError = e;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ランキングを取得する（画面側がタブごとに呼ぶ）。
  /// [api]がnullなら手元のダミーデータから作った一覧を返す。
  Future<List<CommunityWork>> fetchRanking(RankingPeriod period) async {
    final client = api;
    if (client == null) return discoverableWorks;
    try {
      final page = await client.ranking(period);
      _lastError = null;
      return page.works.map((w) => w.toCommunityWork()).toList();
    } on NiarimApiException catch (e) {
      _lastError = e;
      notifyListeners();
      return const [];
    }
  }

  late final List<CommunityWork> _works = buildDummyCommunityWorks();
  final Set<String> _bookmarkedIds = {};
  // お気に入り作者（フォロー、Task#144）のNIARIM User ID集合。
  // ブックマークと同じくバックエンド未実装のためアプリ内一時状態のみ
  // （SharedPreferences等への永続化は行わない）。
  final Set<String> _favoriteAuthorIds = {};
  // リポスト（Task#145の調査を受けた新機能）。誰が・どの作品を・いつ
  // リポストしたかの記録。自分（kDummySelfAuthorId）のリポストは実際に
  // ボタン操作で追加・削除できるが、他のダミー作者のリポストは
  // 「フォロー中の作者タブに他者の作品が混ざる」見た目を最初から確認
  // できるよう、_buildDummyRepostsで固定シードの乱数によりあらかじめ
  // 何件か生成しておく。
  late final List<CommunityRepost> _reposts = _buildDummyReposts(_works);
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
  late final Map<String, Set<String>> _dummyBookmarksByOtherAuthor =
      _buildDummyBookmarksByAuthor(_works);
  // フォロワー一覧（Task#134継続：本人選択制で公開できる妥協案。22.5節）。
  // 他のダミー作者同士が誰をフォローしているかの表示確認用ダミーデータ
  // （固定シードの乱数で生成）。表示時はここへ「自分がフォローして
  // いれば自分自身のID」を加算する（followerIdsOf参照）。
  late final Map<String, Set<String>> _dummyFollowersByAuthor =
      _buildDummyFollowersByAuthor(_works);
  // 各authorIdの「自分のフォロワー一覧を他ユーザーに公開するか」設定。
  // ブックマーク一覧の公開設定（_bookmarksPublicByAuthor）と同じパターン。
  // 既定は非公開、他のダミー作者は公開/非公開どちらの見た目も確認できる
  // よう交互に割り当てている。
  final Map<String, bool> _followersPublicByAuthor =
      _buildDummyPublicVisibility();
  // フォロー通知（Task#134継続：「フォローされたら通知が来るようにして
  // ほしい」という要望を受けた実装）。バックエンド未実装かつ実際の
  // マルチユーザー環境が無いため、新しいフォローをリアルタイムに検知
  // することはできない（他のダミー作者は自律的に行動しない）。ここでは
  // 「自分（kDummySelfAuthorId）を既にフォローしているダミー作者」を
  // 過去に届いた通知として初期化時に生成し、アプリ内通知一覧
  // （21.3節で推奨された方式）として表示する。詳細は22.6節参照。
  late final List<CommunityFollowNotification> _followNotifications =
      _buildFollowNotifications();

  List<CommunityWork> get works => List.unmodifiable(_works);
  Set<String> get bookmarkedIds => Set.unmodifiable(_bookmarkedIds);

  /// ブックマークした作品IDを「新しくブックマークした順」で返す。
  ///
  /// [_bookmarkedIds]はDartのSetリテラルなのでLinkedHashSet＝追加順を
  /// 保持している。これを逆順にすることで、直前にブックマークした作品が
  /// 先頭に来る。解除して付け直した場合も末尾へ追加し直されるため、
  /// 「付け直した時点が新しい」という自然な順序になる。
  ///
  /// バックエンド接続後は、この順序をサーバー側の`bookmarkedAt`
  /// （21.1節のBookmarkItem）へ置き換えること。現状はアプリ内一時状態
  /// なので再起動すると消える（ブックマーク自体が消えるので順序だけの
  /// 問題ではない）。
  List<String> get bookmarkedIdsNewestFirst =>
      _bookmarkedIds.toList().reversed.toList();
  Set<String> get favoriteAuthorIds => Set.unmodifiable(_favoriteAuthorIds);

  /// 新着・ランキングなど「発見」用の一覧に出す作品（NIARIM側で非公開に
  /// した作品を除外する。13章：YouTube側が非公開・削除の場合も表示を
  /// 強制停止する設計だが、ダミーデータにはYouTube側状態の概念が無いため
  /// ここではNIARIM側設定のみを対象にする）。
  List<CommunityWork> get discoverableWorks =>
      _works.where((w) => w.isNiarimPublished).toList();

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
        (w) => w.authorId == authorId && (includeHidden || w.isNiarimPublished),
      )
      .toList();

  int _indexOf(String workId) => _works.indexWhere((w) => w.id == workId);

  bool isBookmarked(String workId) => _bookmarkedIds.contains(workId);

  void toggleBookmark(String workId) {
    if (_bookmarkedIds.contains(workId)) {
      _bookmarkedIds.remove(workId);
    } else {
      _bookmarkedIds.add(workId);
    }
    notifyListeners();
  }

  /// タグを追加する（誰でも可能）。同名タグが既にある場合は何もしない。
  void addTag(String workId, String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    final index = _indexOf(workId);
    if (index == -1) return;
    final current = _works[index];
    if (current.tags.contains(trimmed)) return;
    _works[index] = current.copyWith(tags: [...current.tags, trimmed]);
    notifyListeners();
  }

  /// タグを削除する。ロックされているタグは削除できない
  /// （呼び出し元でロック中のタグに対しては削除ボタン自体を表示しない）。
  void removeTag(String workId, String tag) {
    final index = _indexOf(workId);
    if (index == -1) return;
    final current = _works[index];
    if (current.lockedTags.contains(tag)) return;
    _works[index] = current.copyWith(
      tags: current.tags.where((t) => t != tag).toList(),
      lockedTags: current.lockedTags.where((t) => t != tag).toSet(),
    );
    notifyListeners();
  }

  /// タグのロック状態を切り替える（投稿者本人のみ呼び出し可能。
  /// UI側で`work.authorId == kDummySelfAuthorId`のときのみボタンを表示する）。
  void toggleTagLock(String workId, String tag) {
    final index = _indexOf(workId);
    if (index == -1) return;
    final current = _works[index];
    final lockedTags = {...current.lockedTags};
    if (lockedTags.contains(tag)) {
      lockedTags.remove(tag);
    } else {
      lockedTags.add(tag);
    }
    _works[index] = current.copyWith(lockedTags: lockedTags);
    notifyListeners();
  }

  /// 作品広場独自の公開/非公開設定を切り替える（投稿者本人のみ
  /// 呼び出し可能。UI側で`work.authorId == kDummySelfAuthorId`のときのみ
  /// 切り替えボタンを表示する。29_動画投稿・ランキング機能仕様.md 13章）。
  void toggleNiarimVisibility(String workId) {
    final index = _indexOf(workId);
    if (index == -1) return;
    final current = _works[index];
    _works[index] = current.copyWith(
      isNiarimPublished: !current.isNiarimPublished,
    );
    notifyListeners();
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

  void toggleFavoriteAuthor(String authorId) {
    if (_favoriteAuthorIds.contains(authorId)) {
      _favoriteAuthorIds.remove(authorId);
    } else {
      _favoriteAuthorIds.add(authorId);
    }
    notifyListeners();
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

  /// [authorId]のフォロワー一覧のうち、実際に画面へ表示してよい分だけを
  /// 絞り込んだID一覧（Task#134継続：22.7節）。フォロワー自身が自分の
  /// フォロー中/フォロワー一覧を非公開にしている場合、[authorId]側の
  /// 一覧が公開設定であっても、その人物だけは表示しない（フォロワー
  /// 本人の意思を優先する）。[followerCountOf]自体は非公開のフォロワーも
  /// 含めた実数のまま変えない（「集計」と「表示」を分離する設計）。
  List<String> visibleFollowerIdsOf(String authorId) =>
      followerIdsOf(authorId).where(isFollowersPublic).toList();

  /// [authorId]の表示可能なフォロワー名一覧（[visibleFollowerIdsOf]参照）。
  List<String> visibleFollowerNamesOf(String authorId) =>
      visibleFollowerIdsOf(authorId)
          .map((id) => authorNameOf(id) ?? id)
          .toList();

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
  int followingCountOf(String authorId) => followingIdsOf(authorId).length;

  /// 作者IDから表示名を引く（見つからなければnull）。
  String? authorNameOf(String authorId) => _works
      .where((w) => w.authorId == authorId)
      .map((w) => w.authorName)
      .firstOrNull;

  /// [authorId]のフォロワー数（数字のみ）。「誰がフォローしているか」の
  /// 一覧は既定で非公開のまま（[isFollowersPublic]がfalseの間は数字のみ
  /// 表示し、一覧は表示しない設計をUI側で徹底する。29_動画投稿・
  /// ランキング機能仕様.md 22.4節・22.5節）。集計値の表示だけであれば
  /// 特定個人を識別できずUGCリスクが小さいため、こちらは常に公開情報
  /// として扱う。
  int followerCountOf(String authorId) => followerIdsOf(authorId).length;

  /// [authorId]が自分のフォロワー一覧を他ユーザーに公開しているか。
  /// 既定は非公開（Task#134継続：本人選択制で一覧を公開できる妥協案。
  /// 22.5節参照）。
  bool isFollowersPublic(String authorId) =>
      _followersPublicByAuthor[authorId] ?? false;

  /// 自分のフォロワー一覧の公開設定（ユーザー設定）。
  bool get selfFollowersPublic => isFollowersPublic(kDummySelfAuthorId);

  /// 自分のフォロワー一覧を公開するかどうかを変更する。
  void setSelfFollowersPublic(bool value) {
    _followersPublicByAuthor[kDummySelfAuthorId] = value;
    notifyListeners();
  }

  // ─── フォロー通知（Task#134継続） ────────────────────────────────

  /// 自分（kDummySelfAuthorId）宛てのフォロー通知一覧（新着順）。
  List<CommunityFollowNotification> get followNotifications {
    final list = [..._followNotifications]
      ..sort((a, b) => b.followedAt.compareTo(a.followedAt));
    return List.unmodifiable(list);
  }

  /// 未読のフォロー通知数（コミュニティ画面の通知ベルのバッジに使う）。
  int get unreadFollowNotificationCount =>
      _followNotifications.where((n) => !n.isRead).length;

  /// フォロー通知を全て既読にする（通知一覧画面を開いたタイミングで
  /// 呼ぶ想定）。
  void markAllFollowNotificationsRead() {
    if (_followNotifications.every((n) => n.isRead)) return;
    for (var i = 0; i < _followNotifications.length; i++) {
      _followNotifications[i] = _followNotifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  List<CommunityFollowNotification> _buildFollowNotifications() {
    final random = Random(31);
    final followerIds =
        (_dummyFollowersByAuthor[kDummySelfAuthorId] ?? const <String>{})
            .toList()
          ..sort();
    return [
      for (final id in followerIds)
        CommunityFollowNotification(
          id: 'follow_$id',
          followerId: id,
          followerName: authorNameOf(id) ?? id,
          followedAt: DateTime.now().subtract(
            Duration(hours: random.nextInt(240)),
          ),
        ),
    ];
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
      if (_favoriteAuthorIds.contains(w.authorId)) {
        byWork[w.id] = FavoriteFeedEntry(work: w, feedTime: w.postedAt);
      }
    }
    for (final r in _reposts) {
      if (!_favoriteAuthorIds.contains(r.reposterId)) continue;
      final work = byId(r.workId);
      if (work == null || !work.isNiarimPublished) continue;
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
    final list = byWork.values.toList()
      ..sort((a, b) => b.feedTime.compareTo(a.feedTime));
    return list;
  }

  /// [favoriteAuthorFeed]のうち作品部分だけを取り出した一覧（既存の
  /// CommunityWorkGrid・ショートモード等、CommunityWorkのリストのみを
  /// 要求するUIとの互換性のため）。
  List<CommunityWork> get favoriteAuthorWorks =>
      favoriteAuthorFeed.map((e) => e.work).toList();

  // ─── リポスト（Task#145の調査を受けた実装） ─────────────────────────

  /// 自分（kDummySelfAuthorId）がこの作品をリポスト済みかどうか。
  bool isRepostedBySelf(String workId) => _reposts.any(
    (r) => r.workId == workId && r.reposterId == kDummySelfAuthorId,
  );

  /// この作品をリポストした人数（自分・ダミー他作者を問わない）。
  int repostCountOf(String workId) =>
      _reposts.where((r) => r.workId == workId).length;

  /// リポストの追加・取り消しを切り替える。[authorId]を省略すると自分
  /// （kDummySelfAuthorId）としてリポストする。自分自身が投稿した作品も
  /// リポスト可能（Xの「引用リポスト」のようにフォロワーへ改めて周知する
  /// 用途を想定し、投稿者本人にも制限しない）。
  void toggleRepost(String workId, {String authorId = kDummySelfAuthorId}) {
    final work = byId(workId);
    if (work == null) return;
    final existingIndex = _reposts.indexWhere(
      (r) => r.workId == workId && r.reposterId == authorId,
    );
    if (existingIndex != -1) {
      _reposts.removeAt(existingIndex);
    } else {
      final reposterName = _works
          .firstWhere((w) => w.authorId == authorId, orElse: () => work)
          .authorName;
      _reposts.add(
        CommunityRepost(
          workId: workId,
          reposterId: authorId,
          reposterName: reposterName,
          repostedAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
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
    final isSelf = authorId == kDummySelfAuthorId;
    final ids = isSelf
        ? _bookmarkedIds
        : (_dummyBookmarksByOtherAuthor[authorId] ?? const {});
    final source = isSelf ? _works : discoverableWorks;
    final list = source.where((w) => ids.contains(w.id)).toList();
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
