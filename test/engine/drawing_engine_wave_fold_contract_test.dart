import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/drawing_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

const foldCurve = <ui.Offset>[
  ui.Offset(60, 40),
  ui.Offset(180, 140),
  ui.Offset(60, 240),
  ui.Offset(180, 340),
];

Future<Uint8List> renderFold(
  HairFoldMode mode, {
  bool reverse = false,
  bool enabled = true,
  List<ui.Offset> curve = foldCurve,
}) async {
  final tiles = TileManager(canvasWidth: 256, canvasHeight: 400);
  final engine = DrawingEngine(tileManager: tiles)
    ..pressureEnabled = false
    ..currentColor = const ui.Color(0xffffffff)
    ..currentBrush = Brush(
      id: 'fold',
      name: 'Fold',
      size: 44,
      spacing: 1,
      opacity: 100,
      density: 1,
      fadeMode: FadeMode.off,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      strokeDecay: false,
      outlineEnabled: true,
      outlineWidth: 2,
      outlineColor: 0xff000000,
      foldEnabled: enabled,
      foldTriggerAngle: 45,
      foldMode: mode,
    );
  final points = reverse ? curve.reversed.toList() : curve;
  StrokePoint sample(ui.Offset p) =>
      StrokePoint(x: p.dx, y: p.dy, pressure: 1, tiltX: 0, tiltY: 0);
  engine.beginStroke(sample(points.first), 'test');
  for (var i = 1; i < points.length; i++) {
    final count = (points[i] - points[i - 1]).distance.ceil();
    for (var j = 1; j <= count; j++) {
      engine.continueStroke(
        sample(ui.Offset.lerp(points[i - 1], points[i], j / count)!),
        'test',
      );
    }
  }
  engine.endStroke();
  final image = await tiles.compositeLayerToImage('test');
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = Uint8List.fromList(data!.buffer.asUint8List());
  image.dispose();
  tiles.dispose();
  return bytes;
}

int changedPixels(Uint8List a, Uint8List b) {
  var count = 0;
  for (var i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() > 80 || (a[i + 3] - b[i + 3]).abs() > 80) count++;
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'opposite views change visible fold edges, not just line thickness',
    () async {
      final top = await renderFold(HairFoldMode.waveTopView);
      final low = await renderFold(HairFoldMode.waveLowAngle);
      expect(changedPixels(top, low), greaterThan(100));
    },
  );
  test('opposite curls change which diagonal occludes the other', () async {
    final right = await renderFold(HairFoldMode.curlRight);
    final left = await renderFold(HairFoldMode.curlLeft);
    expect(changedPixels(right, left), greaterThan(100));
  });
  test('fold off ignores the selected mode', () async {
    expect(
      await renderFold(HairFoldMode.curlLeft, enabled: false),
      await renderFold(HairFoldMode.waveTopView, enabled: false),
    );
  });
  test('straight input is ordinary drawing for every mode', () async {
    const line = [ui.Offset(60, 40), ui.Offset(60, 340)];
    final plain = await renderFold(
      HairFoldMode.waveTopView,
      enabled: false,
      curve: line,
    );
    for (final mode in HairFoldMode.values) {
      expect(await renderFold(mode, curve: line), plain);
    }
  });
}
