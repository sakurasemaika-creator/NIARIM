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

  test('墨溜まり: 鋭角（45度）の角の内側だけに指定色のテーパー効果レイヤーを作る', () {
    const w = 80, h = 80;
    final src = lineCanvas(w, h, (b) {
      line(b, w, 15, 40, 40, 40);
      line(b, w, 40, 40, 15, 65);
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
    // 角の内側（左）だけに溜まり、指定色（乗算済み）で塗られる。
    final inside = (43 * w + 33) * 4;
    final a = ink[inside + 3];
    expect(a, greaterThan(200));
    expect(ink[inside] * 255 / a, closeTo(0x7A, 3));
    expect(ink[inside + 1] * 255 / a, closeTo(0x20, 3));
    expect(ink[inside + 2] * 255 / a, closeTo(0x38, 3));
    // 角の外側（右・上）へははみ出さない。
    expect(ink[(40 * w + 44) * 4 + 3], 0);
    expect(ink[(36 * w + 33) * 4 + 3], 0);
    // 範囲外は透明。
    expect(ink[(10 * w + 10) * 4 + 3], 0);
  });

  test('墨溜まり: 直角の角とT字にも角の内側に発生し、鈍角には発生しない', () {
    const w = 80, h = 80;
    Uint8List pool(Uint8List src) => FilterEngine().applyInkPoolLayer(
      src,
      w,
      h,
      color: 0xFF000000,
      rangePx: 16,
      centerWidthPx: 8,
    );
    int alphaAt(Uint8List b, int x, int y) => b[(y * w + x) * 4 + 3];

    // 直角の角：横線の下・縦線の左（内側）だけ。
    final corner = pool(
      lineCanvas(w, h, (b) {
        line(b, w, 15, 40, 40, 40);
        line(b, w, 40, 40, 40, 65);
      }),
    );
    expect(alphaAt(corner, 36, 43), greaterThan(200));
    expect(alphaAt(corner, 36, 36), 0);
    expect(alphaAt(corner, 44, 44), 0);

    // T字：縦線の両側、横線の下だけ。横線の上（まっすぐな側）には出ない。
    final t = pool(
      lineCanvas(w, h, (b) {
        line(b, w, 10, 30, 70, 30);
        line(b, w, 40, 30, 40, 70);
      }),
    );
    expect(alphaAt(t, 36, 33), greaterThan(200));
    expect(alphaAt(t, 44, 33), greaterThan(200));
    for (var x = 10; x <= 70; x++) {
      for (var y = 0; y < 30; y++) {
        expect(alphaAt(t, x, y), 0, reason: '横線の上 ($x, $y)');
      }
    }

    // 鈍角（135°）：出ない。
    final obtuse = pool(
      lineCanvas(w, h, (b) {
        line(b, w, 15, 40, 40, 40);
        line(b, w, 40, 40, 60, 60);
      }),
    );
    expect(alphaCount(obtuse), 0);
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
      line(b, w, 32, 32, 12, 52);
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
