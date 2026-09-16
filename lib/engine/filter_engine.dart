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
}

/// Preserve the existing isolate entry point while ensuring draw-filter pixel
/// art uses the same shared conversion path as direct FilterEngine callers.
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
  return legacy.applyDrawFilterInIsolate(args);
}
