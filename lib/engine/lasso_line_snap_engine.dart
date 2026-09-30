import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Snaps a coarse lasso path to nearby line-art pixels.
///
/// The raw lasso remains the user's guide. Each point searches only a small
/// neighbourhood around that guide and continuity is scored against the
/// previous snapped segment, so a perpendicular stroke crossing the intended
/// contour is strongly disfavoured instead of becoming a new path.
class LassoLineSnapEngine {
  const LassoLineSnapEngine();

  List<Offset> snapPath({
    required List<Offset> guide,
    required Uint8List rgba,
    required int width,
    required int height,
    double radius = 18,
  }) {
    if (guide.length < 2 || rgba.length < width * height * 4) return guide;
    final out = <Offset>[];
    Offset? previousDirection;
    for (var i = 0; i < guide.length; i++) {
      final raw = guide[i];
      final rawDirection = i == 0 ? null : _unit(raw - guide[i - 1]);
      final snapped = _bestCandidate(
        raw: raw,
        rgba: rgba,
        width: width,
        height: height,
        radius: radius,
        previous: out.isEmpty ? null : out.last,
        guideDirection: rawDirection,
        previousDirection: previousDirection,
      );
      final chosen = snapped ?? raw;
      if (out.isNotEmpty) {
        final d = _unit(chosen - out.last);
        if (d != null) previousDirection = d;
      }
      out.add(chosen);
    }
    return out;
  }

  Offset? _bestCandidate({
    required Offset raw,
    required Uint8List rgba,
    required int width,
    required int height,
    required double radius,
    Offset? previous,
    Offset? guideDirection,
    Offset? previousDirection,
  }) {
    final r = radius.ceil();
    final minX = math.max(0, raw.dx.floor() - r);
    final maxX = math.min(width - 1, raw.dx.ceil() + r);
    final minY = math.max(0, raw.dy.floor() - r);
    final maxY = math.min(height - 1, raw.dy.ceil() + r);
    Offset? best;
    var bestScore = double.infinity;
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        if (!_isInk(rgba, width, height, x, y)) continue;
        final p = Offset(x + .5, y + .5);
        final distance = (p - raw).distance;
        if (distance > radius) continue;
        var score = distance;
        if (previous != null) {
          final candidateDirection = _unit(p - previous);
          if (candidateDirection != null) {
            if (guideDirection != null) {
              score += (1 - _dotAbs(candidateDirection, guideDirection)) *
                  radius *
                  1.8;
            }
            if (previousDirection != null) {
              // Direction continuity is deliberately stronger than distance:
              // at a crossing this keeps following the current contour rather
              // than jumping onto the perpendicular line.
              score +=
                  (1 - _dot(candidateDirection, previousDirection).clamp(-1, 1)) *
                  radius *
                  2.4;
            }
          }
          final expectedStep = guideDirection == null ? 0.0 : radius * .35;
          if (expectedStep > 0) {
            score += ((p - previous).distance - expectedStep).abs() * .08;
          }
        }
        if (score < bestScore) {
          bestScore = score;
          best = p;
        }
      }
    }
    return best;
  }

  bool _isInk(Uint8List rgba, int width, int height, int x, int y) {
    final i = (y * width + x) * 4;
    final a = rgba[i + 3];
    if (a < 24) return false;
    // Transparent line-art layers are detected by alpha. On flattened opaque
    // references, also accept pixels visibly darker than near-white paper.
    if (a < 245) return true;
    final luma = rgba[i] * .2126 + rgba[i + 1] * .7152 + rgba[i + 2] * .0722;
    return luma < 235;
  }

  Offset? _unit(Offset v) {
    final length = v.distance;
    return length < .001 ? null : v / length;
  }

  double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  double _dotAbs(Offset a, Offset b) => _dot(a, b).abs();
}
