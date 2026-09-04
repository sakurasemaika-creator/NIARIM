import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/effect_filter_instance.dart';

void main() {
  Uint8List lineCanvas(int w, int h, void Function(Uint8List b) draw) {
    final b = Uint8List(w * h * 4);
    draw(b);
    return b;
  }

  void px(Uint8List b, int w, int x, int y, [int thickness = 1]) {
    for (var oy = -thickness ~/ 2; oy <= thickness ~/ 2; oy++) {
      for (var ox = -thickness ~/ 2; ox <= thickness ~/ 2; ox++) {
        final xx = x + ox, yy = y + oy;
        if (xx < 0 || yy < 0 || xx >= w || yy >= b.length ~/ 4 ~/ w) continue;
        final i = (yy * w + xx) * 4;
        b[i] = b[i + 1] = b[i + 2] = 20;
        b[i + 3] = 255;
      }
    }
  }

  void line(Uint8List b, int w, int x0, int y0, int x1, int y1) {
    final steps = (x1 - x0).abs() > (y1 - y0).abs()
        ? (x1 - x0).abs()
        : (y1 - y0).abs();
    for (var s = 0; s <= steps; s++) {
      final t = steps == 0 ? 0.0 : s / steps;
      px(b, w, (x0 + (x1 - x0) * t).round(), (y0 + (y1 - y0) * t).round());
    }
  }

  int alphaCount(Uint8List b) {
    var n = 0;
    for (var i = 3; i < b.length; i += 4) {
      if (b[i] != 0) n++;
    }
    return n;
  }

  test('墨溜まり: 90度の交差だけに指定色のテーパー効果レイヤーを作る', () {
    const w = 80, h = 80;
    final src = lineCanvas(w, h, (b) {
      line(b, w, 15, 40, 40, 40);
      line(b, w, 40, 40, 40, 65);
    });
    final ink = FilterEngine().applyInkPoolLayer(
      src,
      w,
      h,
      color: 0xFF7A2038,
      rangePx: 16,
      centerWidthPx: 8,
    );
    expect(alphaCount(ink), greaterThan(30));
    final center = (40 * w + 40) * 4;
    expect(ink[center], 0x7A);
    expect(ink[center + 1], 0x20);
    expect(ink[center + 2], 0x38);
    expect(ink[center + 3], 255);
    // 元線から外れた中心近傍にも太りが発生する。
    expect(ink[((38) * w + 38) * 4 + 3], greaterThan(0));
    // 範囲外は透明。
    expect(ink[(10 * w + 10) * 4 + 3], 0);
  });

  test('墨溜まり: 直線だけでは発生しない', () {
    const w = 80, h = 80;
    final src = lineCanvas(w, h, (b) => line(b, w, 10, 40, 70, 40));
    final ink = FilterEngine().applyInkPoolLayer(
      src,
      w,
      h,
      color: 0xFF000000,
      rangePx: 12,
      centerWidthPx: 6,
    );
    expect(alphaCount(ink), 0);
  });

  test('墨溜まり演出: 指定フレーム範囲だけ非破壊で適用される', () {
    const w = 64, h = 64;
    final src = lineCanvas(w, h, (b) {
      line(b, w, 10, 32, 32, 32);
      line(b, w, 32, 32, 32, 54);
    });
    final effect = EffectFilterInstance(
      id: 'ink',
      type: EffectFilterType.inkPool,
      startFrame: 5,
      endFrame: 10,
      param1: 12,
      param2: 6,
      fadeColor: const ui.Color(0xFF5A1A30),
    );
    final engine = FilterEngine();
    final before = engine.applyEffectFilters(src, w, h, [effect], 4);
    final active = engine.applyEffectFilters(src, w, h, [effect], 7);
    expect(before, orderedEquals(src));
    expect(active, isNot(orderedEquals(src)));
  });
}
