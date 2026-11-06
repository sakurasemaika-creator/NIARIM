import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../config/font_fallback.dart';

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
    const fieldStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      fontFamily: 'Kuramubon',
      fontFamilyFallback: kHeadingFontFallback,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 極端に狭いタイトル枠では2つのボタンを並べられないため、
        // 並び順の切り替えも同じメニューから操作できるようにする。
        if (constraints.hasBoundedWidth && constraints.maxWidth < 96) {
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
              width: 48,
              height: 48,
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
        // Keep the complete translated label, or use its named icon.
        final labelPainter = TextPainter(
          text: TextSpan(text: fieldLabel, style: fieldStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.localeOf(context),
          maxLines: 1,
        )..layout();
        final fullWidth = labelPainter.width + 24 + 48;
        labelPainter.dispose();
        final compact =
            constraints.hasBoundedWidth && constraints.maxWidth < fullWidth;

        final fieldControl = PopupMenuButton<bool>(
          tooltip: fieldLabel,
          onSelected: onSortByNameChanged,
          itemBuilder: (_) => [
            PopupMenuItem(value: true, child: Text(l10n.homeSortFieldName)),
            PopupMenuItem(value: false, child: Text(l10n.homeSortFieldUpdated)),
          ],
          child: compact
              ? SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Icon(
                      sortByName ? Icons.sort_by_alpha : Icons.update,
                      size: 20,
                    ),
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: Row(
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
                          style: fieldStyle,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
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
          visualDensity: VisualDensity.standard,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
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
