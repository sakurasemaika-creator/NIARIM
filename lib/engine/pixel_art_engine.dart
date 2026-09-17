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
    final rawColors = List<int?>.filled(cellsX * cellsY, null);

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
        rawColors[cy * cellsX + cx] = _rgb(
          (wr / aw).round(),
          (wg / aw).round(),
          (wb / aw).round(),
        );
      }
    }

    final countPalette = colorMode == PixelColorMode.count
        ? _buildCountPalette(rawColors.whereType<int>().toList(), colorLevels)
        : const <int>[];
    final colors = rawColors
        .map(
          (color) => color == null
              ? null
              : _constrainColor(
                  color,
                  colorMode,
                  paletteColors,
                  countPalette,
                ),
        )
        .toList();

    // Only a true diagonal A/B crossing is eligible for a middle color.
    // Transparency blocks smoothing. Horizontal/vertical A/B boundaries never
    // match this pattern, so they stay crisp.
    for (var cy = 0; cy + 1 < cellsY; cy++) {
      for (var cx = 0; cx + 1 < cellsX; cx++) {
        final tl = colors[cy * cellsX + cx];
        final tr = colors[cy * cellsX + cx + 1];
        final bl = colors[(cy + 1) * cellsX + cx];
        final br = colors[(cy + 1) * cellsX + cx + 1];
        if (tl == null || tr == null || bl == null || br == null) continue;
        if (tl == br && tr == bl && tl != tr) {
          final middle = _middleColor(
            tl,
            tr,
            colorMode,
            paletteColors,
            countPalette,
          );
          if (middle != null) colors[cy * cellsX + cx + 1] = middle;
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
            // Preserve source alpha exactly: never anti-alias against transparency.
          }
        }
      }
    }
    return result;
  }

  int _constrainColor(
    int color,
    PixelColorMode mode,
    List<int> explicitPalette,
    List<int> countPalette,
  ) {
    if (mode == PixelColorMode.count && countPalette.isNotEmpty) {
      return _nearestColor(color, countPalette);
    }
    if ((mode == PixelColorMode.explicit || mode == PixelColorMode.palette) &&
        explicitPalette.isNotEmpty) {
      return _nearestColor(color, explicitPalette);
    }
    return color;
  }

  int? _middleColor(
    int a,
    int b,
    PixelColorMode mode,
    List<int> explicitPalette,
    List<int> countPalette,
  ) {
    final middle = _rgb(
      ((((a >> 16) & 0xff) + ((b >> 16) & 0xff)) / 2).round(),
      ((((a >> 8) & 0xff) + ((b >> 8) & 0xff)) / 2).round(),
      (((a & 0xff) + (b & 0xff)) / 2).round(),
    );
    if (mode == PixelColorMode.count) {
      if (countPalette.isEmpty) return null;
      final candidate = _nearestColor(middle, countPalette);
      return candidate == a || candidate == b ? null : candidate;
    }
    if (mode == PixelColorMode.explicit || mode == PixelColorMode.palette) {
      if (explicitPalette.isEmpty) return null;
      final candidate = _nearestColor(middle, explicitPalette);
      return candidate == a || candidate == b ? null : candidate;
    }
    return middle;
  }

  List<int> _buildCountPalette(List<int> colors, int requestedCount) {
    if (colors.isEmpty) return const [];
    final unique = colors.toSet().toList()..sort();
    final count = requestedCount.clamp(1, 256);
    if (unique.length <= count) return unique;

    final palette = <int>[unique.first];
    while (palette.length < count) {
      var best = unique.first;
      var bestDistance = -1;
      for (final color in unique) {
        var nearestDistance = 1 << 30;
        for (final chosen in palette) {
          final d = _distance(color, chosen);
          if (d < nearestDistance) nearestDistance = d;
        }
        if (nearestDistance > bestDistance) {
          bestDistance = nearestDistance;
          best = color;
        }
      }
      if (palette.contains(best)) break;
      palette.add(best);
    }
    return palette;
  }

  int _nearestColor(int color, List<int> palette) {
    var best = palette.first;
    var bestDistance = 1 << 30;
    for (final candidate in palette) {
      final d = _distance(color, candidate);
      if (d < bestDistance) {
        bestDistance = d;
        best = candidate;
      }
    }
    return _rgb((best >> 16) & 0xff, (best >> 8) & 0xff, best & 0xff);
  }

  int _distance(int a, int b) {
    final dr = ((a >> 16) & 0xff) - ((b >> 16) & 0xff);
    final dg = ((a >> 8) & 0xff) - ((b >> 8) & 0xff);
    final db = (a & 0xff) - (b & 0xff);
    return dr * dr + dg * dg + db * db;
  }

  int _rgb(int r, int g, int b) =>
      0xff000000 | ((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff);
}
