import 'package:flutter/material.dart';

import '../../../config/font_fallback.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/asset_tags.dart';

/// ブラシ・トーン・スタンプ一覧の検索方式。
enum AssetSearchMode {
  /// 素材名に対する部分一致。
  keyword,

  /// 素材へ付けたタグに対する部分一致。
  tag,
}

/// 素材が現在の検索条件に合致するか。
///
/// 3つのパネル（ブラシ・トーン・スタンプ）が同じ判定を使う。空クエリは
/// 常に合致（＝絞り込み無し）とする。
bool assetMatchesSearch({
  required String name,
  required List<String> tags,
  required AssetSearchMode mode,
  required String query,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return mode == AssetSearchMode.keyword
      ? name.toLowerCase().contains(q)
      : tagsMatch(tags, q);
}

/// ブラシ・トーン・スタンプ一覧で共通に使う検索欄。
///
/// 左端のボタンで「キーワード検索」と「タグ検索」を切り替える。タグ検索の
/// ときは、登録済みタグをチップで並べてワンタップで絞り込めるようにする
/// （タグ名を覚えていなくても選べるようにするため。チップは
/// `XxxService.allTags()`が使用件数の多い順で返す）。
class AssetSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final AssetSearchMode mode;
  final ValueChanged<AssetSearchMode> onModeChanged;
  final ValueChanged<String> onQueryChanged;

  /// タグ検索モードで候補として並べるタグ（使用件数の多い順）。
  final List<String> availableTags;

  /// キーワード検索モードのヒント文言（「ブラシ名で検索」など素材ごとに違う）。
  final String keywordHint;

  const AssetSearchBar({
    super.key,
    required this.controller,
    required this.mode,
    required this.onModeChanged,
    required this.onQueryChanged,
    required this.availableTags,
    required this.keywordHint,
  });

  bool _isSelected(String tag) =>
      controller.text.trim().toLowerCase() == tag.toLowerCase();

  void _toggleTag(String tag) {
    // 選択済みのチップをもう一度押したら絞り込みを解除する
    // （「解除するには入力欄を手で消す」しかない状態を避ける）。
    final next = _isSelected(tag) ? '' : tag;
    controller.text = next;
    controller.selection = TextSelection.collapsed(offset: next.length);
    onQueryChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTag = mode == AssetSearchMode.tag;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: isTag ? l10n.creativePanelTagSearchHint : keywordHint,
              // 検索方式の切り替えは入力欄の左端に置く。ヘッダー行は
              // お気に入り・検索・フォルダのボタンで既に埋まっており、
              // 幅280pxのドッキングパネルではこれ以上ボタンを足せないため。
              prefixIcon: IconButton(
                icon: Icon(isTag ? Icons.sell : Icons.search, size: 16),
                color: isTag ? scheme.primary : null,
                visualDensity: VisualDensity.compact,
                onPressed: () => onModeChanged(
                  isTag ? AssetSearchMode.keyword : AssetSearchMode.tag,
                ),
                tooltip: isTag
                    ? l10n.creativePanelSearchModeTag
                    : l10n.creativePanelSearchModeKeyword,
              ),
            ),
            onChanged: onQueryChanged,
          ),
          if (isTag)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: availableTags.isEmpty
                  ? Text(
                      l10n.creativePanelTagNoneYet,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  // 素材が増えるとタグも増えるため、折り返さず横スクロール
                  // させる（縦に伸びると一覧の表示領域を圧迫するため）。
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final tag in availableTags)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: FilterChip(
                                label: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'Kuramubon',
                                    fontFamilyFallback: kHeadingFontFallback,
                                  ),
                                ),
                                selected: _isSelected(tag),
                                // 選択中のチップをもう一度押すと解除できる、
                                // というのは見ただけでは分からないので明示する。
                                tooltip: _isSelected(tag)
                                    ? l10n.creativePanelTagClearFilter
                                    : null,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onSelected: (_) => _toggleTag(tag),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
