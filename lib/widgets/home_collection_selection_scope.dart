import 'package:flutter/material.dart';

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
  final ValueChanged<Set<String>> onVisibleIds;

  static HomeCollectionSelectionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeCollectionSelectionScope>();

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
  });

  final String selectionId;
  final Widget child;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final scope = HomeCollectionSelectionScope.maybeOf(context);
    if (scope == null || !scope.active) return child;
    final checked = scope.selected(selectionId);
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (checked)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.14),
                  border: Border.all(color: scheme.secondary, width: 3),
                  borderRadius: BorderRadius.circular(grid ? 14 : 12),
                ),
              ),
            ),
          ),
        Positioned(
          top: grid ? 8 : 12,
          left: grid ? 8 : 14,
          child: IgnorePointer(
            child: Container(
              key: ValueKey('homeSelectedMarker_$selectionId'),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? scheme.secondary : scheme.surface,
                border: Border.all(color: scheme.secondary, width: 2),
              ),
              child: Icon(
                checked ? Icons.check : Icons.circle_outlined,
                size: 22,
                color: checked ? scheme.onSecondary : scheme.secondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
