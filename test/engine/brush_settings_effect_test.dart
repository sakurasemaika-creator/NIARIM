import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 420;
const _h = 140;

/// ブラシの設定シートの各項目が、実際に描く線を変えることを確かめる
/// （効いていない飾りの設定が無いか）。同じ曲線を、基準のブラシと1項目
/// だけ変えたブラシで描き、描いた画素の数・不透明度の合計・線の端の
/// 濃さを比べる。どの線もタイルは正しい乗算済み（色≤不透明度）。
/// 見本を`build/brush-settings/`へ焼く。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Brush base;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'pen_pressure_enabled': false});
    final service = BrushService();
    await service.init();
    base = service.brushes
        .firstWhere((b) => b.id == 'Brush0001')
        .copyWith(id: 'base', size: 12, opacity: 100);
  });

  ({
    int inked,
    int alphaSum,
    int tailAlpha,
    int partial,
    int invalid,
    Uint8List rgba,
  })
  draw(Brush brush, {int stabilization = 0}) {
    final tm = TileManager(canvasWidth: _w, canvasHeight: _h);
    final engine = DrawingEngine(tileManager: tm)
      ..currentBrush = brush
      ..stabilizationStrength = stabilization
      ..currentColor = const ui.Color(0xFF2040A0)
      ..pressureEnabled = false;
    StrokePoint p(double x, double y) =>
        StrokePoint(x: x, y: y, pressure: 1, tiltX: 0, tiltY: 0);
    tm.beginUndoRecording('L');
    engine.beginStroke(p(20, 70), 'L');
    for (var i = 1; i <= 76; i++) {
      final x = 20 + i * 5.0;
      final y = 70 + 30 * math.sin(i / 6);
      engine.continueStroke(p(x, y), 'L');
    }
    // The canvas draws a faded stroke again once it is complete (the fade at
    // the end needs its length).
    final drawn = tm.endUndoRecording();
    if (engine.needsFinalFadeReplay) {
      tm.applyTileSnapshot('L', drawn.before);
      engine.replayCurrentStrokeWithFinalFade();
    }
    engine.endStroke();
    final rgba = Uint8List(_w * _h * 4);
    var inked = 0, alphaSum = 0, tailAlpha = 0, partial = 0, invalid = 0;
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final tile = tm.getTile('L', x ~/ 256, y ~/ 256);
        if (tile == null) continue;
        final s = ((y % 256) * 256 + (x % 256)) * 4;
        final d = (y * _w + x) * 4;
        for (var c = 0; c < 4; c++) {
          rgba[d + c] = tile[s + c];
        }
        final a = tile[s + 3];
        if (a == 0) continue;
        inked++;
        alphaSum += a;
        if (a < 250) partial++;
        if (x > 380) tailAlpha += a;
        if (tile[s] > a || tile[s + 1] > a || tile[s + 2] > a) invalid++;
      }
    }
    return (
      inked: inked,
      alphaSum: alphaSum,
      tailAlpha: tailAlpha,
      partial: partial,
      invalid: invalid,
      rgba: rgba,
    );
  }

  Future<void> save(String name, Uint8List rgba) async {
    final dir = Directory('build/brush-settings')..createSync(recursive: true);
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final codec = await ui.ImageDescriptor.raw(
      buffer,
      width: _w,
      height: _h,
      pixelFormat: ui.PixelFormat.rgba8888,
    ).instantiateCodec();
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    File('${dir.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  }

  double change(int a, int b) => (a - b).abs() / math.max(1, b);

  test('every setting changes the stroke', () async {
    final reference = draw(base);
    expect(reference.inked, greaterThan(1000));
    expect(reference.invalid, 0);
    for (var x = 26; x < 395; x++) {
      final center = (70 + 30 * math.sin((x - 20) / 30)).round();
      expect(
        [
          for (var y = center - 2; y <= center + 2; y++)
            reference.rgba[(y * _w + x) * 4 + 3],
        ].reduce(math.max),
        255,
        reason: 'The standard pen should paint a solid core at x=$x',
      );
    }
    await save('00_base', reference.rgba);

    final off = base.pressureOff;
    final variants = <String, Brush>{
      'spacing_200': base.copyWith(spacing: 200),
      'blur_40': base.copyWith(
        pressureOff: off.copyWith(
          blur: const FixedBrushSetting(enabled: true, value: 40),
        ),
      ),
      'edge_jitter_80': base.copyWith(
        pressureOff: off.copyWith(
          edgeJitter: const FixedBrushSetting(enabled: true, value: 80),
        ),
      ),
      'opacity_40': base.copyWith(opacity: 40),
      // 手ぶれ補正はブラシではなくアプリの設定（ペン入力設定）で、
      // DrawingEngine.stabilizationStrengthが全ブラシに同じ強さで効く。
      'stabilization_90': base,
      'pixel_mode': base.copyWith(pixelMode: true),
      'decay': base.copyWith(strokeDecay: true),
      'fade_weak': base.copyWith(fadeMode: FadeMode.weak),
      'fade_medium': base.copyWith(fadeMode: FadeMode.medium),
      'fade_strong': base.copyWith(fadeMode: FadeMode.strong),
      // Shape-tip comparisons leave a gap so each square's hole is visible.
      'square_tip': base.copyWith(
        tipShape: BrushTipShape.hollowSquare,
        spacing: 16,
      ),
      'square_tip_rotation': base.copyWith(
        tipShape: BrushTipShape.hollowSquare,
        spacing: 16,
        rotation: true,
      ),
      'density_02': base.copyWith(
        tipShape: BrushTipShape.hollowSquare,
        density: 0.2,
        spacing: 60,
      ),
      'scatter_1': base.copyWith(
        tipShape: BrushTipShape.hollowSquare,
        scatter: 1,
        spacing: 60,
      ),
    };
    final unchanged = <String>[];
    final results =
        <
          String,
          ({
            int inked,
            int alphaSum,
            int tailAlpha,
            int partial,
            int invalid,
            Uint8List rgba,
          })
        >{};
    const appStabilization = {'stabilization_90': 90};
    for (final entry in variants.entries) {
      final r = draw(
        entry.value,
        stabilization: appStabilization[entry.key] ?? 0,
      );
      results[entry.key] = r;
      await save(entry.key, r.rgba);
      expect(r.invalid, 0, reason: '${entry.key}：色が不透明度より大きい画素');
      // 画素ごとの違い（縁を揺らす設定は、数や合計がたまたま基準に近く
      // なることがあるので、同じ位置の濃さの違いも見る）。
      var differing = 0;
      for (var i = 3; i < r.rgba.length; i += 4) {
        if ((r.rgba[i] - reference.rgba[i]).abs() > 16) differing++;
      }
      final moved =
          differing > reference.inked * 0.03 ||
          change(r.inked, reference.inked) > 0.03 ||
          change(r.alphaSum, reference.alphaSum) > 0.03 ||
          change(r.tailAlpha, reference.tailAlpha) > 0.03;
      if (!moved) unchanged.add(entry.key);
    }
    expect(unchanged, isEmpty, reason: '描く線が変わらなかった設定');

    // 値の向きも確かめる。
    expect(results['spacing_200']!.inked, lessThan(reference.inked));
    expect(results['blur_40']!.partial, greaterThan(reference.partial));
    expect(results['opacity_40']!.alphaSum, lessThan(reference.alphaSum * 0.6));
    expect(results['pixel_mode']!.partial, 0, reason: 'ドットは半透明の縁を作らない');
    for (final fade in ['fade_weak', 'fade_medium', 'fade_strong']) {
      expect(
        results[fade]!.tailAlpha,
        lessThan(reference.tailAlpha),
        reason: '$fade：終わりが薄くなる',
      );
    }
    expect(
      results['fade_strong']!.tailAlpha,
      lessThanOrEqualTo(results['fade_weak']!.tailAlpha),
      reason: '強いほど終わりが薄い',
    );
  });
}
