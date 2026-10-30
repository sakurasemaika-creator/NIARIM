import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Match the exact saved name, independent of display-only line break hints.
Finder findExportedWorkName(String name) => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.semanticsLabel ?? widget.data) == name,
);
