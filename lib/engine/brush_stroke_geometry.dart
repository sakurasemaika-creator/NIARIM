import 'dart:math' as math;
import 'dart:ui';

/// Width multiplier of a flat nib measured perpendicular to the stroke.
double nibWidthAcross(Offset tangent, double xScale, double angle) {
  final sinA = math.sin(angle), cosA = math.cos(angle);
  final x = (tangent.dx * sinA - tangent.dy * cosA) * xScale;
  final y = tangent.dx * cosA + tangent.dy * sinA;
  return math.sqrt(x * x + y * y);
}

List<double> lateralOffsets({required int count, required double spacing}) {
  final safeCount = count.clamp(1, 10).toInt();
  final safeSpacing = spacing.isFinite ? spacing.abs() : 0.0;
  final center = (safeCount - 1) / 2.0;
  return List<double>.generate(
    safeCount,
    (index) => (index - center) * safeSpacing,
    growable: false,
  );
}

List<Offset> lateralCenters({
  required Offset center,
  required Offset tangent,
  required int count,
  required double spacing,
}) {
  final length = tangent.distance;
  if (!length.isFinite || length <= 1e-9) {
    return [
      for (final offset in lateralOffsets(count: count, spacing: spacing))
        center + Offset(0, offset),
    ];
  }
  final unit = tangent / length;
  final normal = Offset(-unit.dy, unit.dx);
  return [
    for (final offset in lateralOffsets(count: count, spacing: spacing))
      center + normal * offset,
  ];
}
