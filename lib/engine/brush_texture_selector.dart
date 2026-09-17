import 'dart:math' as math;

import '../models/brush.dart';

/// Selects one custom brush texture when a stroke begins and keeps that
/// selection stable until the stroke ends.
class BrushTextureSelector {
  BrushTextureSelector({int? randomSeed})
      : _random = randomSeed == null ? math.Random() : math.Random(randomSeed);

  final math.Random _random;
  final Map<String, int> _sequentialCursorByBrush = <String, int>{};
  String? _activePath;

  String? get activePath => _activePath;

  String? beginStroke({
    required String brushId,
    required List<String> paths,
    required BrushImageSelectionMode mode,
  }) {
    if (paths.isEmpty) {
      _activePath = null;
      return null;
    }

    final index = switch (mode) {
      BrushImageSelectionMode.random => _random.nextInt(paths.length),
      BrushImageSelectionMode.sequential =>
        (_sequentialCursorByBrush[brushId] ?? 0) % paths.length,
    };
    _activePath = paths[index];

    if (mode == BrushImageSelectionMode.sequential) {
      _sequentialCursorByBrush[brushId] = (index + 1) % paths.length;
    }
    return _activePath;
  }

  void endStroke() {
    _activePath = null;
  }
}
