class CameraKeyframe {
  final int frameIndex;
  final double x;
  final double y;
  final double zoom;
  final double rotation;

  const CameraKeyframe({
    required this.frameIndex,
    this.x = 0,
    this.y = 0,
    this.zoom = 1.0,
    this.rotation = 0,
  });

  CameraKeyframe copyWith({
    int? frameIndex,
    double? x,
    double? y,
    double? zoom,
    double? rotation,
  }) {
    return CameraKeyframe(
      frameIndex: frameIndex ?? this.frameIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      zoom: zoom ?? this.zoom,
      rotation: rotation ?? this.rotation,
    );
  }

  static CameraKeyframe lerp(CameraKeyframe a, CameraKeyframe b, double t) {
    return CameraKeyframe(
      frameIndex: (a.frameIndex + (b.frameIndex - a.frameIndex) * t).round(),
      x: a.x + (b.x - a.x) * t,
      y: a.y + (b.y - a.y) * t,
      zoom: a.zoom + (b.zoom - a.zoom) * t,
      rotation: a.rotation + (b.rotation - a.rotation) * t,
    );
  }
}
