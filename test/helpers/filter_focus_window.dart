import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';

/// On phones the filter panel sits in the canvas's focus window
/// (`FocusModeMenu`, key `filter-focus-menu`): its close button is the
/// window's own (`focus-mode-menu-close`) and its list actions (search,
/// favourites only, import, folders, reorder) are in the window header's
/// menu (`filter-focus-menu-actions`). In the PC dock the panel shows its
/// own header row with those buttons. These helpers reach them in either
/// place, as a user would.

/// The button that closes the filter panel.
Finder filterPanelCloseButton() {
  final inPanel = find.descendant(
    of: find.byType(FilterPanel),
    matching: find.byIcon(Icons.close),
  );
  if (inPanel.evaluate().isNotEmpty) return inPanel.first;
  return find
      .descendant(
        of: find.byKey(const ValueKey('filter-focus-menu')),
        matching: find.byKey(const ValueKey('focus-mode-menu-close')),
      )
      .first;
}

/// Closes the filter panel (from its own close button or the focus
/// window's).
Future<void> closeFilterPanel(WidgetTester tester) async {
  await tester.tap(filterPanelCloseButton());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Opens the list's search field.
Future<void> showFilterSearch(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final inPanel = find.descendant(
    of: find.byType(FilterPanel),
    matching: find.byIcon(Icons.search),
  );
  if (inPanel.evaluate().isNotEmpty) {
    await tester.tap(inPanel.first);
    await tester.pump();
    return;
  }
  await tester.tap(find.byKey(const ValueKey('filter-focus-menu-actions')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(l10n.creativePanelSearchTooltip).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Leaves the open filter without applying it, back to the list.
Future<void> backToFilterList(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  final inPanel = find.byKey(const ValueKey('filter-back-to-list'));
  if (inPanel.evaluate().isNotEmpty) {
    await tester.tap(inPanel);
    await tester.pump();
    return;
  }
  await tester.tap(find.byKey(const ValueKey('filter-focus-menu-actions')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(l10n.filterBackToList).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
