import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:niarim/screens/canvas/widgets/focus_mode_menu.dart';

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
  testWidgets('starts at bottom-left with fixed left, centre and right controls', (
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
            child: SizedBox(width: 180, height: 120),
          ),
        ),
      ),
    );

    final surface = find.byKey(
      const ValueKey('focus-mode-menu-surface'),
    );
    final rect = tester.getRect(surface);
    final minimize = tester.getRect(
      find.byKey(const ValueKey('focus-mode-menu-toggle')),
    );
    final move = tester.getRect(
      find.byKey(const ValueKey('focus-mode-menu-drag-handle')),
    );
    final resize = tester.getRect(
      find.byKey(const ValueKey('focus-mode-menu-resize-handle')),
    );

    expect(rect.left, closeTo(12, 0.1));
    expect(rect.bottom, closeTo(788, 0.1));
    expect(minimize.left, closeTo(rect.left, 0.1));
    expect(move.center.dx, closeTo(rect.center.dx, 0.1));
    expect(resize.right, closeTo(rect.right, 0.1));
  });

  testWidgets('top-right resize handle changes width and height and anchors bottom-left', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FocusModeMenu(
            collapseTooltip: 'Minimize',
            expandTooltip: 'Expand',
            child: SizedBox(width: 220, height: 140),
          ),
        ),
      ),
    );

    final surface = find.byKey(
      const ValueKey('focus-mode-menu-surface'),
    );
    final resizeHandle = find.byKey(
      const ValueKey('focus-mode-menu-resize-handle'),
    );
    final before = tester.getRect(surface);
    await tester.drag(resizeHandle, const Offset(60, -50));
    await tester.pumpAndSettle();
    final larger = tester.getRect(surface);

    expect(larger.width, closeTo(before.width + 60, 0.1));
    expect(larger.height, closeTo(before.height + 50, 0.1));
    expect(larger.left, closeTo(before.left, 0.1));
    expect(larger.bottom, closeTo(before.bottom, 0.1));

    await tester.drag(resizeHandle, const Offset(-40, 30));
    await tester.pumpAndSettle();
    final smaller = tester.getRect(surface);
    expect(smaller.width, closeTo(larger.width - 40, 0.1));
    expect(smaller.height, closeTo(larger.height - 30, 0.1));
    expect(smaller.left, closeTo(before.left, 0.1));
    expect(smaller.bottom, closeTo(before.bottom, 0.1));

    await tester.tap(find.byKey(const ValueKey('focus-mode-menu-toggle')));
    await tester.pumpAndSettle();
    await tester.drag(resizeHandle, const Offset(0, -45));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-mode-menu-toggle')));
    await tester.pumpAndSettle();
    final restored = tester.getRect(surface);
    expect(restored.height, closeTo(smaller.height + 45, 0.1));
    expect(restored.bottom, closeTo(smaller.bottom, 0.1));
  });

  testWidgets('menu keeps its raised surface without a heavy outline', (
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
            child: SizedBox(width: 180, height: 60),
          ),
        ),
      ),
    );

    final surface = find.byKey(
      const ValueKey('focus-mode-menu-surface'),
    );
    final material = tester.widget<Material>(
      find.descendant(of: surface, matching: find.byType(Material)).first,
    );
    expect(material.elevation, 0);
    expect(material.shape, isA<RoundedRectangleBorder>());
    expect(
      (material.shape! as RoundedRectangleBorder).side,
      BorderSide.none,
    );
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
