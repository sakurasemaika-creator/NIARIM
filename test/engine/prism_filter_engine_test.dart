import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/prism_filter_engine.dart';

void main() {
  group('PrismFilterEngine', () {
    test('gradientDirectionDegrees rotates the fill gradient', () {
      final source = Uint8List(3 * 3 * 4);
      for (var i = 0; i < source.length; i += 4) {
        source[i + 3] = 255;
      }

      final engine = PrismFilterEngine();
      final horizontal = engine.apply(
        source,
        3,
        3,
        blurPx: 0,
        gradientDirectionDegrees: 0,
      );
      final vertical = engine.apply(
        source,
        3,
        3,
        blurPx: 0,
        gradientDirectionDegrees: 90,
      );

      List<int> rgbAt(Uint8List bytes, int x, int y) {
        final i = (y * 3 + x) * 4;
        return [bytes[i], bytes[i + 1], bytes[i + 2]];
      }

      // 0° は横方向へ変化し、同じxなら上下で同色。
      expect(rgbAt(horizontal, 0, 0), isNot(rgbAt(horizontal, 2, 0)));
      expect(rgbAt(horizontal, 0, 0), rgbAt(horizontal, 0, 2));

      // 90° は縦方向へ変化し、同じyなら左右で同色。
      expect(rgbAt(vertical, 0, 0), isNot(rgbAt(vertical, 0, 2)));
      expect(rgbAt(vertical, 0, 0), rgbAt(vertical, 2, 0));
    });

    test(
      'blurPx is passed as gaussian blur pixels and may spread outside clip',
      () {
        final source = Uint8List(5 * 5 * 4);
        final center = (2 * 5 + 2) * 4;
        source[center + 3] = 255;

        final engine = PrismFilterEngine();
        final noBlur = engine.apply(
          source,
          5,
          5,
          blurPx: 0,
          gradientDirectionDegrees: 0,
        );
        final blurred = engine.apply(
          source,
          5,
          5,
          blurPx: 1,
          gradientDirectionDegrees: 0,
        );

        final neighbor = (2 * 5 + 1) * 4;
        expect(noBlur[neighbor + 3], 0);
        expect(blurred[neighbor + 3], greaterThan(0));
      },
    );
  });
}
