import 'package:flutter/foundation.dart';
import '../models/community_work.dart';

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

  /// お気に入り登録した作者の投稿作品一覧（新着順）。NIARIM側で非公開に
  /// した作品は除外する（discoverableWorksと同じ扱い）。
  List<CommunityWork> get favoriteAuthorWorks {
    final list = discoverableWorks.where((w) => _favoriteAuthorIds.contains(w.authorId)).toList();
    list.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return list;
  }
}
