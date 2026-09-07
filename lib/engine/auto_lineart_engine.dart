import 'dart:math' as math;
import 'dart:typed_data';

/// A lightweight vector-like representation used only while the Auto Line Art
/// filter is being previewed/applied. It is never persisted as a project layer.
class AutoLineartPoint {
  final double x;
  final double y;
  const AutoLineartPoint(this.x, this.y);
}

class AutoLineartPath {
  final List<AutoLineartPoint> points;
  final bool startIsJunction;
  final bool endIsJunction;
  final double persistence;

  const AutoLineartPath({
    required this.points,
    required this.startIsJunction,
    required this.endIsJunction,
    required this.persistence,
  });
}

class AutoLineartGraph {
  final int width;
  final int height;
  final List<AutoLineartPath> paths;

  const AutoLineartGraph({
    required this.width,
    required this.height,
    required this.paths,
  });
}

/// Raster rough-line -> temporary centerline graph -> antialiased raster engine.
///
/// The graph is intentionally transient. NIARIM stays raster-only: the final
/// output is always a normal raster layer. Keeping the centerline as paths only
/// during preview makes width/taper/smoothing adjustments cheap and avoids
/// repeatedly skeletonizing the same rough artwork.
class AutoLineartEngine {
  AutoLineartEngine._();

  static const _neighbors = <(int, int)>[
    (-1, -1),
    (0, -1),
    (1, -1),
    (-1, 0),
    (1, 0),
    (-1, 1),
    (0, 1),
    (1, 1),
  ];

  static AutoLineartGraph analyze(
    Uint8List rgba,
    int width,
    int height, {
    required double roughWidthPx,
  }) {
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
      return AutoLineartGraph(width: width, height: height, paths: const []);
    }

    final base = Uint8List(width * height);
    for (var i = 0; i < width * height; i++) {
      // Alpha is the least surprising definition of "rough shape" in a raster
      // drawing app. A low threshold keeps antialiased fringe connected.
      if (rgba[i * 4 + 3] >= 24) base[i] = 1;
    }

    final rough = roughWidthPx.clamp(2.0, 80.0);
    // Merge tiny holes/gaps inside a scribbly rough while avoiding a large
    // dilation that would incorrectly connect unrelated nearby strokes.
    final closeRadius = (rough * 0.10).round().clamp(0, 3);
    final cleaned = closeRadius == 0
        ? base
        : _erode(
            _dilate(base, width, height, closeRadius),
            width,
            height,
            closeRadius,
          );

    // Multi-scale topology sampling. The changing tolerance is deliberately
    // small: true main connections tend to survive, whereas accidental branch
    // contacts and raster nubs are unstable across these variants.
    final scaleRadius = math.max(1, (rough * 0.08).round());
    final masks = <Uint8List>[
      _erode(cleaned, width, height, scaleRadius),
      cleaned,
      _dilate(cleaned, width, height, scaleRadius),
    ];
    final skeletons = masks
        .map((m) => _thinZhangSuen(m, width, height))
        .toList(growable: false);
    final skeleton = skeletons[1];

    final rawPaths = _traceSkeleton(skeleton, width, height);
    if (rawPaths.isEmpty) {
      return AutoLineartGraph(width: width, height: height, paths: const []);
    }

    final minBranchLength = math.max(3.0, rough * 0.55);
    final paths = <AutoLineartPath>[];
    for (final raw in rawPaths) {
      if (raw.points.length < 2) continue;
      final length = _polylineLength(raw.points);
      final persistence = _pathPersistence(
        raw.points,
        skeletons,
        width,
        height,
        radius: math.max(1, scaleRadius + 1),
      );

      // Short, unstable terminal nubs are the common artifact from scribbly
      // roughs. Preserve short paths when both ends are topology anchors, so
      // compact X/Y intersections do not get destroyed.
      final anchoredBoth = raw.startIsJunction && raw.endIsJunction;
      final keep =
          anchoredBoth || length >= minBranchLength || persistence >= 0.67;
      if (!keep) continue;

      // Compress exact pixel stepping into direction-change points. Smoothing is
      // intentionally deferred to render(), so its slider does not rerun image
      // analysis.
      final simplified = _simplifyCollinear(raw.points);
      paths.add(
        AutoLineartPath(
          points: simplified,
          startIsJunction: raw.startIsJunction,
          endIsJunction: raw.endIsJunction,
          persistence: persistence,
        ),
      );
    }

    return AutoLineartGraph(width: width, height: height, paths: paths);
  }

  static Uint8List render(
    AutoLineartGraph graph,
    int width,
    int height, {
    required double outputWidthPx,
    required double taperLengthPx,
    required double smoothing,
  }) {
    final out = Uint8List(width * height * 4);
    if (graph.paths.isEmpty || width <= 0 || height <= 0) return out;

    final sx = graph.width == 0 ? 1.0 : width / graph.width;
    final sy = graph.height == 0 ? 1.0 : height / graph.height;
    final scale = (sx + sy) * 0.5;
    final lineWidth = math.max(0.75, outputWidthPx);
    final taper = math.max(0.0, taperLengthPx);
    final smooth = smoothing.clamp(0.0, 100.0);

    for (final path in graph.paths) {
      if (path.points.length < 2) continue;
      var points = path.points
          .map((p) => AutoLineartPoint(p.x * sx, p.y * sy))
          .toList(growable: false);
      points = _smoothPath(
        points,
        smooth,
        lockStart: path.startIsJunction,
        lockEnd: path.endIsJunction,
      );
      _rasterizePath(
        out,
        width,
        height,
        points,
        lineWidth: lineWidth,
        taperLength: taper * scale,
        taperStart: !path.startIsJunction,
        taperEnd: !path.endIsJunction,
      );
    }
    return out;
  }

  static List<AutoLineartPoint> _smoothPath(
    List<AutoLineartPoint> points,
    double smoothing, {
    required bool lockStart,
    required bool lockEnd,
  }) {
    if (smoothing <= 0 || points.length < 3) return points;

    // Resample first so smoothing behaves similarly on diagonal and axial
    // skeleton segments. Junction/end anchors remain exact endpoints.
    var work = _resample(points, 1.5);
    final passes = (1 + smoothing / 18).round().clamp(1, 7);
    final amount = (0.18 + smoothing / 100 * 0.32).clamp(0.18, 0.50);
    for (var pass = 0; pass < passes; pass++) {
      final next = List<AutoLineartPoint>.from(work);
      for (var i = 1; i < work.length - 1; i++) {
        final prev = work[i - 1];
        final cur = work[i];
        final after = work[i + 1];
        final targetX = (prev.x + after.x) * 0.5;
        final targetY = (prev.y + after.y) * 0.5;
        next[i] = AutoLineartPoint(
          cur.x + (targetX - cur.x) * amount,
          cur.y + (targetY - cur.y) * amount,
        );
      }
      if (lockStart) next[0] = points.first;
      if (lockEnd) next[next.length - 1] = points.last;
      work = next;
    }
    return work;
  }

  static List<AutoLineartPoint> _resample(
    List<AutoLineartPoint> points,
    double spacing,
  ) {
    if (points.length < 2) return points;
    final result = <AutoLineartPoint>[points.first];
    var carry = 0.0;
    for (var i = 1; i < points.length; i++) {
      var ax = points[i - 1].x;
      var ay = points[i - 1].y;
      final bx = points[i].x;
      final by = points[i].y;
      var dx = bx - ax;
      var dy = by - ay;
      var seg = math.sqrt(dx * dx + dy * dy);
      if (seg <= 1e-6) continue;
      while (carry + seg >= spacing) {
        final need = spacing - carry;
        final t = need / seg;
        ax += dx * t;
        ay += dy * t;
        result.add(AutoLineartPoint(ax, ay));
        dx = bx - ax;
        dy = by - ay;
        seg = math.sqrt(dx * dx + dy * dy);
        carry = 0;
        if (seg <= 1e-6) break;
      }
      carry += seg;
    }
    final last = points.last;
    if ((result.last.x - last.x).abs() > 1e-4 ||
        (result.last.y - last.y).abs() > 1e-4) {
      result.add(last);
    }
    return result;
  }

  static void _rasterizePath(
    Uint8List out,
    int width,
    int height,
    List<AutoLineartPoint> points, {
    required double lineWidth,
    required double taperLength,
    required bool taperStart,
    required bool taperEnd,
  }) {
    final cumulative = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      final dx = points[i].x - points[i - 1].x;
      final dy = points[i].y - points[i - 1].y;
      cumulative[i] = cumulative[i - 1] + math.sqrt(dx * dx + dy * dy);
    }
    final total = cumulative.last;
    if (total <= 1e-6) return;

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final segStart = cumulative[i - 1];
      final segEnd = cumulative[i];
      final maxRadius = lineWidth * 0.5 + 1.25;
      final minX = (math.min(a.x, b.x) - maxRadius).floor().clamp(0, width - 1);
      final maxX = (math.max(a.x, b.x) + maxRadius).ceil().clamp(0, width - 1);
      final minY = (math.min(a.y, b.y) - maxRadius).floor().clamp(
        0,
        height - 1,
      );
      final maxY = (math.max(a.y, b.y) + maxRadius).ceil().clamp(0, height - 1);
      final vx = b.x - a.x;
      final vy = b.y - a.y;
      final vv = vx * vx + vy * vy;
      if (vv <= 1e-8) continue;

      for (var y = minY; y <= maxY; y++) {
        for (var x = minX; x <= maxX; x++) {
          final px = x + 0.5;
          final py = y + 0.5;
          final t = (((px - a.x) * vx + (py - a.y) * vy) / vv).clamp(0.0, 1.0);
          final qx = a.x + vx * t;
          final qy = a.y + vy * t;
          final dx = px - qx;
          final dy = py - qy;
          final dist = math.sqrt(dx * dx + dy * dy);
          final along = segStart + (segEnd - segStart) * t;

          var widthFactor = 1.0;
          if (taperLength > 0) {
            if (taperStart) {
              widthFactor = math.min(
                widthFactor,
                (along / taperLength).clamp(0.08, 1.0),
              );
            }
            if (taperEnd) {
              widthFactor = math.min(
                widthFactor,
                ((total - along) / taperLength).clamp(0.08, 1.0),
              );
            }
          }
          final radius = math.max(0.35, lineWidth * widthFactor * 0.5);
          // Analytic one-pixel coverage band = antialiasing. No user toggle:
          // Auto Line Art is always antialiased by design.
          final coverage = (radius + 0.5 - dist).clamp(0.0, 1.0);
          if (coverage <= 0) continue;
          final index = (y * width + x) * 4;
          final alpha = (coverage * 255).round();
          if (alpha > out[index + 3]) {
            out[index] = 0;
            out[index + 1] = 0;
            out[index + 2] = 0;
            out[index + 3] = alpha;
          }
        }
      }
    }
  }

  static double _polylineLength(List<AutoLineartPoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      final dx = points[i].x - points[i - 1].x;
      final dy = points[i].y - points[i - 1].y;
      total += math.sqrt(dx * dx + dy * dy);
    }
    return total;
  }

  static double _pathPersistence(
    List<AutoLineartPoint> points,
    List<Uint8List> skeletons,
    int width,
    int height, {
    required int radius,
  }) {
    if (points.isEmpty || skeletons.isEmpty) return 0;
    var supported = 0;
    var total = 0;
    // Sampling every other point is enough and substantially cheaper on long
    // strokes while still seeing local unstable contacts.
    for (var pi = 0; pi < points.length; pi += 2) {
      final p = points[pi];
      for (final skeleton in skeletons) {
        total++;
        if (_hasPixelNear(
          skeleton,
          width,
          height,
          p.x.round(),
          p.y.round(),
          radius,
        )) {
          supported++;
        }
      }
    }
    return total == 0 ? 0 : supported / total;
  }

  static bool _hasPixelNear(
    Uint8List mask,
    int width,
    int height,
    int x,
    int y,
    int radius,
  ) {
    for (var oy = -radius; oy <= radius; oy++) {
      for (var ox = -radius; ox <= radius; ox++) {
        if (ox * ox + oy * oy > radius * radius) continue;
        final nx = x + ox;
        final ny = y + oy;
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        if (mask[ny * width + nx] != 0) return true;
      }
    }
    return false;
  }

  static List<AutoLineartPoint> _simplifyCollinear(
    List<AutoLineartPoint> points,
  ) {
    if (points.length < 3) return points;
    final out = <AutoLineartPoint>[points.first];
    var prevDx = 0;
    var prevDy = 0;
    for (var i = 1; i < points.length; i++) {
      final dx = (points[i].x - points[i - 1].x).sign.toInt();
      final dy = (points[i].y - points[i - 1].y).sign.toInt();
      if (i == 1) {
        prevDx = dx;
        prevDy = dy;
      } else if (dx != prevDx || dy != prevDy) {
        out.add(points[i - 1]);
        prevDx = dx;
        prevDy = dy;
      }
    }
    out.add(points.last);
    return out;
  }

  static List<_RawPath> _traceSkeleton(
    Uint8List skeleton,
    int width,
    int height,
  ) {
    int degree(int index) {
      final x = index % width;
      final y = index ~/ width;
      var count = 0;
      for (final (dx, dy) in _neighbors) {
        final nx = x + dx;
        final ny = y + dy;
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        if (skeleton[ny * width + nx] != 0) count++;
      }
      return count;
    }

    final degrees = Int8List(width * height);
    final anchors = <int>{};
    for (var i = 0; i < skeleton.length; i++) {
      if (skeleton[i] == 0) continue;
      final d = degree(i);
      degrees[i] = d;
      if (d != 2) anchors.add(i);
    }

    // A closed loop has no degree!=2 pixel. Seed one point so the loop is still
    // represented instead of disappearing.
    if (anchors.isEmpty) {
      final first = skeleton.indexWhere((v) => v != 0);
      if (first >= 0) anchors.add(first);
    }

    final usedEdges = <int>{};
    int edgeKey(int a, int b) {
      final lo = math.min(a, b);
      final hi = math.max(a, b);
      return lo * (width * height) + hi;
    }

    List<int> neighborsOf(int index) {
      final x = index % width;
      final y = index ~/ width;
      final result = <int>[];
      for (final (dx, dy) in _neighbors) {
        final nx = x + dx;
        final ny = y + dy;
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        final ni = ny * width + nx;
        if (skeleton[ni] != 0) result.add(ni);
      }
      return result;
    }

    final paths = <_RawPath>[];
    for (final start in anchors.toList()) {
      for (final first in neighborsOf(start)) {
        final ek = edgeKey(start, first);
        if (usedEdges.contains(ek)) continue;
        usedEdges.add(ek);
        final chain = <int>[start, first];
        var previous = start;
        var current = first;
        while (!anchors.contains(current)) {
          final options = neighborsOf(
            current,
          ).where((n) => n != previous).toList();
          if (options.isEmpty) break;
          // Degree-2 pixels should have one onward neighbor. If raster topology
          // produces more, choose the direction that continues most straight.
          var next = options.first;
          if (options.length > 1) {
            final px = previous % width;
            final py = previous ~/ width;
            final cx = current % width;
            final cy = current ~/ width;
            final inX = cx - px;
            final inY = cy - py;
            var bestDot = -999.0;
            for (final candidate in options) {
              final nx = candidate % width;
              final ny = candidate ~/ width;
              final outX = nx - cx;
              final outY = ny - cy;
              final dot = inX * outX + inY * outY.toDouble();
              if (dot > bestDot) {
                bestDot = dot;
                next = candidate;
              }
            }
          }
          final nextEdge = edgeKey(current, next);
          if (usedEdges.contains(nextEdge)) break;
          usedEdges.add(nextEdge);
          previous = current;
          current = next;
          chain.add(current);
          if (chain.length > skeleton.length) break;
        }
        if (chain.length >= 2) {
          paths.add(
            _RawPath(
              points: chain
                  .map(
                    (i) =>
                        AutoLineartPoint((i % width) + 0.5, (i ~/ width) + 0.5),
                  )
                  .toList(growable: false),
              startIsJunction: degrees[start] >= 3,
              endIsJunction: degrees[current] >= 3,
            ),
          );
        }
      }
    }
    return paths;
  }

  static Uint8List _dilate(Uint8List input, int width, int height, int radius) {
    if (radius <= 0) return Uint8List.fromList(input);
    final out = Uint8List(input.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var on = false;
        for (var oy = -radius; oy <= radius && !on; oy++) {
          for (var ox = -radius; ox <= radius; ox++) {
            if (ox * ox + oy * oy > radius * radius) continue;
            final nx = x + ox;
            final ny = y + oy;
            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
            if (input[ny * width + nx] != 0) {
              on = true;
              break;
            }
          }
        }
        if (on) out[y * width + x] = 1;
      }
    }
    return out;
  }

  static Uint8List _erode(Uint8List input, int width, int height, int radius) {
    if (radius <= 0) return Uint8List.fromList(input);
    final out = Uint8List(input.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var on = true;
        for (var oy = -radius; oy <= radius && on; oy++) {
          for (var ox = -radius; ox <= radius; ox++) {
            if (ox * ox + oy * oy > radius * radius) continue;
            final nx = x + ox;
            final ny = y + oy;
            if (nx < 0 ||
                nx >= width ||
                ny < 0 ||
                ny >= height ||
                input[ny * width + nx] == 0) {
              on = false;
              break;
            }
          }
        }
        if (on) out[y * width + x] = 1;
      }
    }
    return out;
  }

  static Uint8List _thinZhangSuen(Uint8List input, int width, int height) {
    final img = Uint8List.fromList(input);
    if (width < 3 || height < 3) return img;
    var changed = true;
    var guard = 0;
    while (changed && guard++ < math.max(width, height)) {
      changed = false;
      for (var pass = 0; pass < 2; pass++) {
        final remove = <int>[];
        for (var y = 1; y < height - 1; y++) {
          for (var x = 1; x < width - 1; x++) {
            final i = y * width + x;
            if (img[i] == 0) continue;
            final p2 = img[(y - 1) * width + x];
            final p3 = img[(y - 1) * width + x + 1];
            final p4 = img[y * width + x + 1];
            final p5 = img[(y + 1) * width + x + 1];
            final p6 = img[(y + 1) * width + x];
            final p7 = img[(y + 1) * width + x - 1];
            final p8 = img[y * width + x - 1];
            final p9 = img[(y - 1) * width + x - 1];
            final ns = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9;
            if (ns < 2 || ns > 6) continue;
            final ring = [p2, p3, p4, p5, p6, p7, p8, p9, p2];
            var transitions = 0;
            for (var r = 0; r < 8; r++) {
              if (ring[r] == 0 && ring[r + 1] != 0) transitions++;
            }
            if (transitions != 1) continue;
            if (pass == 0) {
              if (p2 * p4 * p6 != 0 || p4 * p6 * p8 != 0) continue;
            } else {
              if (p2 * p4 * p8 != 0 || p2 * p6 * p8 != 0) continue;
            }
            remove.add(i);
          }
        }
        if (remove.isNotEmpty) {
          changed = true;
          for (final i in remove) {
            img[i] = 0;
          }
        }
      }
    }
    return img;
  }
}

class _RawPath {
  final List<AutoLineartPoint> points;
  final bool startIsJunction;
  final bool endIsJunction;

  const _RawPath({
    required this.points,
    required this.startIsJunction,
    required this.endIsJunction,
  });
}
