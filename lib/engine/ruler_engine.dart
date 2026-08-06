import 'dart:math';
import 'dart:ui';
import '../models/ruler.dart';

class RulerEngine {
  Ruler? _activeRuler;
  Ruler? get activeRuler => _activeRuler;

  void setActiveRuler(Ruler? ruler) => _activeRuler = ruler;

  Offset snapToRuler(Offset point) {
    if (_activeRuler == null) return point;
    return switch (_activeRuler!.type) {
      RulerType.line => _snapToLine(point),
      RulerType.circle => _snapToCircle(point),
      RulerType.ellipse => _snapToEllipse(point),
      RulerType.radial => _snapToRadial(point),
      RulerType.onePointPerspective => point,
      RulerType.twoPointPerspective => point,
      RulerType.threePointPerspective => point,
    };
  }

  Offset _snapToLine(Offset point) {
    final ruler = _activeRuler!;
    final angle = ruler.rotation;
    final c = cos(angle);
    final s = sin(angle);
    final dx = point.dx - ruler.position.dx;
    final dy = point.dy - ruler.position.dy;
    final projection = dx * c + dy * s;
    return Offset(ruler.position.dx + projection * c, ruler.position.dy + projection * s);
  }

  Offset _snapToCircle(Offset point) {
    final ruler = _activeRuler!;
    final radius = ruler.settings.radiusX ?? 100;
    final dx = point.dx - ruler.position.dx;
    final dy = point.dy - ruler.position.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist == 0) return point;
    return Offset(
      ruler.position.dx + dx / dist * radius,
      ruler.position.dy + dy / dist * radius,
    );
  }

  Offset _snapToEllipse(Offset point) {
    final ruler = _activeRuler!;
    final rx = ruler.settings.radiusX ?? 100;
    final ry = ruler.settings.radiusY ?? 60;
    final dx = point.dx - ruler.position.dx;
    final dy = point.dy - ruler.position.dy;
    final angle = atan2(dy, dx);
    return Offset(
      ruler.position.dx + rx * cos(angle),
      ruler.position.dy + ry * sin(angle),
    );
  }

  Offset _snapToRadial(Offset point) {
    final ruler = _activeRuler!;
    final divisions = ruler.settings.divisions ?? 8;
    final dx = point.dx - ruler.position.dx;
    final dy = point.dy - ruler.position.dy;
    final angle = atan2(dy, dx);
    final sliceAngle = 2 * pi / divisions;
    final snappedAngle = (angle / sliceAngle).round() * sliceAngle;
    final dist = sqrt(dx * dx + dy * dy);
    return Offset(
      ruler.position.dx + dist * cos(snappedAngle),
      ruler.position.dy + dist * sin(snappedAngle),
    );
  }
}
