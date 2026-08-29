import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/community_repost.dart';
import '../models/community_work.dart';

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

/// 「みんなの作品をみる」機能のダミーデータと、タグ・ブックマークの
/// 一時的な状態をアプリ全体で共有するサービス。
///
/// バックエンド（`29_動画投稿・ランキング機能仕様.md`）は未実装のため、
/// ここで保持するのは表示確認用のダミーデータのみ。以前は
/// `CommunityScreen`のState内にローカルで持っていたが、フローティング
/// プレビューウィンドウ（画面をまたいで表示し続ける）・作品詳細画面
/// （別ルート）の両方から同じ状態を参照・編集できる必要があるため、
/// アプリ全体で共有するProviderへ引き上げた。
class CommunityService extends ChangeNotifier {
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
  final Map<String, bool> _bookmarksPublicByAuthor = _buildDummyBookmarkVisibility();
  // 他のダミー作者（自分以外）が何をブックマークしているかの表示確認用
  // ダミーデータ。実際のマルチユーザーバックエンドが無いため、自分の
  // ブックマーク（_bookmarkedIds、実際にトグル可能）とは別に固定シードの
  // 乱数で生成する。
  late final Map<String, Set<String>> _dummyBookmarksByOtherAuthor =
      _buildDummyBookmarksByAuthor(_works);

  List<CommunityWork> get works => List.unmodifiable(_works);
  Set<String> get bookmarkedIds => Set.unmodifiable(_bookmarkedIds);
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
  List<CommunityWork> worksByAuthor(String authorId, {bool includeHidden = false}) => _works
      .where((w) => w.authorId == authorId && (includeHidden || w.isNiarimPublished))
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

  /// NIARIM作品広場独自の公開/非公開設定を切り替える（投稿者本人のみ
  /// 呼び出し可能。UI側で`work.authorId == kDummySelfAuthorId`のときのみ
  /// 切り替えボタンを表示する。29_動画投稿・ランキング機能仕様.md 13章）。
  void toggleNiarimVisibility(String workId) {
    final index = _indexOf(workId);
    if (index == -1) return;
    final current = _works[index];
    _works[index] = current.copyWith(isNiarimPublished: !current.isNiarimPublished);
    notifyListeners();
  }

  // ─── お気に入り作者（フォロー、Task#144） ──────────────────────────
  // 29_動画投稿・ランキング機能仕様.md 13章「フォロワー限定公開（見送り）」
  // が前提としていた「フォロー関係の保存・判定」の実体。閲覧ログイン不要
  // という設計原則を保つため、バックエンド実装時もフォロー関係の判定は
  // 「フォロワー限定作品の絞り込み」のような一覧取得の必須条件にはせず、
  // あくまで閲覧者側の任意の個人設定（お気に入り作者の新着を見やすくする
  // ためのクライアント側フィルタ）として位置づける想定。

  bool isFavoriteAuthor(String authorId) => _favoriteAuthorIds.contains(authorId);

  void toggleFavoriteAuthor(String authorId) {
    if (_favoriteAuthorIds.contains(authorId)) {
      _favoriteAuthorIds.remove(authorId);
    } else {
      _favoriteAuthorIds.add(authorId);
    }
    notifyListeners();
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
    final list = byWork.values.toList()..sort((a, b) => b.feedTime.compareTo(a.feedTime));
    return list;
  }

  /// [favoriteAuthorFeed]のうち作品部分だけを取り出した一覧（既存の
  /// CommunityWorkGrid・ショートモード等、CommunityWorkのリストのみを
  /// 要求するUIとの互換性のため）。
  List<CommunityWork> get favoriteAuthorWorks =>
      favoriteAuthorFeed.map((e) => e.work).toList();

  // ─── リポスト（Task#145の調査を受けた実装） ─────────────────────────

  /// 自分（kDummySelfAuthorId）がこの作品をリポスト済みかどうか。
  bool isRepostedBySelf(String workId) =>
      _reposts.any((r) => r.workId == workId && r.reposterId == kDummySelfAuthorId);

  /// この作品をリポストした人数（自分・ダミー他作者を問わない）。
  int repostCountOf(String workId) => _reposts.where((r) => r.workId == workId).length;

  /// リポストの追加・取り消しを切り替える。[authorId]を省略すると自分
  /// （kDummySelfAuthorId）としてリポストする。自分自身が投稿した作品も
  /// リポスト可能（Xの「引用リポスト」のようにフォロワーへ改めて周知する
  /// 用途を想定し、投稿者本人にも制限しない）。
  void toggleRepost(String workId, {String authorId = kDummySelfAuthorId}) {
    final work = byId(workId);
    if (work == null) return;
    final existingIndex =
        _reposts.indexWhere((r) => r.workId == workId && r.reposterId == authorId);
    if (existingIndex != -1) {
      _reposts.removeAt(existingIndex);
    } else {
      final reposterName =
          _works.firstWhere((w) => w.authorId == authorId, orElse: () => work).authorName;
      _reposts.add(CommunityRepost(
        workId: workId,
        reposterId: authorId,
        reposterName: reposterName,
        repostedAt: DateTime.now(),
      ));
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
      final candidates = works.where((w) => w.authorId != reposterId && w.isNiarimPublished).toList();
      if (candidates.isEmpty) continue;
      final target = candidates[random.nextInt(candidates.length)];
      final reposterName = works.firstWhere((w) => w.authorId == reposterId).authorName;
      reposts.add(CommunityRepost(
        workId: target.id,
        reposterId: reposterId,
        reposterName: reposterName,
        repostedAt: DateTime.now().subtract(Duration(hours: random.nextInt(72))),
      ));
    }
    return reposts;
  }

  // ─── ブックマークの公開設定・ユーザー別ブックマーク一覧
  //     （Task#145の調査を受けた実装） ─────────────────────────────────

  /// [authorId]が自分のブックマーク一覧を他ユーザーに公開しているか。
  bool isBookmarksPublic(String authorId) => _bookmarksPublicByAuthor[authorId] ?? false;

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
    final ids = isSelf ? _bookmarkedIds : (_dummyBookmarksByOtherAuthor[authorId] ?? const {});
    final source = isSelf ? _works : discoverableWorks;
    final list = source.where((w) => ids.contains(w.id)).toList();
    list.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return list;
  }

  static Map<String, bool> _buildDummyBookmarkVisibility() {
    final map = <String, bool>{kDummySelfAuthorId: false};
    // author_02, 04, 06を公開、author_03, 05を非公開にして、一覧側で
    // 公開・非公開どちらの見た目も確認できるようにする。
    const others = ['author_02', 'author_03', 'author_04', 'author_05', 'author_06'];
    for (var i = 0; i < others.length; i++) {
      map[others[i]] = i.isEven;
    }
    return map;
  }

  static Map<String, Set<String>> _buildDummyBookmarksByAuthor(List<CommunityWork> works) {
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
