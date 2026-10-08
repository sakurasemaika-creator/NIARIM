import 'dart:math' as math;
import 'dart:typed_data';

/// 墨溜まり: where lines meet at an acute or a right angle (a V, a fork, the
/// narrow side of a crossing, a T, a square corner), ink pools inside that
/// angle; wider ones get none. Along each of the two lines, on
/// the side facing the other, the pool shows [centreWidthPx] beyond the
/// line's edge at the meeting point and thins in a straight slope to 1 px at
/// [rangePx], like a slide, however thick the line is. The result is the
/// pool alone on a transparent layer (premultiplied RGBA), to go under the
/// line art: it reaches back to the line's centre so no gap shows along the
/// edge.
class InkPoolEngine {
  InkPoolEngine._();

  static const int _alphaThreshold = 24;

  /// Lines meeting at less than this pool ink between them: up to a right
  /// angle, with a little to spare for lines drawn by hand, and short of the
  /// wide side of two rings crossing (106 degrees in the Olympic rings).
  static const double _angleLimit = 96 * math.pi / 180;

  static Uint8List layer(
    Uint8List data,
    int width,
    int height, {
    required int color,
    required double rangePx,
    required double centreWidthPx,
  }) {
    final result = Uint8List(data.length);
    final n = width * height;
    if (width <= 2 || height <= 2 || data.length < n * 4) return result;
    final range = rangePx.clamp(1.0, 80.0);
    final centreWidth = centreWidthPx.clamp(1.0, 60.0);

    final mask = _lineMask(data, n);
    final ink = _ink(data, n);
    final halfWidth = _distanceToBackground(mask, width, height);
    final centre = _thin(mask, width, height);
    final junction = Uint8List(n);
    for (var p = 0; p < n; p++) {
      if (centre[p] == 0) continue;
      final x = p % width, y = p ~/ width;
      if (x == 0 || y == 0 || x == width - 1 || y == height - 1) continue;
      if (_branchCount(centre, width, p) >= 3) junction[p] = 1;
    }
    final near = math.max(4, math.min(12, centreWidth.round() + 2));
    final seeds = _meetingPoints(
      centre,
      junction,
      halfWidth,
      width,
      height,
      near,
    );
    if (seeds.isEmpty) return result;

    final coverage = Float32List(n);
    final distance = Float64List(n)..fillRange(0, n, double.infinity);
    final parent = Int32List(n);
    final label = Int32List(n);
    final touched = <int>[];
    for (final seed in seeds) {
      for (final p in touched) {
        distance[p] = double.infinity;
      }
      touched.clear();
      final sx = seed % width, sy = seed ~/ width;
      // Each line's direction is measured a little way out, past where the
      // thinning bends it round the meeting point.
      final lineHalf = _lineHalfWidth(centre, junction, halfWidth, width, seed);
      final fitFrom = math.max(5.0, 3 * lineHalf);
      final fitTo = fitFrom + 24;
      final merge = _mergeRadius(near, lineHalf);
      // A walk of pixel steps along a slanted line is up to about 15 %
      // longer than the line.
      final explore = math.max(range * 1.2 + merge, fitTo + merge + 1);
      // How far along the lines each centre pixel is from the meeting point,
      // and the way back to it. A crossing of thick lines thins to two forks
      // joined by a short bridge, so the walk goes on through a fork that
      // close; any other meeting point has a pool of its own, and the walk
      // stops there.
      final heap = _MinHeap();
      final stops = <int>[];
      distance[seed] = 0;
      parent[seed] = seed;
      touched.add(seed);
      heap.push(0, seed);
      while (heap.isNotEmpty) {
        final (d, p) = heap.pop();
        if (d > distance[p]) continue;
        final x = p % width;
        final y = p ~/ width;
        if (p != seed && junction[p] != 0) {
          final ex = x - sx, ey = y - sy;
          if (ex * ex + ey * ey > merge * merge) {
            stops.add(p);
            continue;
          }
        }
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
            final q = ny * width + nx;
            if (centre[q] == 0) continue;
            final next = d + (dx != 0 && dy != 0 ? math.sqrt2 : 1.0);
            if (next > explore || next >= distance[q]) continue;
            if (distance[q] == double.infinity) touched.add(q);
            distance[q] = next;
            parent[q] = p;
            heap.push(next, q);
          }
        }
      }
      final (:branches, :forks) = _branchesFrom(
        seed,
        touched,
        distance,
        parent,
        label,
        width,
        math.min(near.toDouble(), explore * .8),
        fitFrom: fitFrom,
        fitTo: fitTo,
        stops: stops,
        junction: junction,
        halfWidth: halfWidth,
        ink: ink,
        lineHalf: lineHalf,
      );
      if (branches.length < 2) continue;

      // The pool lies inside each acute or right angle between two
      // neighbouring lines, on each line's side facing the other (+1: to its
      // left).
      final order = List.generate(branches.length, (k) => k)
        ..sort((a, b) => branches[a].angle.compareTo(branches[b].angle));
      final sides = List.generate(
        branches.length,
        (_) => <({int side, int other, double mx, double my})>[],
      );
      for (var k = 0; k < order.length; k++) {
        final a = order[k], b = order[(k + 1) % order.length];
        if (a == b) continue;
        var gap = branches[b].angle - branches[a].angle;
        if (gap <= 0) gap += 2 * math.pi;
        if (gap >= _angleLimit) continue;
        // Where the two lines really meet: thinning moves the seed a little
        // off it. A crossing thins to forks round it; a corner is where the
        // two lines run into each other.
        final (mx, my) = forks ?? _meeting(branches[a], branches[b], merge);
        // b lies counterclockwise of a, by up to a right angle.
        sides[a].add((side: 1, other: b, mx: mx, my: my));
        sides[b].add((side: -1, other: a, mx: mx, my: my));
      }
      final guard = centreWidth + 2 * lineHalf + 2;
      // The distance to the nearest pixel off the line overstates its half
      // width (by a pixel where the edge is anti-aliased): the pool may run
      // under the line, no further.
      final spare = math.max(.3, lineHalf - 1);
      final stamps =
          <
            ({
              int id,
              int entry,
              int k,
              double x,
              double y,
              double tx,
              double ty,
              double ox,
              double oy,
              double along,
              double edge,
            })
          >[];
      for (final q in touched) {
        final id = label[q];
        if (id < 0 || sides[id].isEmpty) continue;
        final d = distance[q];
        // Next to another meeting point the line bends into it: that one
        // pools by itself.
        if (d > branches[id].end) continue;
        final x = q % width, y = q ~/ width;
        // Along the line here.
        double tx, ty;
        if (d < branches[id].start) {
          (tx, ty) = (branches[id].dx, branches[id].dy);
        } else if (branches[id].directionAt(d) case final t?) {
          (tx, ty) = t;
        } else {
          // Towards this pixel from a few pixels back.
          var back = q;
          for (var k = 0; k < 3; k++) {
            back = parent[back];
          }
          tx = (x - back % width).toDouble();
          ty = (y - back ~/ width).toDouble();
          final length = math.sqrt(tx * tx + ty * ty);
          if (length < 1.5) {
            (tx, ty) = (branches[id].dx, branches[id].dy);
          } else {
            tx /= length;
            ty /= length;
          }
        }
        for (var entry = 0; entry < sides[id].length; entry++) {
          final (:side, :other, :mx, :my) = sides[id][entry];
          // How far along the line this is from where the lines meet: in a
          // straight line from there, unless the line curls back (the walk
          // along it is then clearly longer; a walk of pixel steps along a
          // slanted line overstates the length by up to about 15 %).
          final ex = x - sx - mx, ey = y - sy - my;
          final along = math.max(
            math.sqrt(ex * ex + ey * ey),
            (d - math.sqrt(mx * mx + my * my)) * .85,
          );
          // Slices just past the end still carry its last pixel.
          if (along > range + 1.5) continue;
          // Towards the other line: this line's left or right, wherever the
          // line curves to.
          final ox = -ty * side, oy = tx * side;
          stamps.add((
            id: id,
            entry: entry,
            k: d.round(),
            x: x + .5,
            y: y + .5,
            tx: tx,
            ty: ty,
            ox: ox,
            oy: oy,
            along: along,
            edge: _edgeAlong(ink, width, height, q, ox, oy, halfWidth[q] + 1),
          ));
        }
      }
      // The line's edge, measured from centre pixels that step from side to
      // side of a slanted line, is evened out along the line: where the
      // edge is, from a few slices either side, seen from this slice.
      final byStep = <int, List<int>>{};
      int key(int id, int entry, int k) => (id * 4 + entry) * 100000 + k;
      for (var i = 0; i < stamps.length; i++) {
        final st = stamps[i];
        (byStep[key(st.id, st.entry, st.k)] ??= []).add(i);
      }
      for (final st in stamps) {
        var sum = 0.0, count = 0;
        for (var k = st.k - 2; k <= st.k + 2; k++) {
          for (final j in byStep[key(st.id, st.entry, k)] ?? const <int>[]) {
            final other = stamps[j];
            final ex = other.x + other.ox * other.edge - st.x;
            final ey = other.y + other.oy * other.edge - st.y;
            sum += ex * st.ox + ey * st.oy;
            count++;
          }
        }
        final edge = count == 0 ? st.edge : sum / count;
        final (:side, :other, :mx, :my) = sides[st.id][st.entry];
        // A slice straight across the line, from just across its centre,
        // under the line, out past its inner edge by the pool's thickness;
        // the slices side by side along the line make the pool, so its
        // outline is exactly the taper.
        _stampSlice(
          coverage,
          width,
          height,
          st.x,
          st.y,
          st.tx,
          st.ty,
          st.ox,
          st.oy,
          edge: edge,
          along: st.along,
          centreWidth: centreWidth,
          range: range,
          // Near the meeting point a slice could reach round to the
          // outside: keep to the angle between the two lines there.
          inside: (px, py) => _withinAngle(
            px - (sx + .5 + mx),
            py - (sy + .5 + my),
            branches[st.id],
            branches[other],
            mx: mx,
            my: my,
            guard: guard,
            spare: spare,
          ),
        );
      }
    }

    final ca = (color >> 24) & 0xFF;
    final cr = (color >> 16) & 0xFF;
    final cg = (color >> 8) & 0xFF;
    final cb = color & 0xFF;
    for (var p = 0; p < n; p++) {
      final c = coverage[p];
      if (c <= 0) continue;
      final a = (ca * c).round();
      final i = p * 4;
      result[i] = (cr * a / 255).round();
      result[i + 1] = (cg * a / 255).round();
      result[i + 2] = (cb * a / 255).round();
      result[i + 3] = a;
    }
    return result;
  }

  /// 1 where there is line: opaque pixels on a transparent layer, dark ones
  /// on an opaque picture.
  static Uint8List _lineMask(Uint8List data, int n) {
    var opaque = 0;
    for (var i = 3; i < data.length; i += 4) {
      if (data[i] > _alphaThreshold) opaque++;
    }
    final mostlyOpaque = opaque / n > 0.85;
    final mask = Uint8List(n);
    for (var p = 0; p < n; p++) {
      final i = p * 4;
      final a = data[i + 3];
      if (a <= _alphaThreshold) continue;
      if (!mostlyOpaque) {
        mask[p] = 1;
      } else {
        final lum = data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114;
        if (lum < 210) mask[p] = 1;
      }
    }
    return mask;
  }

  /// The lines thinned to their 1 px centre (Zhang-Suen).
  static Uint8List _thin(Uint8List mask, int width, int height) {
    final image = Uint8List.fromList(mask);
    var foreground = <int>[
      for (var p = 0; p < image.length; p++)
        if (image[p] != 0) p,
    ];
    final remove = <int>[];
    for (var iteration = 0; iteration < 60; iteration++) {
      var changed = false;
      for (var pass = 0; pass < 2; pass++) {
        remove.clear();
        for (final p in foreground) {
          if (image[p] == 0) continue;
          final x = p % width;
          final y = p ~/ width;
          if (x == 0 || y == 0 || x == width - 1 || y == height - 1) continue;
          final p2 = image[p - width];
          final p3 = image[p - width + 1];
          final p4 = image[p + 1];
          final p5 = image[p + width + 1];
          final p6 = image[p + width];
          final p7 = image[p + width - 1];
          final p8 = image[p - 1];
          final p9 = image[p - width - 1];
          final neighbours = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9;
          if (neighbours < 2 || neighbours > 6) continue;
          final ring = [p2, p3, p4, p5, p6, p7, p8, p9, p2];
          var transitions = 0;
          for (var k = 0; k < 8; k++) {
            if (ring[k] == 0 && ring[k + 1] != 0) transitions++;
          }
          if (transitions != 1) continue;
          if (pass == 0) {
            if (p2 * p4 * p6 != 0 || p4 * p6 * p8 != 0) continue;
          } else {
            if (p2 * p4 * p8 != 0 || p2 * p6 * p8 != 0) continue;
          }
          remove.add(p);
        }
        for (final p in remove) {
          image[p] = 0;
        }
        if (remove.isNotEmpty) changed = true;
      }
      if (!changed) break;
      foreground = [
        for (final p in foreground)
          if (image[p] != 0) p,
      ];
    }
    return image;
  }

  /// How close two forks are taken as one crossing: within [near], or
  /// within the width of the line at the fork (a crossing of thick lines
  /// thins to two forks joined by a bridge about that long).
  static double _mergeRadius(int near, double halfWidth) =>
      math.max(near.toDouble(), 3 * halfWidth + 2);

  /// About half the width of the lines meeting at [p]: measured on their
  /// centres a little way out, as the meeting point itself is a wider blot.
  static double _lineHalfWidth(
    Uint8List centre,
    Uint8List junction,
    Float32List halfWidth,
    int width,
    int p,
  ) {
    final px = p % width, py = p ~/ width;
    final height = centre.length ~/ width;
    final values = <double>[];
    for (
      var y = math.max(0, py - 14);
      y <= math.min(height - 1, py + 14);
      y++
    ) {
      for (
        var x = math.max(0, px - 14);
        x <= math.min(width - 1, px + 14);
        x++
      ) {
        final q = y * width + x;
        if (centre[q] == 0 || junction[q] != 0) continue;
        final dx = x - px, dy = y - py;
        final r2 = dx * dx + dy * dy;
        if (r2 < 36 || r2 > 196) continue;
        values.add(halfWidth[q]);
      }
    }
    if (values.isEmpty) return halfWidth[p];
    values.sort();
    return values[values.length ~/ 2];
  }

  /// Where lines [a] and [b] meet, from the seed: where the straight lines
  /// they come in along cross, unless that is further than [limit] away (the
  /// seed then).
  static (double, double) _meeting(_Branch a, _Branch b, double limit) {
    final denominator = a.dx * b.dy - a.dy * b.dx;
    if (denominator.abs() < 1e-3) return (0, 0);
    final s = ((b.x - a.x) * b.dy - (b.y - a.y) * b.dx) / denominator;
    final mx = a.x + a.dx * s, my = a.y + a.dy * s;
    if (mx * mx + my * my > limit * limit) return (0, 0);
    return (mx, my);
  }

  /// Where lines meet, on the lines' centres: a junction (three or more lines
  /// leave it: a T, a Y, a crossing), or a corner (two lines leave it at
  /// about a right angle or sharper, near it and further along alike, so a
  /// tight curve that only looks like a corner close up does not count).
  /// Whether ink pools there is decided later, from the angles between the
  /// lines measured more carefully.
  static List<int> _meetingPoints(
    Uint8List centre,
    Uint8List junction,
    Float32List halfWidth,
    int width,
    int height,
    int near,
  ) {
    final candidates = <({int p, double score})>[];
    for (var p = 0; p < centre.length; p++) {
      if (centre[p] == 0) continue;
      final x = p % width;
      final y = p ~/ width;
      if (x == 0 || y == 0 || x == width - 1 || y == height - 1) continue;
      if (junction[p] != 0) {
        // Junctions come first; among their pixels, the one where most
        // lines leave.
        candidates.add((p: p, score: 10.0 + _branchCount(centre, width, p)));
        continue;
      }
      if (_branchCount(centre, width, p) != 2) continue;
      final close = _branchEnds(centre, width, height, p, near);
      if (close.length != 2 || close.any((e) => e.reach < near * .75)) {
        continue;
      }
      // A right angle measures a little wider on the thinned line, whose
      // corner is cut off diagonally.
      final angle = _angleAt(x, y, close[0], close[1]);
      if (angle > math.pi / 2 + .35) continue;
      final away = _branchEnds(centre, width, height, p, near * 2);
      if (away.length == 2 && away.every((e) => e.reach >= near * 1.5)) {
        if (_angleAt(x, y, away[0], away[1]) > math.pi / 2 + .3) continue;
      }
      candidates.add((p: p, score: math.pi - angle));
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final seeds = <int>[];
    for (final c in candidates) {
      final cx = c.p % width, cy = c.p ~/ width;
      final crowded = seeds.any((s) {
        final dx = s % width - cx, dy = s ~/ width - cy;
        final merge = _mergeRadius(
          near,
          _lineHalfWidth(centre, junction, halfWidth, width, s),
        );
        return dx * dx + dy * dy <= merge * merge;
      });
      if (!crowded) seeds.add(c.p);
    }
    return seeds;
  }

  /// How many lines leave centre pixel [p]: the runs of line pixels round it.
  static int _branchCount(Uint8List centre, int width, int p) {
    final ring = [
      centre[p - width],
      centre[p - width + 1],
      centre[p + 1],
      centre[p + width + 1],
      centre[p + width],
      centre[p + width - 1],
      centre[p - 1],
      centre[p - width - 1],
    ];
    var runs = 0;
    for (var k = 0; k < 8; k++) {
      if (ring[k] == 0 && ring[(k + 1) % 8] != 0) runs++;
    }
    return runs;
  }

  /// Following each line leaving centre pixel [p] for [length] px along the
  /// centre: where each one got to (the mean of its farthest pixels) and how
  /// far it went.
  static List<({double x, double y, double reach})> _branchEnds(
    Uint8List centre,
    int width,
    int height,
    int p,
    int length,
  ) {
    final distance = <int, double>{p: 0};
    final branch = <int, int>{};
    final heap = _MinHeap()..push(0, p);
    // Which run of line pixels round [p] each neighbour is in, by its place
    // in a 3 x 3 block.
    const ring = [
      (0, -1),
      (1, -1),
      (1, 0),
      (1, 1),
      (0, 1),
      (-1, 1),
      (-1, 0),
      (-1, -1),
    ];
    final px = p % width, py = p ~/ width;
    bool on((int, int) o) => centre[(py + o.$2) * width + px + o.$1] != 0;
    final firstStep = List<int>.filled(9, -1);
    final start = List.generate(
      8,
      (k) => k,
    ).firstWhere((k) => !on(ring[k]), orElse: () => 0);
    var branches = 0;
    var inRun = false;
    for (var step = 1; step <= 8; step++) {
      final o = ring[(start + step) % 8];
      if (on(o)) {
        if (!inRun) branches++;
        inRun = true;
        firstStep[(o.$2 + 1) * 3 + o.$1 + 1] = branches - 1;
      } else {
        inRun = false;
      }
    }
    while (heap.isNotEmpty) {
      final (d, q) = heap.pop();
      if (d > (distance[q] ?? double.infinity)) continue;
      final qx = q % width, qy = q ~/ width;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = qx + dx, ny = qy + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final r = ny * width + nx;
          if (centre[r] == 0) continue;
          final next = d + (dx != 0 && dy != 0 ? math.sqrt2 : 1.0);
          if (next > length || next >= (distance[r] ?? double.infinity)) {
            continue;
          }
          distance[r] = next;
          // A first step starts a line: the run of line pixels round [p]
          // it belongs to.
          branch[r] = q == p ? firstStep[(dy + 1) * 3 + dx + 1] : branch[q]!;
          heap.push(next, r);
        }
      }
    }
    final ends = <({double x, double y, double reach})>[];
    for (var b = 0; b < branches; b++) {
      var reach = 0.0;
      for (final e in distance.entries) {
        if (branch[e.key] == b && e.value > reach) reach = e.value;
      }
      var sx = 0.0, sy = 0.0, count = 0;
      for (final e in distance.entries) {
        if (branch[e.key] == b && e.value >= reach - 1.5) {
          sx += e.key % width;
          sy += e.key ~/ width;
          count++;
        }
      }
      if (count > 0) ends.add((x: sx / count, y: sy / count, reach: reach));
    }
    return ends;
  }

  /// The angle at ([x], [y]) between the directions to [a] and [b].
  static double _angleAt(
    int x,
    int y,
    ({double x, double y, double reach}) a,
    ({double x, double y, double reach}) b,
  ) {
    final ax = a.x - x, ay = a.y - y, bx = b.x - x, by = b.y - y;
    final la = math.sqrt(ax * ax + ay * ay), lb = math.sqrt(bx * bx + by * by);
    if (la == 0 || lb == 0) return math.pi;
    return math.acos(((ax * bx + ay * by) / (la * lb)).clamp(-1.0, 1.0));
  }

  /// The lines leaving [seed]: the centre pixels [ringDistance] along them
  /// fall into one group per line. Every reached pixel is labelled with its
  /// line in [label] (-1 for none). Each line's direction at the meeting
  /// point is measured from its centre pixels between [fitFrom] and [fitTo]
  /// along it, stopping short of the next meeting point along it ([stops]),
  /// where the thinning bends the line again.
  static ({List<_Branch> branches, (double, double)? forks}) _branchesFrom(
    int seed,
    List<int> touched,
    Float64List distance,
    Int32List parent,
    Int32List label,
    int width,
    double ringDistance, {
    required double fitFrom,
    required double fitTo,
    required List<int> stops,
    required Uint8List junction,
    required Float32List halfWidth,
    required Float32List ink,
    required double lineHalf,
  }) {
    for (final p in touched) {
      label[p] = -1;
    }
    final ring = [
      for (final p in touched)
        if (distance[p] <= ringDistance && distance[p] > ringDistance - 1.5) p,
    ];
    final ringSet = ring.toSet();
    final ringDirections = <(double, double)>[];
    for (final start in ring) {
      if (label[start] >= 0) continue;
      final id = ringDirections.length;
      final group = <int>[start];
      label[start] = id;
      for (var head = 0; head < group.length; head++) {
        final p = group[head];
        final x = p % width, y = p ~/ width;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final q = (y + dy) * width + x + dx;
            if (ringSet.contains(q) && label[q] < 0) {
              label[q] = id;
              group.add(q);
            }
          }
        }
      }
      var sx = 0.0, sy = 0.0;
      for (final p in group) {
        sx += p % width - seed % width;
        sy += p ~/ width - seed ~/ width;
      }
      ringDirections.add((sx / group.length, sy / group.length));
    }
    // The way in from each group towards the seed is that line's too.
    for (final p in ring) {
      final id = label[p];
      var q = parent[p];
      while (q != seed && label[q] < 0) {
        label[q] = id;
        q = parent[q];
      }
    }
    // Beyond the groups, a pixel belongs to the line it was reached along.
    final order = List.of(touched)
      ..sort((a, b) => distance[a].compareTo(distance[b]));
    for (final p in order) {
      if (label[p] >= 0 || p == seed) continue;
      label[p] = label[parent[p]];
    }

    // Where each line is at each whole distance along it, and the points to
    // measure its direction from.
    final count = ringDirections.length;
    // A line is measured from [fitFrom] past the last fork of this meeting
    // point on its way out (a crossing of thick lines thins to two forks)
    // for as far again as from [fitFrom] to [fitTo], and stops short of the
    // next meeting point.
    final stopSet = stops.toSet();
    final fitEnd = Float64List(count)..fillRange(0, count, double.infinity);
    for (final p in stops) {
      final id = label[p];
      if (id < 0) continue;
      fitEnd[id] = math.min(fitEnd[id], distance[p] - 1.5 * halfWidth[p] - 1);
    }
    // A path can cut the corner past a fork pixel, so passing next to one
    // counts.
    bool atFork(int p) {
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final q = p + dy * width + dx;
          if (q < 0 || q >= junction.length) continue;
          if (junction[q] != 0 && !stopSet.contains(q)) return true;
        }
      }
      return false;
    }

    final lastFork = <int, double>{seed: 0};
    for (final p in order) {
      if (p == seed) continue;
      lastFork[p] = atFork(p) ? distance[p] : lastFork[parent[p]] ?? 0;
    }
    final fitStart = Float64List(count)..fillRange(0, count, double.infinity);
    var longest = fitTo;
    for (final p in touched) {
      longest = math.max(longest, distance[p]);
    }
    final steps = (longest + 2).ceil();
    final sumX = List.generate(count, (_) => Float64List(steps + 1));
    final sumY = List.generate(count, (_) => Float64List(steps + 1));
    final hits = List.generate(count, (_) => Int32List(steps + 1));
    final samples = List.generate(count, (_) => <(double, double, double)>[]);
    final sx = seed % width, sy = seed ~/ width;
    for (final p in touched) {
      final id = label[p];
      if (id < 0) continue;
      final d = distance[p];
      final x = (p % width - sx).toDouble(), y = (p ~/ width - sy).toDouble();
      final k = d.floor();
      if (k <= steps) {
        sumX[id][k] += x;
        sumY[id][k] += y;
        hits[id][k]++;
      }
      final out = d - lastFork[p]!;
      if (out >= fitFrom && out <= fitTo && d <= fitEnd[id]) {
        // Thinning leaves the centre pixels up to half a pixel to one side
        // of a slanted line; measured on the line's ink they are exact,
        // which matters where two lines meet at a sharp angle.
        final (ux, uy) = _unit(ringDirections[id]);
        final across = _inkCentre(ink, width, p, -uy, ux, lineHalf + 1.5);
        samples[id].add((d, x - uy * across, y + ux * across));
        fitStart[id] = math.min(fitStart[id], d);
      }
    }
    // The meeting point as near as the thinning tells it: the middle of
    // its forks (a crossing thins to two), or the seed itself.
    var anchorX = 0.0, anchorY = 0.0, forks = 0;
    for (final p in touched) {
      if (junction[p] == 0 || stopSet.contains(p)) continue;
      anchorX += p % width - sx;
      anchorY += p ~/ width - sy;
      forks++;
    }
    if (forks > 0) {
      anchorX /= forks;
      anchorY /= forks;
    }
    final fitted = [
      for (final list in samples) _tangent(list, anchorX, anchorY),
    ];
    final directions = [
      for (var id = 0; id < count; id++)
        if (fitted[id] case final f?)
          (f.dx, f.dy)
        else
          _unit(ringDirections[id]),
    ];
    // Where each line is at distance 0 if it went straight on into the
    // meeting point (the seed itself when not measured).
    final origins = [
      for (var id = 0; id < count; id++)
        if (fitted[id] case final f?) (f.x, f.y) else (0.0, 0.0),
    ];
    // Two lines leaving in about opposite directions are one line through
    // the meeting point (a crossing, the bar of a T): its direction there is
    // measured on both sides, the longer measurement counting for more, and
    // a side too short to see the line turn (the bit between two crossings
    // close together) mostly takes the other side's.
    double weight(int id) {
      final span = fitted[id]?.span ?? 0;
      return span >= 10 ? span : span * .1 + .01;
    }

    int? oppositeOf(int id) {
      int? best;
      var bestCos = -math.cos(math.pi / 6);
      final (ux, uy) = directions[id];
      for (var other = 0; other < count; other++) {
        if (other == id) continue;
        final (vx, vy) = directions[other];
        final c = ux * vx + uy * vy;
        if (c < bestCos) {
          bestCos = c;
          best = other;
        }
      }
      return best;
    }

    final opposite = [for (var id = 0; id < count; id++) oppositeOf(id)];
    final joined = [for (final d in directions) d];
    for (var a = 0; a < count; a++) {
      final b = opposite[a];
      if (b == null || opposite[b] != a || b < a) continue;
      final wa = weight(a), wb = weight(b);
      final (ax, ay) = directions[a];
      final (bx, by) = directions[b];
      final (ux, uy) = _unit((wa * ax - wb * bx, wa * ay - wb * by));
      joined[a] = (ux, uy);
      joined[b] = (-ux, -uy);
      // A side never measured starts where the other side's line runs.
      if (fitted[a] == null && fitted[b] != null) origins[a] = origins[b];
      if (fitted[b] == null && fitted[a] != null) origins[b] = origins[a];
    }
    for (var id = 0; id < count; id++) {
      directions[id] = joined[id];
    }
    final branches = [
      for (var id = 0; id < count; id++)
        _Branch(
          directions[id],
          origins[id],
          Float64List.fromList([
            for (var k = 0; k <= steps; k++)
              hits[id][k] == 0 ? double.nan : sumX[id][k] / hits[id][k],
          ]),
          Float64List.fromList([
            for (var k = 0; k <= steps; k++)
              hits[id][k] == 0 ? double.nan : sumY[id][k] / hits[id][k],
          ]),
          fitStart[id].isFinite ? fitStart[id] : fitFrom,
          fitEnd[id],
          straight:
              fitted[id] != null &&
              !fitted[id]!.curved &&
              fitted[id]!.span >= 10,
        ),
    ];
    return (branches: branches, forks: forks > 0 ? (anchorX, anchorY) : null);
  }

  static (double, double) _unit((double, double) v) {
    final l = math.sqrt(v.$1 * v.$1 + v.$2 * v.$2);
    return l == 0 ? (1, 0) : (v.$1 / l, v.$2 / l);
  }

  /// The direction a line leaves its meeting point (at [anchorX],
  /// [anchorY]) in, from points along it ([samples]: the distance along the
  /// line, x, y), and the point on it nearest the meeting point. A straight
  /// line is fitted to them; where the nearer and the further half clearly
  /// turn (the rim of a ring), the turn is followed back to the meeting
  /// point. A step of the pixels in a straight line turns them too little
  /// to count. Null with too few points.
  static ({double dx, double dy, double x, double y, double span, bool curved})?
  _tangent(
    List<(double, double, double)> samples,
    double anchorX,
    double anchorY,
  ) {
    final whole = _lineFit(samples);
    if (whole == null) return null;
    var minD = double.infinity, maxD = -double.infinity;
    for (final (d, _, _) in samples) {
      minD = math.min(minD, d);
      maxD = math.max(maxD, d);
    }
    final span = maxD - minD;
    final middle = (minD + maxD) / 2;
    final nearer = _lineFit([
      for (final s in samples)
        if (s.$1 < middle) s,
    ]);
    final further = _lineFit([
      for (final s in samples)
        if (s.$1 >= middle) s,
    ]);
    if (nearer != null && further != null && span >= 10) {
      var turn = further.angle - nearer.angle;
      while (turn > math.pi) {
        turn -= 2 * math.pi;
      }
      while (turn < -math.pi) {
        turn += 2 * math.pi;
      }
      final between = math.sqrt(
        math.pow(further.x - nearer.x, 2) + math.pow(further.y - nearer.y, 2),
      );
      if (turn.abs() > 8 * math.pi / 180 &&
          turn.abs() < math.pi / 2 &&
          between > 3) {
        // The line turns evenly: by as much again per pixel back to the
        // meeting point, and the chord back to there from the nearer
        // half's middle.
        final back = math.sqrt(
          math.pow(nearer.x - anchorX, 2) + math.pow(nearer.y - anchorY, 2),
        );
        final angle = nearer.angle - turn / between * back;
        final chord = (angle + nearer.angle) / 2;
        return (
          dx: math.cos(angle),
          dy: math.sin(angle),
          x: nearer.x - back * math.cos(chord),
          y: nearer.y - back * math.sin(chord),
          span: span,
          curved: true,
        );
      }
    }
    // Straight: the point on the line nearest the meeting point.
    final ux = math.cos(whole.angle), uy = math.sin(whole.angle);
    final along = (anchorX - whole.x) * ux + (anchorY - whole.y) * uy;
    return (
      dx: ux,
      dy: uy,
      x: whole.x + along * ux,
      y: whole.y + along * uy,
      span: span,
      curved: false,
    );
  }

  /// A straight line through points along a line: its direction (as an
  /// angle, the way the distance grows), the mean distance and the point on
  /// it there. Null when the points do not reach 3 px along.
  static ({double angle, double mean, double x, double y})? _lineFit(
    List<(double, double, double)> samples,
  ) {
    if (samples.length < 4) return null;
    var mean = 0.0, minD = double.infinity, maxD = -double.infinity;
    for (final (d, _, _) in samples) {
      mean += d;
      minD = math.min(minD, d);
      maxD = math.max(maxD, d);
    }
    mean /= samples.length;
    if (maxD - minD < 3) return null;
    final lineX = _polyFit(samples, mean, 1, (s) => s.$2);
    final lineY = _polyFit(samples, mean, 1, (s) => s.$3);
    if (lineX == null || lineY == null) return null;
    if (lineX[1] == 0 && lineY[1] == 0) return null;
    return (
      angle: math.atan2(lineY[1], lineX[1]),
      mean: mean,
      x: lineX[0],
      y: lineY[0],
    );
  }

  /// The least-squares polynomial of [degree] in (distance - [mean]) through
  /// the samples' [value]s: its coefficients from the constant up, or null
  /// when they do not decide it.
  static List<double>? _polyFit(
    List<(double, double, double)> samples,
    double mean,
    int degree,
    double Function((double, double, double)) value,
  ) {
    final n = degree + 1;
    final a = List.generate(n, (_) => Float64List(n + 1));
    for (final s in samples) {
      final t = s.$1 - mean;
      final powers = [1.0, t, t * t];
      final v = value(s);
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          a[r][c] += powers[r] * powers[c];
        }
        a[r][n] += powers[r] * v;
      }
    }
    // Gauss-Jordan elimination with partial pivoting.
    for (var c = 0; c < n; c++) {
      var pivot = c;
      for (var r = c + 1; r < n; r++) {
        if (a[r][c].abs() > a[pivot][c].abs()) pivot = r;
      }
      if (a[pivot][c].abs() < 1e-9) return null;
      final swap = a[c];
      a[c] = a[pivot];
      a[pivot] = swap;
      for (var r = 0; r < n; r++) {
        if (r == c) continue;
        final f = a[r][c] / a[c][c];
        for (var k = c; k <= n; k++) {
          a[r][k] -= f * a[c][k];
        }
      }
    }
    return [for (var r = 0; r < n; r++) a[r][n] / a[r][r]];
  }

  /// Whether the offset ([x], [y]) from the meeting point (at [mx], [my]
  /// from the seed), on line [a]'s side towards line [b], lies in the angle
  /// between them (the smaller one), or under line [b] itself ([spare] px
  /// across its centre); offsets further than [guard] always do. The sides
  /// of the angle follow the lines as they curve.
  static bool _withinAngle(
    double x,
    double y,
    _Branch a,
    _Branch b, {
    required double mx,
    required double my,
    required double guard,
    required double spare,
  }) {
    final r = math.sqrt(x * x + y * y);
    if (r > guard || r < 1) return true;
    final (ax, ay) = a.towards(r, mx, my);
    final (bx, by) = b.towards(r, mx, my);
    double cross(double ux, double uy, double vx, double vy) =>
        ux * vy - uy * vx;
    final ab = cross(ax, ay, bx, by).sign;
    if (ab == 0) return true;
    // A slice of line a's pool is on a's side towards b already: inside the
    // angle it is on a's side of b too.
    return cross(bx, by, x, y) * -ab > -spare;
  }

  /// How far the line reaches from the centre of pixel [p] in direction
  /// ([ox], [oy]): the distance to its edge, from its [ink] (0 to 1, read
  /// between pixel centres), at most [limit] (so that near a meeting point
  /// the walk does not run on down the other line).
  static double _edgeAlong(
    Float32List ink,
    int width,
    int height,
    int p,
    double ox,
    double oy,
    double limit,
  ) {
    final cx = p % width + .5, cy = p ~/ width + .5;
    double inkAt(double x, double y) {
      final fx = x - .5, fy = y - .5;
      final x0 = fx.floor(), y0 = fy.floor();
      final ax = fx - x0, ay = fy - y0;
      double at(int px, int py) =>
          px < 0 || py < 0 || px >= width || py >= height
          ? 0
          : ink[py * width + px];
      return (at(x0, y0) * (1 - ax) + at(x0 + 1, y0) * ax) * (1 - ay) +
          (at(x0, y0 + 1) * (1 - ax) + at(x0 + 1, y0 + 1) * ax) * ay;
    }

    // As much ink as there is from the centre out, laid solid: exact for a
    // hard-edged line and for an anti-aliased one alike.
    var reach = inkAt(cx, cy) * .05;
    for (var s = .1; s < limit; s += .1) {
      final value = inkAt(cx + ox * s, cy + oy * s);
      if (value < .02) break;
      reach += value * .1;
    }
    return math.min(reach, limit);
  }

  /// How far across the line (along ([nx], [ny]), up to [limit] px either
  /// way) the middle of its ink is from the centre of pixel [p]: only the
  /// run of ink through that pixel counts, not another line beside it.
  static double _inkCentre(
    Float32List ink,
    int width,
    int p,
    double nx,
    double ny,
    double limit,
  ) {
    final height = ink.length ~/ width;
    final cx = p % width + .5, cy = p ~/ width + .5;
    double inkAt(double x, double y) {
      final fx = x - .5, fy = y - .5;
      final x0 = fx.floor(), y0 = fy.floor();
      final ax = fx - x0, ay = fy - y0;
      double at(int px, int py) =>
          px < 0 || py < 0 || px >= width || py >= height
          ? 0
          : ink[py * width + px];
      return (at(x0, y0) * (1 - ax) + at(x0 + 1, y0) * ax) * (1 - ay) +
          (at(x0, y0 + 1) * (1 - ax) + at(x0 + 1, y0 + 1) * ax) * ay;
    }

    var sum = 0.0, weight = 0.0;
    for (final direction in [1.0, -1.0]) {
      for (
        var t = direction > 0 ? 0.0 : -.25;
        t.abs() <= limit;
        t += .25 * direction
      ) {
        final v = inkAt(cx + nx * t, cy + ny * t);
        if (v < .1) break;
        sum += v * t;
        weight += v;
      }
    }
    return weight == 0 ? 0 : sum / weight;
  }

  /// How much line there is at each pixel, 0 to 1: its opacity on a
  /// transparent layer, its darkness on an opaque picture.
  static Float32List _ink(Uint8List data, int n) {
    var opaque = 0;
    for (var i = 3; i < data.length; i += 4) {
      if (data[i] > _alphaThreshold) opaque++;
    }
    final mostlyOpaque = opaque / n > 0.85;
    final ink = Float32List(n);
    for (var p = 0; p < n; p++) {
      final i = p * 4;
      final a = data[i + 3];
      if (!mostlyOpaque) {
        ink[p] = a / 255;
      } else if (a > 0) {
        final lum =
            (data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114) *
            255 /
            a;
        ink[p] = (1 - lum / 255).clamp(0.0, 1.0) * a / 255;
      }
    }
    return ink;
  }

  /// For each line pixel, the distance from its centre to the nearest pixel
  /// that is not line (chamfer 3-4, in pixels): about half the line's width
  /// on its centre line.
  static Float32List _distanceToBackground(
    Uint8List mask,
    int width,
    int height,
  ) {
    const big = 1 << 28;
    final d = Int32List(width * height);
    for (var p = 0; p < d.length; p++) {
      d[p] = mask[p] == 0 ? 0 : big;
    }
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = y * width + x;
        if (d[p] == 0) continue;
        var best = d[p];
        if (x > 0) best = math.min(best, d[p - 1] + 3);
        if (y > 0) {
          best = math.min(best, d[p - width] + 3);
          if (x > 0) best = math.min(best, d[p - width - 1] + 4);
          if (x < width - 1) best = math.min(best, d[p - width + 1] + 4);
        }
        d[p] = best;
      }
    }
    for (var y = height - 1; y >= 0; y--) {
      for (var x = width - 1; x >= 0; x--) {
        final p = y * width + x;
        if (d[p] == 0) continue;
        var best = d[p];
        if (x < width - 1) best = math.min(best, d[p + 1] + 3);
        if (y < height - 1) {
          best = math.min(best, d[p + width] + 3);
          if (x < width - 1) best = math.min(best, d[p + width + 1] + 4);
          if (x > 0) best = math.min(best, d[p + width - 1] + 4);
        }
        d[p] = best;
      }
    }
    final out = Float32List(d.length);
    for (var p = 0; p < d.length; p++) {
      // Pixels on the image's border with no background in reach count as
      // a line one pixel wide.
      out[p] = d[p] >= big ? 1 : d[p] / 3;
    }
    return out;
  }

  /// An anti-aliased slice of the pool across a line at ([cx], [cy]), [along]
  /// px from where the lines meet: from the line's centre, under the line, out along ([ox], [oy]) past its edge (at [edge]) by the
  /// pool's thickness there, the full [centreWidth] where the lines meet
  /// thinning in a straight slope to 1 px at [range]. The slice is about two
  /// pixels wide along the line ([tx], [ty], pointing away from where they
  /// meet) and tapers across that width too, so slices side by side (a
  /// diagonal pixel step apart too) join up and their outer edge is the
  /// slope itself. Kept where it covers more than what is already there.
  static void _stampSlice(
    Float32List coverage,
    int width,
    int height,
    double cx,
    double cy,
    double tx,
    double ty,
    double ox,
    double oy, {
    required double edge,
    required double along,
    required double centreWidth,
    required double range,
    bool Function(double x, double y)? inside,
  }) {
    double thicknessAt(double s) =>
        1 + (centreWidth - 1) * (1 - s.clamp(0.0, range) / range);
    // Half the slice's width along the line: a diagonal step apart, and
    // wider further out, where slices round a curve fan apart.
    double halfAt(double b) => .9 + .1 * math.max(0.0, b);
    final to = edge + thicknessAt(along - halfAt(edge + centreWidth));
    final half = halfAt(to);
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final a in [-half, half]) {
      for (final b in [-.5, to]) {
        final x = cx + tx * a + ox * b, y = cy + ty * a + oy * b;
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
    final x0 = math.max(0, minX.floor() - 1);
    final x1 = math.min(width - 1, maxX.ceil() + 1);
    final y0 = math.max(0, minY.floor() - 1);
    final y1 = math.min(height - 1, maxY.ceil() + 1);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final px = x + .5 - cx, py = y + .5 - cy;
        final a = px * tx + py * ty;
        final b = px * ox + py * oy;
        // Side by side, the slices make one pool: only its far end (and its
        // outline) need smoothing.
        if (a.abs() > halfAt(b)) continue;
        final s = along + a;
        // 1 px thick right up to the end of the range, then gone.
        var c = (range + 1 - s).clamp(0.0, 1.0);
        // From the line's centre (fading in over the half pixel before it,
        // which the line covers).
        c = math.min(c, (b + .5).clamp(0.0, 1.0));
        c = math.min(c, (edge + thicknessAt(s) + .5 - b).clamp(0.0, 1.0));
        if (c <= 0) continue;
        if (inside != null && !inside(x + .5, y + .5)) continue;
        final q = y * width + x;
        if (c > coverage[q]) coverage[q] = c;
      }
    }
  }
}

/// A line leaving a meeting point.
class _Branch {
  _Branch(
    (double, double) direction,
    (double, double) origin,
    this.alongX,
    this.alongY,
    this.start,
    this.end, {
    required this.straight,
  }) : dx = direction.$1,
       dy = direction.$2,
       angle = math.atan2(direction.$2, direction.$1),
       x = origin.$1,
       y = origin.$2;

  /// Its direction at the meeting point (a unit vector) and that as an
  /// angle.
  final double dx, dy, angle;

  /// A point on it near the meeting point, relative to the seed: with
  /// [dx], [dy], the straight line it comes in along.
  final double x, y;

  /// Where its centre is at each whole distance along it, from the meeting
  /// point (NaN where unknown).
  final Float64List alongX, alongY;

  /// How far along it the thinning stops bending it round the meeting point,
  /// and starts bending it round the next one (infinity: none in reach).
  final double start, end;

  /// Measured straight: it runs in its direction at the meeting point all
  /// the way.
  final bool straight;

  /// Its direction about [d] px along it: on a curve, from where its centre
  /// is a few pixels either side (null where that is not known).
  (double, double)? directionAt(double d) {
    if (straight) return (dx, dy);
    final k = d.round();
    if (k - 5 < 0 || k + 5 >= alongX.length) return null;
    final x = alongX[k + 5] - alongX[k - 5], y = alongY[k + 5] - alongY[k - 5];
    if (x.isNaN || y.isNaN) return null;
    final l = math.sqrt(x * x + y * y);
    if (l < 2) return null;
    return (x / l, y / l);
  }

  /// The way from the meeting point ([mx], [my] from the seed) to where the
  /// line is about [r] px out: on a curve, the line itself rather than its
  /// first direction.
  (double, double) towards(double r, double mx, double my) {
    if (r < start) return (dx, dy);
    final k = r.round();
    for (final j in [k, k - 1, k + 1, k - 2, k + 2]) {
      if (j < 1 || j >= alongX.length) continue;
      final px = alongX[j] - mx, py = alongY[j] - my;
      if (px.isNaN) continue;
      final l = math.sqrt(px * px + py * py);
      if (l < 1) continue;
      return (px / l, py / l);
    }
    return (dx, dy);
  }
}

/// A binary min-heap of (distance, pixel).
class _MinHeap {
  final _keys = <double>[];
  final _values = <int>[];

  bool get isNotEmpty => _keys.isNotEmpty;

  void push(double key, int value) {
    _keys.add(key);
    _values.add(value);
    var i = _keys.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_keys[parent] <= _keys[i]) break;
      _swap(i, parent);
      i = parent;
    }
  }

  (double, int) pop() {
    final top = (_keys.first, _values.first);
    final lastKey = _keys.removeLast();
    final lastValue = _values.removeLast();
    if (_keys.isNotEmpty) {
      _keys[0] = lastKey;
      _values[0] = lastValue;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var smallest = i;
        if (l < _keys.length && _keys[l] < _keys[smallest]) smallest = l;
        if (r < _keys.length && _keys[r] < _keys[smallest]) smallest = r;
        if (smallest == i) break;
        _swap(i, smallest);
        i = smallest;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final k = _keys[a];
    _keys[a] = _keys[b];
    _keys[b] = k;
    final v = _values[a];
    _values[a] = _values[b];
    _values[b] = v;
  }
}
