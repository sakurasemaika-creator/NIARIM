import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/prism_filter_engine.dart';

void main() {
  group('PrismFilterEngine', () {
    test('every separate shape gets the whole rainbow', () {
      // Two slender shapes, one short and high, one long and low, as when
      // several small streaks are drawn on one prism layer.
      const w = 40, h = 120;
      final source = Uint8List(w * h * 4);
      void bar(int x0, int y0, int y1) {
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x0 + 6; x++) {
            source[(y * w + x) * 4 + 3] = 255;
          }
        }
      }

      bar(4, 4, 34);
      bar(24, 40, 116);
      final out = PrismFilterEngine().apply(
        source,
        w,
        h,
        blurPx: 0,
        gradientDirectionDegrees: 90,
      );
      List<int> rgb(int x, int y) {
        final i = (y * w + x) * 4;
        return [out[i], out[i + 1], out[i + 2]];
      }

      for (final (x, y0, y1) in [(6, 4, 34), (26, 40, 116)]) {
        final length = y1 - y0;
        int at(double t) => y0 + (length * t).floor();
        expect(rgb(x, y0), [77, 0, 0], reason: 'red at the top of $x');
        expect(rgb(x, at(1.5 / 6)), [0, 77, 0], reason: 'then green');
        expect(rgb(x, at(2.5 / 6)), [0, 77, 77], reason: 'cyan');
        expect(rgb(x, at(3.5 / 6)), [0, 0, 77], reason: 'blue');
        expect(rgb(x, at(4.5 / 6)), [77, 0, 77], reason: 'purple');
        expect(rgb(x, y1 - 1), [77, 0, 0], reason: 'red at the bottom');
      }
    });

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

      // 六帯は先頭と末尾がどちらも赤なので、端同士ではなく中間点との
      // 差を見る。0° は横方向へ変化し、同じxなら上下で同色。
      expect(rgbAt(horizontal, 0, 0), isNot(rgbAt(horizontal, 1, 0)));
      expect(rgbAt(horizontal, 0, 0), rgbAt(horizontal, 0, 2));

      // 90° は縦方向へ変化し、同じyなら左右で同色。
      expect(rgbAt(vertical, 0, 0), isNot(rgbAt(vertical, 0, 1)));
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
