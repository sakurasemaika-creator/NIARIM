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

  /// For a dot in the rough (an eye, say): its radius in canvas pixels. A
  /// dot is drawn filled at its own size rather than as a line; 0 for a
  /// line.
  final double dotRadius;

  const AutoLineartPath({
    required this.points,
    required this.startIsJunction,
    required this.endIsJunction,
    required this.persistence,
    this.dotRadius = 0,
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
    final skeleton = _thinGuoHall(
      _thinZhangSuen(cleaned, localWidth, localHeight),
      localWidth,
      localHeight,
    );
    _removeRedundantSteps(skeleton, localWidth, localHeight);
    _keepVanishedDots(cleaned, skeleton, localWidth, localHeight);
    _pruneBranches(skeleton, localWidth, localHeight, rough);
    // A branch taken off a junction can leave a corner pixel there.
    _removeRedundantSteps(skeleton, localWidth, localHeight);

    // How far each pixel of the ink is from the paper: the ink's width
    // along the lines, where they merge and overlap.
    final paper = _distanceToPaper(cleaned, localWidth, localHeight);
    final rawPaths = _resolveJunctions(
      _separateMerges(
        _traceSkeleton(skeleton, localWidth, localHeight),
        paper,
        localWidth,
        localHeight,
      ),
      paper,
      localWidth,
      localHeight,
    );
    if (rawPaths.isEmpty) {
      return AutoLineartGraph(
        width: width,
        height: height,
        paths: const [],
        analysisWidth: localWidth,
        analysisHeight: localHeight,
      );
    }

    // One line's width: the middle of the ink widths along the lines.
    final inkWidths = <double>[
      for (final raw in rawPaths)
        for (final p in raw.points)
          math.max(
            1.0,
            2 *
                    paper[p.y.floor().clamp(0, localHeight - 1) * localWidth +
                        p.x.floor().clamp(0, localWidth - 1)] -
                1,
          ),
    ]..sort();
    final lineWidth = inkWidths.isEmpty
        ? rough
        : inkWidths[inkWidths.length ~/ 2];

    final paths = <AutoLineartPath>[];
    for (final raw in rawPaths) {
      if (raw.points.length < 2) continue;
      const persistence = 1.0;

      // Corners put back, the line evened out between them, then thinned to
      // the points that keep its shape. The smoothing slider's own
      // smoothing is deferred to render(), so it does not rerun image
      // analysis. Restore full-canvas coordinates only after all local
      // topology work is complete.
      final cornered = _restoreCorners(raw.points, rough);
      final simplified =
          (raw.points.length <= 2
                  ? cornered
                  : _keepShape(_evenOut(cornered, lineWidth), .3))
              .map(
                (p) => AutoLineartPoint(
                  (p.x + crop.offsetX).clamp(0.0, width - 1.0),
                  (p.y + crop.offsetY).clamp(0.0, height - 1.0),
                ),
              )
              .toList(growable: false);
      // A dot (thinned to one pixel) keeps the size it has in the rough.
      final first = raw.points.first, last = raw.points.last;
      final isDot =
          raw.points.length == 2 &&
          raw.startIsJunction &&
          raw.endIsJunction &&
          _distance(first, last) < 1;
      final dotRadius = isDot
          ? math.max(
              .5,
              paper[first.y.floor().clamp(0, localHeight - 1) * localWidth +
                      ((first.x + last.x) / 2).floor().clamp(
                        0,
                        localWidth - 1,
                      )] -
                  .5,
            )
          : 0.0;
      paths.add(
        AutoLineartPath(
          points: simplified,
          startIsJunction: raw.startIsJunction,
          endIsJunction: raw.endIsJunction,
          persistence: persistence,
          dotRadius: dotRadius,
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
            dotRadius: path.dotRadius,
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
          dotRadius: path.dotRadius,
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
            dotRadius: editedPath.dotRadius,
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
          dotRadius: targetPath.dotRadius,
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
          dotRadius: oldPath.dotRadius,
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
      // A dot is filled at its own size, never thinner than the lines.
      final dot = path.dotRadius > 0;
      _rasterizePath(
        out,
        width,
        height,
        points,
        lineWidth: dot
            ? math.max(lineWidth, path.dotRadius * 2 * scale)
            : lineWidth,
        taperLength: dot ? 0 : taper * scale,
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

    // How far the arms turn, each taken away from the corner: the flat
    // bottom thinning leaves at a corner would make it look gentler.
    double armTurn(int i) {
      final a = chain[i - arm * 2], b = chain[i - arm ~/ 2];
      final c = chain[i + arm ~/ 2], d = chain[i + arm * 2];
      final ux = b.x - a.x, uy = b.y - a.y, vx = d.x - c.x, vy = d.y - c.y;
      final lu = math.sqrt(ux * ux + uy * uy),
          lv = math.sqrt(vx * vx + vy * vy);
      if (lu == 0 || lv == 0) return 0;
      return math.acos(((ux * vx + uy * vy) / (lu * lv)).clamp(-1.0, 1.0));
    }

    // The sharpest point of each corner first.
    final corners = <(int, double)>[];
    for (var i = arm * 2; i < n - arm * 2; i++) {
      if (armTurn(i) >= 1.2) corners.add((i, turnAt(i)));
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

  /// [points] with the wobble of a hand-drawn line, and the bends thinning
  /// leaves next to junctions and joins, evened out: each point moved to
  /// the average of the line around it (a Gaussian over half a line's
  /// [width]). The ends stay put, and so do corners (where the line turns
  /// 40° or more within a line's width), with the smoothing easing off
  /// towards them.
  static List<AutoLineartPoint> _evenOut(
    List<AutoLineartPoint> points,
    double width,
  ) {
    final dense = _resample(points, 1);
    final n = dense.length;
    if (n < 5) return points;
    final k = math.max(3, width.round());
    final sigma = math.max(1.5, width / 2);
    double turnAt(int i) {
      if (i - k < 0 || i + k >= n) return 0;
      final a = dense[i - k], b = dense[i], c = dense[i + k];
      final h1 = math.atan2(b.y - a.y, b.x - a.x);
      final h2 = math.atan2(c.y - b.y, c.x - b.x);
      return _wrapAngle(h2 - h1).abs();
    }

    final turns = [for (var i = 0; i < n; i++) turnAt(i)];
    final anchors = <int>[0];
    for (var i = 1; i < n - 1; i++) {
      if (turns[i] < 40 * math.pi / 180) continue;
      var peak = true;
      for (var o = -k; o <= k && peak; o++) {
        final j = i + o;
        if (j <= 0 || j >= n - 1 || j == i) continue;
        if (turns[j] > turns[i] || (turns[j] == turns[i] && j < i)) {
          peak = false;
        }
      }
      if (peak) anchors.add(i);
    }
    anchors.add(n - 1);
    final out = <AutoLineartPoint>[];
    final reach = (sigma * 2).ceil();
    for (var a = 0; a + 1 < anchors.length; a++) {
      final from = anchors[a], to = anchors[a + 1];
      for (var i = from; i < to; i++) {
        final ease = (math.min(i - from, to - i) / (sigma * 2)).clamp(0.0, 1.0);
        if (ease == 0) {
          out.add(dense[i]);
          continue;
        }
        var sx = 0.0, sy = 0.0, total = 0.0;
        for (var o = -reach; o <= reach; o++) {
          final j = i + o;
          if (j < from || j > to) continue;
          final w = math.exp(-o * o / (2 * sigma * sigma));
          sx += dense[j].x * w;
          sy += dense[j].y * w;
          total += w;
        }
        out.add(
          AutoLineartPoint(
            dense[i].x + (sx / total - dense[i].x) * ease,
            dense[i].y + (sy / total - dense[i].y) * ease,
          ),
        );
      }
    }
    out.add(dense.last);
    return out;
  }

  /// [points] thinned to those that keep its shape within [tolerance] px
  /// (Douglas–Peucker).
  static List<AutoLineartPoint> _keepShape(
    List<AutoLineartPoint> points,
    double tolerance,
  ) {
    if (points.length < 3) return points;
    final keep = List<bool>.filled(points.length, false)
      ..[0] = true
      ..[points.length - 1] = true;
    final stack = <(int, int)>[(0, points.length - 1)];
    while (stack.isNotEmpty) {
      final (a, b) = stack.removeLast();
      if (b - a < 2) continue;
      final pa = points[a], pb = points[b];
      final dx = pb.x - pa.x, dy = pb.y - pa.y;
      final length = math.sqrt(dx * dx + dy * dy);
      var worst = -1.0;
      var at = -1;
      for (var i = a + 1; i < b; i++) {
        final p = points[i];
        final d = length < 1e-9
            ? _distance(p, pa)
            : ((p.x - pa.x) * dy - (p.y - pa.y) * dx).abs() / length;
        if (d > worst) {
          worst = d;
          at = i;
        }
      }
      if (worst > tolerance) {
        keep[at] = true;
        stack
          ..add((a, at))
          ..add((at, b));
      }
    }
    return [
      for (var i = 0; i < points.length; i++)
        if (keep[i]) points[i],
    ];
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

  /// Where two rough lines run into each other, their ink merges into one
  /// stroke as wide as both, narrowing as they come together, and thinning
  /// leaves a Y: the two lines bend into a junction and one line runs on
  /// down the middle of the merged ink. Draw them as the rough has them
  /// instead: each line runs on along its own side of the merged ink, half
  /// the extra width out from its middle, so the two come together
  /// gradually where the ink narrows to one line's width (or end side by
  /// side where it never does).
  ///
  /// A merge is a junction of three lines where two of them come in at an
  /// acute angle from the same side and the ink at the junction is clearly
  /// wider than either of them; an ordinary fork or a line ending on
  /// another is left as it is.
  static List<_RawPath> _separateMerges(
    List<_RawPath> paths,
    Float64List paper,
    int width,
    int height,
  ) {
    if (paths.length < 3) return paths;
    double inkWidth(AutoLineartPoint p) {
      final x = p.x.floor().clamp(0, width - 1);
      final y = p.y.floor().clamp(0, height - 1);
      return math.max(1.0, 2 * paper[y * width + x] - 1);
    }

    var result = List<_RawPath>.of(paths);
    // Each merge replaces three paths (and leaves a junction that is no
    // merge); a line may meet the next merge further on, so look again
    // until nothing changes.
    for (var round = 0; round < paths.length; round++) {
      final merge = _findMerge(result, inkWidth);
      if (merge == null) break;
      result = merge;
    }
    return result;
  }

  static List<_RawPath>? _findMerge(
    List<_RawPath> paths,
    double Function(AutoLineartPoint p) inkWidth,
  ) {
    final ends = <(double, double), List<(int, bool)>>{};
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (path.points.length < 2) continue;
      if (path.startIsJunction) {
        final p = path.points.first;
        (ends[(p.x, p.y)] ??= []).add((i, true));
      }
      if (path.endIsJunction) {
        final p = path.points.last;
        (ends[(p.x, p.y)] ??= []).add((i, false));
      }
    }
    for (final MapEntry(key: (jx, jy), value: meeting) in ends.entries) {
      if (meeting.length != 3) continue;
      if ({for (final (i, _) in meeting) i}.length != 3) continue;
      final junction = AutoLineartPoint(jx, jy);
      final across = inkWidth(junction);
      // Each line from the junction outwards.
      final lines = [
        for (final (i, atStart) in meeting)
          atStart
              ? paths[i].points
              : paths[i].points.reversed.toList(growable: false),
      ];
      // Which way each heads, a little way out (past the junction's knot).
      final headings = [
        for (final line in lines) _headingFrom(line, across * 1.5),
      ];
      if (headings.any((h) => h == null)) continue;
      // The two coming in together: the pair at the smallest angle.
      var a = 0, b = 1, c = 2;
      var best = -2.0;
      for (final (x, y, z) in const [(0, 1, 2), (0, 2, 1), (1, 2, 0)]) {
        final cos = _dot(headings[x]!, headings[y]!);
        if (cos > best) {
          best = cos;
          (a, b, c) = (x, y, z);
        }
      }
      // Acute between them, and the third leaving the other way.
      if (best < math.cos(75 * math.pi / 180)) continue;
      final bisector = _normalized(
        AutoLineartPoint(
          headings[a]!.x + headings[b]!.x,
          headings[a]!.y + headings[b]!.y,
        ),
      );
      if (bisector == null || _dot(bisector, headings[c]!) > -.5) continue;
      // One line's width: the two coming in, away from the junction.
      final lineWidth =
          (_medianWidth(lines[a], across * 1.5, inkWidth) +
              _medianWidth(lines[b], across * 1.5, inkWidth)) /
          2;
      if (across < lineWidth * 1.4) continue;
      // Each side of the merged ink, along the line leaving it, half the
      // extra width out from its middle.
      final merged = lines[c];
      final count = merged.length;
      final mergedPath = paths[meeting[c].$1];
      final farIsJunction = meeting[c].$2
          ? mergedPath.endIsJunction
          : mergedPath.startIsJunction;
      // Two lines lying over each other on to the next junction, coming
      // together only for a moment where they cross (a head's round bottom
      // under a collar line), or crossing at a slant (their shared ink a
      // short line on to a junction where two lines leave it again):
      // _resolveJunctions carries each on through the ink.
      if (farIsJunction) {
        final crossing =
            _lengthOf(merged) <= lineWidth * 9 &&
            _crossingArms(paths, meeting[c].$1, merged.last, lineWidth * 1.5);
        if (crossing || _overlapping(merged, lineWidth, inkWidth)) continue;
      }
      final raw = [
        for (final p in merged) math.max(0.0, (inkWidth(p) - lineWidth) / 2),
      ];
      final offsets = List<double>.generate(count, (k) {
        var sum = 0.0, n = 0;
        for (var o = -2; o <= 2; o++) {
          final i = k + o;
          if (i < 0 || i >= count) continue;
          sum += raw[i];
          n++;
        }
        return sum / n;
      });
      offsets[0] = raw[0];
      // Where the two have come together (the ink one line wide).
      var meet = count - 1;
      for (var k = 1; k < count; k++) {
        if (offsets[k] <= .5) {
          meet = k;
          break;
        }
      }
      // Still apart at the next junction: lines overlapping between two
      // junctions, which _resolveJunctions joins up through the ink.
      if (meet == count - 1 && farIsJunction) continue;
      AutoLineartPoint tangentAt(int k) {
        final from = merged[math.max(0, k - 2)];
        final to = merged[math.min(count - 1, k + 2)];
        return _normalized(AutoLineartPoint(to.x - from.x, to.y - from.y)) ??
            const AutoLineartPoint(1, 0);
      }

      final leaving = tangentAt(0);
      double side(AutoLineartPoint heading) =>
          leaving.x * heading.y - leaving.y * heading.x >= 0 ? 1 : -1;
      final sideA = side(headings[a]!), sideB = side(headings[b]!);
      if (sideA == sideB) continue;
      List<AutoLineartPoint> along(double sign) => [
        for (var k = 0; k <= meet; k++)
          () {
            final t = tangentAt(k);
            return AutoLineartPoint(
              merged[k].x - t.y * offsets[k] * sign,
              merged[k].y + t.x * offsets[k] * sign,
            );
          }(),
      ];
      // The incoming lines without their last bend into the junction.
      List<AutoLineartPoint>? trimmed(List<AutoLineartPoint> line) {
        final reach = (across + lineWidth) / 2;
        var from = 0;
        while (from < line.length && _distance(line[from], junction) < reach) {
          from++;
        }
        if (line.length - from < 2) return null;
        return line.sublist(from).reversed.toList(growable: false);
      }

      final inA = trimmed(lines[a]), inB = trimmed(lines[b]);
      if (inA == null || inB == null) continue;
      final together = offsets[meet] <= .5;
      final rest = meet < count - 1;
      _RawPath incoming(int which, List<AutoLineartPoint> line, double sign) {
        final path = paths[meeting[which].$1];
        // The line's own far end keeps what it was.
        final farEnd = meeting[which].$2
            ? path.endIsJunction
            : path.startIsJunction;
        return _RawPath(
          points: [...line, ...along(sign)],
          startIsJunction: farEnd,
          endIsJunction: together || rest || farIsJunction,
        );
      }

      final replaced = {for (final (i, _) in meeting) i};
      return [
        for (var i = 0; i < paths.length; i++)
          if (!replaced.contains(i)) paths[i],
        incoming(a, inA, sideA),
        incoming(b, inB, sideB),
        if (rest)
          _RawPath(
            points: merged.sublist(meet),
            startIsJunction: true,
            endIsJunction: farIsJunction,
          ),
      ];
    }
    return null;
  }

  /// The way each other line leaves [junction], where path [own] ends,
  /// taken [reach] px out.
  static List<AutoLineartPoint> _armsAt(
    List<_RawPath> paths,
    int own,
    AutoLineartPoint junction,
    double reach,
  ) {
    final arms = <AutoLineartPoint>[];
    for (var j = 0; j < paths.length; j++) {
      if (j == own) continue;
      final path = paths[j];
      for (final atStart in const [true, false]) {
        if (atStart ? !path.startIsJunction : !path.endIsJunction) continue;
        final end = atStart ? path.points.first : path.points.last;
        if (end.x != junction.x || end.y != junction.y) continue;
        final heading = _headingFrom(
          atStart ? path.points : path.points.reversed.toList(growable: false),
          reach,
        );
        if (heading != null) arms.add(heading);
      }
    }
    return arms;
  }

  /// Whether the other lines meet path [own]'s end at [junction] the way
  /// two lines crossing at a slant do: exactly two other lines there, each
  /// leaving away from [own] (a line running on beside [own] leaves the same
  /// way as it), their headings taken [reach] px out.
  static bool _crossingArms(
    List<_RawPath> paths,
    int own,
    AutoLineartPoint junction,
    double reach,
  ) {
    final points = paths[own].points;
    final into = _headingFrom(
      _distance(points.first, junction) < 1e-6
          ? points
          : points.reversed.toList(growable: false),
      reach,
    );
    if (into == null) return false;
    var arms = 0;
    for (var j = 0; j < paths.length; j++) {
      if (j == own) continue;
      final path = paths[j];
      for (final atStart in const [true, false]) {
        if (atStart ? !path.startIsJunction : !path.endIsJunction) continue;
        final end = atStart ? path.points.first : path.points.last;
        if (end.x != junction.x || end.y != junction.y) continue;
        final out = _headingFrom(
          atStart ? path.points : path.points.reversed.toList(growable: false),
          reach,
        );
        if (out == null || _dot(out, into) > -.3) return false;
        arms++;
      }
    }
    return arms == 2;
  }

  static double _lengthOf(List<AutoLineartPoint> points) {
    var length = 0.0;
    for (var k = 1; k < points.length; k++) {
      length += _distance(points[k - 1], points[k]);
    }
    return length;
  }

  /// Whether [line] (between two junctions) is two lines of [lineWidth]
  /// lying over each other: not too long, and its ink, away from the
  /// junctions, mostly clearly wider than one line.
  static bool _overlapping(
    List<AutoLineartPoint> line,
    double lineWidth,
    double Function(AutoLineartPoint p) inkWidth,
  ) {
    var length = 0.0;
    for (var k = 1; k < line.length; k++) {
      length += _distance(line[k - 1], line[k]);
    }
    if (length > lineWidth * 14) return false;
    final inner = <double>[];
    var travelled = 0.0;
    for (var k = 1; k < line.length; k++) {
      travelled += _distance(line[k - 1], line[k]);
      if (travelled >= lineWidth && travelled <= length - lineWidth) {
        inner.add(inkWidth(line[k]));
      }
    }
    if (inner.isEmpty) return false;
    inner.sort();
    return inner[inner.length ~/ 2] >= lineWidth * 1.4;
  }

  /// Where lines cross, meet or lie over each other, thinning bends each one
  /// into the junction, and where two lines overlap between two junctions
  /// it runs a single line down the middle of their ink (the bottom of a
  /// head drawn over a collar line becomes one line, the sides of the head
  /// bending into it). Resolve each junction as the rough was drawn:
  ///
  /// * A short line across a narrow neck of ink (two lines only touching)
  ///   is no line.
  /// * Where two lines run side by side in one band of ink (a hair outline
  ///   just outside the head), each gets its own line along its side of the
  ///   ink, and the lines coming into the band at both ends are carried on
  ///   along them as a whole, so that each course runs smoothest.
  /// * Each line is cut back to where the junction stops bending it.
  /// * The lines that carry on through a junction most smoothly are joined
  ///   by a smooth curve, provided the curve stays inside the ink (a collar
  ///   line straight across, a head's curve round under it, two strokes
  ///   crossing at a slant straight through their shared ink). Smoothest
  ///   means keeping both lines' course at the junction and their curve
  ///   over a few line widths beyond it, so lines that only touch stay on
  ///   their sides. The smoothest joins are taken first, each line end at
  ///   most once; a line turning back sharply (a hair outline turning into
  ///   the hairline at its tip) is joined through its corner after them.
  /// * The single middle line of two overlapping lines is dropped when the
  ///   joins account for its ink.
  /// * A line that only reaches a junction runs straight on until it meets
  ///   another line there.
  static List<_RawPath> _resolveJunctions(
    List<_RawPath> input,
    Float64List paper,
    int width,
    int height,
  ) {
    if (input.length < 2) return input;
    // Bands of two lines side by side are added as their two lines.
    final paths = List<_RawPath>.of(input);
    double paperAt(double x, double y) {
      final px = x.floor(), py = y.floor();
      if (px < 0 || py < 0 || px >= width || py >= height) return 0;
      return paper[py * width + px];
    }

    double inkWidth(AutoLineartPoint p) =>
        math.max(1.0, 2 * paperAt(p.x, p.y) - 1);
    double lengthOf(List<AutoLineartPoint> points) {
      var length = 0.0;
      for (var i = 1; i < points.length; i++) {
        length += _distance(points[i - 1], points[i]);
      }
      return length;
    }

    // One line's width: the middle of the ink widths along all the lines.
    final widths = <double>[
      for (final path in paths)
        for (var i = 2; i + 2 < path.points.length; i++)
          inkWidth(path.points[i]),
    ]..sort();
    if (widths.isEmpty) return input;
    final line = math.max(2.0, widths[widths.length ~/ 2]);

    // The junctions, as clusters: two junctions joined by a line shorter
    // than one line's width are one place.
    final ids = <(double, double), int>{};
    final parent = <int>[];
    int idOf(AutoLineartPoint p) => ids.putIfAbsent((p.x, p.y), () {
      parent.add(parent.length);
      return parent.length - 1;
    });
    int find(int a) {
      while (parent[a] != a) {
        parent[a] = parent[parent[a]];
        a = parent[a];
      }
      return a;
    }

    const keep = 0, link = 1, overlap = 2;
    final role = List<int>.filled(paths.length, keep, growable: true);
    // How many line ends meet at each junction point (a dot's two ends are
    // junctions that meet nothing).
    final meeting = <(double, double), int>{};
    for (final path in paths) {
      if (path.points.length < 2) continue;
      if (path.startIsJunction) {
        final p = path.points.first;
        meeting[(p.x, p.y)] = (meeting[(p.x, p.y)] ?? 0) + 1;
      }
      if (path.endIsJunction) {
        final p = path.points.last;
        meeting[(p.x, p.y)] = (meeting[(p.x, p.y)] ?? 0) + 1;
      }
    }
    bool meets(AutoLineartPoint p) => (meeting[(p.x, p.y)] ?? 0) >= 2;
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (path.points.length < 2) continue;
      if (path.startIsJunction) idOf(path.points.first);
      if (path.endIsJunction) idOf(path.points.last);
      if (!path.startIsJunction || !path.endIsJunction) continue;
      if (!meets(path.points.first) || !meets(path.points.last)) continue;
      final a = idOf(path.points.first), b = idOf(path.points.last);
      if (a == b) continue;
      final length = lengthOf(path.points);
      if (length < line) {
        role[i] = link;
        parent[find(a)] = find(b);
      }
    }
    // Two lines only touching: thinning leaves a short line across the
    // narrow neck of ink between them, clearly narrower than a line in its
    // middle (a smile's bottom brushing a collar line). No line was drawn
    // there.
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (role[i] != keep || !path.startIsJunction || !path.endIsJunction) {
        continue;
      }
      if (!meets(path.points.first) || !meets(path.points.last)) continue;
      if (path.points.length < 3 || lengthOf(path.points) > line * 2) continue;
      var narrowest = double.infinity;
      for (var k = 1; k + 1 < path.points.length; k++) {
        narrowest = math.min(narrowest, inkWidth(path.points[k]));
      }
      if (narrowest <= line * .7) role[i] = link;
    }
    // Two lines lying over each other between two junctions: their ink is
    // clearly wider than one line all along.
    final partners = <(int, int)>{};
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (role[i] != keep || !path.startIsJunction || !path.endIsJunction) {
        continue;
      }
      if (!meets(path.points.first) || !meets(path.points.last)) continue;
      final a = find(idOf(path.points.first));
      final b = find(idOf(path.points.last));
      if (a == b) continue;
      final length = lengthOf(path.points);
      if (length > line * 14) continue;
      final inner = <double>[];
      var travelled = 0.0;
      for (var k = 1; k < path.points.length; k++) {
        travelled += _distance(path.points[k - 1], path.points[k]);
        if (travelled >= line && travelled <= length - line) {
          inner.add(inkWidth(path.points[k]));
        }
      }
      inner.sort();
      // Or the middle of two lines crossing at a slant: thinning leaves
      // their shared ink as a short line between two junctions, the two
      // other lines at each leaving away from it, its ink no wider than one
      // line across.
      final crossing =
          length <= line * 9 &&
          _crossingArms(paths, i, path.points.first, line * 1.5) &&
          _crossingArms(paths, i, path.points.last, line * 1.5);
      if (!crossing &&
          (inner.isEmpty || inner[inner.length ~/ 2] < line * 1.4)) {
        continue;
      }
      role[i] = overlap;
      partners
        ..add((a, b))
        ..add((b, a));
    }

    // A band where the two lines stay apart all along (a hair outline
    // running down just outside the head): each line on its own side, its
    // centre half a line in from that side's edge of the ink, so each keeps
    // its course. Where they cross inside the band (a head's bottom crossing
    // a collar line) the joins through the band are made below instead.
    final sides = <int, (int, int)>{};
    final sideClusters = <int, (int, int)>{};
    final sideHeadings = <int, (AutoLineartPoint, AutoLineartPoint)>{};
    // Two lines running into one end of [i] the way it runs (a hair outline
    // and the head's outline coming down together): they merge into it,
    // where the lines meeting a T's bar or crossing it would come in from
    // the side.
    bool fedByTwo(int i) {
      final points = paths[i].points;
      for (final atStart in const [true, false]) {
        final junction = atStart ? points.first : points.last;
        final into = _headingFrom(
          atStart ? points : points.reversed.toList(growable: false),
          line * 1.5,
        );
        if (into == null) continue;
        var feeders = 0;
        for (var j = 0; j < input.length; j++) {
          if (j == i || role[j] == link) continue;
          final other = paths[j];
          for (final otherAtStart in const [true, false]) {
            if (otherAtStart ? !other.startIsJunction : !other.endIsJunction) {
              continue;
            }
            final end = otherAtStart ? other.points.first : other.points.last;
            if (end.x != junction.x || end.y != junction.y) continue;
            final out = _headingFrom(
              otherAtStart
                  ? other.points
                  : other.points.reversed.toList(growable: false),
              line * 1.5,
            );
            if (out != null && -_dot(out, into) > .5) feeders++;
          }
        }
        if (feeders >= 2) return true;
      }
      return false;
    }

    for (var i = 0; i < input.length; i++) {
      final path = paths[i];
      if (role[i] == link || !path.startIsJunction || !path.endIsJunction) {
        continue;
      }
      if (role[i] != overlap) {
        // Not wide enough all along to be two lines over each other: two
        // lines merging, ink a little wider than one line on average.
        if (!meets(path.points.first) || !meets(path.points.last)) continue;
        if (find(idOf(path.points.first)) == find(idOf(path.points.last))) {
          continue;
        }
        final widths = [
          for (var k = 2; k + 2 < path.points.length; k++)
            inkWidth(path.points[k]),
        ]..sort();
        if (widths.isEmpty ||
            widths[widths.length ~/ 2] < line * 1.15 ||
            lengthOf(path.points) > line * 14 ||
            !fedByTwo(i)) {
          continue;
        }
      }
      final points = paths[i].points;
      final first = points.first, last = points.last;
      final inner = <int>[
        for (var k = 0; k < points.length; k++)
          if (_distance(points[k], first) >= line / 2 &&
              _distance(points[k], last) >= line / 2)
            k,
      ];
      if (inner.length < 4) continue;
      final count = inner.length;
      AutoLineartPoint tangentAt(int k) {
        final from = points[inner[math.max(0, k - 2)]];
        final to = points[inner[math.min(count - 1, k + 2)]];
        return _normalized(AutoLineartPoint(to.x - from.x, to.y - from.y)) ??
            const AutoLineartPoint(1, 0);
      }

      // How far the ink reaches to each side, across the band.
      double edge(AutoLineartPoint p, AutoLineartPoint normal) {
        var d = 0.0;
        while (d < line * 2 &&
            paperAt(p.x + normal.x * (d + .5), p.y + normal.y * (d + .5)) >=
                .5) {
          d += .5;
        }
        return d;
      }

      List<double> smoothed(List<double> raw) =>
          List<double>.generate(count, (k) {
            var sum = 0.0, n = 0;
            for (var o = -2; o <= 2; o++) {
              if (k + o < 0 || k + o >= count) continue;
              sum += raw[k + o];
              n++;
            }
            return sum / n;
          });
      final normals = [
        for (var k = 0; k < count; k++)
          () {
            final t = tangentAt(k);
            return AutoLineartPoint(-t.y, t.x);
          }(),
      ];
      final plus = smoothed([
        for (var k = 0; k < count; k++)
          edge(points[inner[k]], normals[k]) + .5 - line / 2,
      ]);
      final minus = smoothed([
        for (var k = 0; k < count; k++)
          edge(
                points[inner[k]],
                AutoLineartPoint(-normals[k].x, -normals[k].y),
              ) +
              .5 -
              line / 2,
      ]);
      // Two lines crossing at a slant (or touching) come together in the
      // middle of their shared ink and part towards both its ends: not side
      // by side. The junctions settle which way each carries on. (Lines side
      // by side may come together or cross towards one end, where one turns
      // away, and another line's ink may widen a band's ends, so those are
      // left out.)
      double separation(int k) => plus[k] + minus[k];
      final lo = (count * .15).ceil(), hi = (count * .85).floor() - 1;
      var least = double.infinity;
      for (var k = lo; k <= hi; k++) {
        least = math.min(least, separation(k));
      }
      var from = -1, to = -1;
      for (var k = lo; k <= hi; k++) {
        if (separation(k) > least + .2) continue;
        if (from < 0) from = k;
        to = k;
      }
      var before = 0.0, after = 0.0;
      for (var k = lo; k <= hi; k++) {
        if (k < from) before = math.max(before, separation(k));
        if (k > to) after = math.max(after, separation(k));
      }
      final closest = (from + to) / 2;
      if (from >= 0 &&
          closest >= count / 3 &&
          closest <= count * 2 / 3 &&
          (least < line / 4 ||
              (least < line * .6 &&
                  before >= least * 1.3 &&
                  after >= least * 1.3))) {
        continue;
      }
      // A short band at the middle of two lines crossing (its two lines
      // never clearly part inside it): each line coming in carries on
      // straighter as the line leaving on the other side than on its own.
      if (count <= line * 2 &&
          _crossingArms(paths, i, first, line * 1.5) &&
          _crossingArms(paths, i, last, line * 1.5)) {
        final atStart = _armsAt(paths, i, first, line * 1.5);
        final atEnd = _armsAt(paths, i, last, line * 1.5);
        if (atStart.length == 2 && atEnd.length == 2) {
          final startNormal = normals[0], endNormal = normals[count - 1];
          bool plusSide(AutoLineartPoint arm, AutoLineartPoint normal) =>
              _dot(arm, normal) > 0;
          double bend(AutoLineartPoint into, AutoLineartPoint out) =>
              math.acos((-_dot(into, out)).clamp(-1.0, 1.0));
          final [s0, s1] = atStart;
          final [e0, e1] = atEnd;
          if (plusSide(s0, startNormal) != plusSide(s1, startNormal) &&
              plusSide(e0, endNormal) != plusSide(e1, endNormal)) {
            final sameSide =
                plusSide(s0, startNormal) == plusSide(e0, endNormal);
            final alongSides = sameSide
                ? bend(s0, e0) + bend(s1, e1)
                : bend(s0, e1) + bend(s1, e0);
            final across = sameSide
                ? bend(s0, e1) + bend(s1, e0)
                : bend(s0, e0) + bend(s1, e1);
            if (across < alongSides) continue;
          }
        }
      }
      // The longest part of the band that is just the two lines side by
      // side: not where another line leaves it (the ink across much wider
      // than two lines, or one side's edge suddenly moving out), nor where
      // the two come within half a line of each other (crossing or merging
      // there, their ink's edges no longer tell where each runs).
      bool clean(int k) =>
          separation(k) + line <= line * 2.5 && separation(k) >= line / 2;
      bool steady(int k, int from) =>
          (plus[k] - plus[from]).abs() <= .6 &&
          (minus[k] - minus[from]).abs() <= .6;
      var runStart = 0, runEnd = -1;
      for (var k = 0; k < count; k++) {
        if (!clean(k)) continue;
        var end = k;
        while (end + 1 < count && clean(end + 1) && steady(end + 1, end)) {
          end++;
        }
        if (end - k > runEnd - runStart) {
          runStart = k;
          runEnd = end;
        }
        k = end;
      }
      final runLength = runEnd - runStart + 1;
      // Two lines: the two centres mostly at least 1.5 px apart (they may
      // come together at an end, where they merge or cross).
      final separations = [
        for (var k = runStart; k < runStart + runLength; k++)
          plus[k] + minus[k],
      ]..sort();
      final apart =
          runLength >= 4 && separations[separations.length ~/ 2] >= 1.5;
      if (!apart) continue;
      List<AutoLineartPoint> along(List<double> offsets, double sign) => [
        for (var k = runStart; k < runStart + runLength; k++)
          AutoLineartPoint(
            points[inner[k]].x + normals[k].x * offsets[k] * sign,
            points[inner[k]].y + normals[k].y * offsets[k] * sign,
          ),
      ];

      final clusters = (find(idOf(first)), find(idOf(last)));
      final left = paths.length;
      for (final (offsets, sign) in [(plus, 1.0), (minus, -1.0)]) {
        final side = along(offsets, sign);
        paths.add(
          _RawPath(points: side, startIsJunction: true, endIsJunction: true),
        );
        role.add(keep);
        sideClusters[paths.length - 1] = clusters;
        // Each side line heads at its ends the way its own course runs
        // there.
        final towardsStart = _endHeading(side, line);
        final towardsEnd = _endHeading(side.reversed.toList(), line);
        final band = (
          AutoLineartPoint(-tangentAt(runStart).x, -tangentAt(runStart).y),
          tangentAt(runStart + runLength - 1),
        );
        sideHeadings[paths.length - 1] = (
          towardsStart ?? band.$1,
          towardsEnd ?? band.$2,
        );
      }
      sides[i] = (left, left + 1);
      role[i] = overlap;
      // Its lines are joined only at either end, not across the band.
      partners
        ..remove(clusters)
        ..remove((clusters.$2, clusters.$1));
    }

    // Each line end at a junction, cut back to where the junction stops
    // bending it, with the way it heads there.
    final ends = <_JunctionEnd>[];
    final trims = List<List<int>>.generate(
      paths.length,
      (i) => [0, paths[i].points.length - 1],
    );
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (role[i] != keep || path.points.length < 2) continue;
      for (final atStart in const [true, false]) {
        if (atStart ? !path.startIsJunction : !path.endIsJunction) continue;
        final junction = atStart ? path.points.first : path.points.last;
        if (!meets(junction)) continue;
        final outward = atStart
            ? path.points
            : path.points.reversed.toList(growable: false);
        final reach = inkWidth(junction) / 2 + line / 2;
        var cut = 0;
        while (cut < outward.length &&
            _distance(outward[cut], junction) < reach) {
          cut++;
        }
        // Both ends' cuts must leave a line between them.
        final other = atStart ? trims[i][1] : outward.length - 1 - trims[i][0];
        if (cut >= other - 2) continue;
        final from = outward[cut];
        final fitted = _headingAtCut(outward, cut, line);
        if (fitted == null) continue;
        final (heading, curvature) = fitted;
        if (atStart) {
          trims[i][0] = cut;
        } else {
          trims[i][1] = outward.length - 1 - cut;
        }
        ends.add(
          _JunctionEnd(
            i,
            atStart,
            find(idOf(junction)),
            junction,
            from,
            heading,
            curvature,
          ),
        );
      }
    }
    // Each side line's ends, where it was cut from its band.
    for (final MapEntry(key: i, value: (startCluster, endCluster))
        in sideClusters.entries) {
      final points = paths[i].points;
      for (final atStart in const [true, false]) {
        final outward = atStart
            ? points
            : points.reversed.toList(growable: false);
        final (startHeading, endHeading) = sideHeadings[i]!;
        final heading = atStart ? startHeading : endHeading;
        const curvature = 0.0;
        final band = sides.entries.firstWhere(
          (e) => e.value.$1 == i || e.value.$2 == i,
        );
        final bandPoints = paths[band.key].points;
        ends.add(
          _JunctionEnd(
            i,
            atStart,
            atStart ? startCluster : endCluster,
            atStart ? bandPoints.first : bandPoints.last,
            outward.first,
            heading,
            curvature,
          ),
        );
      }
    }
    if (ends.length < 2) return input;

    // How far one end's line, run on into the junction as it was going
    // (keeping its curvature, or straight on, whichever comes closer: a
    // straight stroke's fitted curvature is mostly its pixel steps, which
    // run on across a wide junction would bend it away), misses the other
    // end: the nearest it comes, in line widths, plus how far its heading
    // there is from the other line's, in radians; the two ways averaged.
    // Lines that carry on through a junction keep their course and angle.
    double mismatch(_JunctionEnd a, _JunctionEnd b, double span) {
      double miss(_JunctionEnd from, _JunctionEnd to, {required bool bend}) {
        final want = math.atan2(-to.heading.y, -to.heading.x);
        var nearest = double.infinity, angle = 0.0;
        for (final (p, heading) in from.trajectory(
          span * 1.5 + line,
          .5,
          bend: bend,
        )) {
          final d = _distance(p, to.point);
          if (d < nearest) {
            nearest = d;
            angle = heading;
          }
        }
        return nearest / line + _wrapAngle(angle - want).abs();
      }

      return math.min(
        (miss(a, b, bend: true) + miss(b, a, bend: true)) / 2,
        (miss(a, b, bend: false) + miss(b, a, bend: false)) / 2,
      );
    }

    // A line's last [widths] line widths before the junction, from where it
    // was cut back, away from the junction.
    List<AutoLineartPoint> course(_JunctionEnd end, {double widths = 3}) {
      final points = paths[end.path].points;
      final lo = trims[end.path][0], hi = trims[end.path][1];
      final kept = points.sublist(lo, hi + 1);
      final run = end.atStart ? kept : kept.reversed.toList(growable: false);
      final out = <AutoLineartPoint>[run.first];
      var travelled = 0.0;
      for (var k = 1; k < run.length && travelled <= line * widths; k++) {
        travelled += _distance(run[k - 1], run[k]);
        out.add(run[k]);
      }
      return out;
    }

    // How far two lines joined end to end stay from one smooth curve over
    // six line widths either side of the junction, in line widths. Lines
    // that only touch (a hair outline resting on the head) and lines that
    // cross both run on smoothly at the junction itself; further out, only
    // the line that really carries on keeps the same curve (the head's
    // circle, the crossing stroke's straight line).
    double runsOn(_JunctionEnd a, _JunctionEnd b) =>
        _smoothFitError([
          ...course(a, widths: 6).reversed,
          ...course(b, widths: 6),
        ]) /
        line;

    // How well a line and a side line of a band make one smooth course
    // through the junction: a parabola fitted, in the side line's frame, to
    // the side line's first three line widths and the line's last three
    // before the junction; the root mean square of how far they stay from
    // it, in line widths. Their ends' headings are too unsteady to decide
    // it by (both lines lean together where they merge), their courses
    // either side of the junction are not.
    double offRail(_JunctionEnd from, _JunctionEnd rail) {
      final origin = rail.point, along = rail.heading;
      final samples = [
        for (final p in [...course(rail), ...course(from)])
          (
            ((p.x - origin.x) * along.x + (p.y - origin.y) * along.y) / line,
            ((p.y - origin.y) * along.x - (p.x - origin.x) * along.y) / line,
          ),
      ];
      // Least squares for v = a + b u + c u².
      final m = List<double>.filled(9, 0), r = List<double>.filled(3, 0);
      for (final (u, v) in samples) {
        final row = [1.0, u, u * u];
        for (var i = 0; i < 3; i++) {
          r[i] += row[i] * v;
          for (var j = 0; j < 3; j++) {
            m[i * 3 + j] += row[i] * row[j];
          }
        }
      }
      final fit = _solve3(m, r);
      if (fit == null) return double.infinity;
      var total = 0.0;
      for (final (u, v) in samples) {
        final off = v - (fit[0] + fit[1] * u + fit[2] * u * u);
        total += off * off;
      }
      return math.sqrt(total / samples.length);
    }

    // Junctions where side lines of two bands meet (another line touching a
    // band splits it there): the side lines carry on from band to band, so
    // there every join is weighed by how well it keeps both lines' course,
    // not settled per band.
    final bandsAt = <int, Set<int>>{};
    for (final MapEntry(key: band, value: (first, second)) in sides.entries) {
      for (final rail in [first, second]) {
        final (startCluster, endCluster) = sideClusters[rail]!;
        bandsAt.putIfAbsent(startCluster, () => {}).add(band);
        bandsAt.putIfAbsent(endCluster, () => {}).add(band);
      }
    }
    final contested = {
      for (final MapEntry(key: cluster, value: bands) in bandsAt.entries)
        if (bands.length > 1) cluster,
    };

    // The joins, the ones that keep both lines' course best first.
    final joins = <(double, int, int, List<AutoLineartPoint>)>[];
    // Lines carrying on along a side line of a band, settled per junction.
    final railJoins = <(double, int, int, List<AutoLineartPoint>)>[];
    for (var a = 0; a < ends.length; a++) {
      for (var b = a + 1; b < ends.length; b++) {
        final ea = ends[a], eb = ends[b];
        if (ea.cluster != eb.cluster &&
            !partners.contains((ea.cluster, eb.cluster))) {
          continue;
        }
        final span = _distance(ea.point, eb.point);
        if (span > line * 14) continue;
        final curve = _junctionCurve(ea, eb, span);
        // Inside the ink all the way.
        if (curve.any((p) => paperAt(p.x, p.y) < 1)) continue;
        var turn = 0.0;
        var heading = math.atan2(ea.heading.y, ea.heading.x);
        final through = [ea.point, ...curve, eb.point];
        for (var k = 1; k < through.length; k++) {
          final dx = through[k].x - through[k - 1].x;
          final dy = through[k].y - through[k - 1].y;
          if (dx * dx + dy * dy < 1e-6) continue;
          final next = math.atan2(dy, dx);
          turn += _wrapAngle(next - heading).abs();
          heading = next;
        }
        turn += _wrapAngle(
          math.atan2(-eb.heading.y, -eb.heading.x) - heading,
        ).abs();
        if (turn <= 110 * math.pi / 180) {
          final aSide = sideClusters.containsKey(ea.path);
          final bSide = sideClusters.containsKey(eb.path);
          if (aSide != bSide &&
              ea.cluster == eb.cluster &&
              !contested.contains(ea.cluster)) {
            railJoins.add((
              aSide ? offRail(eb, ea) : offRail(ea, eb),
              a,
              b,
              curve,
            ));
            continue;
          }
          final cost = aSide == bSide || contested.contains(ea.cluster)
              ? mismatch(ea, eb, span) + 15 * runsOn(ea, eb)
              : aSide
              ? offRail(eb, ea)
              : offRail(ea, eb);
          joins.add((cost + span * 1e-4, a, b, curve));
        }
      }
    }
    // A line that turns sharply in the junction (a hair outline running
    // down beside the head and turning back into the hairline at its tip):
    // both ends run straight on to where they meet, inside the ink. Taken
    // after the smooth joins, for the ends they leave.
    for (var a = 0; a < ends.length; a++) {
      for (var b = a + 1; b < ends.length; b++) {
        final ea = ends[a], eb = ends[b];
        if (ea.cluster != eb.cluster &&
            !partners.contains((ea.cluster, eb.cluster))) {
          continue;
        }
        // A side line's heading at its end is only as good as the few
        // pixels of the band left there: it may turn a little to meet the
        // other line inside the ink.
        final aSide = sideClusters.containsKey(ea.path);
        final bSide = sideClusters.containsKey(eb.path);
        (double, List<AutoLineartPoint>)? corner;
        for (final degrees
            in aSide || bSide
                ? const [0, 5, -5, 10, -10, 15, -15, 20, -20]
                : const [0]) {
          final angle = degrees * math.pi / 180;
          corner = _cornerJoin(
            aSide ? ea.turned(angle) : ea,
            bSide && !aSide ? eb.turned(angle) : eb,
            line,
            paperAt,
          );
          if (corner != null) break;
        }
        if (corner == null) continue;
        joins.add((1000 + corner.$1, a, b, corner.$2));
      }
    }
    joins.sort((x, y) => x.$1.compareTo(y.$1));
    final joined = <int, (int, List<AutoLineartPoint>)>{};
    // Each band's side lines are carried on at both its ends together: the
    // lines in and out are paired with the side lines so that each course
    // through the band (the line in, the side line, the line out) runs
    // smoothest. One line taking a side line greedily can leave another
    // only the wrong one, and the two cross in the band; and where two lines
    // come together so closely that either could carry on along either
    // side line (a hair outline coming down onto the head's outline), the
    // lines at the band's other end tell them apart.
    for (final MapEntry(value: (first, second)) in sides.entries) {
      final rails = [first, second];
      // The joins open to a side line's end: the line's end, the side
      // line's end, and the join from the one to the other.
      List<(int, int, List<AutoLineartPoint>)> optionsAt(
        int rail,
        bool atStart,
      ) => [
        for (final (_, a, b, curve) in railJoins)
          if (joined.containsKey(a) || joined.containsKey(b))
            ...const <(int, int, List<AutoLineartPoint>)>[]
          else if (ends[b].path == rail && ends[b].atStart == atStart)
            (a, b, curve)
          else if (ends[a].path == rail && ends[a].atStart == atStart)
            (b, a, curve.reversed.toList(growable: false)),
      ];
      // Every way to pair the lines at one end of the band with its two
      // side lines (or leave a side line's end without one).
      List<List<(int, int, List<AutoLineartPoint>)?>> pairings(bool atStart) {
        final options = [for (final rail in rails) optionsAt(rail, atStart)];
        return [
          for (final x in [null, ...options[0]])
            for (final y in [null, ...options[1]])
              if (x == null || y == null || x.$1 != y.$1) [x, y],
        ];
      }

      final intos = pairings(true), outs = pairings(false);
      if (intos.length * outs.length > 4096) continue;
      var best = const <(int, int, List<AutoLineartPoint>)>[];
      var bestScore = double.infinity;
      for (final into in intos) {
        for (final out in outs) {
          var score = 0.0;
          for (var r = 0; r < 2; r++) {
            final points = [
              if (into[r] case final join?) ...course(ends[join.$1]).reversed,
              ...paths[rails[r]].points,
              if (out[r] case final join?) ...course(ends[join.$1]),
            ];
            // Pairs made count against the cost, so more lines carried on
            // wins over leaving one out to save a little.
            score +=
                _smoothFitError(points) / line -
                2.0 * ((into[r] == null ? 0 : 1) + (out[r] == null ? 0 : 1));
          }
          if (score < bestScore) {
            bestScore = score;
            best = [...into.nonNulls, ...out.nonNulls];
          }
        }
      }
      for (final (a, b, curve) in best) {
        joined[a] = (b, curve);
        joined[b] = (a, curve.reversed.toList(growable: false));
      }
    }
    for (final (_, a, b, curve) in joins) {
      if (joined.containsKey(a) || joined.containsKey(b)) continue;
      joined[a] = (b, curve);
      joined[b] = (a, curve.reversed.toList(growable: false));
    }

    // The middle line of overlapping lines goes only when the joins run
    // through its ink.
    for (var i = 0; i < paths.length; i++) {
      if (role[i] != overlap || sides.containsKey(i)) continue;
      final through = [for (final j in joined.values) ...j.$2];
      var covered = 0;
      for (final p in paths[i].points) {
        final reach = inkWidth(p) / 2 + 1;
        if (through.any((q) => _distance(p, q) <= reach)) covered++;
      }
      if (covered < paths[i].points.length * .8) role[i] = keep;
    }

    // A line end left over runs straight on until it meets another line.
    final others = <AutoLineartPoint>[
      for (final j in joined.values) ...j.$2,
      for (var i = 0; i < paths.length; i++)
        if (role[i] == keep)
          for (var k = trims[i][0]; k <= trims[i][1]; k++) paths[i].points[k],
    ];
    final extended = <int, List<AutoLineartPoint>>{};
    for (var e = 0; e < ends.length; e++) {
      if (joined.containsKey(e)) continue;
      final end = ends[e];
      final reach = _distance(end.point, end.junction) * 2.5 + 1;
      final own = paths[end.path].points;
      AutoLineartPoint? meets;
      for (var step = 1.0; step <= reach && meets == null; step += .5) {
        final q = AutoLineartPoint(
          end.point.x + end.heading.x * step,
          end.point.y + end.heading.y * step,
        );
        if (paperAt(q.x, q.y) < 1) break;
        for (final o in others) {
          if (_distance(o, q) <= .75 && !own.contains(o)) {
            meets = q;
            break;
          }
        }
      }
      extended[e] = [meets ?? end.junction];
    }

    // Each line, cut back, joined end to end with its joins.
    final pieceEnds = <(int, bool), int>{
      for (var e = 0; e < ends.length; e++) (ends[e].path, ends[e].atStart): e,
    };
    List<AutoLineartPoint> piece(int i, bool forward) {
      final points = paths[i].points.sublist(trims[i][0], trims[i][1] + 1);
      final startEnd = pieceEnds[(i, true)];
      final endEnd = pieceEnds[(i, false)];
      final full = [
        if (startEnd != null && extended.containsKey(startEnd))
          ...extended[startEnd]!.reversed,
        ...points,
        if (endEnd != null && extended.containsKey(endEnd))
          ...extended[endEnd]!,
      ];
      return forward ? full : full.reversed.toList(growable: false);
    }

    bool flagOf(int i, bool atStart) {
      final e = pieceEnds[(i, atStart)];
      // A line end cut back at a junction meets another line there.
      if (e != null) return true;
      return atStart ? paths[i].startIsJunction : paths[i].endIsJunction;
    }

    int? joinAt(int i, bool atStart) => pieceEnds[(i, atStart)] == null
        ? null
        : joined[pieceEnds[(i, atStart)]!]?.$1;

    final result = <_RawPath>[];
    final visited = List<bool>.filled(paths.length, false);
    void walk(int first, bool forward) {
      final points = <AutoLineartPoint>[];
      var current = first;
      var ahead = forward;
      final startFlag = flagOf(first, forward);
      var endFlag = true;
      while (true) {
        visited[current] = true;
        points.addAll(piece(current, ahead));
        final exitAtStart = !ahead;
        final e = pieceEnds[(current, exitAtStart)];
        final next = e == null ? null : joined[e];
        if (next == null) {
          endFlag = flagOf(current, exitAtStart);
          break;
        }
        final target = ends[next.$1];
        points.addAll(next.$2);
        if (visited[target.path]) {
          // Round to where the line began: a closed loop.
          points.add(points.first);
          break;
        }
        current = target.path;
        ahead = target.atStart;
      }
      if (points.length >= 2) {
        result.add(
          _RawPath(
            points: List.unmodifiable(points),
            startIsJunction: startFlag,
            endIsJunction: endFlag,
          ),
        );
      }
    }

    for (var i = 0; i < paths.length; i++) {
      if (visited[i] || role[i] != keep) continue;
      if (joinAt(i, true) == null) {
        walk(i, true);
      } else if (joinAt(i, false) == null) {
        walk(i, false);
      }
    }
    // What is left are closed loops of joined lines.
    for (var i = 0; i < paths.length; i++) {
      if (visited[i] || role[i] != keep) continue;
      walk(i, true);
    }
    return result;
  }

  /// Where [a] and [b], each run on from its cut-back point the way it was
  /// going into the junction (keeping its curvature), meet: how far the
  /// line turns there and the points from one end to the other through
  /// that corner (not the ends themselves). Null when they do not meet
  /// within a few line [width]s, the way there leaves the ink, or the
  /// corner is sharper than 15°.
  static (double, List<AutoLineartPoint>)? _cornerJoin(
    _JunctionEnd a,
    _JunctionEnd b,
    double width,
    double Function(double x, double y) paperAt,
  ) {
    const step = .5;
    final reach = width * 6;
    final runA = [(a.point, 0.0), ...a.trajectory(reach, step)];
    final runB = [(b.point, 0.0), ...b.trajectory(reach, step)];
    // The first crossing of the two runs (least run in all).
    (int, int, AutoLineartPoint)? meet;
    for (var i = 1; i < runA.length; i++) {
      final p0 = runA[i - 1].$1, p1 = runA[i].$1;
      for (var j = 1; j < runB.length; j++) {
        if (meet != null && i + j >= meet.$1 + meet.$2) break;
        final q0 = runB[j - 1].$1, q1 = runB[j].$1;
        final rx = p1.x - p0.x, ry = p1.y - p0.y;
        final sx = q1.x - q0.x, sy = q1.y - q0.y;
        final cross = rx * sy - ry * sx;
        if (cross.abs() < 1e-9) continue;
        final qx = q0.x - p0.x, qy = q0.y - p0.y;
        final t = (qx * sy - qy * sx) / cross;
        final u = (qx * ry - qy * rx) / cross;
        if (t < 0 || t > 1 || u < 0 || u > 1) continue;
        meet = (i, j, AutoLineartPoint(p0.x + rx * t, p0.y + ry * t));
      }
    }
    if (meet == null) return null;
    final (i, j, corner) = meet;
    final turn = _wrapAngle(runB[j].$2 + math.pi - runA[i].$2).abs();
    if (turn > 165 * math.pi / 180) return null;
    final points = <AutoLineartPoint>[
      for (var k = 1; k < i; k++) runA[k].$1,
      corner,
      for (var k = j - 1; k >= 1; k--) runB[k].$1,
    ];
    if (points.any((p) => paperAt(p.x, p.y) < 1)) return null;
    return (turn, points);
  }

  /// The way a line heads at its point [cut] (towards [outward]'s start, the
  /// junction), and how it curves, as it runs further out: fitted to the
  /// line beyond the junction's pull (from half a line's [width] on, up to
  /// six widths or a corner) and followed back to the cut, so a curve keeps
  /// its curvature. Where too little line is left before a corner, its
  /// heading over a few pixels on the junction's side of the cut.
  static (AutoLineartPoint, double)? _headingAtCut(
    List<AutoLineartPoint> outward,
    int cut,
    double width,
  ) {
    final reach = width * 6;
    final samples = <(double, AutoLineartPoint)>[(0, outward[cut])];
    for (var d = 2.0; d <= reach; d += 2) {
      final p = _alongFrom(outward, cut, d);
      if (_distance(p, samples.last.$2) < 1e-3) break;
      samples.add((d, p));
    }
    // Up to a corner: where the line's heading over 4 px turns by more than
    // 25° from the 4 px before, checked every 2 px (pixel steps turn a 2 px
    // chord by up to 45°, but a 4 px one far less; a smooth curve turns a
    // few degrees, a corner's turn spread over a few pixels shows in full in
    // one of the pairs).
    final chords = <int, double>{};
    for (var k = 2; k < samples.length; k++) {
      final from = samples[k - 2].$2, to = samples[k].$2;
      final heading = math.atan2(to.y - from.y, to.x - from.x);
      final before = chords[k - 2];
      if (before != null &&
          _wrapAngle(heading - before).abs() > 25 * math.pi / 180) {
        samples.removeRange(k - 1, samples.length);
        break;
      }
      chords[k] = heading;
    }
    samples.removeAt(0);
    final far = [
      for (final (d, p) in samples)
        if (d >= width * .5) (d, p),
    ];
    // x(s) and y(s) as quadratics in the distance s along the line.
    (List<double>, List<double>)? quadratics(
      List<(double, AutoLineartPoint)> fit,
    ) {
      if (fit.length < 4 || fit.last.$1 - fit.first.$1 < width) return null;
      double sum(double Function(double s) f) {
        var total = 0.0;
        for (final (d, _) in fit) {
          total += f(d);
        }
        return total;
      }

      final n = fit.length.toDouble();
      final s1 = sum((s) => s), s2 = sum((s) => s * s);
      final s3 = sum((s) => s * s * s), s4 = sum((s) => s * s * s * s);
      List<double>? solve(double Function(AutoLineartPoint p) of) {
        var b0 = 0.0, b1 = 0.0, b2 = 0.0;
        for (final (d, p) in fit) {
          final v = of(p);
          b0 += v;
          b1 += v * d;
          b2 += v * d * d;
        }
        final m = [
          [n, s1, s2, b0],
          [s1, s2, s3, b1],
          [s2, s3, s4, b2],
        ];
        for (var col = 0; col < 3; col++) {
          var pivot = col;
          for (var row = col + 1; row < 3; row++) {
            if (m[row][col].abs() > m[pivot][col].abs()) pivot = row;
          }
          if (m[pivot][col].abs() < 1e-9) return null;
          final swap = m[col];
          m[col] = m[pivot];
          m[pivot] = swap;
          for (var row = 0; row < 3; row++) {
            if (row == col) continue;
            final f = m[row][col] / m[col][col];
            for (var k = col; k < 4; k++) {
              m[row][k] -= f * m[col][k];
            }
          }
        }
        return [for (var k = 0; k < 3; k++) m[k][3] / m[k][k]];
      }

      final fx = solve((p) => p.x), fy = solve((p) => p.y);
      return fx == null || fy == null ? null : (fx, fy);
    }

    // The curvature of the fitted curve at [s], turning the way out.
    double curvatureAt((List<double>, List<double>) curve, double s) {
      final (fx, fy) = curve;
      final vx = fx[1] + 2 * fx[2] * s, vy = fy[1] + 2 * fy[2] * s;
      final speed = math.sqrt(vx * vx + vy * vy);
      if (speed < 1e-9) return 0;
      return (vx * 2 * fy[2] - vy * 2 * fx[2]) / (speed * speed * speed);
    }

    // A line that stays straight over all the samples (its fitted arc less
    // than ¾ px off straight): its direction from a straight fit to them
    // all. The curve's own slope at the cut, run on past the samples,
    // swings with the pixel steps by up to 20° on a short stretch.
    final whole = quadratics(far);
    if (whole != null) {
      final n = far.length.toDouble();
      var mean = 0.0;
      for (final (d, _) in far) {
        mean += d;
      }
      mean /= n;
      final reachOfFit = far.last.$1 - far.first.$1;
      if (curvatureAt(whole, mean).abs() * reachOfFit * reachOfFit / 8 < .75) {
        double slope(double Function(AutoLineartPoint p) of) {
          var average = 0.0;
          for (final (_, p) in far) {
            average += of(p);
          }
          average /= n;
          var top = 0.0, bottom = 0.0;
          for (final (d, p) in far) {
            top += (d - mean) * (of(p) - average);
            bottom += (d - mean) * (d - mean);
          }
          return top / bottom;
        }

        final along = _normalized(
          AutoLineartPoint(slope((p) => p.x), slope((p) => p.y)),
        );
        if (along != null) {
          return (AutoLineartPoint(-along.x, -along.y), 0.0);
        }
      }
    }
    // A curve: fitted over its first three widths, so the fit follows its
    // bend there, and followed back to the cut. The heading points towards
    // the junction and the curvature goes that way (the opposite sign to
    // going out).
    final near = quadratics([
      for (final (d, p) in far)
        if (d <= width * 3) (d, p),
    ]);
    if (near != null) {
      final heading = _normalized(AutoLineartPoint(-near.$1[1], -near.$2[1]));
      if (heading != null) {
        final limit = 1 / (width * 1.5);
        return (heading, (-curvatureAt(near, 0)).clamp(-limit, limit));
      }
    }
    // A corner close beyond the cut: the line's heading on the junction's
    // side of the cut.
    final inner = _alongFrom(outward, cut, -4);
    final at = outward[cut];
    final heading = _normalized(
      AutoLineartPoint(inner.x - at.x, inner.y - at.y),
    );
    return heading == null ? null : (heading, 0.0);
  }

  /// The point [distance] px along [points] from its point [from]: towards
  /// its end for a positive distance, its start for a negative one (or the
  /// end point it reaches first).
  static AutoLineartPoint _alongFrom(
    List<AutoLineartPoint> points,
    int from,
    double distance,
  ) {
    final step = distance >= 0 ? 1 : -1;
    var left = distance.abs();
    var i = from;
    while (i + step >= 0 && i + step < points.length) {
      final run = _distance(points[i], points[i + step]);
      if (run >= left && run > 0) {
        final t = left / run;
        return AutoLineartPoint(
          points[i].x + (points[i + step].x - points[i].x) * t,
          points[i].y + (points[i + step].y - points[i].y) * t,
        );
      }
      left -= run;
      i += step;
    }
    return points[i];
  }

  /// A smooth curve from line end [a] to line end [b] (across [span] px),
  /// leaving and arriving the way each line heads: its points between them.
  static List<AutoLineartPoint> _junctionCurve(
    _JunctionEnd a,
    _JunctionEnd b,
    double span,
  ) {
    // Handles as for a circular arc turning as much as the two headings do
    // (a third of the span for a straight join).
    final turn = math.acos(
      (-(a.heading.x * b.heading.x + a.heading.y * b.heading.y)).clamp(
        -1.0,
        1.0,
      ),
    );
    final c = math.cos(turn / 4);
    final handle = span / (3 * c * c);
    final p0 = a.point, p3 = b.point;
    final p1 = AutoLineartPoint(
      p0.x + a.heading.x * handle,
      p0.y + a.heading.y * handle,
    );
    final p2 = AutoLineartPoint(
      p3.x + b.heading.x * handle,
      p3.y + b.heading.y * handle,
    );
    final count = math.max(2, span.ceil());
    return [
      for (var k = 1; k < count; k++)
        () {
          final t = k / count, u = 1 - t;
          final w0 = u * u * u, w1 = 3 * u * u * t;
          final w2 = 3 * u * t * t, w3 = t * t * t;
          return AutoLineartPoint(
            p0.x * w0 + p1.x * w1 + p2.x * w2 + p3.x * w3,
            p0.y * w0 + p1.y * w1 + p2.y * w2 + p3.y * w3,
          );
        }(),
    ];
  }

  static double _wrapAngle(double a) {
    var angle = a;
    while (angle > math.pi) {
      angle -= 2 * math.pi;
    }
    while (angle < -math.pi) {
      angle += 2 * math.pi;
    }
    return angle;
  }

  /// The unit direction from the start of [line] to its point [reach] px
  /// along (or its end), or null for a line with no length.
  static AutoLineartPoint? _headingFrom(
    List<AutoLineartPoint> line,
    double reach,
  ) {
    var travelled = 0.0;
    var to = line.last;
    for (var i = 1; i < line.length; i++) {
      travelled += _distance(line[i - 1], line[i]);
      if (travelled >= reach) {
        to = line[i];
        break;
      }
    }
    return _normalized(
      AutoLineartPoint(to.x - line.first.x, to.y - line.first.y),
    );
  }

  /// The middle ink width along [line] from [from] px out to three times
  /// that, or along its outer half when it is shorter.
  static double _medianWidth(
    List<AutoLineartPoint> line,
    double from,
    double Function(AutoLineartPoint p) inkWidth,
  ) {
    final widths = <double>[];
    var travelled = 0.0;
    for (var i = 1; i < line.length; i++) {
      travelled += _distance(line[i - 1], line[i]);
      if (travelled >= from && travelled <= from * 3) {
        widths.add(inkWidth(line[i]));
      }
    }
    if (widths.isEmpty) {
      for (var i = line.length ~/ 2; i < line.length; i++) {
        widths.add(inkWidth(line[i]));
      }
    }
    widths.sort();
    return widths[widths.length ~/ 2];
  }

  static double _dot(AutoLineartPoint a, AutoLineartPoint b) =>
      a.x * b.x + a.y * b.y;

  /// The way a line heads out of its end [fromEnd].first, from a parabola
  /// fitted to its first two line [width]s (a few pixels' tangent leans
  /// with the pixel steps); null when too little of it is left.
  static AutoLineartPoint? _endHeading(
    List<AutoLineartPoint> fromEnd,
    double width,
  ) {
    final window = <AutoLineartPoint>[fromEnd.first];
    var travelled = 0.0;
    for (var k = 1; k < fromEnd.length && travelled < width * 2; k++) {
      travelled += _distance(fromEnd[k - 1], fromEnd[k]);
      window.add(fromEnd[k]);
    }
    if (window.length < 3) return null;
    final inward = _normalized(
      AutoLineartPoint(
        window.last.x - window.first.x,
        window.last.y - window.first.y,
      ),
    );
    if (inward == null) return null;
    final origin = window.first;
    final m = List<double>.filled(9, 0), r = List<double>.filled(3, 0);
    for (final p in window) {
      final u = (p.x - origin.x) * inward.x + (p.y - origin.y) * inward.y;
      final v = (p.y - origin.y) * inward.x - (p.x - origin.x) * inward.y;
      final row = [1.0, u, u * u];
      for (var i = 0; i < 3; i++) {
        r[i] += row[i] * v;
        for (var j = 0; j < 3; j++) {
          m[i * 3 + j] += row[i] * row[j];
        }
      }
    }
    final fit = _solve3(m, r);
    if (fit == null) return null;
    // The slope at the end, back in the picture, pointing out of the line.
    final slope = fit[1];
    return _normalized(
      AutoLineartPoint(
        -(inward.x - slope * inward.y),
        -(inward.y + slope * inward.x),
      ),
    );
  }

  /// How far [points] stay from the smooth curve that fits them best, a
  /// circle or a parabola along their chord: the root mean square, in px.
  static double _smoothFitError(List<AutoLineartPoint> points) {
    final n = points.length;
    if (n < 4) return 0;
    var mx = 0.0, my = 0.0;
    for (final p in points) {
      mx += p.x;
      my += p.y;
    }
    mx /= n;
    my /= n;
    var best = double.infinity;
    // A circle, fitted algebraically (Kåsa) about the points' centre.
    {
      final m = List<double>.filled(9, 0), r = List<double>.filled(3, 0);
      for (final p in points) {
        final x = p.x - mx, y = p.y - my;
        final row = [x, y, 1.0];
        for (var i = 0; i < 3; i++) {
          r[i] -= row[i] * (x * x + y * y);
          for (var j = 0; j < 3; j++) {
            m[i * 3 + j] += row[i] * row[j];
          }
        }
      }
      final fit = _solve3(m, r);
      if (fit != null) {
        final cx = -fit[0] / 2, cy = -fit[1] / 2;
        final squared = cx * cx + cy * cy - fit[2];
        if (squared > 0) {
          final radius = math.sqrt(squared);
          var total = 0.0;
          for (final p in points) {
            final off =
                math.sqrt(
                  (p.x - mx - cx) * (p.x - mx - cx) +
                      (p.y - my - cy) * (p.y - my - cy),
                ) -
                radius;
            total += off * off;
          }
          best = math.sqrt(total / n);
        }
      }
    }
    // A parabola across the chord from the first point to the last (a
    // straight line, too).
    final along = _normalized(
      AutoLineartPoint(
        points.last.x - points.first.x,
        points.last.y - points.first.y,
      ),
    );
    if (along != null) {
      final origin = points.first;
      final scale = math.max(1.0, _distance(points.first, points.last));
      final samples = [
        for (final p in points)
          (
            ((p.x - origin.x) * along.x + (p.y - origin.y) * along.y) / scale,
            (p.y - origin.y) * along.x - (p.x - origin.x) * along.y,
          ),
      ];
      final m = List<double>.filled(9, 0), r = List<double>.filled(3, 0);
      for (final (u, v) in samples) {
        final row = [1.0, u, u * u];
        for (var i = 0; i < 3; i++) {
          r[i] += row[i] * v;
          for (var j = 0; j < 3; j++) {
            m[i * 3 + j] += row[i] * row[j];
          }
        }
      }
      final fit = _solve3(m, r);
      if (fit != null) {
        var total = 0.0;
        for (final (u, v) in samples) {
          final off = v - (fit[0] + fit[1] * u + fit[2] * u * u);
          total += off * off;
        }
        best = math.min(best, math.sqrt(total / n));
      }
    }
    return best.isFinite ? best : 0;
  }

  /// The solution of the 3×3 system [m] (row major) · x = [r], or null when
  /// it has none to speak of.
  static List<double>? _solve3(List<double> m, List<double> r) {
    double det3(List<double> a) =>
        a[0] * (a[4] * a[8] - a[5] * a[7]) -
        a[1] * (a[3] * a[8] - a[5] * a[6]) +
        a[2] * (a[3] * a[7] - a[4] * a[6]);
    final det = det3(m);
    if (det.abs() < 1e-9) return null;
    return [
      for (var column = 0; column < 3; column++)
        det3([for (var i = 0; i < 9; i++) i % 3 == column ? r[i ~/ 3] : m[i]]) /
            det,
    ];
  }

  static AutoLineartPoint? _normalized(AutoLineartPoint v) {
    final length = math.sqrt(v.x * v.x + v.y * v.y);
    if (length < 1e-9) return null;
    return AutoLineartPoint(v.x / length, v.y / length);
  }

  /// The distance from each pixel of [mask] to the nearest pixel of paper
  /// (exact, Euclidean; Felzenszwalb and Huttenlocher's two passes).
  static Float64List _distanceToPaper(Uint8List mask, int width, int height) {
    const far = 1e20;
    final grid = Float64List(width * height);
    for (var i = 0; i < grid.length; i++) {
      grid[i] = mask[i] != 0 ? far : 0;
    }
    final size = math.max(width, height);
    final f = Float64List(size), d = Float64List(size);
    final v = Int32List(size), z = Float64List(size + 1);
    void pass(int n) {
      var k = 0;
      v[0] = 0;
      z[0] = -far;
      z[1] = far;
      for (var q = 1; q < n; q++) {
        double meet(int at) =>
            ((f[q] + q * q) - (f[at] + at * at)) / (2 * q - 2 * at);
        var s = meet(v[k]);
        // z[0] is far below any meeting point, so this stops at k = 0.
        while (s <= z[k]) {
          k--;
          s = meet(v[k]);
        }
        k++;
        v[k] = q;
        z[k] = s;
        z[k + 1] = far;
      }
      k = 0;
      for (var q = 0; q < n; q++) {
        while (z[k + 1] < q) {
          k++;
        }
        final dq = q - v[k];
        d[q] = dq * dq + f[v[k]];
      }
    }

    for (var x = 0; x < width; x++) {
      for (var y = 0; y < height; y++) {
        f[y] = grid[y * width + x];
      }
      pass(height);
      for (var y = 0; y < height; y++) {
        grid[y * width + x] = d[y];
      }
    }
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        f[x] = grid[y * width + x];
      }
      pass(width);
      for (var x = 0; x < width; x++) {
        grid[y * width + x] = math.sqrt(d[x]);
      }
    }
    return grid;
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
        // A step's corner touches the line both above or below and to a
        // side. A line's end pixel beside the next one does not, and taking
        // it would shorten the line (a 2 px staircase from its end on).
        bool on(int dx, int dy) {
          final nx = x + dx, ny = y + dy;
          return nx >= 0 &&
              ny >= 0 &&
              nx < width &&
              ny < height &&
              skeleton[ny * width + nx] != 0;
        }

        if (!(on(0, -1) || on(0, 1)) || !(on(-1, 0) || on(1, 0))) continue;
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

  /// [_thinZhangSuen]'s result thinned to 1 px where it is left 2 px wide
  /// (Guo and Hall's two-pass thinning, which thins a diagonal staircase
  /// without eating it). Guo-Hall on the whole rough puts the centre lines
  /// of merged and crossing strokes elsewhere than the rest of the analysis
  /// is made for, so it only finishes Zhang-Suen's work.
  static Uint8List _thinGuoHall(Uint8List input, int width, int height) {
    final img = Uint8List.fromList(input);
    if (width < 3 || height < 3) return img;
    var foreground = <int>[
      for (var y = 1; y < height - 1; y++)
        for (var x = 1; x < width - 1; x++)
          if (img[y * width + x] != 0) y * width + x,
    ];
    final remove = <int>[];
    var changed = true;
    while (changed) {
      changed = false;
      for (var pass = 0; pass < 2; pass++) {
        remove.clear();
        for (final i in foreground) {
          if (img[i] == 0) continue;
          final p2 = img[i - width] != 0 ? 1 : 0;
          final p3 = img[i - width + 1] != 0 ? 1 : 0;
          final p4 = img[i + 1] != 0 ? 1 : 0;
          final p5 = img[i + width + 1] != 0 ? 1 : 0;
          final p6 = img[i + width] != 0 ? 1 : 0;
          final p7 = img[i + width - 1] != 0 ? 1 : 0;
          final p8 = img[i - 1] != 0 ? 1 : 0;
          final p9 = img[i - width - 1] != 0 ? 1 : 0;
          // One run of neighbours (the pixel joins nothing else together).
          final runs =
              (p2 == 0 && (p3 | p4) != 0 ? 1 : 0) +
              (p4 == 0 && (p5 | p6) != 0 ? 1 : 0) +
              (p6 == 0 && (p7 | p8) != 0 ? 1 : 0) +
              (p8 == 0 && (p9 | p2) != 0 ? 1 : 0);
          if (runs != 1) continue;
          // Not a line's end, and on the edge of the ink.
          final n1 = (p9 | p2) + (p3 | p4) + (p5 | p6) + (p7 | p8);
          final n2 = (p2 | p3) + (p4 | p5) + (p6 | p7) + (p8 | p9);
          final n = math.min(n1, n2);
          if (n < 2 || n > 3) continue;
          // The first pass peels the south-east side, the second the
          // north-west, so a line keeps its middle.
          final side = pass == 0
              ? (p6 | p7 | (1 - p9)) & p8
              : (p2 | p3 | (1 - p5)) & p4;
          if (side != 0) continue;
          remove.add(i);
        }
        if (remove.isNotEmpty) {
          changed = true;
          for (final i in remove) {
            img[i] = 0;
          }
        }
      }
      if (changed) {
        foreground = [
          for (final i in foreground)
            if (img[i] != 0) i,
        ];
      }
    }
    return img;
  }

  /// The centre lines of [input] (Zhang and Suen's two-pass thinning,
  /// with Lü and Wang's correction): 1 px wide, except a diagonal line in
  /// one direction stays a 2 px staircase, which [_thinGuoHall] finishes.
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
            // At least 3 neighbours (Lü and Wang's correction): a diagonal
            // line peeled down to a 2 px staircase has 2 at its end, and
            // taking that end pass after pass eats the whole line (one
            // stroke of an X vanished, a 45° line came out shorter).
            if (ns < 3 || ns > 6) continue;
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

/// A line's end at a junction, cut back to where the junction stops bending
/// it: [path] and which end, the junction [cluster] and [junction] point,
/// the cut-back [point], the unit [heading] the line has there, towards
/// the junction, and how it curves going that way ([curvature], radians
/// per px, positive turning clockwise on screen).
class _JunctionEnd {
  final int path;
  final bool atStart;
  final int cluster;
  final AutoLineartPoint junction;
  final AutoLineartPoint point;
  final AutoLineartPoint heading;
  final double curvature;

  const _JunctionEnd(
    this.path,
    this.atStart,
    this.cluster,
    this.junction,
    this.point,
    this.heading,
    this.curvature,
  );

  /// This end with its heading turned by [angle] radians.
  _JunctionEnd turned(double angle) {
    final c = math.cos(angle), s = math.sin(angle);
    return _JunctionEnd(
      path,
      atStart,
      cluster,
      junction,
      point,
      AutoLineartPoint(
        heading.x * c - heading.y * s,
        heading.x * s + heading.y * c,
      ),
      curvature,
    );
  }

  /// The line run on into the junction as it was going, keeping its
  /// [curvature] (or straight on, without [bend]): points [step] px apart,
  /// each with its heading, for [length] px.
  List<(AutoLineartPoint, double)> trajectory(
    double length,
    double step, {
    bool bend = true,
  }) {
    final turn = bend ? curvature * step : 0.0;
    var x = point.x, y = point.y;
    var angle = math.atan2(heading.y, heading.x);
    return [
      for (var d = step; d <= length; d += step)
        () {
          angle += turn;
          x += math.cos(angle) * step;
          y += math.sin(angle) * step;
          return (AutoLineartPoint(x, y), angle);
        }(),
    ];
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
