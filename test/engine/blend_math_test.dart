import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/blend_math.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';

/// The pure-Dart blend formulas filters use give the same colour as the
/// layer compositor does for a layer set to that blend mode, for all 25
/// modes (opaque colours: the filters blend straight colours and keep the
/// layer's own opacity).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pairs = <(String, List<int>, List<int>)>[
    ('black', [0, 0, 0], [190, 90, 40]),
    ('white', [255, 255, 255], [40, 120, 210]),
    ('gray50', [128, 128, 128], [210, 70, 150]),
    ('chromatic', [42, 176, 219], [224, 73, 118]),
    ('dark source', [200, 150, 90], [20, 60, 30]),
  ];

  testWidgets('every blend mode matches the layer compositor', (tester) async {
    final out = Float64List(3);
    for (final mode in LayerBlendMode.values) {
      for (final (name, backdrop, source) in pairs) {
        final actual = await tester.runAsync(
          () => _compositePixel(mode, backdrop, source),
        );
        blendRgb(
          mode,
          backdrop[0] / 255,
          backdrop[1] / 255,
          backdrop[2] / 255,
          source[0] / 255,
          source[1] / 255,
          source[2] / 255,
          out,
        );
        for (var c = 0; c < 3; c++) {
          expect(
            (out[c] * 255).round(),
            closeTo(actual![c], 3),
            reason: '${mode.name}/$name channel $c',
          );
        }
      }
    }
  });
}

Future<List<int>> _compositePixel(
  LayerBlendMode mode,
  List<int> backdrop,
  List<int> source,
) async {
  final tm = TileManager(canvasWidth: 1, canvasHeight: 1);
  tm.replaceLayerPixels(
    'scene#0#backdrop',
    Uint8List.fromList([...backdrop, 255]),
  );
  tm.replaceLayerPixels('scene#0#source', Uint8List.fromList([...source, 255]));
  final image = await LayerCompositor.composite(
    tm,
    <Layer>[
      Layer(id: 'source', name: 'S', type: LayerType.normal, blendMode: mode),
      const Layer(id: 'backdrop', name: 'B', type: LayerType.normal),
    ],
    (layer) => 'scene#0#${layer.id}',
    1,
    1,
  );
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  tm.dispose();
  return data!.buffer.asUint8List().take(3).toList();
}
