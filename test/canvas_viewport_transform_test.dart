import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';

void main() {
  group('キャンバス表示倍率', () {
    test('縮小下限は等倍の1/5', () {
      expect(kCanvasMinScale, 0.2);
    });

    test('下限を飛び越えるピンチでも1/5ちょうどへクランプする', () {
      final factor = boundedCanvasScaleFactor(0.25, 0.5);
      expect(0.25 * factor, closeTo(0.2, 1e-12));
    });

    test('最小倍率でさらに縮小入力されても倍率は固定され回転を妨げない', () {
      final factor = boundedCanvasScaleFactor(kCanvasMinScale, 0.5);
      expect(factor, closeTo(1.0, 1e-12));
    });

    test('拡大上限も境界へ正確にクランプする', () {
      final factor = boundedCanvasScaleFactor(9.5, 2.0);
      expect(9.5 * factor, closeTo(kCanvasMaxScale, 1e-12));
    });
  });

  test('キャンバス外周背景はCanvasAreaの変換外に固定された兄弟レイヤー', () {
    final source = File(
      'lib/screens/canvas/canvas_screen.dart',
    ).readAsStringSync();
    const backdrop = 'Container(color: kCanvasOutsideColor),';
    const canvasArea = 'CanvasArea(';
    final backdropIndex = source.indexOf(backdrop);
    final canvasIndex = source.indexOf(
      canvasArea,
      backdropIndex + backdrop.length,
    );
    expect(backdropIndex, greaterThanOrEqualTo(0));
    expect(canvasIndex, greaterThan(backdropIndex));
    final between = source.substring(backdropIndex, canvasIndex);
    expect(
      between.contains('Transform('),
      isFalse,
      reason: '背景をキャンバスの回転・縮小Transform内へ入れてはいけない',
    );
  });
}
