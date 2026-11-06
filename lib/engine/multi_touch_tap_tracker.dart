import 'package:flutter/widgets.dart';

enum MultiTouchTapKind { twoFinger, threeFinger, fourOrMoreFinger }

/// Distinguishes deliberate multi-finger taps from pan/pinch/rotation.
/// A tap is emitted only after all participating fingers are released, within
/// [maxDuration], and without any pointer moving beyond [moveSlop].
class MultiTouchTapTracker {
  MultiTouchTapTracker({
    this.moveSlop = 12.0,
    this.maxDuration = const Duration(milliseconds: 320),
  });

  final double moveSlop;
  final Duration maxDuration;

  final Map<int, Offset> _downPositions = {};
  DateTime? _startedAt;
  int _maxPointerCount = 0;
  bool _moved = false;

  void pointerDown(int pointer, Offset position, DateTime now) {
    if (_downPositions.isEmpty) {
      _startedAt = now;
      _maxPointerCount = 0;
      _moved = false;
    }
    _downPositions[pointer] = position;
    if (_downPositions.length > _maxPointerCount) {
      _maxPointerCount = _downPositions.length;
    }
  }

  void pointerMove(int pointer, Offset position) {
    final start = _downPositions[pointer];
    if (start == null) return;
    if ((position - start).distance > moveSlop) _moved = true;
  }

  MultiTouchTapKind? pointerUp(int pointer, DateTime now) {
    _downPositions.remove(pointer);
    if (_downPositions.isNotEmpty) return null;

    final startedAt = _startedAt;
    final durationOk =
        startedAt != null && now.difference(startedAt) <= maxDuration;
    final count = _maxPointerCount;
    final moved = _moved;
    _reset();

    if (!durationOk || moved) return null;
    if (count >= 4) return MultiTouchTapKind.fourOrMoreFinger;
    return switch (count) {
      2 => MultiTouchTapKind.twoFinger,
      3 => MultiTouchTapKind.threeFinger,
      _ => null,
    };
  }

  void pointerCancel(int pointer) {
    _downPositions.remove(pointer);
    _moved = true;
    if (_downPositions.isEmpty) _reset();
  }

  void _reset() {
    _downPositions.clear();
    _startedAt = null;
    _maxPointerCount = 0;
    _moved = false;
  }
}
