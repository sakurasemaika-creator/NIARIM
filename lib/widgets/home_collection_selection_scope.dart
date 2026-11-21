import 'package:flutter/material.dart';

import 'collection_card_keys.dart';
import 'secondary_click_menu.dart';

/// One selection state shared by the four embedded Home collections.
///
/// IDs include collection prefixes outside Projects so files from different
/// tabs cannot be mixed accidentally. Standalone library screens do not have
/// this ancestor and retain their normal behavior.
class HomeCollectionSelectionScope extends InheritedWidget {
  const HomeCollectionSelectionScope({
    super.key,
    required super.child,
    required this.active,
    required this.selectedIds,
    required this.onLongPress,
    required this.onToggle,
    required this.onVisibleIds,
  });

  final bool active;
  final Set<String> selectedIds;
  final ValueChanged<String> onLongPress;
  final ValueChanged<String> onToggle;
  final void Function(String collection, Set<String> ids) onVisibleIds;

  static HomeCollectionSelectionScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<HomeCollectionSelectionScope>();

  bool selected(String id) => selectedIds.contains(id);

  @override
  bool updateShouldNotify(HomeCollectionSelectionScope previous) => true;
}

/// Visual-only selection affordance: a checked corner and a selected border.
/// The child owns hit-testing; the marker never intercepts menu/tap gestures.
class HomeCollectionSelectionSurface extends StatelessWidget {
  const HomeCollectionSelectionSurface({
    super.key,
    required this.selectionId,
    required this.child,
    this.grid = true,
    this.onSecondaryClick,
  });

  final String selectionId;
  final Widget child;
  final bool grid;

  /// 選んでいないときの右クリック（画面の座標）。nullなら行の︙と同じ
  /// メニューを探して開く（[SecondaryClickMenu]）。
  final void Function(Offset globalPosition)? onSecondaryClick;

  @override
  Widget build(BuildContext context) {
    final scope = HomeCollectionSelectionScope.maybeOf(context);
    final active = scope?.active ?? false;
    // カードの本体にキーボードのフォーカスがあるときは、Spaceで選び（長押しと
    // 同じ。選んでいる間は選ぶ・外すの切り替え。Enterは今までどおり開く）、
    // キーボードで操作している間は外側に輪を描く。
    // 選ぶ前と選んでいる間で木の形を変えない（変えるとカードが作り直され、
    // Spaceで選んだとたんにキーボードのフォーカスが外れた）。
    final body = GestureDetector(
      // 選んでいないときは、右クリックで行の︙と同じメニューを開く。
      onSecondaryTapUp: active
          ? null
          : (details) {
              final open = onSecondaryClick;
              if (open != null) {
                open(details.globalPosition);
              } else {
                SecondaryClickMenu.openAt(context, details.globalPosition);
              }
            },
      child: CollectionCardKeyboard(
        onSelect: scope == null ? null : () => scope.onToggle(selectionId),
        borderRadius: BorderRadius.circular(grid ? 14 : 12),
        child: child,
      ),
    );
    if (!active) {
      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [body],
      );
    }
    final checked = scope!.selected(selectionId);
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        body,
        if (checked)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.secondary, width: 2),
                  borderRadius: BorderRadius.circular(grid ? 14 : 12),
                ),
              ),
            ),
          ),
        Positioned(
          top: grid ? 4 : 12,
          left: grid ? 4 : 14,
          child: IgnorePointer(
            child: Container(
              key: ValueKey('homeSelectedMarker_$selectionId'),
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked
                    ? scheme.secondary
                    : scheme.surface.withValues(alpha: 0.9),
                border: Border.all(color: scheme.secondary, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                checked ? Icons.check : null,
                size: 16,
                color: scheme.onSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
