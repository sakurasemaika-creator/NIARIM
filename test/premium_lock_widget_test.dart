import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/premium_lock_widget.dart';

void main() {
  testWidgets(
    'locked Premium content stays visible with a lock and cannot be operated',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PremiumLockState(
              locked: true,
              child: FilledButton(
                onPressed: () => taps++,
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

      await tester.tap(find.text('Premium action'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    },
  );

  testWidgets('available Premium content behaves normally and shows no lock', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumLockState(
            locked: false,
            child: FilledButton(
              onPressed: () => taps++,
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
    expect(taps, 1);
  });
}
