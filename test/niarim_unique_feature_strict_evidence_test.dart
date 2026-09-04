import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/niarim-unique-strict');

  setUpAll(() => out.createSync(recursive: true));

  test('眼鏡断層: マスク無し/空マスクでは完全無変更', () {
    const w = 180, h = 120;
    final src = _gridPattern(w, h);
    final engine = FilterEngine();

    final noMask = engine.applyLensDistortion(
      Uint8List.fromList(src), w, h, 70, null,
    );
    expect(noMask, orderedEquals(src));

    final emptyMask = Uint8List(w * h * 4);
    final empty = engine.applyLensDistortion(
      Uint8List.fromList(src), w, h, 70, emptyMask,
    );
    expect(empty, orderedEquals(src));
  });

  test('眼鏡断層: 選択範囲内だけが歪み、範囲外はbyte単位で保持される', () async {
    const w = 220, h = 150;
    final src = _gridPattern(w, h);
    final mask = _twoLensMask(w, h);
    final engine = FilterEngine();
    final got = engine.applyLensDistortion(
      Uint8List.fromList(src), w, h, 78, mask,
    );

    var insideChanged = 0;
    var insideTotal = 0;
    var outsideChanged = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final inMask = mask[i + 3] > 0;
        final changed = src[i] != got[i] ||
            src[i + 1] != got[i + 1] ||
            src[i + 2] != got[i + 2] ||
            src[i + 3] != got[i + 3];
        if (inMask) {
          insideTotal++;
          if (changed) insideChanged++;
        } else if (changed) {
          outsideChanged++;
        }
      }
    }
    expect(insideTotal, greaterThan(3000));
    expect(insideChanged / insideTotal, greaterThan(0.15));
    expect(outsideChanged, 0,
        reason: '眼鏡断層は選択レイヤーで塗った範囲の外を変更してはいけない');

    await _saveRgba(src, w, h, '${out.path}/lens_input.png');
    await _saveRgba(mask, w, h, '${out.path}/lens_mask_two_lenses.png');
    await _saveRgba(got, w, h, '${out.path}/lens_positive_78.png');
  });

  test('眼鏡断層: 正負度数は見た目が異なり、0は無効', () async {
    const w = 200, h = 140;
    final src = _gridPattern(w, h);
    final mask = _singleLensMask(w, h, cx: 100, cy: 70, rx: 62, ry: 48);
    final engine = FilterEngine();

    final zero = engine.applyLensDistortion(
      Uint8List.fromList(src), w, h, 0, mask,
    );
    final convex = engine.applyLensDistortion(
      Uint8List.fromList(src), w, h, 82, mask,
    );
    final concave = engine.applyLensDistortion(
      Uint8List.fromList(src), w, h, -82, mask,
    );

    expect(zero, orderedEquals(src));
    expect(_meanAbsDiff(src, convex), greaterThan(1.0));
    expect(_meanAbsDiff(src, concave), greaterThan(1.0));
    expect(_meanAbsDiff(convex, concave), greaterThan(1.2),
        reason: '凸レンズ風と凹レンズ風が同じ見た目になってはいけない');

    await _saveRgba(convex, w, h, '${out.path}/lens_convex_plus82.png');
    await _saveRgba(concave, w, h, '${out.path}/lens_concave_minus82.png');
  });

  test('眼鏡断層: 中心オフセットが歪み中心を実際に移動させる', () async {
    const w = 220, h = 150;
    final src = _gridPattern(w, h);
    final mask = _singleLensMask(w, h, cx: 110, cy: 75, rx: 70, ry: 52);
    final engine = FilterEngine();

    final centered = engine.applyLensDistortion(
      Uint8List.fromList(src), w, h, 75, mask,
    );
    final shifted = engine.applyLensDistortion(
      Uint8List.fromList(src), w, h, 75, mask,
      centerOffsetX: 22,
      centerOffsetY: -14,
    );

    expect(_meanAbsDiff(centered, shifted), greaterThan(0.7));
    final c0 = _changeCentroid(src, centered, w, h);
    final c1 = _changeCentroid(src, shifted, w, h);
    expect(c1.dx, greaterThan(c0.dx + 3));
    expect(c1.dy, lessThan(c0.dy - 2));

    await _saveRgba(centered, w, h, '${out.path}/lens_center_default.png');
    await _saveRgba(shifted, w, h, '${out.path}/lens_center_offset_22_-14.png');
  });

  test('眼鏡断層: 離れた2つの連結成分を独立レンズとして処理する', () async {
    const w = 240, h = 150;
    final src = _gridPattern(w, h);
    final mask = _twoLensMask(w, h);
    final engine = FilterEngine();
    final got = engine.applyLensDistortion(
      Uint8List.fromList(src), w, h, 72, mask,
    );

    final leftDiff = _regionDiff(src, got, w, 25, 35, 105, 120);
    final rightDiff = _regionDiff(src, got, w, 135, 35, 215, 120);
    final bridgeDiff = _regionDiff(src, got, w, 106, 55, 134, 95);
    expect(leftDiff, greaterThan(1.0));
    expect(rightDiff, greaterThan(1.0));
    expect(bridgeDiff, 0,
        reason: '左右の選択領域間の未選択ブリッジは歪ませてはいけない');

    await _saveRgba(got, w, h, '${out.path}/lens_two_components.png');
  });

  test('オーロラホログラム: 全6プリセットが固有の出力を作り透明度を保持', () async {
    const w = 160, h = 96;
    final src = _lumaRamp(w, h);
    final engine = FilterEngine();
    final outputs = <AuroraHologramPreset, Uint8List>{};

    for (final preset in AuroraHologramPreset.values) {
      final got = engine.applyAuroraHologram(
        Uint8List.fromList(src), w, h,
        strength: 100,
        brightness: 0,
        saturation: 0,
        preset: preset,
      );
      outputs[preset] = got;
      for (var i = 3; i < got.length; i += 4) {
        expect(got[i], src[i]);
      }
      expect(_meanAbsDiff(src, got), greaterThan(5));
      await _saveRgba(got, w, h,
          '${out.path}/hologram_${preset.name}.png');
    }

    for (var i = 0; i < AuroraHologramPreset.values.length; i++) {
      for (var j = i + 1; j < AuroraHologramPreset.values.length; j++) {
        final a = outputs[AuroraHologramPreset.values[i]]!;
        final b = outputs[AuroraHologramPreset.values[j]]!;
        expect(_meanAbsDiff(a, b), greaterThan(1.0));
      }
    }
  });

  test('背景馴染ませ: 向き180度反転で光/影側が反転し出力が変わる', () async {
    const w = 180, h = 120;
    final src = _subjectOnTransparent(w, h);
    final engine = FilterEngine();

    final d0 = engine.applyBackgroundBlend(
      Uint8List.fromList(src), w, h,
      0xFF8CB0D0, 0, 18, 5,
    );
    final d180 = engine.applyBackgroundBlend(
      Uint8List.fromList(src), w, h,
      0xFF8CB0D0, 180, 18, 5,
    );
    expect(_meanAbsDiff(src, d0), greaterThan(0.5));
    expect(_meanAbsDiff(d0, d180), greaterThan(0.5));

    await _saveRgba(src, w, h, '${out.path}/background_blend_input.png');
    await _saveRgba(d0, w, h, '${out.path}/background_blend_direction_0.png');
    await _saveRgba(d180, w, h, '${out.path}/background_blend_direction_180.png');
  });
}

Uint8List _gridPattern(int w, int h) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final gx = (x * 255 ~/ math.max(1, w - 1));
      final gy = (y * 255 ~/ math.max(1, h - 1));
      final line = (x % 14 < 2) || (y % 14 < 2);
      out[i] = line ? 30 : gx;
      out[i + 1] = line ? 40 : gy;
      out[i + 2] = line ? 55 : ((x + y) * 255 ~/ math.max(1, w + h - 2));
      out[i + 3] = 255;
    }
  }
  return out;
}

Uint8List _singleLensMask(int w, int h,
    {required double cx, required double cy, required double rx, required double ry}) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = (x - cx) / rx;
      final dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1) {
        final i = (y * w + x) * 4;
        out[i] = out[i + 1] = out[i + 2] = 255;
        out[i + 3] = 255;
      }
    }
  }
  return out;
}

Uint8List _twoLensMask(int w, int h) {
  final left = _singleLensMask(w, h,
      cx: w * 0.29, cy: h * 0.52, rx: w * 0.20, ry: h * 0.29);
  final right = _singleLensMask(w, h,
      cx: w * 0.71, cy: h * 0.52, rx: w * 0.20, ry: h * 0.29);
  for (var i = 0; i < left.length; i += 4) {
    if (right[i + 3] > 0) {
      left[i] = left[i + 1] = left[i + 2] = 255;
      left[i + 3] = 255;
    }
  }
  return left;
}

Uint8List _lumaRamp(int w, int h) {
  final out = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final v = (x * 255 ~/ math.max(1, w - 1));
      out[i] = v;
      out[i + 1] = v;
      out[i + 2] = v;
      out[i + 3] = ((x + y) % 17 == 0) ? 120 : 255;
    }
  }
  return out;
}

Uint8List _subjectOnTransparent(int w, int h) {
  final out = Uint8List(w * h * 4);
  for (var y = 28; y < h - 26; y++) {
    for (var x = 48; x < w - 46; x++) {
      final i = (y * w + x) * 4;
      out[i] = 220;
      out[i + 1] = 120;
      out[i + 2] = 82;
      out[i + 3] = 255;
    }
  }
  return out;
}

ui.Offset _changeCentroid(Uint8List a, Uint8List b, int w, int h) {
  double sx = 0, sy = 0, sw = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final d = (a[i] - b[i]).abs() +
          (a[i + 1] - b[i + 1]).abs() +
          (a[i + 2] - b[i + 2]).abs();
      if (d > 4) {
        sx += x * d;
        sy += y * d;
        sw += d;
      }
    }
  }
  return sw == 0 ? ui.Offset.zero : ui.Offset(sx / sw, sy / sw);
}

double _regionDiff(Uint8List a, Uint8List b, int w,
    int x0, int y0, int x1, int y1) {
  double sum = 0;
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * w + x) * 4;
      for (var c = 0; c < 4; c++) {
        sum += (a[i + c] - b[i + c]).abs();
        n++;
      }
    }
  }
  return n == 0 ? 0 : sum / n;
}

double _meanAbsDiff(Uint8List a, Uint8List b) {
  double sum = 0;
  for (var i = 0; i < a.length; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum / a.length;
}

Future<void> _saveRgba(Uint8List rgba, int w, int h, String path) async {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
  final image = await c.future;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}
