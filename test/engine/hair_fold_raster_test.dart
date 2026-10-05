import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/brush_texture_cache.dart';
import 'package:niarim/engine/hair_fold_raster.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_extension_defaults.dart';

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
      // The corner is exactly 90 degrees; keep it clear of the threshold.
      foldTriggerAngle: 60,
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
  int strength = 5,
  double triggerAngle = 90,
  double threshold = 0,
  double pressure = 1,
  bool continuous = false,
  int? steps,
  double opacity = 1,
  List<HairRibbonPoint>? input,
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
            width * pressure,
            opacity,
          ),
      ];
  HairFoldRaster(tiles, 'test').render(
    points: points,
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
      foldAngleRatio: (strength - 1) / 9,
      foldTriggerAngle: triggerAngle,
      foldCrescentDepthThreshold: threshold,
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
  test('short textured wave/curl tails do not keep an outline cap', () {
    final texture = Uint8List(brushTextureSize * brushTextureSize * 4)
      ..fillRange(0, brushTextureSize * brushTextureSize * 4, 255);
    for (final mode in HairFoldMode.values.where(
      (m) => m != HairFoldMode.crescent,
    )) {
      final tiles = TileManager(canvasWidth: 128, canvasHeight: 128);
      addTearDown(tiles.dispose);
      HairFoldRaster(tiles, 'test').render(
        points: const [
          HairRibbonPoint(Offset(60, 40), 60, 1),
          HairRibbonPoint(Offset(70, 40), 60, 1),
        ],
        brush: Brush(
          id: 'custom-tail',
          name: 'Tail',
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
          foldMode: mode,
        ),
        fillColor: const Color(0xffffffff),
        texture: texture,
        taperEnd: true,
      );
      expect(channelAt(tiles, 65, 40, 3), greaterThan(240), reason: mode.name);
      expect(channelAt(tiles, 70, 40, 3), lessThan(16), reason: mode.name);
    }
  });
  List<HairRibbonPoint> sine(double depth) => [
    for (var i = 0; i <= 120; i++)
      HairRibbonPoint(
        Offset(180 + depth * math.sin(i * math.pi / 60), 10.5 + i * 170 / 60),
        64,
        1,
      ),
  ];
  List<int> inkAt(TileManager tiles, int y, int left, int right) => [
    for (var x = left; x < right; x++)
      if (channelAt(tiles, x, y, 3) > 200 && channelAt(tiles, x, y, 0) > 200) x,
  ];
  test('crescent outer bends deeper and inner bends gentler than input', () {
    final tiles = crescent(width: 64, input: sine(130));
    addTearDown(tiles.dispose);
    final apex = inkAt(tiles, 265, 0, 150);
    for (final direction in [-1, 1]) {
      final flank = inkAt(tiles, 265 + direction * 30, 0, 150);
      final inputBend = 130 * (1 - math.cos(30 * math.pi / 170));
      expect(flank.first - apex.first, greaterThan(inputBend + 1));
      expect(flank.last - apex.last, lessThan(inputBend - 1));
    }
  });
  test('first crescent joins the ordinary lead without an inner hook', () {
    final tiles = crescent(width: 64, input: sine(130));
    addTearDown(tiles.dispose);
    var previous = inkAt(tiles, 79, 240, 340).first;
    for (var y = 80; y <= 95; y++) {
      final current = inkAt(tiles, y, 240, 340).first;
      expect((current - previous).abs(), lessThanOrEqualTo(3));
      previous = current;
    }
  });
  for (final strength in [1, 5, 10]) {
    test('shallow crescent keeps its inside bow at strength $strength', () {
      final tiles = crescent(
        width: 64,
        strength: strength,
        triggerAngle: 30,
        threshold: 0,
        input: sine(20),
      );
      addTearDown(tiles.dispose);
      final apex = inkAt(tiles, 265, 100, 220).last;
      expect(apex, lessThan(180));
      for (final y in [245, 285]) {
        expect(inkAt(tiles, y, 100, 220).last, greaterThanOrEqualTo(apex));
      }
    });
  }
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
  test('crescent apex keeps the pen width whatever the curve depth', () {
    for (final radius in [40.0, 80.0]) {
      final tiles = crescent(radius: radius, width: 30);
      addTearDown(tiles.dispose);
      final apex = 180 + radius;
      final fill = inkAt(
        tiles,
        180,
        (apex - 40).floor(),
        (apex + 40).ceil() + 1,
      );
      expect(fill.length, closeTo(30 - 2, 2));
      expect((fill.first + fill.last + 1) / 2, closeTo(apex, 1));
    }
  });
  test('crescent thickness follows pen size and pressure only', () {
    for (final settings in [(20.0, 1.0), (40.0, 1.0), (40.0, .5)]) {
      final tiles = crescent(
        radius: 80,
        width: settings.$1,
        pressure: settings.$2,
      );
      addTearDown(tiles.dispose);
      final fill = inkAt(tiles, 180, 200, 321);
      expect(fill.length, closeTo(settings.$1 * settings.$2 - 2, 2));
      expect((fill.first + fill.last + 1) / 2, closeTo(260, 1));
    }
  });
  bool hasInk(TileManager tiles) => tiles
      .exportAll()
      .values
      .expand((layer) => layer.values)
      .any((tile) => tile.any((value) => value != 0));
  test('a wave shallower than a thick pen stays an ordinary stroke', () {
    // The same 20 px wave: hidden inside a 64 px pen, visible on an 8 px pen.
    final thick = crescent(
      width: 64,
      triggerAngle: 30,
      threshold: BrushExtensionDefaults.foldCrescentDepthThreshold,
      input: sine(20),
    );
    addTearDown(thick.dispose);
    expect(hasInk(thick), isFalse);
    final thin = crescent(
      width: 8,
      triggerAngle: 30,
      threshold: BrushExtensionDefaults.foldCrescentDepthThreshold,
      input: [
        for (final p in sine(20)) HairRibbonPoint(p.position, 8, p.opacity),
      ],
    );
    addTearDown(thin.dispose);
    expect(hasInk(thin), isTrue);
    final lowered = crescent(
      width: 64,
      triggerAngle: 30,
      threshold: .25,
      input: sine(20),
    );
    addTearDown(lowered.dispose);
    expect(hasInk(lowered), isTrue);
  });
  for (final textureKind in ['none', 'opaque', 'bangs']) {
    test(
      'tight crescent inner apex is rounded instead of a cusp ($textureKind)',
      () async {
        if (textureKind == 'bangs') {
          await preloadBrushTexture(
            'assets/brushes/bangs_01.png',
            mode: BrushImageInkMode.light,
          );
        }
        final tiles = crescent(
          width: 64,
          texture: textureKind == 'bangs'
              ? getCachedBrushTexture(
                  'assets/brushes/bangs_01.png',
                  mode: BrushImageInkMode.light,
                )!
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
        // A curve-following inside has a rounded apex, rather than the
        // nearly flat apex-normal contour. Over 6 px its circle sagitta is
        // about 2 px; allow one pixel of texture/coverage quantization.
        for (final direction in [-1, 1]) {
          var previous = apex;
          for (var step = 1; step <= 6; step++) {
            final edge = innerEdge(265 + direction * step);
            expect(edge, greaterThanOrEqualTo(apex), reason: 'no inward hook');
            expect((edge - previous).abs(), lessThanOrEqualTo(1));
            expect(edge - apex, lessThanOrEqualTo(3));
            previous = edge;
          }
        }
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
