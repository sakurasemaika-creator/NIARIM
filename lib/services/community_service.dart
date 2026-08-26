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

  List<CommunityWork> get works => List.unmodifiable(_works);
  Set<String> get bookmarkedIds => Set.unmodifiable(_bookmarkedIds);

  CommunityWork? byId(String workId) {
    final index = _indexOf(workId);
    return index == -1 ? null : _works[index];
  }

  List<CommunityWork> worksByAuthor(String authorId) =>
      _works.where((w) => w.authorId == authorId).toList();

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
}
