import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/premium_lock_widget.dart';

void main() {
  testWidgets(
    'locked Premium content stays visible, blocks the action, and routes the tap to upsell',
    (tester) async {
      var actionTaps = 0;
      var upsellTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumLockState(
              locked: true,
              onLockedTap: () => upsellTaps++,
              child: FilledButton(
                onPressed: () => actionTaps++,
                child: const Text('Premium action'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Premium action'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is IgnorePointer && widget.ignoring,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Premium action'));
      await tester.pump();
      expect(actionTaps, 0);
      expect(upsellTaps, 1);
    },
  );

  testWidgets('available Premium content behaves normally and shows no lock', (
    tester,
  ) async {
    var actionTaps = 0;
    var upsellTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumLockState(
            locked: false,
            onLockedTap: () => upsellTaps++,
            child: FilledButton(
              onPressed: () => actionTaps++,
              child: const Text('Premium action'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Premium action'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is IgnorePointer && widget.ignoring,
      ),
      findsNothing,
    );

    await tester.tap(find.text('Premium action'));
    await tester.pump();
    expect(actionTaps, 1);
    expect(upsellTaps, 0);
  });
}
