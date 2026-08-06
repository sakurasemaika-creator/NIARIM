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
