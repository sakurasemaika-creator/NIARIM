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

  Ruler copyWith({
    RulerType? type,
    Offset? position,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    RulerSettings? settings,
  }) {
    return Ruler(
      type: type ?? this.type,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      settings: settings ?? this.settings,
    );
  }
}

enum RulerType {
  line,
  circle,
  ellipse,
  radial,
  onePointPerspective,
  twoPointPerspective,
  threePointPerspective,
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

  RulerSettings copyWith({
    int? divisions,
    Offset? vanishingPoint1,
    Offset? vanishingPoint2,
    Offset? vanishingPoint3,
    double? radiusX,
    double? radiusY,
  }) {
    return RulerSettings(
      divisions: divisions ?? this.divisions,
      vanishingPoint1: vanishingPoint1 ?? this.vanishingPoint1,
      vanishingPoint2: vanishingPoint2 ?? this.vanishingPoint2,
      vanishingPoint3: vanishingPoint3 ?? this.vanishingPoint3,
      radiusX: radiusX ?? this.radiusX,
      radiusY: radiusY ?? this.radiusY,
    );
  }
}
