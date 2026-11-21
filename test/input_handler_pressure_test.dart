import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/input_handler.dart';

/// マウスには筆圧が無いので常に1.0。環境によって0が届き（Linuxの
/// デスクトップ）、筆圧で太さが変わるブラシが一番細く描かれていた。
/// ペンの筆圧はそのまま使う。
void main() {
  test('a mouse always draws at full pressure', () {
    final handler = InputHandler();
    const mouse = PointerDownEvent(
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryMouseButton,
      pressure: 0,
    );
    handler.classifyInput(mouse);
    expect(handler.toStrokePoint(mouse).pressure, 1.0);

    const pen = PointerDownEvent(
      kind: PointerDeviceKind.stylus,
      pressure: 0.3,
      pressureMin: 0,
      pressureMax: 1,
    );
    handler.classifyInput(pen);
    expect(handler.toStrokePoint(pen).pressure, closeTo(0.3, 1e-9));
  });
}
