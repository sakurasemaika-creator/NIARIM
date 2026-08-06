import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'drawing_engine.dart';

class InputHandler {
  bool _isStylusActive = false;
  InputType _lastInputType = InputType.touch;

  InputType get lastInputType => _lastInputType;
  bool get isStylusActive => _isStylusActive;

  InputType classifyInput(PointerEvent event) {
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      _isStylusActive = true;
      _lastInputType = InputType.stylus;
      return InputType.stylus;
    } else if (event.kind == PointerDeviceKind.mouse) {
      _lastInputType = InputType.mouse;
      return InputType.mouse;
    } else {
      _lastInputType = InputType.touch;
      return InputType.touch;
    }
  }

  StrokePoint toStrokePoint(PointerEvent event) {
    final type = _lastInputType; // classifyInput()は呼び出し元で既に実行済み
    return StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: event.pressure.clamp(0.0, 1.0),
      tiltX: event.tilt * math.cos(event.orientation),
      tiltY: event.tilt * math.sin(event.orientation),
      inputType: type,
    );
  }

  void onStylusUp() {
    _isStylusActive = false;
  }

  bool shouldDraw(PointerEvent event, {required bool hasStylusSupport}) {
    // classifyInput()は呼び出し元で既に実行済みの前提で_lastInputTypeを参照
    if (!hasStylusSupport) return true;
    return _lastInputType == InputType.stylus || _lastInputType == InputType.mouse;
  }
}
