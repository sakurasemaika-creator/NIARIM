from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1):
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise SystemExit(f'anchor not found in {path}: {old[:120]!r}')
    p.write_text(s.replace(old, new, count))

# ---------------------------------------------------------------------------
# FilterDef: persistent auto-lineart color.
# ---------------------------------------------------------------------------
p = Path('lib/models/filter_def.dart')
s = p.read_text()
s = s.replace(
    '  final double autoLineartSmoothing;\n  final double prismBlurPx;',
    '  final double autoLineartSmoothing;\n  final int autoLineartColor;\n  final double prismBlurPx;',
    1,
)
s = s.replace(
    '    this.autoLineartSmoothing = 5,\n    this.prismBlurPx = 8,',
    '    this.autoLineartSmoothing = 5,\n    this.autoLineartColor = 0xFF000000,\n    this.prismBlurPx = 8,',
    1,
)
s = s.replace(
    '    double? autoLineartSmoothing,\n    double? prismBlurPx,',
    '    double? autoLineartSmoothing,\n    int? autoLineartColor,\n    double? prismBlurPx,',
    1,
)
s = s.replace(
    '      autoLineartSmoothing: autoLineartSmoothing ?? this.autoLineartSmoothing,\n      prismBlurPx:',
    '      autoLineartSmoothing: autoLineartSmoothing ?? this.autoLineartSmoothing,\n      autoLineartColor: autoLineartColor ?? this.autoLineartColor,\n      prismBlurPx:',
    1,
)
s = s.replace(
    "    'autoLineartSmoothing': autoLineartSmoothing,\n    'prismBlurPx':",
    "    'autoLineartSmoothing': autoLineartSmoothing,\n    'autoLineartColor': autoLineartColor,\n    'prismBlurPx':",
    1,
)
s = s.replace(
    "    autoLineartSmoothing: (j['autoLineartSmoothing'] as num?)?.toDouble() ?? 45,\n    prismBlurPx:",
    "    autoLineartSmoothing: (j['autoLineartSmoothing'] as num?)?.toDouble() ?? 5,\n    autoLineartColor: j['autoLineartColor'] as int? ?? 0xFF000000,\n    prismBlurPx:",
    1,
)
p.write_text(s)

# ---------------------------------------------------------------------------
# FilterService: default/update support for color.
# ---------------------------------------------------------------------------
p = Path('lib/services/filter_service.dart')
s = p.read_text()
s = s.replace(
    '      autoLineartSmoothing: 5,\n    ),',
    '      autoLineartSmoothing: 5,\n      autoLineartColor: 0xFF000000,\n    ),',
    1,
)
s = s.replace(
    '    double? autoLineartSmoothing,\n    double? prismBlurPx,',
    '    double? autoLineartSmoothing,\n    int? autoLineartColor,\n    double? prismBlurPx,',
    1,
)
s = s.replace(
    '      autoLineartSmoothing: autoLineartSmoothing,\n      prismBlurPx:',
    '      autoLineartSmoothing: autoLineartSmoothing,\n      autoLineartColor: autoLineartColor,\n      prismBlurPx:',
    1,
)
p.write_text(s)

# ---------------------------------------------------------------------------
# AutoLineartEngine: colored rasterization, rough+line preview composition,
# and edit transfer across smoothing/rough-width topology refreshes.
# ---------------------------------------------------------------------------
p = Path('lib/engine/auto_lineart_engine.dart')
s = p.read_text()

# Insert transfer helper before moveControlPoint.
marker = '  /// Moves one preview control point. Coincident points (normally the endpoints\n'
if marker not in s:
    raise SystemExit('engine moveControlPoint marker not found')
helper = r'''  /// Transfers manual control-point offsets from [edited] relative to [baseline]
  /// onto a newly prepared graph [target]. This is used when smoothing level or
  /// accepted rough width changes: persistent strokes retain the user's edits,
  /// newly detected strokes remain untouched, and removed/split strokes follow
  /// the fresh topology instead of resurrecting stale geometry.
  static AutoLineartGraph transferControlEdits(
    AutoLineartGraph baseline,
    AutoLineartGraph edited,
    AutoLineartGraph target,
  ) {
    if (baseline.paths.isEmpty || edited.paths.isEmpty || target.paths.isEmpty) {
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
        if (basePath.points.length != editedPath.points.length ||
            basePath.points.length < 2 ||
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
        final direct = distance(basePath.points.first, targetPath.points.first) +
            distance(basePath.points.last, targetPath.points.last) +
            topologyPenalty;
        final reverse = distance(basePath.points.first, targetPath.points.last) +
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
      final points = <AutoLineartPoint>[];
      for (var ti = 0; ti < targetPath.points.length; ti++) {
        final tp = targetPath.points[ti];
        var nearest = 0;
        var nearestSq = double.infinity;
        for (var bi = 0; bi < basePath.points.length; bi++) {
          final mapped = bestReversed
              ? basePath.points[basePath.points.length - 1 - bi]
              : basePath.points[bi];
          final dx = mapped.x - tp.x;
          final dy = mapped.y - tp.y;
          final d2 = dx * dx + dy * dy;
          if (d2 < nearestSq) {
            nearestSq = d2;
            nearest = bi;
          }
        }
        final baseIndex = bestReversed
            ? basePath.points.length - 1 - nearest
            : nearest;
        final bp = basePath.points[baseIndex];
        final ep = editedPath.points[baseIndex];
        points.add(
          AutoLineartPoint(
            (tp.x + (ep.x - bp.x)).clamp(
              0.0,
              math.max(0, target.width - 1).toDouble(),
            ),
            (tp.y + (ep.y - bp.y)).clamp(
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

'''
s = s.replace(marker, helper + marker, 1)

# render color argument.
s = s.replace(
    '    required double smoothing,\n  }) {',
    '    required double smoothing,\n    int color = 0xFF000000,\n  }) {',
    1,
)
s = s.replace(
    '        taperEnd: !path.endIsJunction,\n      );',
    '        taperEnd: !path.endIsJunction,\n        color: color,\n      );',
    1,
)
s = s.replace(
    '    required bool taperEnd,\n  }) {',
    '    required bool taperEnd,\n    required int color,\n  }) {',
    1,
)
old_pixel = '''          if (alpha > out[index + 3]) {
            out[index] = 0;
            out[index + 1] = 0;
            out[index + 2] = 0;
            out[index + 3] = alpha;
          }'''
new_pixel = '''          final colorAlpha = (color >> 24) & 0xFF;
          final finalAlpha = (alpha * colorAlpha / 255).round();
          if (finalAlpha > out[index + 3]) {
            out[index] = (color >> 16) & 0xFF;
            out[index + 1] = (color >> 8) & 0xFF;
            out[index + 2] = color & 0xFF;
            out[index + 3] = finalAlpha;
          }'''
if old_pixel not in s:
    raise SystemExit('raster color anchor not found')
s = s.replace(old_pixel, new_pixel, 1)

# Preview compositor before polyline helper.
marker2 = '  static double _polylineLength(List<AutoLineartPoint> points) {'
if marker2 not in s:
    raise SystemExit('polyline marker not found')
compose = r'''  /// Composes the reference rough at a reduced opacity under the generated
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

'''
s = s.replace(marker2, compose + marker2, 1)
p.write_text(s)

# ---------------------------------------------------------------------------
# Full-resolution isolate: use prepared 0..10 graph and selected line color.
# ---------------------------------------------------------------------------
p = Path('lib/engine/filter_engine.dart')
s = p.read_text()
old = '''    FilterKind.autoLineart => AutoLineartEngine.render(
      AutoLineartEngine.analyze(
        data,
        width,
        height,
        roughWidthPx: filter.autoLineartRoughWidth,
      ),
      width,
      height,
      outputWidthPx: filter.autoLineartOutputWidth,
      taperLengthPx: filter.autoLineartTaperLength,
      smoothing: filter.autoLineartSmoothing,
    ),'''
new = '''    FilterKind.autoLineart => AutoLineartEngine.render(
      AutoLineartEngine.prepareEditableGraph(
        AutoLineartEngine.analyze(
          data,
          width,
          height,
          roughWidthPx: filter.autoLineartRoughWidth,
        ),
        smoothingLevel: filter.autoLineartSmoothing.round().clamp(0, 10),
      ),
      width,
      height,
      outputWidthPx: filter.autoLineartOutputWidth,
      taperLengthPx: filter.autoLineartTaperLength,
      smoothing: 0,
      color: filter.autoLineartColor,
    ),'''
if old not in s:
    raise SystemExit('filter isolate auto lineart anchor not found')
p.write_text(s.replace(old, new, 1))

# ---------------------------------------------------------------------------
# FilterPanel: preview composition, persistent manual edits through parameter
# changes, color chip, and final manual render color.
# ---------------------------------------------------------------------------
p = Path('lib/screens/canvas/widgets/filter_panel.dart')
s = p.read_text()
s = s.replace(
    '  AutoLineartGraph? _autoLineartPreviewGraph;\n  double? _autoLineartPreviewRoughWidth;',
    '  AutoLineartGraph? _autoLineartPreviewGraph;\n  AutoLineartGraph? _autoLineartEditBaselineGraph;\n  double? _autoLineartPreviewRoughWidth;',
    1,
)
old_block = '''      if (_autoLineartBaseGraph == null ||
          _autoLineartPreviewRoughWidth != filter.autoLineartRoughWidth) {
        _autoLineartBaseGraph = AutoLineartEngine.analyze(
          base,
          _previewW,
          _previewH,
          roughWidthPx: math.max(
            2.0,
            filter.autoLineartRoughWidth * _previewScale,
          ),
        );
        _autoLineartPreviewRoughWidth = filter.autoLineartRoughWidth;
        _autoLineartPreviewGraph = null;
        _autoLineartPreviewSmoothingLevel = null;
        _autoLineartManualEdited = false;
      }
      if (_autoLineartPreviewGraph == null ||
          _autoLineartPreviewSmoothingLevel != smoothingLevel) {
        _autoLineartPreviewGraph = AutoLineartEngine.prepareEditableGraph(
          _autoLineartBaseGraph!,
          smoothingLevel: smoothingLevel,
        );
        _autoLineartPreviewSmoothingLevel = smoothingLevel;
        _autoLineartManualEdited = false;
      }
      filtered = AutoLineartEngine.render(
        _autoLineartPreviewGraph!,
        _previewW,
        _previewH,
        outputWidthPx: math.max(
          1.0,
          filter.autoLineartOutputWidth * _previewScale,
        ),
        taperLengthPx: filter.autoLineartTaperLength * _previewScale,
        smoothing: 0,
      );'''
new_block = '''      final roughChanged = _autoLineartBaseGraph == null ||
          _autoLineartPreviewRoughWidth != filter.autoLineartRoughWidth;
      final smoothingChanged =
          _autoLineartPreviewSmoothingLevel != smoothingLevel;
      if (roughChanged || smoothingChanged || _autoLineartPreviewGraph == null) {
        final previousBaseline = _autoLineartEditBaselineGraph;
        final previousEdited = _autoLineartPreviewGraph;
        final preserveManual = _autoLineartManualEdited &&
            previousBaseline != null &&
            previousEdited != null;
        if (roughChanged) {
          _autoLineartBaseGraph = AutoLineartEngine.analyze(
            base,
            _previewW,
            _previewH,
            roughWidthPx: math.max(
              2.0,
              filter.autoLineartRoughWidth * _previewScale,
            ),
          );
          _autoLineartPreviewRoughWidth = filter.autoLineartRoughWidth;
        }
        final prepared = AutoLineartEngine.prepareEditableGraph(
          _autoLineartBaseGraph!,
          smoothingLevel: smoothingLevel,
        );
        _autoLineartPreviewGraph = preserveManual
            ? AutoLineartEngine.transferControlEdits(
                previousBaseline,
                previousEdited,
                prepared,
              )
            : prepared;
        _autoLineartEditBaselineGraph = prepared;
        _autoLineartPreviewSmoothingLevel = smoothingLevel;
        _autoLineartManualEdited = preserveManual;
      }
      final line = AutoLineartEngine.render(
        _autoLineartPreviewGraph!,
        _previewW,
        _previewH,
        outputWidthPx: math.max(
          1.0,
          filter.autoLineartOutputWidth * _previewScale,
        ),
        taperLengthPx: filter.autoLineartTaperLength * _previewScale,
        smoothing: 0,
        color: filter.autoLineartColor,
      );
      filtered = AutoLineartEngine.composePreview(
        base,
        line,
        roughOpacity: 0.4,
      );'''
if old_block not in s:
    raise SystemExit('panel auto preview block not found')
s = s.replace(old_block, new_block, 1)

# rough width callback: no state reset.
old_rough = '''                _autoLineartBaseGraph = null;
                _autoLineartPreviewGraph = null;
                _autoLineartPreviewRoughWidth = null;
                _autoLineartPreviewSmoothingLevel = null;
                _autoLineartManualEdited = false;
                _updatePreview();'''
if old_rough not in s:
    raise SystemExit('panel rough reset anchor not found')
s = s.replace(old_rough, '                _updatePreview();', 1)

# smoothing callback: no edit reset.
old_smooth = '''                _autoLineartPreviewGraph = null;
                _autoLineartPreviewSmoothingLevel = null;
                _autoLineartManualEdited = false;
                _updatePreview();'''
if old_smooth not in s:
    raise SystemExit('panel smoothing reset anchor not found')
s = s.replace(old_smooth, '                _updatePreview();', 1)

# color chip before output width.
anchor = '''            _integerStepperSlider(
              l10n.filterAutoLineartOutputWidth,'''
color_control = '''            _colorControl(
              '線画色',
              current.autoLineartColor,
              (c) => service.updateFilterParams(
                current.id,
                autoLineartColor: c,
              ),
            ),
            _integerStepperSlider(
              l10n.filterAutoLineartOutputWidth,'''
if anchor not in s:
    raise SystemExit('panel output width anchor not found')
s = s.replace(anchor, color_control, 1)

# manual final render selected color.
s = s.replace(
    '        smoothing: 0,\n      );\n    } else if (_isPrism(filter)) {',
    '        smoothing: 0,\n        color: filter.autoLineartColor,\n      );\n    } else if (_isPrism(filter)) {',
    1,
)

# legacy _runFilter branch also use prepared 0..10 + color (defensive consistency).
old_run = '''      case FilterKind.autoLineart:
        return AutoLineartEngine.render(
          AutoLineartEngine.analyze(
            data,
            width,
            height,
            roughWidthPx: filter.autoLineartRoughWidth * _previewScale,
          ),
          width,
          height,
          outputWidthPx: math.max(
            1.0,
            filter.autoLineartOutputWidth * _previewScale,
          ),
          taperLengthPx: filter.autoLineartTaperLength * _previewScale,
          smoothing: filter.autoLineartSmoothing,
        );'''
new_run = '''      case FilterKind.autoLineart:
        return AutoLineartEngine.render(
          AutoLineartEngine.prepareEditableGraph(
            AutoLineartEngine.analyze(
              data,
              width,
              height,
              roughWidthPx: filter.autoLineartRoughWidth * _previewScale,
            ),
            smoothingLevel: filter.autoLineartSmoothing.round().clamp(0, 10),
          ),
          width,
          height,
          outputWidthPx: math.max(
            1.0,
            filter.autoLineartOutputWidth * _previewScale,
          ),
          taperLengthPx: filter.autoLineartTaperLength * _previewScale,
          smoothing: 0,
          color: filter.autoLineartColor,
        );'''
if old_run not in s:
    raise SystemExit('panel _runFilter auto anchor not found')
s = s.replace(old_run, new_run, 1)
p.write_text(s)

# ---------------------------------------------------------------------------
# Engine tests: color, 40% rough preview, edit transfer, add/remove topology.
# ---------------------------------------------------------------------------
p = Path('test/auto_lineart_filter_test.dart')
s = p.read_text()
marker = "    test(\n      'dragging a shared junction keeps coincident branch endpoints joined',"
if marker not in s:
    raise SystemExit('test insertion marker not found')
insert = r'''
    test('render uses the selected line-art color without changing AA alpha', () {
      final graph = AutoLineartGraph(
        width: 40,
        height: 20,
        paths: const [
          AutoLineartPath(
            points: [AutoLineartPoint(4, 10), AutoLineartPoint(36, 10)],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final out = AutoLineartEngine.render(
        graph,
        40,
        20,
        outputWidthPx: 3,
        taperLengthPx: 0,
        smoothing: 0,
        color: 0xFF2A7BE4,
      );
      final i = (10 * 40 + 20) * 4;
      expect(out[i], 0x2A);
      expect(out[i + 1], 0x7B);
      expect(out[i + 2], 0xE4);
      expect(out[i + 3], greaterThan(200));
    });

    test('preview keeps the rough at about 40 percent under colored line art', () {
      final rough = Uint8List.fromList([200, 100, 50, 255, 200, 100, 50, 255]);
      final line = Uint8List.fromList([0, 0, 0, 0, 20, 220, 80, 255]);
      final out = AutoLineartEngine.composePreview(rough, line, roughOpacity: .4);
      expect(out[3], inInclusiveRange(100, 104));
      expect(out[0], 200);
      expect(out[1], 100);
      expect(out[2], 50);
      expect(out[4], 20);
      expect(out[5], 220);
      expect(out[6], 80);
      expect(out[7], 255);
    });

    test('manual offsets survive smoothing changes', () {
      final baseline = AutoLineartGraph(
        width: 100,
        height: 100,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(10, 50),
              AutoLineartPoint(30, 48),
              AutoLineartPoint(50, 50),
              AutoLineartPoint(70, 52),
              AutoLineartPoint(90, 50),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final edited = AutoLineartEngine.moveControlPoint(
        baseline,
        pathIndex: 0,
        pointIndex: 2,
        point: const AutoLineartPoint(50, 35),
      );
      final target = AutoLineartEngine.prepareEditableGraph(
        baseline,
        smoothingLevel: 5,
      );
      final transferred = AutoLineartEngine.transferControlEdits(
        baseline,
        edited,
        target,
      );
      expect(transferred.paths.single.points.any((p) => p.y < 42), isTrue);
    });

    test('rough-width topology refresh keeps edits and accepts new paths', () {
      final baseline = AutoLineartGraph(
        width: 120,
        height: 80,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(10, 40),
              AutoLineartPoint(50, 40),
              AutoLineartPoint(90, 40),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final edited = AutoLineartEngine.moveControlPoint(
        baseline,
        pathIndex: 0,
        pointIndex: 1,
        point: const AutoLineartPoint(50, 28),
      );
      final expanded = AutoLineartGraph(
        width: 120,
        height: 80,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(5, 40),
              AutoLineartPoint(50, 40),
              AutoLineartPoint(105, 40),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
          AutoLineartPath(
            points: [AutoLineartPoint(70, 15), AutoLineartPoint(100, 15)],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final transferred = AutoLineartEngine.transferControlEdits(
        baseline,
        edited,
        expanded,
      );
      expect(transferred.paths, hasLength(2));
      expect(transferred.paths.first.points[1].y, lessThan(35));
      expect(transferred.paths[1].points, expanded.paths[1].points);
    });

    test('rough-width topology refresh allows a persistent path to shorten', () {
      final baseline = AutoLineartGraph(
        width: 120,
        height: 80,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(5, 40),
              AutoLineartPoint(50, 40),
              AutoLineartPoint(110, 40),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final edited = AutoLineartEngine.moveControlPoint(
        baseline,
        pathIndex: 0,
        pointIndex: 1,
        point: const AutoLineartPoint(50, 30),
      );
      final shortened = AutoLineartGraph(
        width: 120,
        height: 80,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(20, 40),
              AutoLineartPoint(50, 40),
              AutoLineartPoint(75, 40),
            ],
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final transferred = AutoLineartEngine.transferControlEdits(
        baseline,
        edited,
        shortened,
      );
      expect(transferred.paths.single.points.first.x, closeTo(20, .001));
      expect(transferred.paths.single.points.last.x, closeTo(75, .001));
      expect(transferred.paths.single.points[1].y, lessThan(35));
    });
'''
s = s.replace(marker, insert + '\n' + marker, 1)
p.write_text(s)
