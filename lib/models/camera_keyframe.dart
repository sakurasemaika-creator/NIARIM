class CameraKeyframe {
  final int frameIndex;
  final double x;
  final double y;
  final double zoom;
  final double rotation;

  /// The key's time before it was rounded to [frameIndex], kept when its
  /// range is retimed so retiming again starts from it (a range sped up and
  /// slowed back returns to its frames). Null when the key lies exactly on
  /// its frame.
  final double? exactFrame;

  const CameraKeyframe({
    required this.frameIndex,
    this.x = 0,
    this.y = 0,
    this.zoom = 1.0,
    this.rotation = 0,
    this.exactFrame,
  });

  /// The key's time: [exactFrame] while it still rounds to [frameIndex]
  /// (a key moved without it falls back to its frame).
  double get exactTime {
    final exact = exactFrame;
    return exact != null && exact.isFinite && exact.round() == frameIndex
        ? exact
        : frameIndex.toDouble();
  }

  CameraKeyframe copyWith({
    int? frameIndex,
    double? x,
    double? y,
    double? zoom,
    double? rotation,
    Object? exactFrame = _keepExact,
  }) {
    final next = frameIndex ?? this.frameIndex;
    final exact = this.exactFrame;
    return CameraKeyframe(
      // A key moved by whole frames keeps its fraction with it.
      exactFrame: exactFrame != _keepExact
          ? exactFrame as double?
          : exact == null
          ? null
          : exact + (next - this.frameIndex),
      frameIndex: next,
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

const Object _keepExact = Object();
