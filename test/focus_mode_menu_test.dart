import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/canvas/widgets/focus_mode_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('minimizing hides the body and expanding restores its state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FocusModeMenu(
            collapseTooltip: 'Minimize',
            expandTooltip: 'Expand',
            child: _CounterContent(),
          ),
        ),
      ),
    );

    expect(find.text('Count: 0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('focus-mode-menu-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Count: 0'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('focus-mode-menu-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Count: 0'), findsOneWidget);

    await tester.tap(find.text('Increase'));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('focus-mode-menu-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-mode-menu-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Count: 1'), findsOneWidget);
  });

  testWidgets('drag handle moves the menu and keeps it inside the viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FocusModeMenu(
            collapseTooltip: 'Minimize',
            expandTooltip: 'Expand',
            child: SizedBox(
              width: 180,
              height: 80,
              child: Center(child: Text('Preview controls')),
            ),
          ),
        ),
      ),
    );

    final surface = find.byKey(
      const ValueKey('focus-mode-menu-surface'),
    );
    final handle = find.byKey(
      const ValueKey('focus-mode-menu-drag-handle'),
    );

    final before = tester.getRect(surface);
    await tester.drag(handle, const Offset(100, -100));
    await tester.pumpAndSettle();
    final moved = tester.getRect(surface);

    expect(moved.left, greaterThan(before.left));
    expect(moved.top, lessThan(before.top));

    await tester.drag(handle, const Offset(2000, -2000));
    await tester.pumpAndSettle();
    final atFarEdge = tester.getRect(surface);
    expect(atFarEdge.right, lessThanOrEqualTo(400));
    expect(atFarEdge.top, greaterThanOrEqualTo(0));

    await tester.drag(handle, const Offset(-4000, 4000));
    await tester.pumpAndSettle();
    final returned = tester.getRect(surface);
    expect(returned.left, greaterThanOrEqualTo(0));
    expect(returned.bottom, lessThanOrEqualTo(800));

    // A minimized handle must still use the expanded panel's bounds.
    await tester.tap(find.byKey(const ValueKey('focus-mode-menu-toggle')));
    await tester.pumpAndSettle();
    await tester.drag(handle, const Offset(2000, -2000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-mode-menu-toggle')));
    await tester.pumpAndSettle();
    final restored = tester.getRect(surface);
    expect(restored.right, lessThanOrEqualTo(400));
    expect(restored.top, greaterThanOrEqualTo(0));
  });
}

class _CounterContent extends StatefulWidget {
  const _CounterContent();

  @override
  State<_CounterContent> createState() => _CounterContentState();
}

class _CounterContentState extends State<_CounterContent> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Count: $_count'),
      TextButton(
        onPressed: () => setState(() => _count++),
        child: const Text('Increase'),
      ),
    ],
  );
}
