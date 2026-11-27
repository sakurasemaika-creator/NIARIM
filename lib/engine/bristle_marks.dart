import 'dart:math' as math;
import 'dart:typed_data';

/// The marks a loaded bristle brush leaves along one stroke: fine hair
/// streaks along the stroke (毛のすじ), edges that fray into fibres, and
/// dry-brush breakup (かすれ) as the paint runs short.
///
/// Every pixel is judged by where it lies on the stroke, not by the dab
/// that reaches it: across the stroke (which hair passes over it) and along
/// it (how far the brush has come). So the many overlapping dabs of a stroke
/// agree, and the marks follow the stroke without dab arcs. The same stroke
/// draws the same marks every time (its start picks the brush's state).
///
/// - Hair streaks: hairs about a pixel and a half apart and clumps of them
///   about a tenth of the brush wide. A hair or a clump is thin for a while
///   and then full again, so the streaks start and stop at different places
///   along the stroke; where one is missing the paper or the paint below
///   shows through, and elsewhere the paint is the chosen colour, a little
///   denser on some hairs than on others. The brush wavers slightly with
///   the hand, so the streaks are not ruled lines.
/// - Fray: within a few pixels of the edge only some hairs reach, each as
///   far as it happens to: fine fibres along the stroke.
/// - Dry brush: the brush starts loaded and dries along the stroke, to the
///   level of かすれ (no further, so a long stroke never vanishes), more
///   at a lighter touch. A drying brush keeps marking only with the hairs
///   that still hold paint, so the paint breaks into long scratchy fibres,
///   the edges first, and the tail thins to single hairs.
/// - A brush without hair streaks but with かすれ is a painting knife: the
///   paint stays smooth with clean edges, and where the knife is pressed
///   lightly (or has laid most of its load) it scrapes the paint thin in
///   long streaks that let the layer below show.
/// - The load varies along the stroke: denser where the brush is full, a few
///   more thin hairs where it runs thin (the paint is still the chosen
///   colour; only the streaks change).
/// - Lifting off (the pressure falling below the stroke's firmest, or a
///   入り抜き narrowing the tip), fewer and fewer hairs touch: the edges
///   first, then hair by hair, so the stroke breaks into scratchy streaks and
///   thins away instead of ending in a blunt block.
/// - A knife pushes the paint to the sides of its blade: a faint groove runs
///   along each edge, just inside the ridge of paint at the edge.
/// - A tap (a dab without a direction) presses the hairs down round its
///   centre: a dense round dab whose rim splays into fine hair ends.
final class BristleMarks {
  BristleMarks({
    required int streaks,
    required int dryness,
    required double brushSize,
    required int seed,
  }) : _streaks = streaks.clamp(0, 100) / 100,
       _dry = dryness.clamp(0, 100) / 100,
       _hairPitch = 1.0 + 0.06 * math.sqrt(math.max(1.0, brushSize)),
       _clumpPitch = 2.0 + math.max(1.0, brushSize) * 0.11,
       _hairRun = 6 + math.max(1.0, brushSize) * 0.9,
       _dryRun = 8 + math.max(1.0, brushSize) * 1.2,
       _fringe = (math.max(1.0, brushSize) * 0.09).clamp(1.5, 6.0),
       _waver = math.max(1.0, brushSize) * 0.03,
       _waverRun = 1 / (12 + math.max(1.0, brushSize) * 2.2),
       _dryLength =
           (100 + math.max(4.0, brushSize) * 4) *
           (1.3 - dryness.clamp(0, 100) / 100),
       _loadRun = 1 / (30 + math.max(1.0, brushSize) * 3.5),
       _ridge = (math.max(1.0, brushSize) * 0.05).clamp(1.6, 4.0),
       _ridgeWidth = (math.max(1.0, brushSize) * 0.025).clamp(0.9, 2.2),
       _splay = (math.max(1.0, brushSize) * 0.12).clamp(2.5, 12.0),
       _shift = (seed & 0xFFFF) / 0xFFFF * 512,
       _row = (seed >> 16 & 0xFF) * 3.7;

  final double _streaks;
  final double _dry;

  /// The distance between neighbouring hairs and clumps of hairs (canvas
  /// px).
  final double _hairPitch;
  final double _clumpPitch;

  /// How far along the stroke a hair stays thin or full (canvas px), and
  /// how long the fibres of dry paint are.
  final double _hairRun;
  final double _dryRun;

  /// How deep into the stroke its frayed edge reaches (canvas px).
  final double _fringe;

  /// How far the hairs waver across the stroke with the hand, and how
  /// quickly along it.
  final double _waver;
  final double _waverRun;

  /// How far the brush goes before it is as dry as かすれ says.
  final double _dryLength;

  /// How quickly the load changes along the stroke (per canvas px).
  final double _loadRun;

  /// How far inside a knife's edge the groove runs, and how wide it is
  /// (canvas px).
  final double _ridge;
  final double _ridgeWidth;

  /// How deep into a tap its splayed hair ends reach (canvas px).
  final double _splay;

  /// Where this stroke's hairs sit (in hairs) and which stretch of the
  /// marks along the stroke it takes.
  final double _shift;
  final double _row;

  // The dab now being laid.
  double _cx = 0, _cy = 0, _dx = 1, _dy = 0, _length = 0;
  double _radius = 1;
  // How far the paint reaches either side of the stroke's middle (left of
  // the way it goes, then right) and their inverses.
  double _reachLeft = 1, _reachRight = 1;
  double _invLeft = 1, _invRight = 1;
  double _press = 1;
  double _lift = 0;
  double _load = 0;
  bool _tap = false;

  /// Sets the dab centred at ([cx], [cy]) with [radius], [length] along the
  /// stroke, going in direction ([dx], [dy]) (a unit vector), at [pressure]
  /// (0–1). Without a direction ([dx] and [dy] both 0) the dab is a tap.
  ///
  /// [contact] (0–1) is how fully the brush touches the paper: 1 as firmly
  /// as it has been on this stroke, less as it lifts off. [reachLeft] and
  /// [reachRight] are how far the tip's paint reaches to the left and the
  /// right of its way, as shares of [radius] (a flat tip held across its
  /// way reaches less far than its radius).
  void aim(
    double cx,
    double cy,
    double radius,
    double length,
    double dx,
    double dy,
    double pressure, {
    double contact = 1,
    double reachLeft = 1,
    double reachRight = 1,
  }) {
    _cx = cx;
    _cy = cy;
    _radius = radius > 0 ? radius : 1;
    _length = length;
    _tap = dx == 0 && dy == 0;
    _dx = _tap ? 1 : dx;
    _dy = _tap ? 0 : dy;
    _press = pressure < 0 ? 0 : (pressure > 1 ? 1 : pressure);
    // How full the brush is here (−1 thin to 1 loaded): it changes slowly
    // along the stroke, so the dab's place is near enough for all of it.
    _load =
        _noise1((length < 0 ? 0 : length) * _loadRun + _row * 0.31, 0) * 2 - 1;
    _reachLeft = math.max(0.5, _radius * reachLeft);
    _reachRight = math.max(0.5, _radius * reachRight);
    _invLeft = 1 / _reachLeft;
    _invRight = 1 / _reachRight;
    // Lifting starts once the touch is under about three quarters of the
    // stroke's firmest and is complete at about a sixth.
    var t = (0.72 - contact) / 0.56;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    _lift = t * t * (3 - 2 * t);
  }

  /// The share (0–1) of the dab's paint that canvas point ([x], [y]) keeps.
  double at(double x, double y) {
    final ox = x - _cx;
    final oy = y - _cy;
    if (_tap) return _tapAt(ox, oy);
    final along = _length + ox * _dx + oy * _dy;
    var across = oy * _dx - ox * _dy;
    // How far inside the paint's edge the point is, and how far out from
    // the middle towards that edge (0 in the middle, 1 at the edge).
    final double edge;
    var u = 0.0;
    if (across >= 0) {
      edge = _reachLeft - across;
      u = across * _invLeft;
    } else {
      edge = _reachRight + across;
      u = -across * _invRight;
    }
    if (u > 1) u = 1;
    final s = along < 0 ? 0.0 : along;
    final k = _streaks;
    if (k <= 0) return _knifeAt(across, edge, s);
    // The hand wavers: the hairs drift a little across the stroke.
    across += _waver * (_noise1(along * _waverRun + _row, 1) - 0.5) * 2;
    final h = across / _hairPitch + _shift;
    final load = _load;
    // A hair is thin for a stretch, then full again.
    final hair = _marks2(h, s / _hairRun + _row);
    final c = across / _clumpPitch + _shift * 0.37;
    final clump = _marks2(c + 17.3, s / (_hairRun * 1.8) + _row * 0.6);
    // Slightly thinner paint on some hairs than on others: fine streaks in
    // the stroke, more of them where the brush runs thin. (Most hairs lay
    // the paint as it is.)
    final thinAt = 0.45 - 0.2 * load;
    final thin = hair >= thinAt ? 0.0 : (thinAt - hair) / thinAt;
    var keep = 1 - k * (0.32 - 0.18 * load) * thin * thin;
    // Now and then a missing hair, and towards the edges, where the brush
    // splays, parted clumps: the paint below shows through.
    keep *= _open(hair, k * (0.1 - 0.07 * load), 0.04);
    keep *= _open(clump, k * 0.22 * u * u, 0.05);
    // Fibres at the edge.
    if (edge < _fringe) {
      final reach = edge <= 0 ? 0.0 : edge / _fringe;
      final fibre = _marks2(h * 1.3 + 41.9, s / (_fringe * 4 + 6) + _row);
      keep *= _step(fibre - (1 - reach) * (0.4 + 0.6 * k), 0.08);
    }
    if (keep <= 0) return 0;
    // Lifting off, fewer and fewer hairs touch: the edges first, then
    // single hairs, each for a stretch along the stroke.
    if (_lift > 0) {
      final level = _lift * (1.05 + 0.4 * u * u) - 0.06;
      if (level > 0) {
        final soft = 0.05 + 0.05 * _lift;
        // The second part of the mark is needed only when the first does
        // not settle the step (it adds 0 to 0.35).
        final first =
            _marks2(h * 0.9 + 61.3, s / (_hairRun * 1.6) + _row) * 0.65;
        if (first + 0.35 <= level - soft) return 0;
        if (first < level + soft) {
          final touch =
              first +
              _marks2(c * 0.8 + 29.1, s / (_hairRun * 2.6) + _row * 0.8) * 0.35;
          keep *= _step(touch - level, soft);
          if (keep <= 0) return 0;
        }
      }
    }
    if (_dry > 0) {
      final run = s >= _dryLength ? 1.0 : s / _dryLength;
      // A lighter touch, and a thinner load, dry out sooner.
      final dried = _dry * run * (1.35 - 0.6 * _press) * (1 - 0.25 * load);
      if (dried > 0) {
        // Only the hairs that still hold paint mark: long fibres, the edges
        // first, the middle last.
        final level = dried * (0.25 + 0.9 * u * u);
        // (The second part, 0 to 0.4, only when the first leaves it open.)
        final first = _marks2(h * 0.8 + 7.1, s / _dryRun + _row) * 0.6;
        if (first + 0.4 <= level - 0.04) return 0;
        if (first < level + 0.04) {
          final paint =
              first +
              _marks2(across / _clumpPitch + 3.3, s / (_dryRun * 1.5) + _row) *
                  0.4;
          keep *= _step(paint - level, 0.04);
        }
      }
    }
    return keep > _full ? 1.0 : keep;
  }

  /// A share this near 1 lays the same paint as 1 (at most one level of 255
  /// less), so it is taken as 1: a pixel the stroke has covered then needs
  /// no more work from the dabs that follow.
  static const double _full = 0.998;

  /// A knife (かすれ without hair streaks): the paint stays smooth with
  /// clean edges. [across] is the point's place across the blade's way,
  /// [edge] how far inside the paint's edge it is and [s] how far along the
  /// stroke.
  double _knifeAt(double across, double edge, double s) {
    if (_dry <= 0) return 1;
    var keep = 1.0;
    // The blade pushes paint to its sides: a ridge at each edge and, just
    // inside it, a faint groove where the edge of the blade ran. It wavers
    // a little, deepens and fades, and breaks now and then.
    if (edge > _ridge * 0.75 - _ridgeWidth &&
        edge < _ridge * 1.35 + _ridgeWidth) {
      final side = across >= 0 ? 0.0 : 113.7;
      final run = s / (_radius * 3 + 24) + _row + side;
      final at = _ridge * (0.75 + 0.6 * _marks2(side + 5.9, run));
      final d = (edge - at) / _ridgeWidth;
      if (d > -1 && d < 1) {
        final depth = _marks2(side + 71.3, run * 0.7 + 3.1);
        if (depth > 0.22) {
          final bump = 1 - d * d;
          final cut = (depth - 0.22) * 0.45 * bump * bump;
          // (Too faint to see at its sides and where it fades out.)
          if (cut > 0.012) keep -= cut;
        }
      }
    }
    // Pressed lightly, or as it runs out of paint, it scrapes the paint thin
    // in fine streaks along the blade's way.
    final dry = s >= _dryLength ? 1.0 : s / _dryLength;
    final light = _press >= 0.85 ? 0.0 : (0.85 - _press) * 1.6;
    // (A firm press with a loaded knife leaves no streaks at all.)
    final level = _dry * (light + 0.15 * dry) - 0.08;
    if (level <= 0 && _lift <= 0) return keep;
    final streak = _marks2(
      across / (1.5 + _radius * 0.03) + _shift,
      s / (_radius * 8 + 30) + _row,
    );
    if (level > 0) keep *= 1 - 0.7 * _step(level - streak, 0.1);
    // Lifting off, the blade leaves the paper streak by streak: what it
    // still touches it lays as before, the rest it leaves bare.
    if (_lift > 0) {
      final touch =
          streak * 0.6 + _marks2(across / _ridge + 47.3, s / 40 + _row) * 0.4;
      keep *= _step(touch - (_lift * 1.08 - 0.06), 0.06);
    }
    return keep > _full ? 1.0 : keep;
  }

  /// A tap: the hairs pressed down round the centre. The middle is dense,
  /// with faint hair marks spreading out from it; towards the rim the hair
  /// ends splay out, each reaching its own way.
  double _tapAt(double ox, double oy) {
    final k = _streaks;
    if (k <= 0) return 1;
    final r = math.sqrt(ox * ox + oy * oy);
    // Round the dab, in hairs (the marks go once round and meet again).
    var n = (2 * math.pi * _radius / (_hairPitch * 0.8)).round();
    if (n < 8) n = 8;
    if (n > _marksSize) n = _marksSize;
    var angle = math.atan2(oy, ox);
    if (angle < 0) angle += 2 * math.pi;
    final round = angle / (2 * math.pi);
    var keep = 1.0;
    // The hairs spread out from the middle: faint hair marks in the outer
    // part of the dab (none where they all meet).
    final outer = (r / _radius - 0.45) / 0.3;
    if (outer > 0) {
      final hair = _ringMarks(round * n, n, r / (_hairRun * 0.7) + _row);
      final thin = hair >= 0.4 ? 0.0 : (0.4 - hair) / 0.4;
      keep = 1 - k * 0.22 * thin * thin * (outer >= 1 ? 1 : outer);
    }
    final splay = math.min(_splay, _radius * 0.45);
    final into = r - (_radius - splay);
    if (into > 0) {
      // Each hair end reaches a share of the way out (most of them far, a
      // few short), so the rim is a fringe of fine points.
      final few = n >= 32 ? n ~/ 4 : 8;
      final end =
          _ringMarks(round * n, n, _row + 4.2) * 0.8 +
          _ringMarks(round * few, few, _row + 9.6) * 0.2;
      keep *= _step(end * (0.7 + 0.6 * k) + 0.1 - into / splay, 0.1);
    }
    return keep > _full ? 1.0 : keep;
  }

  /// 1 where [value] is above [level] and 0 below it, over a soft step of
  /// [soft] either side: the paint left where a hair may be missing.
  static double _open(double value, double level, double soft) {
    final t = (value - level + soft) / (2 * soft);
    if (t >= 1) return 1;
    if (t <= 0) return 0;
    return t * t * (3 - 2 * t);
  }

  /// A soft step from 0 (at −[soft]) to 1 (at +[soft]).
  static double _step(double value, double soft) {
    final t = (value + soft) / (2 * soft);
    if (t >= 1) return 1;
    if (t <= 0) return 0;
    return t * t * (3 - 2 * t);
  }

  /// Smooth noise along [x] (0–1): one random value per whole number,
  /// eased between them, read from a table.
  static double _noise1(double x, int seed) {
    final i = x.floor();
    var f = x - i;
    f = f * f * (3 - 2 * f);
    final row = _rows;
    final base = seed * _rowLength;
    final h0 = row[base + (i & (_rowLength - 1))];
    final h1 = row[base + ((i + 1) & (_rowLength - 1))];
    return h0 + (h1 - h0) * f;
  }

  static const int _rowLength = 1024;
  static final Float32List _rows = Float32List.fromList([
    for (var seed = 0; seed < 2; seed++)
      for (var i = 0; i < _rowLength; i++) _hash(i, seed),
  ]);

  static double _hash(int i, int seed) {
    var h = (i * 374761393 + seed * 668265263) & 0xFFFFFFFF;
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF;
    h ^= h >> 16;
    return (h & 0xFFFF) / 0xFFFF;
  }

  /// Smooth marks across ([a]) and along ([s]) the stroke (0–1): eased
  /// noise on a grid, read from a tile that repeats every [_marksSize]
  /// units.
  static double _marks2(double a, double s) {
    final table = _marksTable;
    final xi = a.floor();
    final yi = s.floor();
    var fx = a - xi;
    var fy = s - yi;
    fx = fx * fx * (3 - 2 * fx);
    fy = fy * fy * (3 - 2 * fy);
    const m = _marksSize - 1;
    final x0 = xi & m, x1 = (xi + 1) & m;
    final y0 = (yi & m) * _marksSize, y1 = ((yi + 1) & m) * _marksSize;
    final top = table[y0 + x0] + (table[y0 + x1] - table[y0 + x0]) * fx;
    final bottom = table[y1 + x0] + (table[y1 + x1] - table[y1 + x0]) * fx;
    return top + (bottom - top) * fy;
  }

  /// [_marks2] on a ring of [n] (at most [_marksSize]) units across: [a]
  /// from 0 to [n] goes once round and meets itself again.
  static double _ringMarks(double a, int n, double s) {
    final table = _marksTable;
    var xi = a.floor();
    var fx = a - xi;
    if (xi >= n) xi -= n;
    if (xi < 0) xi += n;
    final yi = s.floor();
    var fy = s - yi;
    fx = fx * fx * (3 - 2 * fx);
    fy = fy * fy * (3 - 2 * fy);
    const m = _marksSize - 1;
    final x0 = xi, x1 = xi + 1 == n ? 0 : xi + 1;
    final y0 = (yi & m) * _marksSize, y1 = ((yi + 1) & m) * _marksSize;
    final top = table[y0 + x0] + (table[y0 + x1] - table[y0 + x0]) * fx;
    final bottom = table[y1 + x0] + (table[y1 + x1] - table[y1 + x0]) * fx;
    return top + (bottom - top) * fy;
  }

  static const int _marksSize = 256;
  static final Float32List _marksTable = _buildMarks();

  static Float32List _buildMarks() {
    const n = _marksSize;
    final out = Float32List(n * n);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        out[y * n + x] = _hash(x + y * 7919, 5);
      }
    }
    return out;
  }
}
