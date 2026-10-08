import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Snaps a coarse lasso path onto the line art it was drawn along.
///
/// The user's lasso is a guide, not the boundary. It is resampled at even
/// steps, and at every sample the line art is scanned across the guide (along
/// its normal) within [radius]: each ink pixel met there is a place the
/// boundary could pass. One route through those places is then chosen for the
/// whole lasso at once (dynamic programming) by weighing, at every step:
///
/// * how far the point lies from the guide (the nearest line wins, so a lasso
///   drawn around the outside follows the outer contour, not inner lines);
/// * how far it moves sideways compared with the guide (the boundary keeps
///   the direction the user was heading in);
/// * how much of the stretch from the previous point is off the ink (the
///   boundary keeps following one continuous line).
///
/// A line crossing the contour therefore never captures it: getting onto it
/// means jumping sideways and leaving the ink, then doing so again to come
/// back. Where no line is within [radius], the guide itself is kept.
class LassoLineSnapEngine {
  const LassoLineSnapEngine();

  /// The whole snapped boundary for [guide] (the raw lasso points).
  List<Offset> snapPath({
    required List<Offset> guide,
    required Uint8List rgba,
    required int width,
    required int height,
    double radius = 18,
    int gapTolerancePx = 6,
  }) {
    if (guide.length < 2 || rgba.length < width * height * 4) {
      return List.of(guide);
    }
    final tracker = LassoLineSnapTracker(
      rgba: rgba,
      width: width,
      height: height,
      radius: radius,
      gapTolerancePx: gapTolerancePx,
    );
    guide.forEach(tracker.add);
    return tracker.closedPath;
  }
}

/// Builds the snapped lasso while it is being drawn.
///
/// Feed every raw pointer sample to [add]; [path] is the best boundary for
/// everything drawn so far, so the live preview and the final selection are
/// the same route. Each new sample costs a fixed amount of work, however long
/// the lasso already is.
class LassoLineSnapTracker {
  LassoLineSnapTracker({
    required this.rgba,
    required this.width,
    required this.height,
    required double radius,
    this.gapTolerancePx = 6,
  }) : radius = math.max(2, radius),
       step = (math.max(2, radius) / 8).clamp(1.5, 6.0),
       _disk = _diskOffsets(math.max(2, radius));

  /// The reference the boundary snaps to (RGBA, [width]×[height]).
  final Uint8List rgba;
  final int width;
  final int height;

  /// How far from the guide a line is still followed, in canvas px.
  final double radius;

  /// Distance between consecutive samples of the guide, in canvas px.
  final double step;

  /// User-configurable maximum consecutive empty pixels that may be crossed
  /// while treating a break in line art as one continuous contour.
  final int gapTolerancePx;

  int get _maxGapPixels => gapTolerancePx.clamp(0, 12);

  /// Keep a small additional budget for multiple tiny breaks on one route,
  /// while still making the single user setting the primary control.
  int get _maxTotalGapPixels => _maxGapPixels == 0 ? 0 : _maxGapPixels + 2;

  /// Most places considered across one sample.
  static const int _maxCandidates = 40;

  // Weights of the route's costs. Distances are measured in units of
  // [radius] or [step] so the behaviour does not depend on the canvas size.
  static const double _distanceWeight = 1.0;
  static const double _sidewaysWeight = 0.5;
  static const double _backwardWeight = 1.0;
  static const double _detourWeight = 0.5;
  static const double _gapWeight = 1.5;
  static const double _guideCost = 1.5;
  static const double _switchCost = 1.0;

  /// Pixel offsets within [radius], nearest first.
  final List<(int, int)> _disk;

  /// Lines already traced between two places, by their ends; the live
  /// preview asks for the same stretches on every move.
  final Map<(Offset, Offset), List<Offset>?> _traced = {};

  final List<Offset> _guide = [];
  final List<_Sample> _samples = [];
  Offset? _lastRaw;
  double _untilNextSample = 0;

  /// Adds the next raw pointer sample of the lasso.
  void add(Offset raw) {
    final last = _lastRaw;
    _lastRaw = raw;
    if (last == null) {
      _guide.add(raw);
      _untilNextSample = step;
      return;
    }
    final segment = raw - last;
    final length = segment.distance;
    if (length <= 0) return;
    var travelled = 0.0;
    while (length - travelled >= _untilNextSample) {
      travelled += _untilNextSample;
      _guide.add(last + segment * (travelled / length));
      _untilNextSample = step;
      _advance();
    }
    _untilNextSample -= length - travelled;
  }

  /// The finished boundary: [path], closed back to its start along the line
  /// art where the two ends lie on the same line.
  List<Offset> get closedPath {
    final open = path;
    if (open.length < 3) return open;
    final first = open.first;
    final last = open.last;
    if (_offInkLength(last, first) <= 1.5) return open;
    final closing = _isInkAt(first) && _isInkAt(last)
        ? _traceInk(last, first)
        : null;
    return closing == null ? open : [...open, ...closing];
  }

  /// The best boundary for the lasso drawn so far (open at its ends).
  List<Offset> get path {
    if (_samples.isEmpty) return List.of(_guide);
    var state = 0;
    var best = double.infinity;
    final last = _samples.last;
    for (var s = 0; s < last.cost.length; s++) {
      if (last.cost[s] < best) {
        best = last.cost[s];
        state = s;
      }
    }
    final points = List<Offset>.filled(_samples.length, Offset.zero);
    final onInk = List<bool>.filled(_samples.length, false);
    for (var i = _samples.length - 1; i >= 0; i--) {
      final sample = _samples[i];
      points[i] = sample.points[state];
      onInk[i] = state != sample.guideState;
      state = sample.from[state];
    }
    return _followInk(points, onInk);
  }

  /// The route, with every shortcut between two places on the line art
  /// replaced by the line itself.
  ///
  /// Samples only see the line across the guide, so where the guide passes
  /// a notch (a V-neck, an armpit) at a distance, the route can only cut
  /// straight across it, or fall back to the guide. When the line art
  /// connects the two ends of such a shortcut by a route not much longer
  /// than the shortcut, the boundary follows that line instead.
  List<Offset> _followInk(List<Offset> points, List<bool> onInk) {
    final out = <Offset>[];
    var i = 0;
    while (i < points.length) {
      out.add(points[i]);
      if (onInk[i]) {
        var j = i + 1;
        while (j < points.length && !onInk[j]) {
          j++;
        }
        if (j < points.length) {
          final bridged = j - i - 1;
          final shortcut = bridged > 0
              ? bridged <= _maxBridgedSamples
              : _offInkLength(points[i], points[j]) > 1.5;
          final line = shortcut ? _traceInk(points[i], points[j]) : null;
          if (line != null) {
            out.addAll(line);
            i = j;
            continue;
          }
        }
      }
      i++;
    }
    return out;
  }

  /// Most guide samples in a row that a traced line may replace.
  int get _maxBridgedSamples => (radius * 2 / step).ceil();

  /// The points along the line art from [a] to [b] (both excluded), or null
  /// when they are not joined by ink within a route about three times as
  /// long as the straight distance.
  List<Offset>? _traceInk(Offset a, Offset b) {
    final key = (a, b);
    if (_traced.containsKey(key)) return _traced[key];
    return _traced[key] = _traceInkUncached(a, b);
  }

  List<Offset>? _traceInkUncached(Offset a, Offset b) {
    final chord = (b - a).distance;
    final budget = math.max(3 * chord, chord + 2 * radius);
    final start = _inkPixelNear(a);
    final goal = _inkPixelNear(b);
    if (start == null || goal == null) return null;
    final margin = ((budget - chord) / 2).ceil() + _maxGapPixels + 2;
    final left = math.max(0, math.min(start.$1, goal.$1) - margin);
    final top = math.max(0, math.min(start.$2, goal.$2) - margin);
    final right = math.min(width - 1, math.max(start.$1, goal.$1) + margin);
    final bottom = math.min(height - 1, math.max(start.$2, goal.$2) + margin);
    final w = right - left + 1;
    final h = bottom - top + 1;
    final gapStride = _maxGapPixels + 1;
    final stateCount = w * h * gapStride;
    final cameFrom = Int32List(stateCount)..fillRange(0, stateCount, -1);
    final totalGap = Int16List(stateCount)..fillRange(0, stateCount, 32767);
    int pixelIndex(int x, int y) => (y - top) * w + (x - left);
    int stateIndex(int pixel, int gapRun) => pixel * gapStride + gapRun;
    final startPixel = pixelIndex(start.$1, start.$2);
    final goalPixel = pixelIndex(goal.$1, goal.$2);
    final startState = stateIndex(startPixel, 0);
    cameFrom[startState] = startState;
    totalGap[startState] = 0;
    final queue = <int>[startState];
    var found = -1;
    for (var head = 0; head < queue.length && found < 0; head++) {
      final current = queue[head];
      final pixel = current ~/ gapStride;
      final gapRun = current % gapStride;
      final cx = pixel % w + left;
      final cy = pixel ~/ w + top;
      if (pixel == goalPixel) {
        found = current;
        break;
      }
      // 4-connected traversal makes the tolerance correspond to the
      // actual horizontal/vertical pixel distance of the line-art break.
      const neighbors = <(int, int)>[
        (1, 0),
        (-1, 0),
        (0, 1),
        (0, -1),
      ];
      for (final (dx, dy) in neighbors) {
        final x = cx + dx;
        final y = cy + dy;
        if (x < left || x > right || y < top || y > bottom) continue;
        final ink = _isInkAt(Offset(x + .5, y + .5));
        final nextGapRun = ink ? 0 : gapRun + 1;
        if (nextGapRun > _maxGapPixels) continue;
        final nextTotalGap = totalGap[current] + (ink ? 0 : 1);
        if (nextTotalGap > _maxTotalGapPixels) continue;
        final next = stateIndex(pixelIndex(x, y), nextGapRun);
        if (cameFrom[next] != -1) continue;
        cameFrom[next] = current;
        totalGap[next] = nextTotalGap;
        queue.add(next);
      }

    }
    if (found < 0) return null;

    final pixels = <Offset>[];
    for (var state = found; state != startState; state = cameFrom[state]) {
      final pixel = state ~/ gapStride;
      pixels.add(Offset(pixel % w + left + .5, pixel ~/ w + top + .5));
    }
    pixels.add(Offset(start.$1 + .5, start.$2 + .5));
    final traced = pixels.reversed.toList();
    var length = (traced.first - a).distance + (b - traced.last).distance;
    for (var k = 1; k < traced.length; k++) {
      length += (traced[k] - traced[k - 1]).distance;
    }
    if (length > budget) return null;

    // Only return the route when the amount of empty space crossed is small.
    // This makes a 2–6 px break in one contour join naturally, while a large
    // open region still falls back to the user's lasso path.
    var offInk = 0;
    for (var k = 1; k < traced.length - 1; k++) {
      if (!_isInkAt(traced[k])) offInk++;
    }
    if (offInk > _maxTotalGapPixels) return null;
    return [for (var k = 0; k < traced.length; k += 2) traced[k]];
  }

  /// The ink pixel at [p], or one right next to it.
  (int, int)? _inkPixelNear(Offset p) {
    final x0 = p.dx.floor();
    final y0 = p.dy.floor();
    for (final (dx, dy) in _disk.take(25)) {
      final x = x0 + dx;
      final y = y0 + dy;
      if (_isInkAt(Offset(x + .5, y + .5))) return (x, y);
    }
    return null;
  }

  /// Extends the route by the newest guide sample.
  void _advance() {
    final i = _guide.length - 1;
    if (i < 1) return;
    // The normal comes from the guide behind the sample: the user's direction
    // of travel, which is all that is known while drawing.
    final tangent = _unit(_guide[i] - _guide[math.max(0, i - 2)]);
    if (tangent == null) return;
    final normal = Offset(-tangent.dy, tangent.dx);
    if (_samples.isEmpty) {
      // The first sample had no direction yet; it shares the second's.
      _samples.add(_candidates(_guide[0], normal)..start(_guideCost));
    }
    final sample = _candidates(
      _guide[i],
      normal,
      previousPlaces: _samples.last.points,
    );
    final previous = _samples.last;
    for (var b = 0; b < sample.points.length; b++) {
      final bOnGuide = b == sample.guideState;
      final here = bOnGuide ? _guideCost : sample.distanceCost[b];
      var best = double.infinity;
      var from = 0;
      for (var a = 0; a < previous.points.length; a++) {
        final aOnGuide = a == previous.guideState;
        if (!aOnGuide &&
            !bOnGuide &&
            _offInkLength(previous.points[a], sample.points[b]) >
                _maxGapPixels) {
          // Do not jump directly between separate ink segments when their
          // open break is larger than the user's configured tolerance.
          continue;
        }
        // Leaving or rejoining the line pays for drifting towards or away
        // from the guide, so the guide is never a free way across to some
        // other line.
        final double move;
        if (aOnGuide && bOnGuide) {
          move = 0;
        } else if (aOnGuide || bOnGuide) {
          move =
              _switchCost +
              _sidewaysWeight *
                  ((sample.points[b] - sample.points.last).distance -
                          (previous.points[a] - previous.points.last).distance)
                      .abs() /
                  step;
        } else {
          move = _moveCost(
            previous.points[a],
            previous.points.last,
            sample.points[b],
            sample.points.last,
          );
        }
        final total = previous.cost[a] + move;
        if (total < best) {
          best = total;
          from = a;
        }
      }
      sample.cost[b] = best + here;
      sample.from[b] = from;
    }
    _samples.add(sample);
  }

  /// The places across the guide at [point] where the boundary could pass:
  /// ink pixels along the [normal] within [radius], plus the guide itself.
  _Sample _candidates(
    Offset point,
    Offset normal, {
    List<Offset> previousPlaces = const [],
  }) {
    final r = radius.floor();
    final inkOffsets = <int>[];
    for (var t = -r; t <= r; t++) {
      if (_isInkAt(point + normal * t.toDouble())) inkOffsets.add(t);
    }
    // A narrow run of ink is a line crossing the scan: its middle is the
    // place. A long run lies along the scan (a line crossing the contour, or
    // a filled area), and the contour may pass anywhere in it: where the
    // previous sample's places continue into it, at its ends, and at a few
    // points spread along it.
    final offsets = <double>[];
    final spread = <double>[];
    final maxRun = math.max(3, radius * .5);
    var runStart = 0;
    for (var k = 1; k <= inkOffsets.length; k++) {
      final ended =
          k == inkOffsets.length || inkOffsets[k] != inkOffsets[k - 1] + 1;
      if (!ended) continue;
      final first = inkOffsets[runStart];
      final last = inkOffsets[k - 1];
      runStart = k;
      if (last - first + 1 <= maxRun) {
        offsets.add((first + last) / 2);
        continue;
      }
      offsets
        ..add(first.toDouble())
        ..add(last.toDouble());
      for (final place in previousPlaces) {
        final t = _dot(place - point, normal).roundToDouble();
        if (t > first && t < last) offsets.add(t);
      }
      const pieces = 8;
      for (var j = 1; j < pieces; j++) {
        spread.add((first + (last - first) * j / pieces).roundToDouble());
      }
    }
    // In order of importance: line middles, run ends and continuations,
    // then the spread points.
    final unique = <double>{...offsets, ...spread}.take(_maxCandidates);
    offsets
      ..clear()
      ..addAll(unique);
    final places = [for (final t in offsets) point + normal * t];
    // At a sharp corner the scan can pass beside the line altogether; the
    // ink nearest to the guide is then the corner itself.
    final nearest = _nearestInk(point);
    if (nearest != null &&
        places.every((place) => (place - nearest).distance > .75)) {
      places.add(nearest);
    }
    final points = <Offset>[...places, point];
    final distanceCost = Float64List(points.length);
    for (var k = 0; k < places.length; k++) {
      distanceCost[k] = _distanceWeight * (places[k] - point).distance / radius;
    }
    return _Sample(points: points, distanceCost: distanceCost);
  }

  /// What moving from [a] (beside guide point [guideA]) to [b] (beside
  /// [guideB]) costs.
  double _moveCost(Offset a, Offset guideA, Offset b, Offset guideB) {
    // Drifting towards or away from the guide: a jump onto another line.
    // Holding a corner while the guide sweeps round it keeps its distance.
    final sideways =
        ((b - guideB).distance - (a - guideA).distance).abs() / step;
    // Going against the direction the user was drawing in.
    final direction = _unit(guideB - guideA);
    final backward = direction == null
        ? 0.0
        : math.max(0.0, -_dot(b - a, direction)) / step;
    // Covering more ground than the guide did: an excursion along a line
    // that crosses the guide, out and back again. (Notches the guide cuts
    // across are traced afterwards by [_followInk].)
    final detour =
        math.max(0.0, (b - a).distance - (guideB - guideA).distance) / step;
    return _sidewaysWeight * sideways +
        _backwardWeight * backward +
        _detourWeight * detour +
        _gapWeight * _offInkLength(a, b) / step;
  }

  /// How much of the straight stretch from [a] to [b] is not on ink, in px.
  double _offInkLength(Offset a, Offset b) {
    final length = (b - a).distance;
    if (length < 1) return 0;
    final count = length.ceil().clamp(2, 16);
    var off = 0;
    for (var k = 1; k < count; k++) {
      if (!_isInkAt(Offset.lerp(a, b, k / count)!)) off++;
    }
    return length * off / (count - 1);
  }

  static double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

  /// The middle of the line nearest to [point] within [radius], measured
  /// across the line from the side facing [point].
  Offset? _nearestInk(Offset point) {
    final x0 = point.dx.floor();
    final y0 = point.dy.floor();
    for (final (dx, dy) in _disk) {
      final edge = Offset(x0 + dx + .5, y0 + dy + .5);
      if (!_isInkAt(edge)) continue;
      final across = _unit(edge - point);
      if (across == null) return edge;
      final maxWidth = math.max(3.0, radius * .5);
      var depth = 0.0;
      while (depth + .5 <= maxWidth && _isInkAt(edge + across * (depth + .5))) {
        depth += .5;
      }
      // Still on ink at the widest a line can be: this is a line running
      // towards the guide, not one to measure across. Keep its near end.
      if (depth + .5 > maxWidth) return edge;
      return edge + across * (depth / 2);
    }
    return null;
  }

  static List<(int, int)> _diskOffsets(double radius) {
    final r = radius.floor();
    final offsets = <(int, int)>[
      for (var dy = -r; dy <= r; dy++)
        for (var dx = -r; dx <= r; dx++)
          if (dx * dx + dy * dy <= radius * radius) (dx, dy),
    ];
    offsets.sort(
      (a, b) =>
          (a.$1 * a.$1 + a.$2 * a.$2).compareTo(b.$1 * b.$1 + b.$2 * b.$2),
    );
    return offsets;
  }

  bool _isInkAt(Offset p) {
    final x = p.dx.floor();
    final y = p.dy.floor();
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    final i = (y * width + x) * 4;
    final a = rgba[i + 3];
    if (a < 24) return false;
    // Transparent line-art layers are read by alpha. On flattened, opaque
    // references, ink is what is visibly darker than near-white paper.
    if (a < 245) return true;
    final luma = rgba[i] * .2126 + rgba[i + 1] * .7152 + rgba[i + 2] * .0722;
    return luma < 235;
  }

  static Offset? _unit(Offset v) {
    final length = v.distance;
    return length < .001 ? null : v / length;
  }
}

/// One guide sample: where the boundary could pass, and the cheapest route
/// to each of those places.
class _Sample {
  _Sample({required this.points, required this.distanceCost})
    : cost = Float64List(points.length),
      from = Int32List(points.length);

  /// The candidate places; the last one is the guide point itself.
  final List<Offset> points;
  final Float64List distanceCost;
  final Float64List cost;
  final Int32List from;

  int get guideState => points.length - 1;

  /// Makes this the first sample of the route, where staying on the guide
  /// costs [guideCost].
  void start(double guideCost) {
    for (var s = 0; s < points.length; s++) {
      cost[s] = s == guideState ? guideCost : distanceCost[s];
    }
  }
}
