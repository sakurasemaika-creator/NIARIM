import 'package:flutter/widgets.dart';

/// Panels already have a shared dock header (collapse, move, hide), so
/// embedded floating-window close controls must not be duplicated there.
/// Mobile/floating panels continue to show their own close controls.
class DockedPanelCloseScope extends InheritedWidget {
  const DockedPanelCloseScope({
    super.key,
    required super.child,
  });

  static bool isDocked(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DockedPanelCloseScope>() !=
      null;

  @override
  bool updateShouldNotify(DockedPanelCloseScope oldWidget) => false;
}
