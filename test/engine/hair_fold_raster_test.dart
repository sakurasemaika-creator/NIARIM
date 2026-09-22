import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_stroke_geometry.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/hair_fold_raster.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';

TileManager draw({double frontOpacity = 1, int? textureAlpha}) {
  final tiles = TileManager(canvasWidth: 128, canvasHeight: 200);
  const a = Offset(20, 40), b = Offset(80, 100), c = Offset(20, 160);
  final points = [
    HairRibbonPoint(a, 60, frontOpacity),
    HairRibbonPoint(b, 60, frontOpacity),
    const HairRibbonPoint(Offset(78, 102), 60, 1),
    const HairRibbonPoint(c, 60, 1),
  ];
  final texture = textureAlpha == null
      ? null
      : Uint8List(brushTextureSize * brushTextureSize * 4);
  if (texture != null) {
    for (var i = 3; i < texture.length; i += 4) {
      texture[i] = textureAlpha!;
    }
  }
  HairFoldRaster(tiles, 'test').render(
    points: points,
    folds: const [
      FoldEvent(
        sample: BrushStrokeSample(
          screenPosition: c,
          documentPosition: c,
          effectiveWidth: 60,
        ),
        tangent: Offset(-1, 1),
        inwardNormal: Offset(-1, 0),
        signedTurnRadians: 1.57,
        screenDistance: 160,
        sourceCurve: [a, b, c],
        sourceIndices: [0, 1, 3],
      ),
    ],
    brush: const Brush(
      id: 'fold',
      name: 'fold',
      size: 60,
      opacity: 100,
      spacing: 1,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      strokeDecay: false,
      fadeMode: FadeMode.off,
      outlineEnabled: true,
      outlineWidth: 2,
      foldEnabled: true,
    ),
    fillColor: const Color(0xffffffff),
    texture: texture,
  );
  return tiles;
}

void main() {
  test(
    'partially transparent authored texture never gains alpha at a fold',
    () {
      final tiles = draw(textureAlpha: 128);
      for (final tile in tiles.exportAll()['test']!.values) {
        for (var i = 3; i < tile.length; i += 4) {
          expect(tile[i], lessThanOrEqualTo(128));
        }
      }
      tiles.dispose();
    },
  );
  for (final opacity in [0.0, 0.1]) {
    test('front pressure opacity $opacity cannot erase opaque rear ink', () {
      final tiles = draw(frontOpacity: opacity);
      final tile = tiles.getTile('test', 0, 0)!;
      expect(tile[(90 * TileManager.tileSize + 70) * 4 + 3], 255);
      tiles.dispose();
    });
  }
}
