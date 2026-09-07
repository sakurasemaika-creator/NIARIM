from pathlib import Path

engine = Path('lib/engine/auto_lineart_engine.dart')
s = engine.read_text(encoding='utf-8')

if 'final int analysisWidth;' not in s:
    old = '''class AutoLineartGraph {
  final int width;
  final int height;
  final List<AutoLineartPath> paths;

  const AutoLineartGraph({
    required this.width,
    required this.height,
    required this.paths,
  });
}'''
    new = '''class AutoLineartGraph {
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
}'''
    if old not in s:
        raise SystemExit('AutoLineartGraph anchor not found')
    s = s.replace(old, new, 1)

if '_cropForegroundMask(' not in s:
    anchor = '  static AutoLineartGraph analyze(\n'
    helper = '''  /// Crops the binary foreground to the smallest useful work area. The expensive
  /// morphology/thinning passes run only inside this region; points are offset
  /// back into full-canvas coordinates before the graph is returned.
  static ({
    Uint8List mask,
    int width,
    int height,
    int offsetX,
    int offsetY,
  })? _cropForegroundMask(
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
      return (
        mask: mask,
        width: width,
        height: height,
        offsetX: 0,
        offsetY: 0,
      );
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

'''
    if anchor not in s:
        raise SystemExit('analyze anchor not found')
    s = s.replace(anchor, helper + anchor, 1)

start_marker = '    final base = _buildForegroundMask(rgba, width, height);\n\n'
end_marker = '    return AutoLineartGraph(width: width, height: height, paths: paths);\n  }\n\n  static Uint8List render('
start = s.find(start_marker)
end = s.find(end_marker)
if start < 0 or end < 0 or end < start:
    raise SystemExit('analyze body anchors not found')

replacement = '''    // Fast path: ordinary NIARIM drawing layers are mostly transparent, so
    // _buildForegroundMask returns immediately after its alpha pass. Flattened
    // opaque roughs alone pay for border/background contrast estimation.
    final base = _buildForegroundMask(rgba, width, height);

    final rough = roughWidthPx.clamp(2.0, 80.0);
    final closeRadius = (rough * 0.10).round().clamp(0, 3);
    final scaleRadius = math.max(1, (rough * 0.08).round());

    // Expensive morphology + three skeletonizations are restricted to the rough
    // artwork's bounding box. Padding covers every local morphology radius and
    // keeps endpoints/junctions away from an artificial crop edge.
    final analysisPadding = math.max(
      4,
      closeRadius * 2 + scaleRadius * 2 + (rough * 0.25).ceil(),
    );
    final crop = _cropForegroundMask(
      base,
      width,
      height,
      padding: analysisPadding,
    );
    if (crop == null) {
      return AutoLineartGraph(width: width, height: height, paths: const []);
    }
    final localBase = crop.mask;
    final localWidth = crop.width;
    final localHeight = crop.height;

    // Merge tiny holes/gaps inside a scribbly rough while avoiding a large
    // dilation that would incorrectly connect unrelated nearby strokes.
    final cleaned = closeRadius == 0
        ? localBase
        : _erode(
            _dilate(localBase, localWidth, localHeight, closeRadius),
            localWidth,
            localHeight,
            closeRadius,
          );

    // Multi-scale topology sampling. The changing tolerance is deliberately
    // small: true main connections tend to survive, whereas accidental branch
    // contacts and raster nubs are unstable across these variants.
    final masks = <Uint8List>[
      _erode(cleaned, localWidth, localHeight, scaleRadius),
      cleaned,
      _dilate(cleaned, localWidth, localHeight, scaleRadius),
    ];
    final skeletons = masks
        .map((m) => _thinZhangSuen(m, localWidth, localHeight))
        .toList(growable: false);
    final skeleton = skeletons[1];

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

    final minBranchLength = math.max(3.0, rough * 0.55);
    final paths = <AutoLineartPath>[];
    for (final raw in rawPaths) {
      if (raw.points.length < 2) continue;
      final length = _polylineLength(raw.points);
      final persistence = _pathPersistence(
        raw.points,
        skeletons,
        localWidth,
        localHeight,
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
      // analysis. Restore full-canvas coordinates only after all local topology
      // work is complete.
      final simplified = _simplifyCollinear(raw.points)
          .map(
            (p) => AutoLineartPoint(
              p.x + crop.offsetX,
              p.y + crop.offsetY,
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

  static Uint8List render('''

s = s[:start] + replacement + s[end + len(end_marker):]
engine.write_text(s, encoding='utf-8')

# Add regression/diagnostic coverage for sparse large canvases and coordinate
# restoration after cropped topology analysis.
test = Path('test/auto_lineart_filter_test.dart')
t = test.read_text(encoding='utf-8')
if 'restricts expensive topology work to a sparse rough bounding box' not in t:
    insert = '''
    test('restricts expensive topology work to a sparse rough bounding box', () {
      const w = 512, h = 512;
      final src = _canvas(w, h);
      _line(src, w, h, 236, 252, 276, 252, 5);

      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 11);
      expect(graph.paths, isNotEmpty);
      expect(graph.analysisWidth * graph.analysisHeight, lessThan(w * h ~/ 20));

      // Paths must still use original canvas coordinates after local analysis.
      final out = AutoLineartEngine.render(
        graph,
        w,
        h,
        outputWidthPx: 2,
        taperLengthPx: 6,
        smoothing: 45,
      );
      expect(_alpha(out, w, 256, 252), greaterThan(100));
      expect(_alpha(out, w, 40, 40), 0);
    });

    test('cropped analysis preserves coordinates near the bottom-right edge', () {
      const w = 320, h = 240;
      final src = _canvas(w, h);
      _line(src, w, h, 260, 210, 306, 210, 4);

      final graph = AutoLineartEngine.analyze(src, w, h, roughWidthPx: 9);
      expect(graph.paths, isNotEmpty);
      expect(graph.analysisWidth, lessThan(w));
      expect(graph.analysisHeight, lessThan(h));

      final out = AutoLineartEngine.render(
        graph,
        w,
        h,
        outputWidthPx: 2,
        taperLengthPx: 4,
        smoothing: 30,
      );
      expect(_alpha(out, w, 283, 210), greaterThan(80));
      expect(_alpha(out, w, 123, 100), 0);
    });
'''
    marker = '  });\n}\n'
    pos = t.rfind(marker)
    if pos < 0:
        raise SystemExit('test insertion anchor not found')
    t = t[:pos] + insert + t[pos:]
    test.write_text(t, encoding='utf-8')

print('Auto Line Art bbox optimization patch applied')
