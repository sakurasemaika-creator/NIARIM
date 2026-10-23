import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../config/font_fallback.dart';
import 'checked_menu_item.dart';

enum _SortMenuAction { name, updated, direction }

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
    final fieldLabel = sortByName
        ? l10n.homeSortFieldName
        : l10n.homeSortFieldUpdated;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 極端に狭いタイトル枠では2つのボタンを並べられないため、
        // 並び順の切り替えも同じメニューから操作できるようにする。
        if (constraints.hasBoundedWidth && constraints.maxWidth < 64) {
          return PopupMenuButton<_SortMenuAction>(
            tooltip: fieldLabel,
            onSelected: (action) {
              switch (action) {
                case _SortMenuAction.name:
                  onSortByNameChanged(true);
                case _SortMenuAction.updated:
                  onSortByNameChanged(false);
                case _SortMenuAction.direction:
                  onToggleDirection();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _SortMenuAction.name,
                child: Text(l10n.homeSortFieldName),
              ),
              PopupMenuItem(
                value: _SortMenuAction.updated,
                child: Text(l10n.homeSortFieldUpdated),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _SortMenuAction.direction,
                child: Text(
                  sortAscending
                      ? l10n.homeSortDirectionAscTooltip
                      : l10n.homeSortDirectionDescTooltip,
                ),
              ),
            ],
            child: SizedBox(
              width: 32,
              height: 40,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Icon(
                  sortByName ? Icons.sort_by_alpha : Icons.update,
                  size: 20,
                ),
              ),
            ),
          );
        }
        // AppBarは端末幅・文字サイズ・左右のaction数によってタイトル領域が
        // かなり狭くなる。従来は「項目名 + ▼ + 48px IconButton」を常に
        // 横並びにしていたため、狭い端末でRenderFlexがほんの僅かにはみ出し
        // 「OVERFLOWED BY 0.00 PIXELS」が表示されることがあった。
        // 幅が狭い場合は並び替え基準を意味するアイコン表示へ自動的に縮約し、
        // 通常幅では従来どおり文字ラベルを表示する。
        final compact =
            constraints.hasBoundedWidth && constraints.maxWidth < 132;

        // 今の基準にチェックを付け、ボタンを覆わないよう下に開く（以前は
        // ボタンの上に重なって開き、どちらを選んでいるかも出なかった）。
        final fieldControl = PopupMenuButton<bool>(
          tooltip: fieldLabel,
          initialValue: sortByName,
          position: PopupMenuPosition.under,
          onSelected: onSortByNameChanged,
          itemBuilder: (_) => [
            checkedMenuItem(
              context,
              value: true,
              checked: sortByName,
              label: l10n.homeSortFieldName,
            ),
            checkedMenuItem(
              context,
              value: false,
              checked: !sortByName,
              label: l10n.homeSortFieldUpdated,
            ),
          ],
          child: compact
              ? SizedBox(
                  width: 32,
                  height: 40,
                  child: Center(
                    child: Icon(
                      sortByName ? Icons.sort_by_alpha : Icons.update,
                      size: 20,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 縮約しない幅であっても、OSの文字サイズ設定
                    // （textScaler）を大きくしている端末ではラベルが伸びて
                    // title枠を超えてしまう（1.3倍以上でRenderFlex
                    // オーバーフローが発生することを確認済み）。
                    // Flexibleで可変にし、ellipsisで枠内へ収める。
                    Flexible(
                      child: Text(
                        fieldLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
        );

        final directionControl = IconButton(
          icon: Icon(
            sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 20,
          ),
          tooltip: sortAscending
              ? l10n.homeSortDirectionAscTooltip
              : l10n.homeSortDirectionDescTooltip,
          onPressed: onToggleDirection,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: BoxConstraints.tightFor(
            width: compact ? 32 : 40,
            height: 40,
          ),
        );

        return Row(
          mainAxisSize: MainAxisSize.min,
          // 文字サイズ拡大時にプルダウン側が縮められるようFlexibleで包む
          // （矢印ボタンは固定幅のまま残す）。
          children: [
            Flexible(child: fieldControl),
            directionControl,
          ],
        );
      },
    );
  }
}
