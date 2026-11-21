import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart' show Matrix4, MatrixUtils;

import 'premultiplied.dart';
import 'tile_manager.dart';

/// Original selected pixels and the rest of their layer. Each transform uses
/// this source, so a gesture outside the canvas cannot discard source pixels.
class SelectionTransformRaster {
  SelectionTransformRaster({
    required TileManager tiles,
    required String layerKey,
    required this.mask,
    required this.bounds,
  }) : width = tiles.canvasWidth,
       height = tiles.canvasHeight,
       base = Uint8List(tiles.canvasWidth * tiles.canvasHeight * 4),
       selected = Uint8List(tiles.canvasWidth * tiles.canvasHeight * 4) {
    const size = TileManager.tileSize;
    for (var ty = 0; ty < tiles.tilesY; ty++) {
      for (var tx = 0; tx < tiles.tilesX; tx++) {
        final tile = tiles.getTile(layerKey, tx, ty);
        if (tile == null) continue;
        final x0 = tx * size;
        final y0 = ty * size;
        final rows = (height - y0).clamp(0, size);
        final columns = (width - x0).clamp(0, size);
        for (var y = 0; y < rows; y++) {
          for (var x = 0; x < columns; x++) {
            final dst = (y + y0) * width + x + x0;
            final src = (y * size + x) * 4;
            final pixels = mask[dst] == 0 ? base : selected;
            pixels.setRange(dst * 4, dst * 4 + 4, tile, src);
          }
        }
      }
    }
  }

  final int width;
  final int height;
  final Uint8List mask;
  final Rect bounds;
  final Uint8List base;
  final Uint8List selected;

  ({Uint8List pixels, Uint8List mask}) render(Matrix4 matrix) {
    final pixels = Uint8List.fromList(base);
    final transformedMask = Uint8List(mask.length);
    final inverse = Matrix4.copy(matrix);
    if (inverse.invert() == 0) return (pixels: pixels, mask: transformedMask);
    final box = MatrixUtils.transformRect(matrix, bounds);
    final xMin = box.left.floor().clamp(0, width);
    final xMax = box.right.ceil().clamp(0, width);
    final yMin = box.top.floor().clamp(0, height);
    final yMax = box.bottom.ceil().clamp(0, height);
    final m = inverse.storage;
    for (var y = yMin; y < yMax; y++) {
      final sx = (y + 0.5) * m[4] + m[12];
      final sy = (y + 0.5) * m[5] + m[13];
      for (var x = xMin; x < xMax; x++) {
        final u = ((x + 0.5) * m[0] + sx).floor();
        final v = ((x + 0.5) * m[1] + sy).floor();
        if (u < 0 || u >= width || v < 0 || v >= height) continue;
        final src = v * width + u;
        if (mask[src] == 0) continue;
        final dst = y * width + x;
        transformedMask[dst] = 1;
        final alpha = selected[src * 4 + 3];
        if (alpha == 0) continue;
        for (var channel = 0; channel < 4; channel++) {
          final i = dst * 4 + channel;
          pixels[i] =
              selected[src * 4 + channel] +
              premultipliedChannel(pixels[i], 255 - alpha);
        }
      }
    }
    return (pixels: pixels, mask: transformedMask);
  }
}
