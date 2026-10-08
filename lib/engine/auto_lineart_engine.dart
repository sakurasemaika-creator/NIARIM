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

  /// Size of the expensive topology-analysis region. This stays at zero for an
  /// empty graph and is mainly useful for diagnostics/tests; render coordinates
  /// always remain in the original canvas coordinate space.
  final int analysisWidth;
  final int analysisHeight;

  const AutoLineartGraph({
    required this.width,
    required this.height,
    required this.paths,
    this.analysisWidth = 0,
    this.analysisHeight = 0,
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

  /// Builds the binary rough-line mask used by the topology pass.
  ///
  /// Transparent drawing layers keep the historical alpha-based behaviour.
  /// Imported/scanned roughs are often flattened onto an opaque white (or dark)
  /// background, though; treating alpha as foreground in that case turns the
  /// whole canvas into one solid blob. When at least 90% of the canvas is
  /// opaque, estimate a uniform background colour from the image border and use
  /// colour/luminance contrast instead. If the border itself is highly varied,
  /// fall back to alpha rather than guessing a background for arbitrary artwork.
  static Uint8List _buildForegroundMask(Uint8List rgba, int width, int height) {
    final pixelCount = width * height;
    final alphaMask = Uint8List(pixelCount);
    var alphaForeground = 0;
    for (var i = 0; i < pixelCount; i++) {
      if (rgba[i * 4 + 3] >= 24) {
        alphaMask[i] = 1;
        alphaForeground++;
      }
    }

    if (alphaForeground < pixelCount * 0.90 || width < 2 || height < 2) {
      return alphaMask;
    }

    final borderR = <int>[];
    final borderG = <int>[];
    final borderB = <int>[];
    void addBorderPixel(int x, int y) {
      final offset = (y * width + x) * 4;
      if (rgba[offset + 3] < 24) return;
      borderR.add(rgba[offset]);
      borderG.add(rgba[offset + 1]);
      borderB.add(rgba[offset + 2]);
    }

    for (var x = 0; x < width; x++) {
      addBorderPixel(x, 0);
      addBorderPixel(x, height - 1);
    }
    for (var y = 1; y < height - 1; y++) {
      addBorderPixel(0, y);
      addBorderPixel(width - 1, y);
    }
    if (borderR.length < 4) return alphaMask;

    borderR.sort();
    borderG.sort();
    borderB.sort();
    final middle = borderR.length ~/ 2;
    final bgR = borderR[middle];
    final bgG = borderG[middle];
    final bgB = borderB[middle];

    // Do not apply a single-background heuristic to photos/painted borders.
    final borderDistances = <double>[];
    for (var i = 0; i < borderR.length; i++) {
      final dr = borderR[i] - bgR;
      final dg = borderG[i] - bgG;
      final db = borderB[i] - bgB;
      borderDistances.add(math.sqrt((dr * dr + dg * dg + db * db).toDouble()));
    }
    borderDistances.sort();
    final p75 = borderDistances[((borderDistances.length - 1) * 0.75).round()];
    if (p75 > 42) return alphaMask;

    final bgLuminance = bgR * 0.299 + bgG * 0.587 + bgB * 0.114;
    final contrastMask = Uint8List(pixelCount);
    const minColorDistanceSq = 18 * 18;
    const minLuminanceDistance = 14.0;
    for (var i = 0; i < pixelCount; i++) {
      final offset = i * 4;
      if (rgba[offset + 3] < 24) continue;
      final r = rgba[offset];
      final g = rgba[offset + 1];
      final b = rgba[offset + 2];
      final dr = r - bgR;
      final dg = g - bgG;
      final db = b - bgB;
      final colorDistanceSq = dr * dr + dg * dg + db * db;
      final luminance = r * 0.299 + g * 0.587 + b * 0.114;
      if (colorDistanceSq >= minColorDistanceSq ||
          (luminance - bgLuminance).abs() >= minLuminanceDistance) {
        contrastMask[i] = 1;
      }
    }
    return contrastMask;
  }

  /// Crops the binary foreground to the smallest useful work area. The expensive
  /// morphology/thinning passes run only inside this region; points are offset
  /// back into full-canvas coordinates before the graph is returned.
  static ({Uint8List mask, int width, int height, int offsetX, int offsetY})?
  _cropForegroundMask(
    Uint8List mask,
    int width,
    int height, {
    required int padding,
  }) {
    var minX = width;
    var minY = height;
    var maxX = -1;
    var maxY = -1;
    for (var y = 0; y < height; y++) {
      final row = y * width;
      for (var x = 0; x < width; x++) {
        if (mask[row + x] == 0) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < minX || maxY < minY) return null;

    minX = math.max(0, minX - padding);
    minY = math.max(0, minY - padding);
    maxX = math.min(width - 1, maxX + padding);
    maxY = math.min(height - 1, maxY + padding);
    final croppedWidth = maxX - minX + 1;
    final croppedHeight = maxY - minY + 1;

    if (croppedWidth == width && croppedHeight == height) {
      return (mask: mask, width: width, height: height, offsetX: 0, offsetY: 0);
    }

    final cropped = Uint8List(croppedWidth * croppedHeight);
    for (var y = 0; y < croppedHeight; y++) {
      final sourceStart = (minY + y) * width + minX;
      final targetStart = y * croppedWidth;
      cropped.setRange(
        targetStart,
        targetStart + croppedWidth,
        mask,
        sourceStart,
      );
    }
    return (
      mask: cropped,
      width: croppedWidth,
      height: croppedHeight,
      offsetX: minX,
      offsetY: minY,
    );
  }

  static AutoLineartGraph analyze(
    Uint8List rgba,
    int width,
    int height, {
    required double roughWidthPx,
  }) {
    if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
      return AutoLineartGraph(width: width, height: height, paths: const []);
    }

    // Fast path: ordinary NIARIM drawing layers are mostly transparent, so
    // _buildForegroundMask returns immediately after its alpha pass. Flattened
    // opaque roughs alone pay for border/background contrast estimation.
    final base = _buildForegroundMask(rgba, width, height);

    final rough = roughWidthPx.clamp(2.0, 80.0);

    // Thinning runs only inside the rough artwork's bounding box (plus a
    // margin, so ends and junctions are not cut by the crop's edge).
    final crop = _cropForegroundMask(
      base,
      width,
      height,
      padding: math.max(4, rough.ceil() + 2),
    );
    if (crop == null) {
      return AutoLineartGraph(width: width, height: height, paths: const []);
    }
    final localBase = crop.mask;
    final localWidth = crop.width;
    final localHeight = crop.height;

    // Only the specks of paper inside a stroke are filled, so a scribbled
    // stroke thins to one centre line instead of little loops. Two strokes
    // with paper between them stay two lines, however close they run.
    final cleaned = _fillPinholes(localBase, localWidth, localHeight, rough);

    // The centre line, without the short branches thinning sprouts at a
    // bump or a rounded end (anything shorter than the rough width off a
    // line).
    final skeleton = _thinZhangSuen(cleaned, localWidth, localHeight);
    _removeRedundantSteps(skeleton, localWidth, localHeight);
    _keepVanishedDots(cleaned, skeleton, localWidth, localHeight);
    _pruneBranches(skeleton, localWidth, localHeight, rough);
    // A branch taken off a junction can leave a corner pixel there.
    _removeRedundantSteps(skeleton, localWidth, localHeight);

    final rawPaths = _traceSkeleton(skeleton, localWidth, localHeight);
    if (rawPaths.isEmpty) {
      return AutoLineartGraph(
        width: width,
        height: height,
        paths: const [],
        analysisWidth: localWidth,
        analysisHeight: localHeight,
      );
    }

    final paths = <AutoLineartPath>[];
    for (final raw in rawPaths) {
      if (raw.points.length < 2) continue;
      const persistence = 1.0;

      // Compress exact pixel stepping into direction-change points. Smoothing is
      // intentionally deferred to render(), so its slider does not rerun image
      // analysis. Restore full-canvas coordinates only after all local topology
      // work is complete.
      final simplified = _simplifyCollinear(_restoreCorners(raw.points, rough))
          .map(
            (p) => AutoLineartPoint(
              (p.x + crop.offsetX).clamp(0.0, width - 1.0),
              (p.y + crop.offsetY).clamp(0.0, height - 1.0),
            ),
          )
          .toList(growable: false);
      paths.add(
        AutoLineartPath(
          points: simplified,
          startIsJunction: raw.startIsJunction,
          endIsJunction: raw.endIsJunction,
          persistence: persistence,
        ),
      );
    }

    return AutoLineartGraph(
      width: width,
      height: height,
      paths: paths,
      analysisWidth: localWidth,
      analysisHeight: localHeight,
    );
  }

  /// Converts an analyzed topology graph into the temporary editable control
  /// polygon used by the preview. [smoothingLevel] is discrete (0..10).
  /// Levels 1..9 remove roughly 10%..90% of each path's interior controls;
  /// level 10 is intentionally special and leaves only the two endpoints,
  /// making every path a straight segment. Junction/end anchors remain exact.
  static AutoLineartGraph prepareEditableGraph(
    AutoLineartGraph source, {
    required int smoothingLevel,
  }) {
    final level = smoothingLevel.clamp(0, 10);
    if (level == 0 || source.paths.isEmpty) return source;

    final paths = <AutoLineartPath>[];
    for (final path in source.paths) {
      final original = path.points;
      if (original.length <= 2) {
        paths.add(path);
        continue;
      }

      if (level == 10) {
        paths.add(
          AutoLineartPath(
            points: [original.first, original.last],
            startIsJunction: path.startIsJunction,
            endIsJunction: path.endIsJunction,
            persistence: path.persistence,
          ),
        );
        continue;
      }

      // Smooth along the line itself, a couple of pixels at a time, so that
      // only jitter is evened out: averaging the sparse control points
      // directly pulled a zigzag's corners towards each other and flattened
      // it. Each control point then takes the smoothed line's position at
      // the same distance along it.
      final along = <double>[0];
      for (var i = 1; i < original.length; i++) {
        along.add(along.last + _distance(original[i - 1], original[i]));
      }
      final dense = _resample(original, 2.0);
      final passes = math.max(1, level);
      final amount = 0.12 + level * 0.025;
      var smooth = dense;
      for (var pass = 0; pass < passes; pass++) {
        final next = List<AutoLineartPoint>.from(smooth);
        for (var i = 1; i < smooth.length - 1; i++) {
          final prev = smooth[i - 1];
          final cur = smooth[i];
          final after = smooth[i + 1];
          next[i] = AutoLineartPoint(
            cur.x + (((prev.x + after.x) * 0.5) - cur.x) * amount,
            cur.y + (((prev.y + after.y) * 0.5) - cur.y) * amount,
          );
        }
        smooth = next;
      }
      final work = <AutoLineartPoint>[
        original.first,
        for (var i = 1; i < original.length - 1; i++)
          _pointAlong(smooth, along[i] / along.last),
        original.last,
      ];

      // Keep the controls that shape the line most (a corner), dropping the
      // least telling first (Visvalingam), until the level's share is left.
      final interiorCount = original.length - 2;
      final keepInterior = (interiorCount * (1.0 - level / 10.0)).round().clamp(
        0,
        interiorCount,
      );
      final reduced = _keepMostTelling(
        work,
        keepInterior,
        maxDeviation: level * 0.6,
      );

      paths.add(
        AutoLineartPath(
          points: reduced,
          startIsJunction: path.startIsJunction,
          endIsJunction: path.endIsJunction,
          persistence: path.persistence,
        ),
      );
    }

    return AutoLineartGraph(
      width: source.width,
      height: source.height,
      paths: paths,
      analysisWidth: source.analysisWidth,
      analysisHeight: source.analysisHeight,
    );
  }

  /// Transfers manual control-point offsets from [edited] relative to [baseline]
  /// onto a newly prepared graph [target]. This is used when smoothing level or
  /// accepted rough width changes: persistent strokes retain the user's edits,
  /// newly detected strokes remain untouched, and removed/split strokes follow
  /// the fresh topology instead of resurrecting stale geometry.
  static AutoLineartGraph transferControlEdits(
    AutoLineartGraph baseline,
    AutoLineartGraph edited,
    AutoLineartGraph target,
  ) {
    if (baseline.paths.isEmpty ||
        edited.paths.isEmpty ||
        target.paths.isEmpty) {
      return target;
    }
    final diagonal = math.sqrt(
      target.width.toDouble() * target.width +
          target.height.toDouble() * target.height,
    );
    final maxMatch = math.max(8.0, diagonal * 0.18);
    final used = <int>{};
    final out = <AutoLineartPath>[];

    for (final targetPath in target.paths) {
      var bestIndex = -1;
      var bestCost = double.infinity;
      var bestReversed = false;
      for (var i = 0; i < baseline.paths.length; i++) {
        if (used.contains(i) || i >= edited.paths.length) continue;
        final basePath = baseline.paths[i];
        final editedPath = edited.paths[i];
        if (basePath.points.length < 2 ||
            editedPath.points.length < 2 ||
            targetPath.points.length < 2) {
          continue;
        }
        var topologyPenalty = 0.0;
        if (basePath.startIsJunction != targetPath.startIsJunction) {
          topologyPenalty += maxMatch * 0.35;
        }
        if (basePath.endIsJunction != targetPath.endIsJunction) {
          topologyPenalty += maxMatch * 0.35;
        }
        double distance(AutoLineartPoint a, AutoLineartPoint b) {
          final dx = a.x - b.x;
          final dy = a.y - b.y;
          return math.sqrt(dx * dx + dy * dy);
        }

        final direct =
            distance(basePath.points.first, targetPath.points.first) +
            distance(basePath.points.last, targetPath.points.last) +
            topologyPenalty;
        final reverse =
            distance(basePath.points.first, targetPath.points.last) +
            distance(basePath.points.last, targetPath.points.first) +
            topologyPenalty;
        final reversed = reverse < direct;
        final cost = reversed ? reverse : direct;
        if (cost < bestCost) {
          bestCost = cost;
          bestIndex = i;
          bestReversed = reversed;
        }
      }

      if (bestIndex < 0 || bestCost > maxMatch * 2) {
        out.add(targetPath);
        continue;
      }
      used.add(bestIndex);
      final basePath = baseline.paths[bestIndex];
      final editedPath = edited.paths[bestIndex];

      // Structural edits (segment insertion / point deletion) are intentional
      // user geometry, not merely offsets from the automatic baseline. Preserve
      // them verbatim across a smoothing/rough-width refresh instead of
      // dropping them because the point counts no longer match.
      if (basePath.points.length != editedPath.points.length) {
        out.add(
          AutoLineartPath(
            points: List<AutoLineartPoint>.unmodifiable(editedPath.points),
            startIsJunction: editedPath.startIsJunction,
            endIsJunction: editedPath.endIsJunction,
            persistence: editedPath.persistence,
          ),
        );
        continue;
      }

      final points = <AutoLineartPoint>[];
      var pathLength = 0.0;
      for (var i = 1; i < basePath.points.length; i++) {
        final dx = basePath.points[i].x - basePath.points[i - 1].x;
        final dy = basePath.points[i].y - basePath.points[i - 1].y;
        pathLength += math.sqrt(dx * dx + dy * dy);
      }
      final averageSpacing =
          pathLength / math.max(1, basePath.points.length - 1);
      // A manually moved point may itself disappear when smoothing is raised.
      // Spread that displacement over about 2.5 old control spacings so the
      // user's curve survives in neighboring retained controls instead of
      // snapping back to the automatic path.
      final influenceRadius = math.max(6.0, averageSpacing * 2.5);
      for (final tp in targetPath.points) {
        var offsetX = 0.0;
        var offsetY = 0.0;
        for (var bi = 0; bi < basePath.points.length; bi++) {
          final baseIndex = bestReversed ? basePath.points.length - 1 - bi : bi;
          final bp = basePath.points[baseIndex];
          final ep = editedPath.points[baseIndex];
          final editDx = ep.x - bp.x;
          final editDy = ep.y - bp.y;
          if (editDx.abs() < 1e-6 && editDy.abs() < 1e-6) continue;
          final dx = bp.x - tp.x;
          final dy = bp.y - tp.y;
          final distance = math.sqrt(dx * dx + dy * dy);
          if (distance >= influenceRadius) continue;
          final influence = 1.0 - distance / influenceRadius;
          offsetX += editDx * influence;
          offsetY += editDy * influence;
        }
        points.add(
          AutoLineartPoint(
            (tp.x + offsetX).clamp(
              0.0,
              math.max(0, target.width - 1).toDouble(),
            ),
            (tp.y + offsetY).clamp(
              0.0,
              math.max(0, target.height - 1).toDouble(),
            ),
          ),
        );
      }
      out.add(
        AutoLineartPath(
          points: points,
          startIsJunction: targetPath.startIsJunction,
          endIsJunction: targetPath.endIsJunction,
          persistence: targetPath.persistence,
        ),
      );
    }

    return AutoLineartGraph(
      width: target.width,
      height: target.height,
      paths: out,
      analysisWidth: target.analysisWidth,
      analysisHeight: target.analysisHeight,
    );
  }

  /// Moves exactly one preview control point. Each editable control is
  /// independent, including controls that happen to share coordinates.
  static AutoLineartGraph moveControlPoint(
    AutoLineartGraph source, {
    required int pathIndex,
    required int pointIndex,
    required AutoLineartPoint point,
  }) {
    if (pathIndex < 0 ||
        pathIndex >= source.paths.length ||
        pointIndex < 0 ||
        pointIndex >= source.paths[pathIndex].points.length) {
      return source;
    }
    final nextPoint = AutoLineartPoint(
      point.x.clamp(0.0, math.max(0, source.width - 1).toDouble()),
      point.y.clamp(0.0, math.max(0, source.height - 1).toDouble()),
    );
    final paths = <AutoLineartPath>[];
    for (var p = 0; p < source.paths.length; p++) {
      final oldPath = source.paths[p];
      final points = List<AutoLineartPoint>.from(oldPath.points);
      for (var i = 0; i < points.length; i++) {
        if (p == pathIndex && i == pointIndex) points[i] = nextPoint;
      }
      paths.add(
        AutoLineartPath(
          points: points,
          startIsJunction: oldPath.startIsJunction,
          endIsJunction: oldPath.endIsJunction,
          persistence: oldPath.persistence,
        ),
      );
    }
    return AutoLineartGraph(
      width: source.width,
      height: source.height,
      paths: paths,
      analysisWidth: source.analysisWidth,
      analysisHeight: source.analysisHeight,
    );
  }

  static int controlPointCount(AutoLineartGraph graph) =>
      graph.paths.fold<int>(0, (sum, path) => sum + path.points.length);

  static Uint8List render(
    AutoLineartGraph graph,
    int width,
    int height, {
    required double outputWidthPx,
    required double taperLengthPx,
    required double smoothing,
    int color = 0xFF000000,
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
      points = _curveThrough(points);
      _rasterizePath(
        out,
        width,
        height,
        points,
        lineWidth: lineWidth,
        taperLength: taper * scale,
        taperStart: !path.startIsJunction,
        taperEnd: !path.endIsJunction,
        color: color,
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

  /// Thinning a thick stroke cuts its sharp corners short (the corner of a
  /// thick V thins to a flat bottom a few pixels inside). Where the thinned
  /// line turns sharply between two straight arms, put the corner back where
  /// the arms, extended, meet. A curve, whose arms are not straight, and a
  /// gentle bend are left alone.
  static List<AutoLineartPoint> _restoreCorners(
    List<AutoLineartPoint> chain,
    double rough,
  ) {
    final arm = math.max(5, (rough * 0.8).round());
    final n = chain.length;
    if (n < arm * 4 + 1) return chain;
    double turnAt(int i) {
      final a = chain[i - arm], b = chain[i], c = chain[i + arm];
      final ux = b.x - a.x, uy = b.y - a.y, vx = c.x - b.x, vy = c.y - b.y;
      final lu = math.sqrt(ux * ux + uy * uy),
          lv = math.sqrt(vx * vx + vy * vy);
      if (lu == 0 || lv == 0) return 0;
      return math.acos(((ux * vx + uy * vy) / (lu * lv)).clamp(-1.0, 1.0));
    }

    final corners = <(int, double)>[];
    for (var i = arm * 2; i < n - arm * 2; i++) {
      final turn = turnAt(i);
      if (turn >= 1.2) corners.add((i, turn));
    }
    corners.sort((a, b) => b.$2.compareTo(a.$2));
    final taken = <int>[];
    final replacements = <int, AutoLineartPoint>{};
    for (final (i, _) in corners) {
      if (taken.any((t) => (t - i).abs() < arm * 2)) continue;
      // Each arm, from twice the arm length out to half of it, must be
      // straight to within a pixel.
      bool straight(int from, int to) {
        final a = chain[from], b = chain[to];
        final dx = b.x - a.x, dy = b.y - a.y;
        final length = math.sqrt(dx * dx + dy * dy);
        if (length < 1) return false;
        for (var k = math.min(from, to); k <= math.max(from, to); k++) {
          final p = chain[k];
          final off = ((p.x - a.x) * dy - (p.y - a.y) * dx).abs() / length;
          if (off > 1.0) return false;
        }
        return true;
      }

      final inFrom = i - arm * 2, inTo = i - arm ~/ 2;
      final outFrom = i + arm ~/ 2, outTo = i + arm * 2;
      if (!straight(inFrom, inTo) || !straight(outFrom, outTo)) continue;
      final a1 = chain[inFrom], a2 = chain[inTo];
      final b1 = chain[outTo], b2 = chain[outFrom];
      final d1x = a2.x - a1.x, d1y = a2.y - a1.y;
      final d2x = b2.x - b1.x, d2y = b2.y - b1.y;
      final denominator = d1x * d2y - d1y * d2x;
      if (denominator.abs() < 1e-6) continue;
      final t = ((b1.x - a1.x) * d2y - (b1.y - a1.y) * d2x) / denominator;
      final corner = AutoLineartPoint(a1.x + d1x * t, a1.y + d1y * t);
      final shift = _distance(corner, chain[i]);
      if (shift > rough * 0.75) continue;
      taken.add(i);
      replacements[i] = corner;
    }
    if (replacements.isEmpty) return chain;
    final out = <AutoLineartPoint>[];
    var k = 0;
    while (k < n) {
      final corner = replacements[k];
      if (corner == null) {
        // Inside a corner's span the points give way to the corner itself.
        final inSpan = replacements.keys.any(
          (c) => k > c - arm ~/ 2 && k < c + arm ~/ 2,
        );
        if (!inSpan) out.add(chain[k]);
        k++;
        continue;
      }
      out.add(corner);
      k++;
    }
    return out;
  }

  /// A smooth curve through the control points (Catmull-Rom), so a circle
  /// with few controls stays round instead of becoming a polygon; at a sharp
  /// corner the curve keeps the corner.
  static List<AutoLineartPoint> _curveThrough(List<AutoLineartPoint> points) {
    final n = points.length;
    if (n < 3) return points;
    final closed = _distance(points.first, points.last) < 1e-6;
    // The points either side of [k]; round the seam of a closed line.
    AutoLineartPoint before(int k) =>
        k > 0 ? points[k - 1] : (closed ? points[n - 2] : points[k]);
    AutoLineartPoint after(int k) =>
        k < n - 1 ? points[k + 1] : (closed ? points[1] : points[k]);
    bool corner(int k) {
      if (!closed && (k <= 0 || k >= n - 1)) return true;
      final a = before(k), b = points[k], c = after(k);
      final ux = b.x - a.x, uy = b.y - a.y, vx = c.x - b.x, vy = c.y - b.y;
      final lu = math.sqrt(ux * ux + uy * uy),
          lv = math.sqrt(vx * vx + vy * vy);
      if (lu == 0 || lv == 0) return true;
      return (ux * vx + uy * vy) / (lu * lv) < 0.5;
    }

    // Tangents per unit of the segment they shape: one-sided at a corner
    // and at the ends of an open line; elsewhere along the chord through the
    // neighbours, in proportion to this segment's share of the two, so a
    // short segment next to a long one does not overshoot.
    (double, double) smooth(int k, double share) {
      final a = before(k), c = after(k);
      return ((c.x - a.x) * share, (c.y - a.y) * share);
    }

    (double, double) tangentIn(int k) {
      final a = before(k), b = points[k];
      if (corner(k)) return (b.x - a.x, b.y - a.y);
      final lin = _distance(a, b), lout = _distance(b, after(k));
      return smooth(k, lin / (lin + lout));
    }

    (double, double) tangentOut(int k) {
      final b = points[k], c = after(k);
      if (corner(k)) return (c.x - b.x, c.y - b.y);
      final lin = _distance(before(k), b), lout = _distance(b, c);
      return smooth(k, lout / (lin + lout));
    }

    final out = <AutoLineartPoint>[points.first];
    for (var k = 0; k + 1 < n; k++) {
      final p0 = points[k], p1 = points[k + 1];
      final (m0x, m0y) = tangentOut(k);
      final (m1x, m1y) = tangentIn(k + 1);
      final steps = math.max(1, (_distance(p0, p1) / 1.5).ceil());
      for (var j = 1; j <= steps; j++) {
        final t = j / steps;
        final t2 = t * t, t3 = t2 * t;
        final h00 = 2 * t3 - 3 * t2 + 1;
        final h10 = t3 - 2 * t2 + t;
        final h01 = -2 * t3 + 3 * t2;
        final h11 = t3 - t2;
        out.add(
          AutoLineartPoint(
            h00 * p0.x + h10 * m0x + h01 * p1.x + h11 * m1x,
            h00 * p0.y + h10 * m0y + h01 * p1.y + h11 * m1y,
          ),
        );
      }
    }
    return out;
  }

  static double _distance(AutoLineartPoint a, AutoLineartPoint b) {
    final dx = b.x - a.x, dy = b.y - a.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// The point a fraction [t] (0..1) of the way along [points] by length.
  static AutoLineartPoint _pointAlong(List<AutoLineartPoint> points, double t) {
    if (points.length == 1) return points.first;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += _distance(points[i - 1], points[i]);
    }
    var target = t.clamp(0.0, 1.0) * total;
    for (var i = 1; i < points.length; i++) {
      final seg = _distance(points[i - 1], points[i]);
      if (target <= seg || i == points.length - 1) {
        final f = seg <= 1e-9 ? 0.0 : (target / seg).clamp(0.0, 1.0);
        final a = points[i - 1], b = points[i];
        return AutoLineartPoint(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f);
      }
      target -= seg;
    }
    return points.last;
  }

  /// [points] with at most [keepInterior] of its interior points left: the
  /// ones whose removal would change the line least go first (Visvalingam),
  /// but never one standing more than [maxDeviation] px off the line its
  /// neighbours make, so a corner (a zigzag's points) survives every level
  /// while jitter goes.
  static List<AutoLineartPoint> _keepMostTelling(
    List<AutoLineartPoint> points,
    int keepInterior, {
    required double maxDeviation,
  }) {
    final kept = List<AutoLineartPoint>.from(points);
    double deviation(int i) {
      final a = kept[i - 1], b = kept[i], c = kept[i + 1];
      final twiceArea = ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y))
          .abs();
      final base = _distance(a, c);
      return base < 1e-9 ? _distance(a, b) : twiceArea / base;
    }

    while (kept.length - 2 > keepInterior) {
      var weakest = -1;
      var weakestDeviation = double.infinity;
      for (var i = 1; i < kept.length - 1; i++) {
        final d = deviation(i);
        if (d < weakestDeviation) {
          weakestDeviation = d;
          weakest = i;
        }
      }
      if (weakest < 0 || weakestDeviation > maxDeviation) break;
      kept.removeAt(weakest);
    }
    // Two controls at the same place are one.
    final result = <AutoLineartPoint>[kept.first];
    for (var i = 1; i < kept.length; i++) {
      final p = kept[i];
      if (i < kept.length - 1 && p.x == result.last.x && p.y == result.last.y) {
        continue;
      }
      result.add(p);
    }
    return result;
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
    required int color,
  }) {
    final cumulative = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      final dx = points[i].x - points[i - 1].x;
      final dy = points[i].y - points[i - 1].y;
      cumulative[i] = cumulative[i - 1] + math.sqrt(dx * dx + dy * dy);
    }
    final total = cumulative.last;
    if (total <= 1e-6) return;
    // A short stroke (or a dot) keeps its full width in the middle instead
    // of tapering away to nothing.
    final tapered = math.min(taperLength, total / 3);

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
          if (tapered > 0) {
            if (taperStart) {
              widthFactor = math.min(
                widthFactor,
                (along / tapered).clamp(0.08, 1.0),
              );
            }
            if (taperEnd) {
              widthFactor = math.min(
                widthFactor,
                ((total - along) / tapered).clamp(0.08, 1.0),
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
          final colorAlpha = (color >> 24) & 0xFF;
          final finalAlpha = (alpha * colorAlpha / 255).round();
          if (finalAlpha > out[index + 3]) {
            // Layer pixels are premultiplied.
            out[index] = (((color >> 16) & 0xFF) * finalAlpha / 255).round();
            out[index + 1] = (((color >> 8) & 0xFF) * finalAlpha / 255).round();
            out[index + 2] = ((color & 0xFF) * finalAlpha / 255).round();
            out[index + 3] = finalAlpha;
          }
        }
      }
    }
  }

  /// Composes the reference rough at a reduced opacity under the generated
  /// line-art preview. The source layer itself is never mutated, so closing or
  /// cancelling the filter has no opacity side effects.
  static Uint8List composePreview(
    Uint8List rough,
    Uint8List line, {
    double roughOpacity = 0.4,
  }) {
    final length = math.min(rough.length, line.length);
    final out = Uint8List(length);
    final ro = roughOpacity.clamp(0.0, 1.0);
    for (var i = 0; i + 3 < length; i += 4) {
      final ra = rough[i + 3] / 255.0 * ro;
      final la = line[i + 3] / 255.0;
      final oa = la + ra * (1.0 - la);
      if (oa <= 1e-8) continue;
      double channel(int c) {
        final lr = line[i + c] / 255.0;
        final rr = rough[i + c] / 255.0;
        return (lr * la + rr * ra * (1.0 - la)) / oa;
      }

      out[i] = (channel(0) * 255).round().clamp(0, 255);
      out[i + 1] = (channel(1) * 255).round().clamp(0, 255);
      out[i + 2] = (channel(2) * 255).round().clamp(0, 255);
      out[i + 3] = (oa * 255).round().clamp(0, 255);
    }
    return out;
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
    bool on(int x, int y) =>
        x >= 0 &&
        y >= 0 &&
        x < width &&
        y < height &&
        skeleton[y * width + x] != 0;

    final degrees = Int8List(width * height);
    final anchors = <int>{};
    for (var i = 0; i < skeleton.length; i++) {
      if (skeleton[i] == 0) continue;
      final d = _branchDegree(skeleton, width, height, i % width, i ~/ width);
      degrees[i] = d;
      if (d != 2) anchors.add(i);
    }

    // A junction is often a small knot of junction pixels: treat each knot
    // as one point (its middle), so its pixels are not joined to each other
    // by a mesh of tiny paths, and the lines meeting there meet at one place.
    final knot = Int32List(width * height)..fillRange(0, width * height, -1);
    final knotMiddles = <AutoLineartPoint>[];
    for (final start in anchors) {
      if (degrees[start] < 3 || knot[start] != -1) continue;
      final id = knotMiddles.length;
      final members = <int>[start];
      knot[start] = id;
      for (var head = 0; head < members.length; head++) {
        final p = members[head];
        final x = p % width, y = p ~/ width;
        for (final (dx, dy) in _neighbors) {
          if (!on(x + dx, y + dy)) continue;
          final q = (y + dy) * width + x + dx;
          if (degrees[q] >= 3 && knot[q] == -1) {
            knot[q] = id;
            members.add(q);
          }
        }
      }
      var sx = 0.0, sy = 0.0;
      for (final p in members) {
        sx += p % width + 0.5;
        sy += p ~/ width + 0.5;
      }
      knotMiddles.add(
        AutoLineartPoint(sx / members.length, sy / members.length),
      );
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

    final traced = Uint8List(skeleton.length);
    final paths = <_RawPath>[];
    void trace(int start, int first, Set<int> stops) {
      final ek = edgeKey(start, first);
      if (usedEdges.contains(ek)) return;
      usedEdges.add(ek);
      final chain = <int>[start, first];
      var previous = start;
      var current = first;
      while (!stops.contains(current)) {
        // Step to the next pixel along the line: not back, and not to a
        // pixel touching where we came from (the corner of a diagonal step).
        final px = previous % width, py = previous ~/ width;
        final options = neighborsOf(current).where((n) {
          if (n == previous) return false;
          if (traced[n] != 0 && !stops.contains(n)) return false;
          final nx = n % width, ny = n ~/ width;
          return (nx - px).abs() > 1 ||
              (ny - py).abs() > 1 ||
              stops.contains(n);
        }).toList();
        if (options.isEmpty) break;
        // Prefer an edge-neighbour, then the straightest continuation.
        final cx = current % width, cy = current ~/ width;
        final inX = cx - px, inY = cy - py;
        var next = options.first;
        var best = -999.0;
        for (final candidate in options) {
          final nx = candidate % width, ny = candidate ~/ width;
          final outX = nx - cx, outY = ny - cy;
          var score = (inX * outX + inY * outY).toDouble();
          if (outX == 0 || outY == 0) score += .5;
          if (stops.contains(candidate)) score += 4;
          if (score > best) {
            best = score;
            next = candidate;
          }
        }
        final nextEdge = edgeKey(current, next);
        if (usedEdges.contains(nextEdge)) break;
        usedEdges.add(nextEdge);
        traced[current] = 1;
        previous = current;
        current = next;
        chain.add(current);
        if (chain.length > skeleton.length) break;
      }
      for (final i in chain) {
        traced[i] = 1;
      }
      // Within one knot: not a line of its own.
      final sameKnot = knot[start] != -1 && knot[start] == knot[current];
      if (chain.length >= 2 && !(sameKnot && start != current)) {
        final points = chain
            .map((i) => AutoLineartPoint((i % width) + 0.5, (i ~/ width) + 0.5))
            .toList();
        if (knot[start] != -1) points[0] = knotMiddles[knot[start]];
        if (knot[current] != -1) {
          points[points.length - 1] = knotMiddles[knot[current]];
        }
        paths.add(
          _RawPath(
            points: List.unmodifiable(points),
            startIsJunction: degrees[start] >= 3 || start == current,
            endIsJunction: degrees[current] >= 3 || start == current,
          ),
        );
      }
    }

    for (final start in anchors.toList()) {
      traced[start] = 1;
      final around = neighborsOf(start);
      if (around.isEmpty) {
        // A dot (an eye, say) thins to a single pixel: keep it as a dot.
        final x = (start % width) + 0.5, y = (start ~/ width) + 0.5;
        paths.add(
          _RawPath(
            points: [
              AutoLineartPoint(x - .25, y),
              AutoLineartPoint(x + .25, y),
            ],
            startIsJunction: true,
            endIsJunction: true,
          ),
        );
        continue;
      }
      for (final first in around) {
        if (traced[first] != 0 && !anchors.contains(first)) continue;
        trace(start, first, anchors);
      }
    }
    // Closed loops (a circle that touches nothing) have no end or junction
    // to start from: start anywhere on them and go round back to it.
    for (var i = 0; i < skeleton.length; i++) {
      if (skeleton[i] == 0 || traced[i] != 0) continue;
      traced[i] = 1;
      final around = neighborsOf(i);
      if (around.isEmpty) continue;
      trace(i, around.first, {i});
    }
    return paths;
  }

  /// [mask] with the specks of background inside a stroke filled in: an
  /// enclosed patch at most half the [rough] width across and a third of it
  /// square in area. A gap between two strokes (long, however narrow) or the
  /// inside of a small loop is left alone.
  static Uint8List _fillPinholes(
    Uint8List mask,
    int width,
    int height,
    double rough,
  ) {
    final out = Uint8List.fromList(mask);
    final n = width * height;
    final maxSide = math.max(2, (rough / 2).floor());
    final maxArea = math.max(4, (rough * rough / 9).floor());
    final seen = Uint8List(n);
    final patch = <int>[];
    for (var start = 0; start < n; start++) {
      if (mask[start] != 0 || seen[start] != 0) continue;
      patch
        ..clear()
        ..add(start);
      seen[start] = 1;
      var enclosed = true;
      var minX = width, minY = height, maxX = -1, maxY = -1;
      for (var head = 0; head < patch.length; head++) {
        final p = patch[head];
        final x = p % width, y = p ~/ width;
        if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
          enclosed = false;
        }
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
        for (final q in [p - 1, p + 1, p - width, p + width]) {
          if (q < 0 || q >= n) continue;
          if ((q - p).abs() == 1 && q ~/ width != y) continue;
          if (mask[q] != 0 || seen[q] != 0) continue;
          seen[q] = 1;
          patch.add(q);
        }
      }
      if (!enclosed || patch.length > maxArea) continue;
      if (maxX - minX + 1 > maxSide || maxY - minY + 1 > maxSide) continue;
      for (final p in patch) {
        out[p] = 1;
      }
    }
    return out;
  }

  /// Removes, from the thinned line [skeleton], the short branches that
  /// thinning sprouts off a line at a bump or a rounded end: a piece running
  /// from a free end to a junction in fewer than [rough] pixels. A short
  /// stroke on its own (no junction) stays.
  static void _pruneBranches(
    Uint8List skeleton,
    int width,
    int height,
    double rough,
  ) {
    bool on(int x, int y) =>
        x >= 0 &&
        y >= 0 &&
        x < width &&
        y < height &&
        skeleton[y * width + x] != 0;
    int lines(int x, int y) => _branchDegree(skeleton, width, height, x, y);

    for (var round = 0; round < 3; round++) {
      var removed = false;
      for (var p = 0; p < skeleton.length; p++) {
        if (skeleton[p] == 0) continue;
        final x0 = p % width, y0 = p ~/ width;
        if (lines(x0, y0) != 1) continue;
        // Walk from this free end along the line.
        final walked = <int>[p];
        var length = 0.0;
        var reachedJunction = false;
        var current = p;
        var previous = -1;
        while (length < rough) {
          final cx = current % width, cy = current ~/ width;
          var next = -1;
          var nextStraight = false;
          for (final (dx, dy) in _neighbors) {
            if (!on(cx + dx, cy + dy)) continue;
            final q = (cy + dy) * width + cx + dx;
            if (q == previous || walked.contains(q)) continue;
            // Prefer a side neighbour (the corner of a diagonal step is
            // the same line).
            final straight = dx == 0 || dy == 0;
            if (next == -1 || (straight && !nextStraight)) {
              next = q;
              nextStraight = straight;
            }
          }
          if (next == -1) break;
          final nx = next % width, ny = next ~/ width;
          length += (nx != cx && ny != cy) ? math.sqrt2 : 1.0;
          if (lines(nx, ny) >= 3) {
            reachedJunction = true;
            break;
          }
          walked.add(next);
          previous = current;
          current = next;
        }
        if (!reachedJunction) continue;
        for (final q in walked) {
          skeleton[q] = 0;
        }
        removed = true;
      }
      if (!removed) break;
    }
  }

  /// [_lineDegree] on a cleaned skeleton (no diagonal steps' extra corner
  /// pixels left): there a pixel touching three or more line pixels is a
  /// junction. Two lines joining at a shallow angle meet in a triangle of
  /// three pixels, each touching the other two and its own line: counted in
  /// groups, each seems to lie on one line, and the junction would be missed.
  static int _branchDegree(
    Uint8List skeleton,
    int width,
    int height,
    int x,
    int y,
  ) {
    final degree = _lineDegree(skeleton, width, height, x, y);
    if (degree != 2) return degree;
    var count = 0;
    for (final (dx, dy) in _neighbors) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
      if (skeleton[ny * width + nx] != 0) count++;
    }
    return count >= 3 ? 3 : 2;
  }

  /// How many lines leave pixel ([x], [y]) of the thinned [skeleton]: the
  /// groups of touching line pixels round it (a diagonal step's corner
  /// pixel touches both sides, so it is one line, not two). A pixel of a
  /// 2 x 2 knot, where thinning leaves two crossing lines, is a junction.
  static int _lineDegree(
    Uint8List skeleton,
    int width,
    int height,
    int x,
    int y,
  ) {
    bool on(int px, int py) =>
        px >= 0 &&
        py >= 0 &&
        px < width &&
        py < height &&
        skeleton[py * width + px] != 0;
    final around = <(int, int)>[
      for (final (dx, dy) in _neighbors)
        if (on(x + dx, y + dy)) (dx, dy),
    ];
    if (around.isEmpty) return 0;
    for (final (kx, ky) in const [(0, 0), (-1, 0), (0, -1), (-1, -1)]) {
      if (on(x + kx, y + ky) &&
          on(x + kx + 1, y + ky) &&
          on(x + kx, y + ky + 1) &&
          on(x + kx + 1, y + ky + 1)) {
        return 3;
      }
    }
    final group = List<int>.generate(around.length, (k) => k);
    int find(int k) {
      while (group[k] != k) {
        k = group[k] = group[group[k]];
      }
      return k;
    }

    for (var a = 0; a < around.length; a++) {
      for (var b = a + 1; b < around.length; b++) {
        final (ax, ay) = around[a];
        final (bx, by) = around[b];
        if ((ax - bx).abs() <= 1 && (ay - by).abs() <= 1) {
          group[find(a)] = find(b);
        }
      }
    }
    return {for (var k = 0; k < around.length; k++) find(k)}.length;
  }

  /// Thinning leaves the odd extra pixel at a diagonal step (the corner of
  /// an L of three pixels): take those out, so every pixel along a line
  /// touches just the one before and the one after.
  static void _removeRedundantSteps(Uint8List skeleton, int width, int height) {
    for (var pass = 0; pass < 8; pass++) {
      var removed = false;
      for (var p = 0; p < skeleton.length; p++) {
        if (skeleton[p] == 0) continue;
        final x = p % width, y = p ~/ width;
        var count = 0;
        for (final (dx, dy) in _neighbors) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          if (skeleton[ny * width + nx] != 0) count++;
        }
        if (count < 2 || count > 3) continue;
        if (_lineDegree(skeleton, width, height, x, y) != 1) continue;
        skeleton[p] = 0;
        removed = true;
      }
      if (!removed) break;
    }
  }

  /// Thinning can wipe out a small round blob (an eye drawn as a dot)
  /// entirely: give every blob of [mask] left without a centre pixel one, at
  /// the blob pixel nearest its middle, so it is drawn as a dot.
  static void _keepVanishedDots(
    Uint8List mask,
    Uint8List skeleton,
    int width,
    int height,
  ) {
    final seen = Uint8List(mask.length);
    final queue = <int>[];
    for (var start = 0; start < mask.length; start++) {
      if (mask[start] == 0 || seen[start] != 0) continue;
      queue
        ..clear()
        ..add(start);
      seen[start] = 1;
      var hasCentre = false;
      var sx = 0.0, sy = 0.0;
      for (var head = 0; head < queue.length; head++) {
        final p = queue[head];
        if (skeleton[p] != 0) hasCentre = true;
        final x = p % width, y = p ~/ width;
        sx += x;
        sy += y;
        for (final (dx, dy) in _neighbors) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final q = ny * width + nx;
          if (mask[q] == 0 || seen[q] != 0) continue;
          seen[q] = 1;
          queue.add(q);
        }
      }
      if (hasCentre) continue;
      final cx = sx / queue.length, cy = sy / queue.length;
      var best = queue.first;
      var bestDistance = double.infinity;
      for (final p in queue) {
        final dx = p % width - cx, dy = p ~/ width - cy;
        final d = dx * dx + dy * dy;
        if (d < bestDistance) {
          bestDistance = d;
          best = p;
        }
      }
      skeleton[best] = 1;
    }
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
