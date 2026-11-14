import 'package:flutter/foundation.dart';

/// 並び順・絞り込みを起動し直しても覚えておく、ホームの一覧。
enum HomeList { projects, works, shared, trash }

/// ホームの一覧で選んだ並び順と絞り込み（[HomeList]ごと）。
///
/// 値で比べられる写しで、設定（`SettingsService.homeListFilters`）に残す。
/// 名前で持つので、読めない・知らない名前は使う側が既定へ戻す。
@immutable
class HomeListFilters {
  const HomeListFilters({
    this.sort,
    this.favoritesOnly = false,
    this.hiddenKinds = const {},
  });

  /// 並び順（名前／更新日時と向き）の名前。null は選んでいない（既定の
  /// 「更新日時」の新しい順）。
  final String? sort;

  /// 「お気に入りのみ」（ゴミ箱には無い）。
  final bool favoritesOnly;

  /// ゴミ箱の種類の絞り込みで外した種類の名前。選んでいる種類ではなく
  /// 外した種類を覚えるので、後の版で足した種類は初めから出る。
  final Set<String> hiddenKinds;

  @override
  bool operator ==(Object other) =>
      other is HomeListFilters &&
      other.sort == sort &&
      other.favoritesOnly == favoritesOnly &&
      setEquals(other.hiddenKinds, hiddenKinds);

  @override
  int get hashCode =>
      Object.hash(sort, favoritesOnly, Object.hashAllUnordered(hiddenKinds));
}
