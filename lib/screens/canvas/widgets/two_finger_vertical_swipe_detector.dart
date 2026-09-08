import 'package:flutter/widgets.dart';

enum TwoFingerVerticalSwipeDirection { up, down }

/// Detects deliberate two-finger vertical swipes without entering Flutter's
/// gesture arena. Single-finger taps, scrolling, and the layer reorder handle
/// therefore keep their existing behavior.
class TwoFingerVerticalSwipeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final double threshold;

  const TwoFingerVerticalSwipeDetector({
    super.key,
    required this.child,
    this.onSwipeUp,
    this.onSwipeDown,
    this.threshold = 40,
  });

  @override
  State<TwoFingerVerticalSwipeDetector> createState() =>
      _TwoFingerVerticalSwipeDetectorState();
}

class _TwoFingerVerticalSwipeDetectorState
    extends State<TwoFingerVerticalSwipeDetector> {
  final Map<int, Offset> _positions = <int, Offset>{};
  Offset? _gestureStart;
  bool _tracking = false;
  bool _fired = false;

  Offset get _averagePosition {
    var dx = 0.0;
    var dy = 0.0;
    for (final position in _positions.values) {
      dx += position.dx;
      dy += position.dy;
    }
    return Offset(dx / _positions.length, dy / _positions.length);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _positions[event.pointer] = event.position;
    if (_positions.length == 2) {
      _gestureStart = _averagePosition;
      _tracking = true;
      _fired = false;
    } else if (_positions.length > 2) {
      _tracking = false;
      _gestureStart = null;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_positions.containsKey(event.pointer)) return;
    _positions[event.pointer] = event.position;
    final start = _gestureStart;
    if (!_tracking || _fired || _positions.length != 2 || start == null) {
      return;
    }
    final delta = _averagePosition - start;
    final vertical = delta.dy.abs();
    if (vertical < widget.threshold || vertical <= delta.dx.abs() * 1.2) {
      return;
    }
    _fired = true;
    if (delta.dy < 0) {
      widget.onSwipeUp?.call();
    } else {
      widget.onSwipeDown?.call();
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _positions.remove(event.pointer);
    if (_positions.length < 2) {
      _tracking = false;
      _gestureStart = null;
      _fired = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: widget.child,
    );
  }
}
