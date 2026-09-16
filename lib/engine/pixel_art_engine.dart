import 'dart:typed_data';

import '../models/pixel_color_mode.dart';

/// Shared NIARIM pixel-art conversion contract.
///
/// Alpha is never averaged. Transparent outer edges therefore stay hard.
/// Horizontal/vertical internal boundaries stay hard. Diagonal opaque-color
/// boundaries may use a middle color only when the active color policy allows
/// it; callers can use the same converter for filters, brushes, and stamps.
class PixelArtEngine {
  const PixelArtEngine();

  Uint8List convert(
    Uint8List data,
    int width,
    int height, {
    int pixelSize = 8,
    PixelColorMode colorMode = PixelColorMode.count,
    int colorLevels = 6,
    List<int> paletteColors = const [],
  }) {
    final size = pixelSize.clamp(1, 64);
    final result = Uint8List.fromList(data);
    final cellsX = (width + size - 1) ~/ size;
    final cellsY = (height + size - 1) ~/ size;
    final colors = List<int?>.filled(cellsX * cellsY, null);

    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        var wr = 0, wg = 0, wb = 0, aw = 0;
        for (var dy = 0; dy < size && cy * size + dy < height; dy++) {
          for (var dx = 0; dx < size && cx * size + dx < width; dx++) {
            final i = (((cy * size + dy) * width) + cx * size + dx) * 4;
            final a = data[i + 3];
            if (a == 0) continue;
            wr += data[i] * a;
            wg += data[i + 1] * a;
            wb += data[i + 2] * a;
            aw += a;
          }
        }
        if (aw == 0) continue;
        colors[cy * cellsX + cx] = _constrainColor(
          (wr / aw).round(),
          (wg / aw).round(),
          (wb / aw).round(),
          colorMode,
          colorLevels,
          paletteColors,
        );
      }
    }

    // Only a true diagonal A/B crossing is eligible for a middle color.
    // A transparent cell in the 2x2 neighborhood blocks smoothing, and an
    // ordinary horizontal/vertical A/B boundary does not match this pattern.
    for (var cy = 0; cy + 1 < cellsY; cy++) {
      for (var cx = 0; cx + 1 < cellsX; cx++) {
        final tl = colors[cy * cellsX + cx];
        final tr = colors[cy * cellsX + cx + 1];
        final bl = colors[(cy + 1) * cellsX + cx];
        final br = colors[(cy + 1) * cellsX + cx + 1];
        if (tl == null || tr == null || bl == null || br == null) continue;
        if (tl == br && tr == bl && tl != tr) {
          final middle = _middleColor(tl, tr, colorMode, colorLevels, paletteColors);
          if (middle != null) {
            // Replace one of the two diagonal corner cells only. This softens
            // the internal stair-step without creating sub-pixel alpha or
            // widening the outer silhouette.
            colors[cy * cellsX + cx + 1] = middle;
          }
        }
      }
    }

    for (var cy = 0; cy < cellsY; cy++) {
      for (var cx = 0; cx < cellsX; cx++) {
        final color = colors[cy * cellsX + cx];
        if (color == null) continue;
        final r = (color >> 16) & 0xff;
        final g = (color >> 8) & 0xff;
        final b = color & 0xff;
        for (var dy = 0; dy < size && cy * size + dy < height; dy++) {
          for (var dx = 0; dx < size && cx * size + dx < width; dx++) {
            final i = (((cy * size + dy) * width) + cx * size + dx) * 4;
            if (data[i + 3] == 0) continue;
            result[i] = r;
            result[i + 1] = g;
            result[i + 2] = b;
            // Preserve source alpha exactly.
          }
        }
      }
    }
    return result;
  }

  int _constrainColor(int r, int g, int b, PixelColorMode mode, int levels, List<int> palette) {
    if ((mode == PixelColorMode.explicit || mode == PixelColorMode.palette) && palette.isNotEmpty) {
      return _nearest(r, g, b, palette);
    }
    if (mode == PixelColorMode.count) {
      final step = (256 / levels.clamp(1, 256)).round().clamp(1, 256);
      r = ((r / step).round() * step).clamp(0, 255);
      g = ((g / step).round() * step).clamp(0, 255);
      b = ((b / step).round() * step).clamp(0, 255);
    }
    return 0xff000000 | (r << 16) | (g << 8) | b;
  }

  int? _middleColor(int a, int b, PixelColorMode mode, int levels, List<int> palette) {
    final r = (((a >> 16) & 0xff) + ((b >> 16) & 0xff)) ~/ 2;
    final g = (((a >> 8) & 0xff) + ((b >> 8) & 0xff)) ~/ 2;
    final bl = ((a & 0xff) + (b & 0xff)) ~/ 2;
    if (mode == PixelColorMode.explicit || mode == PixelColorMode.palette) {
      if (palette.isEmpty) return null;
      final candidate = _nearest(r, g, bl, palette);
      if (candidate == a || candidate == b) return null;
      return candidate;
    }
    return _constrainColor(r, g, bl, mode, levels, palette);
  }

  int _nearest(int r, int g, int b, List<int> palette) {
    var best = palette.first;
    var bestDistance = 1 << 30;
    for (final color in palette) {
      final dr = r - ((color >> 16) & 0xff);
      final dg = g - ((color >> 8) & 0xff);
      final db = b - (color & 0xff);
      final d = dr * dr + dg * dg + db * db;
      if (d < bestDistance) {
        bestDistance = d;
        best = color;
      }
    }
    return 0xff000000 | (best & 0x00ffffff);
  }
}
