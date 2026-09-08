from pathlib import Path

p = Path('lib/engine/auto_lineart_engine.dart')
s = p.read_text()
old = '''      final points = <AutoLineartPoint>[];
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
      }'''
new = '''      final points = <AutoLineartPoint>[];
      var pathLength = 0.0;
      for (var i = 1; i < basePath.points.length; i++) {
        final dx = basePath.points[i].x - basePath.points[i - 1].x;
        final dy = basePath.points[i].y - basePath.points[i - 1].y;
        pathLength += math.sqrt(dx * dx + dy * dy);
      }
      final averageSpacing = pathLength / math.max(1, basePath.points.length - 1);
      // A manually moved point may itself disappear when smoothing is raised.
      // Spread that displacement over about 2.5 old control spacings so the
      // user's curve survives in neighboring retained controls instead of
      // snapping back to the automatic path.
      final influenceRadius = math.max(6.0, averageSpacing * 2.5);
      for (final tp in targetPath.points) {
        var offsetX = 0.0;
        var offsetY = 0.0;
        for (var bi = 0; bi < basePath.points.length; bi++) {
          final baseIndex = bestReversed
              ? basePath.points.length - 1 - bi
              : bi;
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
      }'''
if old not in s:
    raise SystemExit('transfer point block not found')
p.write_text(s.replace(old, new, 1))
