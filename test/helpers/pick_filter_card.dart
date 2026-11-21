import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The filter panel always opens on its list of filters; this scrolls the
/// panel's vertically scrolling tile grid to the card for [filterId] and taps it, as a user
/// would.
Future<void> pickFilterCard(WidgetTester tester, String filterId) async {
  // The panel returns to the unselected gallery in a post-frame callback after opening.
  await tester.pump();
  final card = find.byKey(ValueKey('filter-card-$filterId'));
  await tester.scrollUntilVisible(
    card,
    120,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('filter-tile-grid')),
      matching: find.byType(Scrollable),
    ),
  );
  // A card only partly inside the strip would take the tap off-screen.
  await tester.ensureVisible(card);
  await tester.pump();
  await tester.tap(card);
}
