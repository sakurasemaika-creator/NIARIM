import 'dart:math' as math;
import 'dart:typed_data';

/// 墨溜まり: where lines meet (a corner, a T, a crossing), ink pools inside
/// the angles between them. Along each line, on the side facing its
/// neighbour, the pool is as thick as [centreWidthPx] at the meeting point
/// and thins in a straight slope to 1 px at [rangePx], like a slide; it
/// never bulges out on the outside of a corner or above the bar of a T. The
/// result is the pool alone on a transparent layer (premultiplied RGBA), to
/// go under the line art.
class InkPoolEngine {
  InkPoolEngine._();

  static const int _alphaThreshold = 24;

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
    final centre = _thin(mask, width, height);
    final seeds = _meetingPoints(centre, width, height, centreWidth);
    if (seeds.isEmpty) return result;

    final coverage = Float32List(n);
    final distance = Float64List(n)..fillRange(0, n, double.infinity);
    final parent = Int32List(n);
    final label = Int32List(n);
    final touched = <int>[];
    final near = math.max(4, math.min(12, centreWidth.round() + 2));
    for (final seed in seeds) {
      for (final p in touched) {
        distance[p] = double.infinity;
      }
      touched.clear();
      // How far along the lines each centre pixel is from the meeting point,
      // and the way back to it.
      final heap = _MinHeap();
      distance[seed] = 0;
      parent[seed] = seed;
      touched.add(seed);
      heap.push(0, seed);
      while (heap.isNotEmpty) {
        final (d, p) = heap.pop();
        if (d > distance[p]) continue;
        final x = p % width;
        final y = p ~/ width;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
            final q = ny * width + nx;
            if (centre[q] == 0) continue;
            final next = d + (dx != 0 && dy != 0 ? math.sqrt2 : 1.0);
            if (next > range || next >= distance[q]) continue;
            if (distance[q] == double.infinity) touched.add(q);
            distance[q] = next;
            parent[q] = p;
            heap.push(next, q);
          }
        }
      }
      final branches = _branchesFrom(
        seed,
        touched,
        distance,
        parent,
        label,
        width,
        math.min(near.toDouble(), range * .8),
      );
      if (branches.length < 2) continue;

      // The pool lies inside each angle between two neighbouring lines that
      // is less than a straight line: inside a corner, and under the bar of
      // a T on both sides of its stem, never on the outside.
      final order = List.generate(branches.length, (k) => k)
        ..sort((a, b) => branches[a].angle.compareTo(branches[b].angle));
      final sides = List.generate(branches.length, (_) => <(double, double)>[]);
      for (var k = 0; k < order.length; k++) {
        final a = branches[order[k]];
        final b = branches[order[(k + 1) % order.length]];
        var gap = b.angle - a.angle;
        if (gap <= 0) gap += 2 * math.pi;
        if (gap >= math.pi - .15) continue;
        sides[order[k]].add((b.dx, b.dy));
        sides[(order[(k + 1) % order.length])].add((a.dx, a.dy));
      }
      for (final q in touched) {
        final id = label[q];
        if (id < 0 || sides[id].isEmpty) continue;
        final d = distance[q];
        final x = q % width, y = q ~/ width;
        // Along the line here: towards this pixel from a few pixels back.
        var back = q;
        for (var k = 0; k < 3; k++) {
          back = parent[back];
        }
        var tx = (x - back % width).toDouble(),
            ty = (y - back ~/ width).toDouble();
        var length = math.sqrt(tx * tx + ty * ty);
        if (length < 1.5) {
          tx = branches[id].dx;
          ty = branches[id].dy;
          length = math.sqrt(tx * tx + ty * ty);
        }
        if (length == 0) continue;
        tx /= length;
        ty /= length;
        // The pool's thickness here: the full width at the meeting point,
        // 1 px at the end of the range, all of it on the inner side.
        final thickness = 1 + (centreWidth - 1) * (1 - d / range);
        final radius = math.max(.25, (thickness - .5) / 2);
        for (final (nx, ny) in sides[id]) {
          // The side of the line facing the neighbouring line.
          final along = nx * tx + ny * ty;
          var ox = nx - along * tx, oy = ny - along * ty;
          final ol = math.sqrt(ox * ox + oy * oy);
          if (ol < 1e-6) continue;
          ox /= ol;
          oy /= ol;
          // From just across the centre line out to the pool's edge.
          final reach = math.max(0.0, radius - .5);
          _stampAt(
            coverage,
            width,
            height,
            x + .5 + ox * reach,
            y + .5 + oy * reach,
            radius,
            // Near the meeting point a disc could reach round to the
            // outside: keep to the angle between the two lines there.
            inside: (px, py) => _withinAngle(
              px - (seed % width + .5),
              py - (seed ~/ width + .5),
              branches[id],
              (dx: nx, dy: ny),
              guard: centreWidth + 2,
            ),
          );
        }
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

  /// Where lines meet, on the lines' centres: a junction (three or more lines
  /// leave it: a T, a Y, a crossing), or a corner (two lines leave it at a
  /// right angle or sharper, near it and further along alike, so a tight
  /// curve that only looks like a corner close up does not count).
  static List<int> _meetingPoints(
    Uint8List centre,
    int width,
    int height,
    double centreWidth,
  ) {
    final near = math.max(4, math.min(12, centreWidth.round() + 2));
    final candidates = <({int p, double score})>[];
    for (var p = 0; p < centre.length; p++) {
      if (centre[p] == 0) continue;
      final x = p % width;
      final y = p ~/ width;
      if (x == 0 || y == 0 || x == width - 1 || y == height - 1) continue;
      final branches = _branchCount(centre, width, p);
      if (branches >= 3) {
        // Junctions come first; among their pixels, the one where most
        // lines leave.
        candidates.add((p: p, score: 10.0 + branches));
        continue;
      }
      if (branches != 2) continue;
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
    final suppress = near * near;
    for (final c in candidates) {
      final cx = c.p % width, cy = c.p ~/ width;
      final crowded = seeds.any((s) {
        final dx = s % width - cx, dy = s ~/ width - cy;
        return dx * dx + dy * dy <= suppress;
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
  /// line in [label] (-1 for none); each line's direction is the way from the
  /// seed to its group.
  static List<({double dx, double dy, double angle})> _branchesFrom(
    int seed,
    List<int> touched,
    Float64List distance,
    Int32List parent,
    Int32List label,
    int width,
    double ringDistance,
  ) {
    for (final p in touched) {
      label[p] = -1;
    }
    final ring = [
      for (final p in touched)
        if (distance[p] <= ringDistance && distance[p] > ringDistance - 1.5) p,
    ];
    final ringSet = ring.toSet();
    final branches = <({double dx, double dy, double angle})>[];
    for (final start in ring) {
      if (label[start] >= 0) continue;
      final id = branches.length;
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
      sx /= group.length;
      sy /= group.length;
      branches.add((dx: sx, dy: sy, angle: math.atan2(sy, sx)));
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
    return branches;
  }

  /// Whether the offset ([x], [y]) from the meeting point lies in the angle
  /// between directions [a] and [b] (the smaller one), with a pixel to
  /// spare; offsets further than [guard] always do.
  static bool _withinAngle(
    double x,
    double y,
    ({double dx, double dy, double angle}) a,
    ({double dx, double dy}) b, {
    required double guard,
  }) {
    final r2 = x * x + y * y;
    if (r2 > guard * guard || r2 < 1) return true;
    // Inside the angle: on b's side of a, and on a's side of b.
    double cross(double ux, double uy, double vx, double vy) =>
        ux * vy - uy * vx;
    final ab = cross(a.dx, a.dy, b.dx, b.dy);
    final la = math.sqrt(a.dx * a.dx + a.dy * a.dy);
    final lb = math.sqrt(b.dx * b.dx + b.dy * b.dy);
    if (la == 0 || lb == 0) return true;
    final sideOfA = cross(a.dx, a.dy, x, y) / la * ab.sign;
    final sideOfB = cross(b.dx, b.dy, x, y) / lb * -ab.sign;
    return sideOfA > -1 && sideOfB > -1;
  }

  /// An anti-aliased disc of [radius] centred on ([cx], [cy]), kept where it
  /// covers more than what is already there.
  static void _stampAt(
    Float32List coverage,
    int width,
    int height,
    double cx,
    double cy,
    double radius, {
    bool Function(double x, double y)? inside,
  }) {
    final minX = math.max(0, (cx - radius - 1).floor());
    final maxX = math.min(width - 1, (cx + radius + 1).ceil());
    final minY = math.max(0, (cy - radius - 1).floor());
    final maxY = math.min(height - 1, (cy + radius + 1).ceil());
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final dx = x + .5 - cx, dy = y + .5 - cy;
        final c = (radius + .5 - math.sqrt(dx * dx + dy * dy)).clamp(0.0, 1.0);
        if (c <= 0) continue;
        if (inside != null && !inside(x + .5, y + .5)) continue;
        final q = y * width + x;
        if (c > coverage[q]) coverage[q] = c;
      }
    }
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
