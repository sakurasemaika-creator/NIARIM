import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 「名前／更新日時」の並び替え基準プルダウンと、昇順・降順を切り替える
/// 矢印ボタンを横に並べた共通コントロール。プロジェクト一覧・共有一覧・
/// ゴミ箱一覧など、名前と更新日時で並び替えられる一覧画面すべてで
/// 同じ見た目・操作性にするために切り出している。
class SortModeControl extends StatelessWidget {
  final bool sortByName;
  final bool sortAscending;
  final ValueChanged<bool> onSortByNameChanged;
  final VoidCallback onToggleDirection;

  const SortModeControl({
    super.key,
    required this.sortByName,
    required this.sortAscending,
    required this.onSortByNameChanged,
    required this.onToggleDirection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<bool>(
          onSelected: onSortByNameChanged,
          itemBuilder: (_) => [
            PopupMenuItem(value: true, child: Text(l10n.homeSortFieldName)),
            PopupMenuItem(value: false, child: Text(l10n.homeSortFieldUpdated)),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sortByName ? l10n.homeSortFieldName : l10n.homeSortFieldUpdated,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Kuramubon',
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 20,
          ),
          tooltip: sortAscending
              ? l10n.homeSortDirectionAscTooltip
              : l10n.homeSortDirectionDescTooltip,
          onPressed: onToggleDirection,
        ),
      ],
    );
  }
}
