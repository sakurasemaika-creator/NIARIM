import 'package:flutter/gestures.dart';

/// A pan that wins over a surrounding scroll view when the pointer lands on
/// something the user can grab (a curve point, a control point).
///
/// A plain pan only accepts after moving twice the touch slop, while a
/// vertical scroll view accepts after the slop itself, so dragging a point up
/// or down inside scrolling controls scrolled the controls instead. Here a
/// pointer that [grabs] reports as landing on a handle claims the gesture as
/// soon as it has moved [grabSlop] (0 = as soon as it lands); until then
/// other gestures on the same spot, such as a long press, still get their
/// chance. Pointers that land elsewhere behave like an ordinary pan.
class GrabPanGestureRecognizer extends PanGestureRecognizer {
  GrabPanGestureRecognizer({super.debugOwner, this.grabSlop = kTouchSlop / 2});

  final double grabSlop;

  /// Whether a pointer landing at this local position grabs a handle.
  bool Function(Offset localPosition)? grabs;

  final Map<int, Offset> _grabbed = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    if (!(grabs?.call(event.localPosition) ?? false)) return;
    if (grabSlop <= 0) {
      resolvePointer(event.pointer, GestureDisposition.accepted);
    } else {
      _grabbed[event.pointer] = event.position;
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    final start = _grabbed[event.pointer];
    if (start == null) return;
    if (event is PointerMoveEvent) {
      if ((event.position - start).distance > grabSlop) {
        _grabbed.remove(event.pointer);
        resolvePointer(event.pointer, GestureDisposition.accepted);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _grabbed.remove(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _grabbed.remove(pointer);
    super.rejectGesture(pointer);
  }
}
