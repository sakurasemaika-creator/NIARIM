import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/aurora-hologram');

  setUpAll(() => out.createSync(recursive: true));

  test('texture palette identities remain distinct and visually useful', () {
    final signatures = <String>{};
    for (final preset in AuroraHologramPreset.values) {
      final stops = auroraHologramStops(preset);
      final signature = stops.join('|');
      expect(
        signatures.add(signature),
        isTrue,
        reason: '${preset.name} must not collapse into another preset palette',
      );

      // Texture presets are intentionally broader than hologram-only palettes
      // (for example metallic gold and silver), so do not require every preset
      // to contain pure white or a neon interference colour. Instead lock the
      // properties every usable gradient-map texture actually needs: complete
      // luminance coverage, ordered stops, valid RGB values, and visible tonal
      // variation across the palette.
      expect(stops.length, greaterThanOrEqualTo(5));
      expect(stops.first.$1, 0.0);
      expect(stops.last.$1, 1.0);

      var previousPosition = -1.0;
      var minLuminance = 255.0;
      var maxLuminance = 0.0;
      var minChannel = 255;
      var maxChannel = 0;
      for (final (position, r, g, b) in stops) {
        expect(position, inInclusiveRange(0.0, 1.0));
        expect(position, greaterThan(previousPosition));
        previousPosition = position;
        for (final channel in [r, g, b]) {
          expect(channel, inInclusiveRange(0, 255));
          if (channel < minChannel) minChannel = channel;
          if (channel > maxChannel) maxChannel = channel;
        }
        final luminance = r * 0.299 + g * 0.587 + b * 0.114;
        if (luminance < minLuminance) minLuminance = luminance;
        if (luminance > maxLuminance) maxLuminance = luminance;
      }
      expect(
        maxLuminance - minLuminance,
        greaterThan(25),
        reason: '${preset.name} needs enough tonal variation to read as texture',
      );
      expect(
        maxChannel - minChannel,
        greaterThan(35),
        reason: '${preset.name} needs visible channel range',
      );
    }
    expect(signatures, hasLength(AuroraHologramPreset.values.length));

    final aurora = _paletteStats(AuroraHologramPreset.aurora);
    final soap = _paletteStats(AuroraHologramPreset.soapBubble);
    final cyber = _paletteStats(AuroraHologramPreset.cyberNeon);
    final pastel = _paletteStats(AuroraHologramPreset.pastelDream);
    final sunset = _paletteStats(AuroraHologramPreset.sunsetGold);
    final silver = _paletteStats(AuroraHologramPreset.silverFoil);

    // Keep the defining identities of representative presets locked while
    // allowing material-specific palettes to use different highlight recipes.
    expect(aurora.avgB - aurora.avgR, greaterThan(45));
    expect(aurora.avgG - aurora.avgR, greaterThan(30));
    expect(soap.avgChroma, lessThan(65));
    expect(cyber.minChannel, lessThanOrEqualTo(10));
    expect(cyber.avgChroma, greaterThan(120));
    expect(pastel.avgChroma, lessThan(70));
    expect(sunset.avgR - sunset.avgB, greaterThan(45));
    expect(sunset.avgR - sunset.avgG, greaterThan(30));
    expect(silver.avgChroma, lessThan(25));
  });

  test(
    'wide grayscale canvas -> production filter route -> all presets -> PNG',
    () async {
      const width = 1024;
      const height = 320;
      final source = _buildWideGrayRamp(width, height);

      await _writeRgbaPng(
        source,
        width,
        height,
        File('${out.path}/00_input_grayscale.png'),
      );

      for (final preset in AuroraHologramPreset.values) {
        final filter = FilterDef(
          id: 'visual-audit-${preset.name}',
          name: 'Aurora Hologram ${preset.name}',
          kind: FilterKind.auroraHologram,
          strength: 100,
          hologramBrightness: 0,
          hologramSaturation: 0,
          hologramPreset: preset,
        );
        final result = applyDrawFilterInIsolate((
          source,
          width,
          height,
          filter,
          null,
        ));
        expect(
          result,
          isNot(equals(source)),
          reason:
              '${preset.name} must change the canvas pixels on the production route',
        );
        await _writeRgbaPng(
          result,
          width,
          height,
          File('${out.path}/preset_${preset.name}.png'),
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

({double avgR, double avgG, double avgB, double avgChroma, int minChannel})
_paletteStats(AuroraHologramPreset preset) {
  final stops = auroraHologramStops(preset);
  var sumR = 0.0, sumG = 0.0, sumB = 0.0, sumChroma = 0.0;
  var minChannel = 255;
  for (final (_, r, g, b) in stops) {
    sumR += r;
    sumG += g;
    sumB += b;
    final maxChannel = [r, g, b].reduce((a, c) => a > c ? a : c);
    final minRgb = [r, g, b].reduce((a, c) => a < c ? a : c);
    sumChroma += maxChannel - minRgb;
    if (minRgb < minChannel) minChannel = minRgb;
  }
  final count = stops.length;
  return (
    avgR: sumR / count,
    avgG: sumG / count,
    avgB: sumB / count,
    avgChroma: sumChroma / count,
    minChannel: minChannel,
  );
}

Uint8List _buildWideGrayRamp(int width, int height) {
  final data = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final base = (x / (width - 1) * 255).round();
      final band = ((y / (height - 1)) * 48 - 24).round();
      final shade = (base + band).clamp(0, 255);
      final i = (y * width + x) * 4;
      data[i] = shade;
      data[i + 1] = shade;
      data[i + 2] = shade;
      data[i + 3] = 255;
    }
  }
  return data;
}

Future<void> _writeRgbaPng(
  Uint8List rgba,
  int width,
  int height,
  File file,
) async {
  final image = await _imageFromRgba(rgba, width, height);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('PNG encoding returned null');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  } finally {
    image.dispose();
  }
}

Future<ui.Image> _imageFromRgba(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
