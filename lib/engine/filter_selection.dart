import 'dart:math' as math;
import 'dart:typed_data';

/// A selection's coverage, one byte per pixel: 0 is outside, 255 inside,
/// values between partly inside (a preview's scaled-down edge). The canvas's
/// own selection masks mark selected pixels with any non-zero value.
///
/// The canvas selection as coverage: every non-zero value becomes 255.
Uint8List selectionCoverage(Uint8List mask) {
  final out = Uint8List(mask.length);
  for (var i = 0; i < mask.length; i++) {
    if (mask[i] != 0) out[i] = 255;
  }
  return out;
}

/// Whether [coverage] selects anything at all.
bool selectsAnything(Uint8List? coverage) {
  if (coverage == null) return false;
  for (var i = 0; i < coverage.length; i++) {
    if (coverage[i] != 0) return true;
  }
  return false;
}

/// [coverage] (of [width]×[height]) at [outWidth]×[outHeight]: each output
/// pixel is the share of its source area that is selected, so a preview's
/// edge is as soft as the selection edge looks at that size.
Uint8List scaleSelectionCoverage(
  Uint8List coverage,
  int width,
  int height,
  int outWidth,
  int outHeight,
) {
  if (outWidth == width && outHeight == height) {
    return Uint8List.fromList(coverage);
  }
  final out = Uint8List(outWidth * outHeight);
  final sx = width / outWidth;
  final sy = height / outHeight;
  for (var oy = 0; oy < outHeight; oy++) {
    final y0 = (oy * sy).floor();
    final y1 = math.max(y0 + 1, ((oy + 1) * sy).ceil()).clamp(1, height);
    for (var ox = 0; ox < outWidth; ox++) {
      final x0 = (ox * sx).floor();
      final x1 = math.max(x0 + 1, ((ox + 1) * sx).ceil()).clamp(1, width);
      var sum = 0, count = 0;
      for (var y = y0; y < y1; y++) {
        final row = y * width;
        for (var x = x0; x < x1; x++) {
          sum += coverage[row + x];
          count++;
        }
      }
      out[oy * outWidth + ox] = count == 0 ? 0 : (sum / count).round();
    }
  }
  return out;
}

/// [filtered] where [coverage] selects, [original] where it does not, and a
/// mix of the two on a partly selected edge: a filter applied to the canvas
/// selection leaves everything outside it as it was. Both are premultiplied
/// RGBA of the same size; the mix of two valid pixels stays valid.
Uint8List restrictToSelection(
  Uint8List original,
  Uint8List filtered,
  Uint8List coverage,
) {
  final out = Uint8List(filtered.length);
  for (var p = 0; p < coverage.length; p++) {
    final i = p * 4;
    final w = coverage[p];
    if (w == 255) {
      out[i] = filtered[i];
      out[i + 1] = filtered[i + 1];
      out[i + 2] = filtered[i + 2];
      out[i + 3] = filtered[i + 3];
    } else if (w == 0) {
      out[i] = original[i];
      out[i + 1] = original[i + 1];
      out[i + 2] = original[i + 2];
      out[i + 3] = original[i + 3];
    } else {
      for (var c = 0; c < 4; c++) {
        out[i + c] = ((filtered[i + c] * w + original[i + c] * (255 - w)) / 255)
            .round();
      }
    }
  }
  return out;
}

/// [pixels] with everything outside [coverage] made transparent (a layer a
/// filter generates, such as an outline, only within the selection).
Uint8List clearOutsideSelection(Uint8List pixels, Uint8List coverage) {
  final out = Uint8List(pixels.length);
  for (var p = 0; p < coverage.length; p++) {
    final w = coverage[p];
    if (w == 0) continue;
    final i = p * 4;
    for (var c = 0; c < 4; c++) {
      out[i + c] = w == 255 ? pixels[i + c] : (pixels[i + c] * w / 255).round();
    }
  }
  return out;
}

/// [coverage] as the RGBA mask the glasses and sphere shading filters read
/// (their alpha is the coverage).
Uint8List coverageAsRgbaMask(Uint8List coverage) {
  final out = Uint8List(coverage.length * 4);
  for (var p = 0; p < coverage.length; p++) {
    final w = coverage[p];
    if (w == 0) continue;
    final i = p * 4;
    out[i] = w;
    out[i + 1] = w;
    out[i + 2] = w;
    out[i + 3] = w;
  }
  return out;
}

/// The alpha of an RGBA mask (a selection layer) as coverage.
Uint8List rgbaMaskCoverage(Uint8List rgba) {
  final out = Uint8List(rgba.length ~/ 4);
  for (var p = 0; p < out.length; p++) {
    out[p] = rgba[p * 4 + 3];
  }
  return out;
}

/// Paints (or with [erase], clears) a round brush of [radius] px along the
/// polyline [points] (x, y pairs in pixels) into [coverage] of [width]×
/// [height], in place. The brush edge is anti-aliased over one pixel.
void paintCoverageStroke(
  Uint8List coverage,
  int width,
  int height,
  List<(double, double)> points, {
  required double radius,
  bool erase = false,
}) {
  if (points.isEmpty) return;
  final r = math.max(0.5, radius);
  // Distance from (px, py) to the polyline, checked segment by segment
  // within each segment's bounding box.
  void stampSegment((double, double) a, (double, double) b) {
    final (ax, ay) = a;
    final (bx, by) = b;
    final x0 = (math.min(ax, bx) - r - 1).floor().clamp(0, width - 1);
    final x1 = (math.max(ax, bx) + r + 1).ceil().clamp(0, width - 1);
    final y0 = (math.min(ay, by) - r - 1).floor().clamp(0, height - 1);
    final y1 = (math.max(ay, by) + r + 1).ceil().clamp(0, height - 1);
    final dx = bx - ax, dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    for (var y = y0; y <= y1; y++) {
      final py = y + 0.5;
      for (var x = x0; x <= x1; x++) {
        final px = x + 0.5;
        var t = lengthSquared == 0
            ? 0.0
            : ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
        t = t.clamp(0.0, 1.0);
        final cx = ax + dx * t - px, cy = ay + dy * t - py;
        final d = math.sqrt(cx * cx + cy * cy);
        // The eraser clears fully as far as a pen of the same size paints
        // its soft edge, so erasing along a stroke leaves no faint outline.
        final cover = (r + (erase ? 1.5 : 0.5) - d).clamp(0.0, 1.0);
        if (cover <= 0) continue;
        final i = y * width + x;
        final v = (cover * 255).round();
        if (erase) {
          coverage[i] = math.min(coverage[i], 255 - v);
        } else {
          coverage[i] = math.max(coverage[i], v);
        }
      }
    }
  }

  if (points.length == 1) {
    stampSegment(points.first, points.first);
    return;
  }
  for (var i = 1; i < points.length; i++) {
    stampSegment(points[i - 1], points[i]);
  }
}
