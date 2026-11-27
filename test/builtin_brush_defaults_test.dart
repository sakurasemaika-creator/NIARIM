// 組み込みブラシの既定は、選んだ色で描ける（所有者の指摘、2026-11-27「なんだか
// 指定色よりも色が薄すぎるブラシがいくつかあると思うんですが、これはどういう
// 意図ですか？例えば、油性マーカーとかもっと上から塗りつぶす感じになるので
// こんなに薄くなりませんよね？」）。
//
// - 不透明度は100。わざと透けるのは水彩（透け方は水分量で決める）・ぼかし
//   （色を置く筆ではなく、輪郭の無いにじみ）だけ。エアブラシも色そのものは
//   100%で、濃いのは真ん中だけ、ふちへ向かってぼやける（所有者の指定、
//   「エアブラシは全体が透けているのではなく、ちゃんと色自体は100％で描かれる
//   けれど濃いのはストロークの中央だけでふちがぼやけるイメージですね」。
//   断面は test/engine/airbrush_profile_test.dart）。
// - 筆圧で不透明度を変えるブラシは、弱い筆圧でも半分より薄くしない（ペンの
//   筆圧0.5〜0.7でいつもの線が淡い色にならない）。エアブラシは筆圧で吹き
//   付ける濃さを変える道具なので弱い端は30のまま。Gペンは筆圧で太さだけを
//   変える。
// - 長い線の途中で薄くならない（インク切れの減衰を使わない。フェードは線の
//   両端だけを透けさせる）。
// - 乾いた画材（鉛筆・チョーク・木炭・パステル）は紙の目が残るが、粉の乗った
//   所は選んだ色。
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_pressure_resolver.dart';
import 'package:niarim/services/brush_service.dart';

import 'helpers/delta_e.dart';

const _blue = 0x2648D6;
const _w = 400;
const _h = 120;

/// The brushes that are see-through on purpose, and their opacity.
const _translucent = {
  'Brush0010': 100, // 水彩: 水分量で透ける
  'Brush0011': 25, // ぼかし
};

/// Brushes whose pen pressure sets how strongly they spray.
const _pressureSprayed = {'Brush0003'}; // エアブラシ

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final brushes = BrushService.builtInBrushes;

  test('every built-in brush lays the chosen colour at full opacity, except '
      'the ones see-through on purpose', () {
    for (final brush in brushes) {
      expect(brush.opacity, _translucent[brush.id] ?? 100, reason: brush.name);
      final range = brush.pressureOn.opacity;
      if (range.enabled &&
          !_translucent.containsKey(brush.id) &&
          !_pressureSprayed.contains(brush.id)) {
        expect(range.strong, 100, reason: brush.name);
        expect(range.weak, greaterThanOrEqualTo(45), reason: brush.name);
      }
      // No brush runs out of ink along a long stroke (the fade only fades
      // its two ends: test/engine/fade_ends_test.dart).
      expect(brush.strokeDecay, isFalse, reason: brush.name);
    }
    final gPen = brushes.singleWhere((b) => b.id == 'Brush0002');
    expect(gPen.pressureOn.opacity.enabled, isFalse);
    expect(gPen.pressureOn.size.enabled, isTrue);
  });

  test('a stroke reads as the chosen colour with a mouse and at a usual pen '
      'pressure', () async {
    // The strongest colour across each column, averaged along the middle of
    // a long stroke (so the ends' tapers do not count), as ΔE2000 from the
    // chosen colour on white paper: [mouse (1.0), pen (0.6)].
    const limits = {
      'Brush0002': [2.0, 2.0], // Gペン
      'Brush0008': [2.0, 20.0], // 丸ペン（筆圧0.6で1画素ほどの細さ）
      'Brush0015': [2.0, 2.0], // 面相筆
      'Brush0009': [2.0, 2.0], // 平筆（筆圧で色を薄くしない）
      'Brush0005': [2.0, 2.0], // マーカーペン
      'Brush0004': [2.0, 2.0], // 混色ブラシ
      'Brush0007': [2.0, 16.0], // 鉛筆
      'Brush0028': [8.0, 20.0], // 鉛筆（4B）
      'Brush0012': [8.0, 16.0], // チョーク
      'Brush0026': [8.0, 20.0], // 木炭（粗目）
      'Brush0029': [8.0, 20.0], // パステル（粉）
      'Brush0027': [3.0, 3.0], // ガッシュ（不透明水彩）
      'Brush0042': [2.0, 2.0], // 油彩筆
      'Brush0043': [2.0, 2.0], // かすれ筆
      'Brush0044': [2.0, 2.0], // ペインティングナイフ
      'Brush0017': [3.0, 8.0], // ラメペン
      'Brush0030': [4.0, 4.0], // 雲（先端の画像を線ごとに選ぶので5本の中央値）
      'Brush0003': [1.0, 20.0], // エアブラシ（真ん中は選んだ色）
    };
    for (final entry in limits.entries) {
      final brush = brushes.singleWhere((b) => b.id == entry.key);
      await _expectChosenColour(brush, entry.value);
    }
  });
}

/// Draws [brush] across white paper at pressure 1.0 and 0.6 and checks the
/// colour along the middle of each stroke is within [limits] of the chosen
/// colour. Brushes that pick their tips at random for each stroke (the cloud)
/// are judged by the median of five strokes.
Future<void> _expectChosenColour(Brush brush, List<double> limits) async {
  await preloadBrushTextures(
    brush.resolvedCustomImagePaths,
    mode: brush.imageInkMode,
  );
  final strokes =
      brush.customImageSelectionMode ==
              BrushImageSelectionMode.randomPerStamp &&
          brush.resolvedCustomImagePaths.length > 1
      ? 5
      : 1;
  for (final (k, pressure) in [(0, 1.0), (1, 0.6)]) {
    final found = [
      for (var i = 0; i < strokes; i++) _middleDeltaE(brush, pressure),
    ]..sort();
    expect(
      found[strokes ~/ 2],
      lessThan(limits[k]),
      reason: '${brush.name} at pressure $pressure: $found',
    );
  }
}

/// The strongest colour across each column, averaged along the middle of a
/// stroke of [brush] at [pressure], as ΔE2000 from the chosen colour.
double _middleDeltaE(Brush brush, double pressure) {
  final tiles = TileManager(canvasWidth: _w, canvasHeight: _h);
  final engine = DrawingEngine(tileManager: tiles)
    ..currentBrush = brush
    ..currentColor = const ui.Color(0xFF000000 | _blue)
    ..pressureEnabled = true;
  tiles.beginUndoRecording('l');
  engine.beginStroke(StrokePoint(x: 30, y: 60, pressure: pressure), 'l');
  for (var x = 32.0; x <= _w - 30; x += 2) {
    engine.continueStroke(StrokePoint(x: x, y: 60, pressure: pressure), 'l');
  }
  if (engine.needsFinalFadeReplay) {
    final preview = tiles.endUndoRecording();
    tiles.applyTileSnapshot('l', preview.before);
    tiles.beginUndoRecording('l');
    engine.replayCurrentStrokeWithFinalFade();
  }
  engine.endStroke();
  tiles.endUndoRecording();
  final scale = resolveBrushPressure(
    brush: brush,
    pressureEnabled: true,
    curvedPressure: pressure,
  ).sizeScale;
  final reach = math.max(2, (brush.size * scale / 2).ceil());
  var sum = 0.0;
  for (var x = 120; x <= 280; x++) {
    var best = double.infinity;
    for (var y = 60 - reach; y <= 60 + reach; y++) {
      final c = tiles.getPixelColorAt('l', x, y);
      if (c == null) continue;
      double over(double v) => (v * c.a + (1 - c.a)) * 255;
      best = math.min(
        best,
        deltaE2000(labOf(over(c.r), over(c.g), over(c.b)), labOfRgb(_blue)),
      );
    }
    sum += best.isFinite ? best : 100;
  }
  tiles.dispose();
  return sum / 161;
}
