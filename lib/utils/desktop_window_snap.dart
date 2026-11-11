import 'dart:ui' show Offset, Rect, Size;

/// Magnetically align a freely positioned PC/DeX tool window with another.
/// Edges snap only within [threshold] *and* when the windows overlap along
/// the perpendicular axis. Overlapping and separated layouts remain valid;
/// this does not force docking or change persistent window ordering.
Offset snapDesktopWindow(
  Offset proposed,
  Size movingSize,
  Iterable<Rect> neighbours, {
  double threshold = 12,
}) {
  final current = proposed & movingSize;
  double? dx;
  double? dy;

  void chooseX(double candidate) {
    if (candidate.abs() > threshold) return;
    if (dx == null || candidate.abs() < dx!.abs()) dx = candidate;
  }

  void chooseY(double candidate) {
    if (candidate.abs() > threshold) return;
    if (dy == null || candidate.abs() < dy!.abs()) dy = candidate;
  }

  for (final other in neighbours) {
    final sharesVerticalSpace =
        current.top < other.bottom && current.bottom > other.top;
    final sharesHorizontalSpace =
        current.left < other.right && current.right > other.left;
    if (sharesVerticalSpace) {
      chooseX(other.left - current.right); // attach to left neighbour
      chooseX(other.right - current.left); // attach to right neighbour
      chooseX(other.left - current.left); // align left edges
      chooseX(other.right - current.right); // align right edges
    }
    if (sharesHorizontalSpace) {
      chooseY(other.top - current.bottom); // attach above
      chooseY(other.bottom - current.top); // attach below
      chooseY(other.top - current.top);
      chooseY(other.bottom - current.bottom);
    }
  }
  return Offset(proposed.dx + (dx ?? 0), proposed.dy + (dy ?? 0));
}
