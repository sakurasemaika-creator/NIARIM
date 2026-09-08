import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/two_finger_vertical_swipe_detector.dart';

void main() {
  const surfaceKey = ValueKey('layer-gesture-surface');

  testWidgets('fires up and down only for a two-finger vertical swipe', (
    tester,
  ) async {
    var up = 0;
    var down = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 120,
            child: TwoFingerVerticalSwipeDetector(
              onSwipeUp: () => up++,
              onSwipeDown: () => down++,
              child: const ColoredBox(
                key: surfaceKey,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(surfaceKey));
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(center + const Offset(-30, 20));
    await second.down(center + const Offset(30, 20));
    await first.moveBy(const Offset(0, -60));
    await second.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(up, 1);
    expect(down, 0);
    await first.up();
    await second.up();

    final third = await tester.createGesture(pointer: 3);
    final fourth = await tester.createGesture(pointer: 4);
    await third.down(center + const Offset(-30, -20));
    await fourth.down(center + const Offset(30, -20));
    await third.moveBy(const Offset(0, 60));
    await fourth.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(up, 1);
    expect(down, 1);
    await third.up();
    await fourth.up();
  });

  testWidgets('does not fire for a single finger or horizontal motion', (
    tester,
  ) async {
    var fired = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            height: 120,
            child: TwoFingerVerticalSwipeDetector(
              onSwipeUp: () => fired++,
              onSwipeDown: () => fired++,
              child: const ColoredBox(
                key: surfaceKey,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byKey(surfaceKey));
    final single = await tester.createGesture(pointer: 10);
    await single.down(center);
    await single.moveBy(const Offset(0, -80));
    await single.up();

    final first = await tester.createGesture(pointer: 11);
    final second = await tester.createGesture(pointer: 12);
    await first.down(center + const Offset(-20, 0));
    await second.down(center + const Offset(20, 0));
    await first.moveBy(const Offset(80, 10));
    await second.moveBy(const Offset(80, 10));
    await first.up();
    await second.up();
    await tester.pump();

    expect(fired, 0);
  });
}
