import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/pixel_color_mode.dart';

Uint8List _source(int w, int h) {
  final data = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final inside = x >= 2 && x < w - 2 && y >= 2 && y < h - 2;
      data[i] = inside ? (30 + x * 20).clamp(0, 255) : 0;
      data[i + 1] = inside ? (40 + y * 18).clamp(0, 255) : 0;
      data[i + 2] = inside ? (220 - x * 12).clamp(0, 255) : 0;
      data[i + 3] = inside ? 255 : 0;
    }
  }
  return data;
}

Uint8List _mask(int w, int h) {
  final data = Uint8List(w * h * 4);
  for (var y = 2; y < h - 2; y++) {
    for (var x = 2; x < w - 2; x++) {
      data[(y * w + x) * 4 + 3] = 255;
    }
  }
  return data;
}

bool _differs(Uint8List a, Uint8List b) {
  if (a.length != b.length) return true;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return true;
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all draw FilterKind values execute through production dispatcher', () {
    const allKinds = <FilterKind>[
      FilterKind.gaussianBlur,
      FilterKind.lensBlur,
      FilterKind.animeStyle,
      FilterKind.outline,
      FilterKind.toneCurve,
      FilterKind.levels,
      FilterKind.sharpen,
      FilterKind.unsharpMask,
      FilterKind.vignette,
      FilterKind.noise,
      FilterKind.retroAnime,
      FilterKind.crt,
      FilterKind.monochrome,
      FilterKind.colorAdjust,
      FilterKind.threshold,
      FilterKind.fisheye,
      FilterKind.chromaticAberration,
      FilterKind.lensDistortion,
      FilterKind.pixelate,
      FilterKind.auroraHologram,
      FilterKind.backgroundBlend,
      FilterKind.inkPool,
      FilterKind.autoLineart,
    ];
    expect(FilterKind.values, allKinds);

    const w = 12;
    const h = 12;
    final source = _source(w, h);
    final mask = _mask(w, h);

    for (final kind in allKinds) {
      final def = FilterDef(
        id: 'audit_${kind.name}',
        name: kind.name,
        kind: kind,
        strength: switch (kind) {
          FilterKind.gaussianBlur ||
          FilterKind.lensBlur ||
          FilterKind.unsharpMask => 2,
          FilterKind.pixelate => 3,
          FilterKind.lensDistortion => 45,
          _ => 60,
        },
        colorLevels: 4,
        edgeStrength: 1.2,
        inputBlack: 20,
        inputWhite: 220,
        outputBlack: 5,
        outputWhite: 245,
        toneCurvePreset: ToneCurvePreset.brighten,
        outlineColor: 0xFFFF0000,
        outlineWidth: 2,
        vignetteColor: 0xFF102040,
        caSaturation: 30,
        caBrightness: 20,
        caContrast: 25,
        monochromeColor: 0xFF80C0FF,
        thresholdValue: 110,
        lensCenterOffsetX: 0.5,
        lensCenterOffsetY: -0.5,
        pixelColorMode: PixelColorMode.explicit,
        pixelExplicitColors: const [
          0xFF000000,
          0xFFFFFFFF,
          0xFFFF0000,
          0xFF00FFFF,
        ],
        hologramBrightness: 10,
        hologramSaturation: 20,
        hologramPreset: AuroraHologramPreset.soapBubble,
        bgBlendColor: 0xFF708090,
        bgBlendDirection: 45,
        bgBlendLength: 3,
        bgBlendBlur: 2,
        // 墨溜まりは線の交差・鋭角部だけを太らせるフィルターなので、
        // 12x12の監査用入力（中央8x8の不透明矩形＝4つの直角がある）でも
        // 変化が出るよう、範囲と中央太さを入力サイズに合わせて小さく取る。
        inkPoolColor: 0xFF102030,
        inkPoolRange: 4,
        inkPoolCenterWidth: 2,
      );
      final out = applyDrawFilterInIsolate((source, w, h, def, mask));
      expect(out, hasLength(source.length), reason: '${kind.name} output size');
      expect(
        _differs(source, out),
        isTrue,
        reason:
            '${kind.name} should produce a visible pixel change for audit input',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('tone curve and hologram preset tables cover every preset', () {
    const tonePresets = <ToneCurvePreset>[
      ToneCurvePreset.linear,
      ToneCurvePreset.brighten,
      ToneCurvePreset.darken,
      ToneCurvePreset.highContrast,
      ToneCurvePreset.lowContrast,
      ToneCurvePreset.invert,
    ];
    expect(ToneCurvePreset.values, tonePresets);
    for (final preset in tonePresets) {
      final points = toneCurvePoints(preset);
      expect(points.length, greaterThanOrEqualTo(2), reason: preset.name);
      expect(points.first.dx, 0, reason: '${preset.name} starts at x=0');
      expect(points.last.dx, 1, reason: '${preset.name} ends at x=1');
    }

    const hologramPresets = <AuroraHologramPreset>[
      AuroraHologramPreset.aurora,
      AuroraHologramPreset.soapBubble,
      AuroraHologramPreset.cyberNeon,
      AuroraHologramPreset.pastelDream,
      AuroraHologramPreset.sunsetGold,
      AuroraHologramPreset.silverFoil,
    ];
    expect(AuroraHologramPreset.values, hologramPresets);
    for (final preset in hologramPresets) {
      final stops = auroraHologramStops(preset);
      expect(stops.length, greaterThanOrEqualTo(3), reason: preset.name);
      expect(stops.first.$1, 0.0, reason: '${preset.name} starts at 0');
      expect(stops.last.$1, 1.0, reason: '${preset.name} ends at 1');
      for (var i = 1; i < stops.length; i++) {
        expect(
          stops[i].$1,
          greaterThanOrEqualTo(stops[i - 1].$1),
          reason: '${preset.name} stops are ordered',
        );
      }
    }
  });

  test(
    'all pixel color modes quantize deterministically and preserve alpha',
    () {
      const modes = <PixelColorMode>[
        PixelColorMode.none,
        PixelColorMode.count,
        PixelColorMode.explicit,
        PixelColorMode.palette,
      ];
      expect(PixelColorMode.values, modes);
      final source = Uint8List.fromList([123, 80, 240, 255, 10, 20, 30, 0]);
      for (final mode in modes) {
        final out = quantizeColors(
          source,
          colorMode: mode,
          colorLevels: 4,
          paletteColors: const [0xFF000000, 0xFFFFFFFF, 0xFF8040FF],
        );
        expect(out, hasLength(source.length));
        expect(
          out[7],
          0,
          reason: '${mode.name} must preserve transparent alpha',
        );
        if (mode == PixelColorMode.none) {
          expect(out, orderedEquals(source));
        } else {
          expect(out[3], 255);
        }
      }
    },
  );
}
