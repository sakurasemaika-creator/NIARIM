import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/niarim-unique-visual-v3');
  setUpAll(() => out.createSync(recursive: true));

  test('眼鏡断層: 顔に近い線画で両レンズ内だけ自然に局所変形する', () async {
    const w = 360, h = 300;
    final face = _animeFace(w, h);
    final mask = Uint8List(w * h * 4);
    _fillEllipseMask(mask, w, h, 128, 137, 61, 43);
    _fillEllipseMask(mask, w, h, 232, 137, 61, 43);

    final engine = FilterEngine();
    final plus = engine.applyLensDistortion(
      Uint8List.fromList(face),
      w,
      h,
      45,
      mask,
    );
    final minus = engine.applyLensDistortion(
      Uint8List.fromList(face),
      w,
      h,
      -45,
      mask,
    );
    final offset = engine.applyLensDistortion(
      Uint8List.fromList(face),
      w,
      h,
      45,
      mask,
      centerOffsetX: 10,
      centerOffsetY: -5,
    );

    var outsideChanged = 0;
    var insideChanged = 0;
    for (var p = 0; p < w * h; p++) {
      final i = p * 4;
      final changed =
          face[i] != plus[i] ||
          face[i + 1] != plus[i + 1] ||
          face[i + 2] != plus[i + 2] ||
          face[i + 3] != plus[i + 3];
      if (mask[i + 3] == 0) {
        if (changed) outsideChanged++;
      } else if (changed) {
        insideChanged++;
      }
    }
    expect(outsideChanged, 0);
    expect(insideChanged, greaterThan(500));
    expect(_mad(plus, minus), greaterThan(0.35));
    expect(_mad(plus, offset), greaterThan(0.12));

    // 鼻・口などレンズ外の顔パーツは完全保持される。
    expect(_regionMad(face, plus, w, 160, 175, 200, 245), 0);
    // 左右の目周辺は実際に変形する。
    expect(_regionMad(face, plus, w, 82, 105, 170, 165), greaterThan(0.15));
    expect(_regionMad(face, plus, w, 190, 105, 278, 165), greaterThan(0.15));

    await _save(face, w, h, '${out.path}/lens_face_before.png');
    await _save(mask, w, h, '${out.path}/lens_face_mask.png');
    await _save(plus, w, h, '${out.path}/lens_face_plus45.png');
    await _save(minus, w, h, '${out.path}/lens_face_minus45.png');
    await _save(offset, w, h, '${out.path}/lens_face_offset_plus10_minus5.png');
  });

  test('墨溜まり: 45°/90°には発生し、鈍角135°と直線には発生しない', () async {
    const w = 150, h = 120;
    final engine = FilterEngine();

    final acute45 = _angleSample(w, h, 45);
    final right90 = _angleSample(w, h, 90);
    final obtuse135 = _angleSample(w, h, 135);
    final straight180 = _angleSample(w, h, 180);

    final a45 = engine.applyInkPoolLayer(
      acute45,
      w,
      h,
      color: 0xFF5E1730,
      rangePx: 22,
      centerWidthPx: 10,
    );
    final a90 = engine.applyInkPoolLayer(
      right90,
      w,
      h,
      color: 0xFF5E1730,
      rangePx: 22,
      centerWidthPx: 10,
    );
    final a135 = engine.applyInkPoolLayer(
      obtuse135,
      w,
      h,
      color: 0xFF5E1730,
      rangePx: 22,
      centerWidthPx: 10,
    );
    final a180 = engine.applyInkPoolLayer(
      straight180,
      w,
      h,
      color: 0xFF5E1730,
      rangePx: 22,
      centerWidthPx: 10,
    );

    expect(_alphaCount(a45), greaterThan(50));
    expect(_alphaCount(a90), greaterThan(50));
    // ユーザー仕様は90°以下のみ。135°・直線は誤検出しない。
    expect(_alphaCount(a135), 0);
    expect(_alphaCount(a180), 0);

    await _save(acute45, w, h, '${out.path}/ink_angle45_before.png');
    await _save(
      _composite(acute45, a45),
      w,
      h,
      '${out.path}/ink_angle45_after.png',
    );
    await _save(right90, w, h, '${out.path}/ink_angle90_before.png');
    await _save(
      _composite(right90, a90),
      w,
      h,
      '${out.path}/ink_angle90_after.png',
    );
    await _save(
      _composite(obtuse135, a135),
      w,
      h,
      '${out.path}/ink_angle135_no_effect.png',
    );
    await _save(
      _composite(straight180, a180),
      w,
      h,
      '${out.path}/ink_straight_no_effect.png',
    );
  });

  test('墨溜まり: 範囲と中央太さが独立して効き、指定色・端1pxテーパーを保つ', () async {
    const w = 180, h = 140;
    final src = _angleSample(w, h, 60);
    final engine = FilterEngine();
    final narrow = engine.applyInkPoolLayer(
      src,
      w,
      h,
      color: 0xFF7B2348,
      rangePx: 10,
      centerWidthPx: 5,
    );
    final longRange = engine.applyInkPoolLayer(
      src,
      w,
      h,
      color: 0xFF7B2348,
      rangePx: 28,
      centerWidthPx: 5,
    );
    final thickCenter = engine.applyInkPoolLayer(
      src,
      w,
      h,
      color: 0xFF7B2348,
      rangePx: 28,
      centerWidthPx: 14,
    );

    expect(_alphaCount(longRange), greaterThan(_alphaCount(narrow)));
    expect(_alphaCount(thickCenter), greaterThan(_alphaCount(longRange)));

    // 出力に使われる不透明色は指定色そのもの。
    for (var i = 0; i < thickCenter.length; i += 4) {
      if (thickCenter[i + 3] == 0) continue;
      expect(thickCenter[i], 0x7B);
      expect(thickCenter[i + 1], 0x23);
      expect(thickCenter[i + 2], 0x48);
    }

    // 交点付近ほど太く、枝を外側へ辿るほど細くなる（端1pxテーパー）ことを
    // 数値確認する。
    //
    // 測るのは**その枝自身の太さ**＝y=cyを含む途切れないインクの縦の連なり。
    // 列全体の上端〜下端（外接する縦幅）を測ってはいけない。この検体は
    // 60度のV字で**2本とも頂点から左へ伸びる**ため、外接幅は「2本の枝の
    // 間の隙間」まで数えてしまい、外側ほど広くなる（実際にそれで
    // 「テーパーが効いていない」と誤検知していた）。
    final cx = w ~/ 2;
    final cy = h ~/ 2;
    final centerRun = _branchInkRun(thickCenter, w, h, cx, cy);
    final midRun = _branchInkRun(thickCenter, w, h, cx - 18, cy);
    final nearEdgeRun = _branchInkRun(thickCenter, w, h, cx - 24, cy);
    final edgeRun = _branchInkRun(thickCenter, w, h, cx - 28, cy);
    final outsideRun = _branchInkRun(thickCenter, w, h, cx - 34, cy);
    expect(centerRun, greaterThanOrEqualTo(8), reason: '交点付近は十分太いこと');
    expect(midRun, lessThan(centerRun), reason: '交点から離れるほど細くなること');
    expect(nearEdgeRun, lessThan(midRun));
    expect(edgeRun, lessThan(nearEdgeRun));
    expect(outsideRun, lessThan(edgeRun), reason: '範囲の外はさらに細く、元の線へ戻ること');

    await _save(
      _composite(src, narrow),
      w,
      h,
      '${out.path}/ink_range10_width5.png',
    );
    await _save(
      _composite(src, longRange),
      w,
      h,
      '${out.path}/ink_range28_width5.png',
    );
    await _save(
      _composite(src, thickCenter),
      w,
      h,
      '${out.path}/ink_range28_width14.png',
    );
  });
}

Uint8List _animeFace(int w, int h) {
  final b = Uint8List(w * h * 4);
  for (var i = 0; i < b.length; i += 4) {
    b[i] = 250;
    b[i + 1] = 248;
    b[i + 2] = 244;
    b[i + 3] = 255;
  }
  void line(
    double x0,
    double y0,
    double x1,
    double y1, {
    int shade = 42,
    int thick = 2,
  }) {
    final steps = math.max((x1 - x0).abs(), (y1 - y0).abs()).ceil();
    for (var s = 0; s <= steps; s++) {
      final t = steps == 0 ? 0.0 : s / steps;
      _dot(
        b,
        w,
        h,
        (x0 + (x1 - x0) * t).round(),
        (y0 + (y1 - y0) * t).round(),
        shade,
        thick,
      );
    }
  }

  void ellipse(
    double cx,
    double cy,
    double rx,
    double ry, {
    int shade = 42,
    int thick = 2,
  }) {
    for (var n = 0; n < 720; n++) {
      final a = 2 * math.pi * n / 720;
      _dot(
        b,
        w,
        h,
        (cx + rx * math.cos(a)).round(),
        (cy + ry * math.sin(a)).round(),
        shade,
        thick,
      );
    }
  }

  // 顔輪郭・髪
  ellipse(180, 151, 105, 123, shade: 70, thick: 2);
  line(78, 100, 110, 40, shade: 60, thick: 3);
  line(110, 40, 150, 87, shade: 60, thick: 3);
  line(150, 87, 181, 30, shade: 60, thick: 3);
  line(181, 30, 215, 88, shade: 60, thick: 3);
  line(215, 88, 252, 44, shade: 60, thick: 3);
  line(252, 44, 283, 105, shade: 60, thick: 3);
  // 眉
  line(91, 108, 148, 101, thick: 3);
  line(212, 101, 269, 108, thick: 3);
  // 目（楕円＋上まぶた＋虹彩）
  ellipse(128, 137, 39, 21, thick: 2);
  ellipse(232, 137, 39, 21, thick: 2);
  line(91, 133, 128, 119, thick: 3);
  line(128, 119, 166, 133, thick: 3);
  line(194, 133, 232, 119, thick: 3);
  line(232, 119, 269, 133, thick: 3);
  ellipse(128, 138, 10, 14, shade: 25, thick: 2);
  ellipse(232, 138, 10, 14, shade: 25, thick: 2);
  // 鼻・口
  line(180, 151, 173, 190, shade: 90, thick: 2);
  line(173, 190, 185, 192, shade: 90, thick: 2);
  line(153, 219, 180, 225, shade: 65, thick: 2);
  line(180, 225, 207, 219, shade: 65, thick: 2);
  // 頬の短いハッチ
  for (var k = 0; k < 5; k++) {
    line(90 + k * 8, 181, 97 + k * 8, 174, shade: 150, thick: 1);
    line(235 + k * 8, 174, 242 + k * 8, 181, shade: 150, thick: 1);
  }
  return b;
}

Uint8List _angleSample(int w, int h, double angleDeg) {
  final b = Uint8List(w * h * 4);
  final cx = w ~/ 2, cy = h ~/ 2;
  final len = math.min(w, h) * 0.34;
  // 第1枝は左向き。第2枝との小さい角が angleDeg になるよう配置。
  _drawLine(b, w, h, cx, cy, (cx - len).round(), cy);
  if (angleDeg >= 179.5) {
    _drawLine(b, w, h, cx, cy, (cx + len).round(), cy);
  } else {
    final rad = (180 - angleDeg) * math.pi / 180;
    _drawLine(
      b,
      w,
      h,
      cx,
      cy,
      (cx + math.cos(rad) * len).round(),
      (cy - math.sin(rad) * len).round(),
    );
  }
  return b;
}

void _drawLine(Uint8List b, int w, int h, int x0, int y0, int x1, int y1) {
  final steps = math.max((x1 - x0).abs(), (y1 - y0).abs());
  for (var s = 0; s <= steps; s++) {
    final t = steps == 0 ? 0.0 : s / steps;
    _dot(
      b,
      w,
      h,
      (x0 + (x1 - x0) * t).round(),
      (y0 + (y1 - y0) * t).round(),
      24,
      2,
    );
  }
}

void _dot(Uint8List b, int w, int h, int x, int y, int shade, int thick) {
  final r = math.max(0, thick ~/ 2);
  for (var oy = -r; oy <= r; oy++) {
    for (var ox = -r; ox <= r; ox++) {
      final xx = x + ox, yy = y + oy;
      if (xx < 0 || xx >= w || yy < 0 || yy >= h) continue;
      final i = (yy * w + xx) * 4;
      b[i] = b[i + 1] = b[i + 2] = shade;
      b[i + 3] = 255;
    }
  }
}

void _fillEllipseMask(
  Uint8List b,
  int w,
  int h,
  double cx,
  double cy,
  double rx,
  double ry,
) {
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy > 1) continue;
      final i = (y * w + x) * 4;
      b[i] = b[i + 1] = b[i + 2] = b[i + 3] = 255;
    }
  }
}

Uint8List _composite(Uint8List base, Uint8List over) {
  final out = Uint8List.fromList(base);
  for (var i = 0; i < out.length; i += 4) {
    final a = over[i + 3] / 255.0;
    if (a <= 0) continue;
    out[i] = (over[i] * a + out[i] * (1 - a)).round();
    out[i + 1] = (over[i + 1] * a + out[i + 1] * (1 - a)).round();
    out[i + 2] = (over[i + 2] * a + out[i + 2] * (1 - a)).round();
    out[i + 3] = math.max(out[i + 3], over[i + 3]);
  }
  return out;
}

int _alphaCount(Uint8List b) {
  var n = 0;
  for (var i = 3; i < b.length; i += 4) {
    if (b[i] != 0) n++;
  }
  return n;
}

/// 列[x]の、[y]を含む**途切れていない**インクの縦の連なりの長さ
/// （＝その位置での枝1本ぶんの太さ）。
///
/// 列全体の上端〜下端を測る実装にしないこと。枝が複数ある検体では
/// 枝と枝の間の隙間まで数えてしまい、太さの比較にならない。
int _branchInkRun(Uint8List b, int w, int h, int x, int y) {
  if (b[(y * w + x) * 4 + 3] == 0) return 0;
  var top = y, bottom = y;
  while (top - 1 >= 0 && b[((top - 1) * w + x) * 4 + 3] != 0) {
    top--;
  }
  while (bottom + 1 < h && b[((bottom + 1) * w + x) * 4 + 3] != 0) {
    bottom++;
  }
  return bottom - top + 1;
}

double _mad(Uint8List a, Uint8List b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += (a[i] - b[i]).abs();
  }
  return s / a.length;
}

double _regionMad(
  Uint8List a,
  Uint8List b,
  int w,
  int x0,
  int y0,
  int x1,
  int y1,
) {
  var s = 0.0, n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * w + x) * 4;
      for (var c = 0; c < 4; c++) {
        s += (a[i + c] - b[i + c]).abs();
        n++;
      }
    }
  }
  return n == 0 ? 0 : s / n;
}

Future<void> _save(Uint8List rgba, int w, int h, String path) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    w,
    h,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}
