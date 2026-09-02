import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/input_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real pointer events classify touch mouse stylus and inverted stylus', () {
    final h = InputHandler();
    const allTypes = <InputType>[
      InputType.touch,
      InputType.stylus,
      InputType.mouse,
    ];
    expect(InputType.values, allTypes);

    final touch = PointerDownEvent(
      kind: PointerDeviceKind.touch,
      localPosition: const Offset(10, 20),
      pressure: 0.4,
    );
    expect(h.classifyInput(touch), InputType.touch);
    expect(h.lastInputType, InputType.touch);
    expect(h.isStylusActive, isFalse);
    expect(h.shouldDraw(touch, hasStylusSupport: false), isTrue);
    expect(h.shouldDraw(touch, hasStylusSupport: true), isFalse);

    final mouse = PointerDownEvent(
      kind: PointerDeviceKind.mouse,
      localPosition: const Offset(30, 40),
      pressure: 1,
    );
    expect(h.classifyInput(mouse), InputType.mouse);
    expect(h.lastInputType, InputType.mouse);
    expect(h.shouldDraw(mouse, hasStylusSupport: true), isTrue);

    final stylus = PointerDownEvent(
      kind: PointerDeviceKind.stylus,
      localPosition: const Offset(50, 60),
      pressure: 0.5,
      tilt: 0.6,
      orientation: math.pi / 3,
    );
    expect(h.classifyInput(stylus), InputType.stylus);
    expect(h.lastInputType, InputType.stylus);
    expect(h.isStylusActive, isTrue);
    expect(h.shouldDraw(stylus, hasStylusSupport: true), isTrue);

    final point = h.toStrokePoint(stylus, pressureCurve: (p) => p * p);
    expect(point.x, 50);
    expect(point.y, 60);
    expect(point.pressure, closeTo(0.25, 1e-9));
    expect(point.tiltX, closeTo(0.6 * math.cos(math.pi / 3), 1e-9));
    expect(point.tiltY, closeTo(0.6 * math.sin(math.pi / 3), 1e-9));
    expect(point.inputType, InputType.stylus);

    h.onStylusUp();
    expect(h.isStylusActive, isFalse);

    final inverted = PointerDownEvent(
      kind: PointerDeviceKind.invertedStylus,
      localPosition: const Offset(70, 80),
      pressure: 0.8,
    );
    expect(h.classifyInput(inverted), InputType.stylus);
    expect(h.isStylusActive, isTrue);
    final raw = h.toStrokePoint(inverted);
    expect(raw.pressure, closeTo(0.8, 1e-9));
    expect(raw.inputType, InputType.stylus);
  });

  test('pressure is clamped before the global curve is applied', () {
    final h = InputHandler();
    final event = PointerDownEvent(
      kind: PointerDeviceKind.stylus,
      localPosition: Offset.zero,
      pressure: 2.0,
    );
    h.classifyInput(event);
    final point = h.toStrokePoint(event, pressureCurve: (p) => p * 0.5);
    expect(point.pressure, 0.5);
  });
}
