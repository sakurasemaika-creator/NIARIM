import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('組み込み全6ブラシをBrushService実プリセット値のまま実描画しPNGと画素特性を検査する', () async {
    final service = BrushService();
    await service.init();
    final brushes = service.brushes
        .where((b) => b.id.startsWith('Brush000'))
        .toList();
    expect(brushes.map((b) => b.id).toSet(), {
      'Brush0001',
      'Brush0002',
      'Brush0003',
      'Brush0004',
      'Brush0005',
      'Brush0006',
    }, reason: '組み込みブラシ6種が欠けず監査対象になること');

    final signatures = <String, String>{};
    final nonTransparent = <String, int>{};
    final intermediateAlpha = <String, int>{};

    for (final brush in brushes) {
      const w = 220, h = 120;
      final tm = TileManager(canvasWidth: w, canvasHeight: h);
      final engine = DrawingEngine(tileManager: tm)
        ..currentBrush = brush
        ..currentColor = const ui.Color(0xFFD83A28);

      // 実際のペン入力に近い、筆圧が弱→強→弱へ変化する緩いS字ストローク。
      const points = <(double, double, double)>[
        (18, 78, 0.30),
        (35, 63, 0.45),
        (55, 51, 0.62),
        (78, 45, 0.78),
        (104, 48, 1.00),
        (130, 58, 0.85),
        (156, 70, 0.65),
        (182, 76, 0.45),
        (204, 70, 0.30),
      ];
      engine.beginStroke(
        StrokePoint(
          x: points.first.$1,
          y: points.first.$2,
          pressure: points.first.$3,
        ),
        'paint',
      );
      for (final p in points.skip(1)) {
        engine.continueStroke(
          StrokePoint(x: p.$1, y: p.$2, pressure: p.$3),
          'paint',
        );
      }
      engine.endStroke();

      final image = await tm.compositeLayerToImage('paint');
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${out.path}/builtin_brush_${brush.id}_${_safe(brush.name)}.png',
      ).writeAsBytes(png!.buffer.asUint8List());

      var count = 0;
      var mid = 0;
      var hash = 2166136261;
      for (var i = 0; i < rgba.length; i += 4) {
        final a = rgba[i + 3];
        if (a != 0) count++;
        if (a > 0 && a < 255) mid++;
        // FNV-like fingerprint over all channels: visual outputs should not all collapse to one shape.
        hash = ((hash ^ rgba[i]) * 16777619) & 0x7fffffff;
        hash = ((hash ^ rgba[i + 1]) * 16777619) & 0x7fffffff;
        hash = ((hash ^ rgba[i + 2]) * 16777619) & 0x7fffffff;
        hash = ((hash ^ a) * 16777619) & 0x7fffffff;
      }
      nonTransparent[brush.id] = count;
      intermediateAlpha[brush.id] = mid;
      signatures[brush.id] = '$hash:$count:$mid';
      expect(
        count,
        greaterThan(20),
        reason:
            '${brush.name} must produce a visible stroke with its actual preset',
      );

      image.dispose();
      tm.dispose();
    }

    // 6プリセットが同じ見た目へ潰れていないこと。細いペン同士など似るものはあっても、
    // 少なくとも大半は別の画素指紋になる必要がある。
    expect(signatures.values.toSet().length, greaterThanOrEqualTo(5));

    // エアブラシはopacity40 + blur50の実プリセットなので中間alphaが大量に生じる。
    expect(intermediateAlpha['Brush0003']!, greaterThan(200));
    // Gペンは3px、エアブラシは30pxなので同じ入力でも描画面積が明確に違う。
    expect(
      nonTransparent['Brush0003']!,
      greaterThan(nonTransparent['Brush0002']! * 3),
    );
    // マーカーは65%不透明度 + 減衰を持つため、中間alphaが存在する。
    expect(intermediateAlpha['Brush0005']!, greaterThan(20));
  });
}

String _safe(String s) =>
    s.replaceAll(RegExp(r'[^0-9A-Za-z_\-ぁ-んァ-ヶ一-龠]'), '_');
