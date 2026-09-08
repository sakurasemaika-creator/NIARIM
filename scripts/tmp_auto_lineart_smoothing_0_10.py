from pathlib import Path


def replace(path, old, new):
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise SystemExit(f"anchor not found in {path}: {old[:100]!r}")
    p.write_text(s.replace(old, new, 1))


p = Path("lib/engine/auto_lineart_engine.dart")
s = p.read_text()
start = s.index("  /// Converts an analyzed topology graph into the temporary editable control")
end = s.index("  /// Moves one preview control point.", start)
new_method = '''  /// Converts an analyzed topology graph into the temporary editable control
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

      var work = List<AutoLineartPoint>.from(original);
      final passes = math.max(1, level);
      final amount = 0.12 + level * 0.025;
      for (var pass = 0; pass < passes; pass++) {
        final next = List<AutoLineartPoint>.from(work);
        for (var i = 1; i < work.length - 1; i++) {
          final prev = work[i - 1];
          final cur = work[i];
          final after = work[i + 1];
          next[i] = AutoLineartPoint(
            cur.x + (((prev.x + after.x) * 0.5) - cur.x) * amount,
            cur.y + (((prev.y + after.y) * 0.5) - cur.y) * amount,
          );
        }
        next[0] = original.first;
        next[next.length - 1] = original.last;
        work = next;
      }

      final interiorCount = original.length - 2;
      final keepInterior =
          (interiorCount * (1.0 - level / 10.0)).round().clamp(
            0,
            interiorCount,
          );
      final reduced = <AutoLineartPoint>[work.first];
      for (var i = 1; i <= keepInterior; i++) {
        final index = (i * (work.length - 1) / (keepInterior + 1)).round();
        final point = work[index.clamp(1, work.length - 2)];
        if (reduced.last.x != point.x || reduced.last.y != point.y) {
          reduced.add(point);
        }
      }
      reduced.add(work.last);

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

'''
p.write_text(s[:start] + new_method + s[end:])

replace(
    "lib/screens/canvas/widgets/filter_panel.dart",
    "filter.autoLineartSmoothing.round().clamp(0, 100)",
    "filter.autoLineartSmoothing.round().clamp(0, 10)",
)
replace(
    "lib/screens/canvas/widgets/filter_panel.dart",
    "current.autoLineartSmoothing.round().clamp(0, 100),\n              0,\n              100,",
    "current.autoLineartSmoothing.round().clamp(0, 10),\n              0,\n              10,",
)
replace("lib/models/filter_def.dart", "this.autoLineartSmoothing = 50,", "this.autoLineartSmoothing = 5,")
replace("lib/services/filter_service.dart", "autoLineartSmoothing: 45,", "autoLineartSmoothing: 5,")

p = Path("lib/services/filter_service.dart")
s = p.read_text()
old = '''      _filters.addAll(
        raw.map(
          (s) => FilterDef.fromJson(jsonDecode(s) as Map<String, dynamic>),
        ),
      );'''
new = '''      var migratedAutoLineartSmoothing = false;
      _filters.addAll(
        raw.map((s) {
          var filter = FilterDef.fromJson(jsonDecode(s) as Map<String, dynamic>);
          if (filter.kind == FilterKind.autoLineart &&
              filter.autoLineartSmoothing > 10) {
            filter = filter.copyWith(
              autoLineartSmoothing:
                  (filter.autoLineartSmoothing / 10).round().clamp(0, 10).toDouble(),
            );
            migratedAutoLineartSmoothing = true;
          }
          return filter;
        }),
      );'''
if old not in s:
    raise SystemExit("filter service load anchor not found")
s = s.replace(old, new, 1)
old2 = '''      if (missing.isNotEmpty) {
        _filters.addAll(missing);
        await _persist();
      }'''
new2 = '''      if (missing.isNotEmpty) {
        _filters.addAll(missing);
      }
      if (missing.isNotEmpty || migratedAutoLineartSmoothing) {
        await _persist();
      }'''
if old2 not in s:
    raise SystemExit("filter service persist anchor not found")
p.write_text(s.replace(old2, new2, 1))

p = Path("test/auto_lineart_filter_test.dart")
s = p.read_text()
s = s.replace("test('100-level smoothing reduces editable control points', () {", "test('0-10 smoothing progressively reduces editable control points', () {")
old = '''      final low = AutoLineartEngine.prepareEditableGraph(
        base,
        smoothingLevel: 10,
      );
      final high = AutoLineartEngine.prepareEditableGraph(
        base,
        smoothingLevel: 100,
      );'''
new = '''      final low = AutoLineartEngine.prepareEditableGraph(
        base,
        smoothingLevel: 1,
      );
      final high = AutoLineartEngine.prepareEditableGraph(
        base,
        smoothingLevel: 9,
      );'''
if old not in s:
    raise SystemExit("old smoothing test anchor not found")
s = s.replace(old, new, 1)
insert = '''
    test('level 10 leaves exactly two endpoints on every path', () {
      final graph = AutoLineartGraph(
        width: 100,
        height: 100,
        paths: const [
          AutoLineartPath(
            points: [
              AutoLineartPoint(10, 10),
              AutoLineartPoint(20, 18),
              AutoLineartPoint(35, 30),
              AutoLineartPoint(50, 50),
            ],
            startIsJunction: false,
            endIsJunction: true,
            persistence: 1,
          ),
          AutoLineartPath(
            points: [
              AutoLineartPoint(50, 50),
              AutoLineartPoint(65, 34),
              AutoLineartPoint(80, 20),
              AutoLineartPoint(90, 10),
            ],
            startIsJunction: true,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final straight = AutoLineartEngine.prepareEditableGraph(
        graph,
        smoothingLevel: 10,
      );
      expect(straight.paths, hasLength(2));
      expect(straight.paths.every((path) => path.points.length == 2), isTrue);
      expect(straight.paths[0].points.last.x, 50);
      expect(straight.paths[0].points.last.y, 50);
      expect(straight.paths[1].points.first.x, 50);
      expect(straight.paths[1].points.first.y, 50);
    });

    test('levels 1-9 remove about 10%-90% of interior controls', () {
      final points = List<AutoLineartPoint>.generate(
        12,
        (i) => AutoLineartPoint(i.toDouble(), (i % 3).toDouble()),
      );
      final graph = AutoLineartGraph(
        width: 20,
        height: 20,
        paths: [
          AutoLineartPath(
            points: points,
            startIsJunction: false,
            endIsJunction: false,
            persistence: 1,
          ),
        ],
      );
      final level1 = AutoLineartEngine.prepareEditableGraph(graph, smoothingLevel: 1);
      final level9 = AutoLineartEngine.prepareEditableGraph(graph, smoothingLevel: 9);
      expect(level1.paths.single.points.length, 11);
      expect(level9.paths.single.points.length, 3);
    });
'''
marker = "    test(\n      'dragging a shared junction keeps coincident branch endpoints joined',"
if marker not in s:
    raise SystemExit("test insertion anchor not found")
p.write_text(s.replace(marker, insert + "\n" + marker, 1))
