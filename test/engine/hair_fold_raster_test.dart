import 'dart:math' as math;
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

TileManager crescent({
  double radius = 85,
  double width = 60,
  double rotation = 0,
  bool continuous = false,
  int? steps,
  double opacity = 1,
  List<HairRibbonPoint>? input,
  List<FoldEvent>? folds,
  Uint8List? texture,
}) {
  final tiles = TileManager(canvasWidth: 360, canvasHeight: 360);
  final points =
      input ??
      [
        for (var i = 0; i <= (steps ?? (continuous ? 120 : 60)); i++)
          HairRibbonPoint(
            Offset(180, 180) +
                Offset(
                      math.cos(-math.pi / 2 + math.pi * i / 60 + rotation),
                      math.sin(-math.pi / 2 + math.pi * i / 60 + rotation),
                    ) *
                    radius,
            width,
            opacity,
          ),
      ];
  HairFoldRaster(tiles, 'test').render(
    points: points,
    folds:
        folds ??
        [
          FoldEvent(
            sample: BrushStrokeSample(
              screenPosition: points.last.position,
              documentPosition: points.last.position,
              effectiveWidth: width,
            ),
            tangent: const Offset(-1, 0),
            inwardNormal: const Offset(-1, 0),
            signedTurnRadians: math.pi,
            screenDistance: radius * math.pi,
            isContinuousTurnFold: continuous,
            sourceCurve: points
                .take(continuous ? 91 : points.length)
                .map((p) => p.position)
                .toList(),
            sourceIndices: List.generate(
              continuous ? 91 : points.length,
              (i) => i,
            ),
          ),
        ],
    brush: Brush(
      id: 'crescent',
      name: 'crescent',
      size: width,
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
      foldMode: HairFoldMode.crescent,
      rotation: false,
    ),
    fillColor: const Color(0xffffffff),
    texture: texture,
  );
  return tiles;
}

int channelAt(TileManager tiles, int x, int y, int channel) {
  final tile = tiles.getTile(
    'test',
    x ~/ TileManager.tileSize,
    y ~/ TileManager.tileSize,
  );
  return tile?[(y % TileManager.tileSize * TileManager.tileSize +
                  x % TileManager.tileSize) *
              4 +
          channel] ??
      0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'crescent reversals follow input even when a small bend misses the detector',
    () {
      final points = [
        for (var i = 0; i <= 180; i++)
          HairRibbonPoint(
            Offset(180 + 60 * math.sin(i * math.pi / 60), 30 + i * 1.6),
            26,
            1,
          ),
      ];
      FoldEvent event(int pivot, double sign) => FoldEvent(
        sample: BrushStrokeSample(
          screenPosition: points[pivot + 15].position,
          documentPosition: points[pivot + 15].position,
          effectiveWidth: 26,
        ),
        tangent: const Offset(0, 1),
        inwardNormal: const Offset(-1, 0),
        signedTurnRadians: sign,
        screenDistance: pivot * 2,
        sourceCurve: points
            .sublist(pivot - 15, pivot + 16)
            .map((p) => p.position)
            .toList(),
        sourceIndices: List.generate(31, (i) => pivot - 15 + i),
      );
      final oneEvent = crescent(
        width: 26,
        input: points,
        folds: [event(30, 1)],
      );
      final allEvents = crescent(
        width: 26,
        input: points,
        folds: [event(30, 1), event(90, -1), event(150, 1)],
      );
      addTearDown(oneEvent.dispose);
      addTearDown(allEvents.dispose);
      var changed = 0;
      for (var y = 0; y < 360; y++) {
        for (var x = 0; x < 360; x++) {
          if ((channelAt(oneEvent, x, y, 3) - channelAt(allEvents, x, y, 3))
                  .abs() >
              80) {
            changed++;
          }
        }
      }
      expect(changed, 0);
    },
  );
  test('short continuation after a fold tapers without a swollen cap', () {
    final tiles = crescent(continuous: true, steps: 95);
    addTearDown(tiles.dispose);
    expect(channelAt(tiles, 65, 170, 3), 0);
    expect(channelAt(tiles, 95, 170, 3), 255);
  });
  test('a one-segment continuous neck keeps its negative turn direction', () {
    final clockwise = crescent(continuous: true, steps: 91);
    final counterclockwise = crescent(
      continuous: true,
      input: [
        for (var i = 0; i <= 91; i++)
          HairRibbonPoint(
            Offset(180, 180) +
                Offset(
                      -math.cos(-math.pi / 2 + math.pi * i / 60),
                      math.sin(-math.pi / 2 + math.pi * i / 60),
                    ) *
                    85,
            60,
            1,
          ),
      ],
    );
    addTearDown(clockwise.dispose);
    addTearDown(counterclockwise.dispose);
    var differences = 0;
    for (var y = 150; y <= 190; y++) {
      for (var x = 65; x <= 125; x++) {
        if ((channelAt(clockwise, x, y, 3) -
                    channelAt(counterclockwise, 359 - x, y, 3))
                .abs() >
            64) {
          differences++;
        }
      }
    }
    expect(differences, lessThan(5));
  });
  test('continuous crescent neck has no cap seam or opacity accumulation', () {
    final tiles = crescent(continuous: true, width: 30, opacity: .4);
    addTearDown(tiles.dispose);
    for (var y = 178; y <= 182; y++) {
      for (var x = 91; x <= 99; x++) {
        expect(
          channelAt(tiles, x, y, 0),
          greaterThan(245),
          reason: 'neck at $x,$y',
        );
        expect(channelAt(tiles, x, y, 3), 102);
      }
    }
    for (final tile in tiles.exportAll()['test']!.values) {
      for (var i = 3; i < tile.length; i += 4) {
        expect(tile[i], lessThanOrEqualTo(102));
      }
    }
  });
  test('crescent interior has no seams between curved strips', () {
    final tiles = crescent();
    addTearDown(tiles.dispose);
    for (var degrees = -35; degrees <= 35; degrees++) {
      for (var radius = 80; radius <= 90; radius++) {
        final x = (180 + radius * math.cos(degrees * math.pi / 180)).floor();
        final y = (180 + radius * math.sin(degrees * math.pi / 180)).floor();
        expect(
          channelAt(tiles, x, y, 0),
          greaterThan(245),
          reason: 'fill at $x,$y',
        );
        expect(channelAt(tiles, x, y, 3), 255, reason: 'coverage at $x,$y');
      }
    }
  });
  test('crescent apex keeps the configured width around the authored axis', () {
    final tiles = crescent(radius: 36, width: 60);
    addTearDown(tiles.dispose);
    // The authored apex is (216,180): its 60 px body spans x=186..246.
    expect(channelAt(tiles, 188, 180, 0), greaterThan(245));
    expect(channelAt(tiles, 243, 180, 0), greaterThan(245));
    expect(channelAt(tiles, 250, 180, 3), 0);
  });
  for (final textureKind in ['none', 'opaque', 'bangs']) {
    test(
      'tight crescent inner apex is rounded instead of a cusp ($textureKind)',
      () async {
        if (textureKind == 'bangs') {
          await preloadBrushTexture('assets/brushes/bangs_01.png');
        }
        final tiles = crescent(
          width: 64,
          texture: textureKind == 'bangs'
              ? getCachedBrushTexture('assets/brushes/bangs_01.png')!
              : textureKind == 'opaque'
              ? (Uint8List(brushTextureSize * brushTextureSize * 4)
                  ..fillRange(0, brushTextureSize * brushTextureSize * 4, 255))
              : null,
          input: [
            for (var i = 0; i <= 120; i++)
              HairRibbonPoint(
                Offset(
                  180 + 130 * math.sin(i * math.pi / 60),
                  10.5 + i * 170 / 60,
                ),
                64,
                1,
              ),
          ],
        );
        addTearDown(tiles.dispose);
        int innerEdge(int y) => [
          for (var x = 50; x <= 110; x++)
            if (channelAt(tiles, x, y, 0) > 200 &&
                channelAt(tiles, x, y, 3) > 200)
              x,
        ].last;
        final apex = innerEdge(265);
        expect((innerEdge(259) - apex).abs(), lessThanOrEqualTo(1));
        expect((innerEdge(271) - apex).abs(), lessThanOrEqualTo(1));
      },
    );
  }
  test(
    'crescent body keeps an open rounded inside within the bend diameter',
    () {
      final tiles = crescent(radius: 50, width: 60);
      addTearDown(tiles.dispose);
      // A full ordinary start cap can cover the upper opening on this very
      // tight turn. The curved body below that cap must still remain open.
      expect(channelAt(tiles, 184, 196, 3), 0);
      expect(channelAt(tiles, 230, 180, 3), 255);
    },
  );
  test(
    'curved crescent body follows stroke angle after the ordinary start',
    () {
      final texture = Uint8List(brushTextureSize * brushTextureSize * 4);
      for (var y = 12; y < brushTextureSize - 12; y++) {
        for (var x = 26; x < brushTextureSize - 26; x++) {
          texture[(y * brushTextureSize + x) * 4 + 3] = 255;
        }
      }
      final original = crescent(texture: texture);
      final rotated = crescent(texture: texture, rotation: math.pi / 2);
      addTearDown(original.dispose);
      addTearDown(rotated.dispose);
      var changed = 0;
      // The fixed-angle start now intentionally matches the ordinary pen.
      // Compare the lower half, after the authored curve has turned 90 degrees.
      for (var y = 180; y < 360; y++) {
        for (var x = 0; x < 360; x++) {
          if ((channelAt(original, x, y, 3) - channelAt(rotated, 359 - y, x, 3))
                  .abs() >
              96) {
            changed++;
          }
        }
      }
      expect(changed, lessThan(30));
    },
  );
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
