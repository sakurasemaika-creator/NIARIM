import 'dart:ui';

class Ruler {
  final RulerType type;
  final Offset position;
  final double rotation;
  final bool isLocked;
  final bool isVisible;
  final RulerSettings settings;

  const Ruler({
    required this.type,
    required this.position,
    this.rotation = 0,
    this.isLocked = false,
    this.isVisible = true,
    required this.settings,
  });
}

enum RulerType {
  line, circle, ellipse, radial,
  onePointPerspective, twoPointPerspective, threePointPerspective,
}

class RulerSettings {
  final int? divisions;
  final Offset? vanishingPoint1;
  final Offset? vanishingPoint2;
  final Offset? vanishingPoint3;
  final double? radiusX;
  final double? radiusY;

  const RulerSettings({
    this.divisions,
    this.vanishingPoint1,
    this.vanishingPoint2,
    this.vanishingPoint3,
    this.radiusX,
    this.radiusY,
  });
}
