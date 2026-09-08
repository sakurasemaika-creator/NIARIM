import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/input_handler.dart';
import 'package:niarim/engine/multi_touch_tap_tracker.dart';

void main() {
  group('MultiTouchTapTracker', () {
    test(
      'recognizes a two-finger tap only after both fingers are released',
      () {
        final tracker = MultiTouchTapTracker();
        final t0 = DateTime(2026, 1, 1);
        tracker.pointerDown(1, const Offset(10, 10), t0);
        tracker.pointerDown(2, const Offset(30, 10), t0);
        expect(
          tracker.pointerUp(1, t0.add(const Duration(milliseconds: 80))),
          isNull,
        );
        expect(
          tracker.pointerUp(2, t0.add(const Duration(milliseconds: 120))),
          MultiTouchTapKind.twoFinger,
        );
      },
    );

    test('pinch movement is not treated as a two-finger tap', () {
      final tracker = MultiTouchTapTracker();
      final t0 = DateTime(2026, 1, 1);
      tracker.pointerDown(1, const Offset(10, 10), t0);
      tracker.pointerDown(2, const Offset(30, 10), t0);
      tracker.pointerMove(2, const Offset(60, 10));
      tracker.pointerUp(1, t0.add(const Duration(milliseconds: 100)));
      expect(
        tracker.pointerUp(2, t0.add(const Duration(milliseconds: 140))),
        isNull,
      );
    });

    test('recognizes a three-finger tap and ignores four fingers', () {
      final t0 = DateTime(2026, 1, 1);
      final three = MultiTouchTapTracker();
      for (var i = 1; i <= 3; i++) {
        three.pointerDown(i, Offset(i * 10.0, 10), t0);
      }
      three.pointerUp(1, t0.add(const Duration(milliseconds: 60)));
      three.pointerUp(2, t0.add(const Duration(milliseconds: 80)));
      expect(
        three.pointerUp(3, t0.add(const Duration(milliseconds: 100))),
        MultiTouchTapKind.threeFinger,
      );

      final four = MultiTouchTapTracker();
      for (var i = 1; i <= 4; i++) {
        four.pointerDown(i, Offset(i * 10.0, 10), t0);
      }
      for (var i = 1; i <= 3; i++) {
        four.pointerUp(i, t0.add(const Duration(milliseconds: 80)));
      }
      expect(
        four.pointerUp(4, t0.add(const Duration(milliseconds: 100))),
        isNull,
      );
    });
  });

  group('InputHandler palm rejection', () {
    test(
      'rejects touch only while stylus is active and setting is enabled',
      () {
        final handler = InputHandler();
        handler.classifyInput(
          const PointerDownEvent(kind: PointerDeviceKind.stylus),
        );
        expect(handler.isStylusActive, isTrue);
        expect(
          handler.shouldRejectPalmTouch(
            InputType.touch,
            palmRejectionEnabled: true,
          ),
          isTrue,
        );
        expect(
          handler.shouldRejectPalmTouch(
            InputType.touch,
            palmRejectionEnabled: false,
          ),
          isFalse,
        );
        expect(
          handler.shouldRejectPalmTouch(
            InputType.stylus,
            palmRejectionEnabled: true,
          ),
          isFalse,
        );
      },
    );

    test('touch up does not clear active stylus state', () {
      final handler = InputHandler();
      handler.classifyInput(
        const PointerDownEvent(kind: PointerDeviceKind.stylus),
      );
      handler.onPointerUp(const PointerUpEvent(kind: PointerDeviceKind.touch));
      expect(handler.isStylusActive, isTrue);
      handler.onPointerUp(const PointerUpEvent(kind: PointerDeviceKind.stylus));
      expect(handler.isStylusActive, isFalse);
    });
  });
}
