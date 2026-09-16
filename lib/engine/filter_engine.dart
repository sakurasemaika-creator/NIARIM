import 'dart:typed_data';

import '../models/filter_def.dart';
import '../models/pixel_color_mode.dart';
import 'filter_engine_legacy.dart' as legacy;
import 'pixel_art_engine.dart';

export 'filter_engine_legacy.dart' hide FilterEngine, applyDrawFilterInIsolate;

/// Compatibility facade that keeps the existing FilterEngine API while routing
/// true pixel-art conversion through the shared PixelArtEngine contract.
class FilterEngine extends legacy.FilterEngine {
  @override
  Uint8List applyPixelate(
    Uint8List data,
    int width,
    int height, {
    int mosaicSize = 8,
    PixelColorMode colorMode = PixelColorMode.count,
    int colorLevels = 6,
    List<int> paletteColors = const [],
  }) => const PixelArtEngine().convert(
    data,
    width,
    height,
    pixelSize: mosaicSize,
    colorMode: colorMode,
    colorLevels: colorLevels,
    paletteColors: paletteColors,
  );

  /// Classic mosaic: each block becomes its arithmetic mean RGBA.
  /// Pixel-art edge synthesis and palette reduction are intentionally not used
  /// here: mosaic remains a separate effect.
  @override
  Uint8List applyMosaic(
    Uint8List data,
    int width,
    int height,
    int mosaicSize,
  ) {
    if (width <= 0 || height <= 0 || data.length < width * height * 4) {
      return Uint8List.fromList(data);
    }
    final size = mosaicSize.clamp(1, 64);
    final out = Uint8List.fromList(data);
    for (var by = 0; by < height; by += size) {
      final yEnd = (by + size).clamp(0, height);
      for (var bx = 0; bx < width; bx += size) {
        final xEnd = (bx + size).clamp(0, width);
        var r = 0;
        var g = 0;
        var b = 0;
        var a = 0;
        var count = 0;
        for (var y = by; y < yEnd; y++) {
          for (var x = bx; x < xEnd; x++) {
            final i = (y * width + x) * 4;
            r += data[i];
            g += data[i + 1];
            b += data[i + 2];
            a += data[i + 3];
            count++;
          }
        }
        final rr = (r / count).round();
        final gg = (g / count).round();
        final bb = (b / count).round();
        final aa = (a / count).round();
        for (var y = by; y < yEnd; y++) {
          for (var x = bx; x < xEnd; x++) {
            final i = (y * width + x) * 4;
            out[i] = rr;
            out[i + 1] = gg;
            out[i + 2] = bb;
            out[i + 3] = aa;
          }
        }
      }
    }
    return out;
  }
}

/// Preserve the existing isolate entry point while ensuring draw-filter pixel
/// art and classic mosaic use their distinct conversion paths.
Uint8List applyDrawFilterInIsolate(
  (Uint8List data, int width, int height, FilterDef filter, Uint8List? maskData)
  args,
) {
  final (data, width, height, filter, _) = args;
  if (filter.kind == FilterKind.pixelate) {
    return FilterEngine().applyPixelate(
      data,
      width,
      height,
      mosaicSize: filter.strength.round().clamp(1, 64),
      colorMode: filter.pixelColorMode,
      colorLevels: filter.colorLevels,
      paletteColors: filter.pixelExplicitColors,
    );
  }
  if (filter.kind == FilterKind.mosaic) {
    return FilterEngine().applyMosaic(
      data,
      width,
      height,
      filter.strength.round().clamp(1, 64),
    );
  }
  return legacy.applyDrawFilterInIsolate(args);
}
