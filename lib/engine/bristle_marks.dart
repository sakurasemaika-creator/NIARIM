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
/// - A tap (a dab without a direction) presses the hairs down around its
///   centre: dense in the middle, a few hair gaps, fibres at the rim.
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

  /// Where this stroke's hairs sit (in hairs) and which stretch of the
  /// marks along the stroke it takes.
  final double _shift;
  final double _row;

  // The dab now being laid.
  double _cx = 0, _cy = 0, _dx = 1, _dy = 0, _length = 0;
  double _radius = 1, _invRadius = 1;
  double _press = 1;
  bool _tap = false;

  /// Sets the dab centred at ([cx], [cy]) with [radius], [length] along the
  /// stroke, going in direction ([dx], [dy]) (a unit vector), at [pressure]
  /// (0–1). Without a direction ([dx] and [dy] both 0) the dab is a tap.
  void aim(
    double cx,
    double cy,
    double radius,
    double length,
    double dx,
    double dy,
    double pressure,
  ) {
    _cx = cx;
    _cy = cy;
    _radius = radius > 0 ? radius : 1;
    _invRadius = 1 / _radius;
    _length = length;
    _tap = dx == 0 && dy == 0;
    _dx = _tap ? 1 : dx;
    _dy = _tap ? 0 : dy;
    _press = pressure < 0 ? 0 : (pressure > 1 ? 1 : pressure);
  }

  /// The share (0–1) of the dab's paint that canvas point ([x], [y]) keeps.
  double at(double x, double y) {
    final ox = x - _cx;
    final oy = y - _cy;
    if (_tap) return _tapAt(ox, oy);
    final along = _length + ox * _dx + oy * _dy;
    var across = oy * _dx - ox * _dy;
    final edge = _radius - (across < 0 ? -across : across);
    // The hand wavers: the hairs drift a little across the stroke.
    across += _waver * (_noise1(along * _waverRun + _row, 1) - 0.5) * 2;
    final h = across / _hairPitch + _shift;
    final s = along < 0 ? 0.0 : along;
    final k = _streaks;
    var keep = 1.0;
    if (k > 0) {
      // A hair is thin for a stretch, then full again.
      final hair = _marks2(h, s / _hairRun + _row);
      final c = across / _clumpPitch + _shift * 0.37;
      final clump = _marks2(c + 17.3, s / (_hairRun * 1.8) + _row * 0.6);
      // Slightly thinner paint on some hairs than on others: fine streaks
      // in the stroke.
      // (Most hairs lay the paint as it is.)
      final thin = hair >= 0.45 ? 0.0 : (0.45 - hair) / 0.45;
      keep = 1 - k * 0.3 * thin * thin;
      // Now and then a missing hair, and towards the edges, where the brush
      // splays, parted clumps: the paint below shows through.
      var u = 1 - edge * _invRadius;
      if (u < 0) u = 0;
      if (u > 1) u = 1;
      keep *= _open(hair, k * 0.1, 0.04);
      keep *= _open(clump, k * 0.22 * u * u, 0.05);
      // Fibres at the edge.
      if (edge < _fringe) {
        final reach = edge <= 0 ? 0.0 : edge / _fringe;
        final fibre = _marks2(h * 1.3 + 41.9, s / (_fringe * 4 + 6) + _row);
        keep *= _step(fibre - (1 - reach) * (0.4 + 0.6 * k), 0.08);
      }
      if (keep <= 0) return 0;
    }
    if (_dry > 0) {
      final run = s >= _dryLength ? 1.0 : s / _dryLength;
      // A lighter touch dries out sooner.
      final dried = _dry * run * (1.35 - 0.6 * _press);
      if (dried > 0) {
        var u = 1 - edge * _invRadius;
        if (u < 0) u = 0;
        if (u > 1) u = 1;
        if (k > 0) {
          // Only the hairs that still hold paint mark: long fibres, the
          // edges first, the middle last.
          final level = dried * (0.25 + 0.9 * u * u);
          final paint =
              _marks2(h * 0.8 + 7.1, s / _dryRun + _row) * 0.6 +
              _marks2(across / _clumpPitch + 3.3, s / (_dryRun * 1.5) + _row) *
                  0.4;
          keep *= _step(paint - level, 0.04);
        }
      }
      if (k <= 0) {
        // A knife lays the paint smooth. Pressed lightly, or as it runs
        // out of paint, it scrapes it thin in fine streaks along the blade's
        // way.
        final run = s >= _dryLength ? 1.0 : s / _dryLength;
        final light = _press >= 0.85 ? 0.0 : (0.85 - _press) * 1.6;
        // (A firm press with a loaded knife leaves no streaks at all.)
        final level = _dry * (light + 0.15 * run) - 0.08;
        if (level > 0) {
          final streak = _marks2(
            across / (1.5 + _radius * 0.03) + _shift,
            s / (_radius * 8 + 30) + _row,
          );
          keep *= 1 - 0.7 * _step(level - streak, 0.1);
        }
      }
    }
    return keep;
  }

  /// A tap: hairs pressed down around the centre.
  double _tapAt(double ox, double oy) {
    final k = _streaks;
    if (k <= 0) return 1;
    final r = math.sqrt(ox * ox + oy * oy);
    final edge = _radius - r;
    // Pressed down, the hairs lie side by side: fine streaks across the
    // dab, and at its rim the hair ends spread out from the centre.
    final hair = _marks2(
      oy / _hairPitch + _shift,
      ox / (_hairPitch * 6) + _row,
    );
    final thin = hair >= 0.45 ? 0.0 : (0.45 - hair) / 0.45;
    var keep = (1 - k * 0.25 * thin * thin) * _open(hair, k * 0.06, 0.04);
    final turn = math.atan2(oy, ox) * _radius / _hairPitch;
    if (edge < _fringe) {
      final reach = edge <= 0 ? 0.0 : edge / _fringe;
      final fibre = _marks2(turn * 1.3 + 41.9, r / (_fringe * 2 + 3) + _row);
      keep *= _step(fibre - (1 - reach) * (0.4 + 0.6 * k), 0.08);
    }
    return keep;
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
