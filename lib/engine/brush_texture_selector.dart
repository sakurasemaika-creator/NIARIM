import 'dart:math' as math;

import '../models/brush.dart';

/// Selects the stroke's texture and, in per-dab mode, a reproducible
/// sequence of tips for that stroke.
class BrushTextureSelector {
  BrushTextureSelector({int? randomSeed})
    : _random = randomSeed == null ? math.Random() : math.Random(randomSeed);

  final math.Random _random;
  final Map<String, int> _sequentialCursorByBrush = <String, int>{};
  String? _activePath;
  List<String> _dabPaths = const [];
  int _dabSeed = 0;
  int? _lastDab;
  math.Random? _dabRandom;

  String? get activePath => _activePath;

  String? beginStroke({
    required String brushId,
    required List<String> paths,
    required BrushImageSelectionMode mode,
  }) {
    endStroke();
    if (paths.isEmpty) return null;

    if (mode == BrushImageSelectionMode.randomPerStamp && paths.length > 1) {
      _dabPaths = paths;
      _dabSeed = _random.nextInt(1 << 31);
      _activePath = paths[_dabSeed % paths.length];
      rewindDabs();
      return _activePath;
    }

    final index = switch (mode) {
      BrushImageSelectionMode.random ||
      BrushImageSelectionMode.randomPerStamp => _random.nextInt(paths.length),
      BrushImageSelectionMode.sequential =>
        (_sequentialCursorByBrush[brushId] ?? 0) % paths.length,
    };
    _activePath = paths[index];

    if (mode == BrushImageSelectionMode.sequential) {
      _sequentialCursorByBrush[brushId] = (index + 1) % paths.length;
    }
    return _activePath;
  }

  String? nextDabPath() {
    final random = _dabRandom;
    if (random == null) return _activePath;

    final previous = _lastDab;
    if (previous == null) {
      _lastDab = _dabSeed % _dabPaths.length;
      return _activePath;
    }
    final other = random.nextInt(_dabPaths.length - 1);
    final index = other >= previous ? other + 1 : other;
    _lastDab = index;
    return _dabPaths[index];
  }

  void rewindDabs() {
    if (_dabPaths.isEmpty) return;
    _dabRandom = math.Random(_dabSeed);
    _lastDab = null;
  }

  void endStroke() {
    _activePath = null;
    _dabPaths = const [];
    _dabRandom = null;
    _lastDab = null;
  }
}
