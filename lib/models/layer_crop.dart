import 'dart:ui' show Rect;

/// The part of a timeline image or video that shows (画面トリミング).
///
/// The edges are fractions (0–1) of the material's own layer: the canvas-size
/// picture the material is fitted into, before its position, scale, turn and
/// mask. So the same crop cuts the same part of the picture whatever order
/// the other edits were made in, at any canvas resolution, and on every
/// frame of a video. The material's file is not changed.
class LayerCrop {
  const LayerCrop({
    this.left = 0,
    this.top = 0,
    this.right = 1,
    this.bottom = 1,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// The smallest part a crop keeps, across and down.
  static const double minSize = 0.001;

  /// Nothing is cut.
  static const full = LayerCrop();

  bool get isFull => left <= 0 && top <= 0 && right >= 1 && bottom >= 1;

  /// Whether the edges are in order, inside 0–1 and keep at least [minSize].
  bool get isValid =>
      [left, top, right, bottom].every((v) => v.isFinite) &&
      left >= 0 &&
      top >= 0 &&
      right <= 1 &&
      bottom <= 1 &&
      right - left >= minSize - 1e-9 &&
      bottom - top >= minSize - 1e-9;

  /// The kept part of a [width] × [height] picture.
  Rect rectIn(double width, double height) =>
      Rect.fromLTRB(left * width, top * height, right * width, bottom * height);

  LayerCrop copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) => LayerCrop(
    left: left ?? this.left,
    top: top ?? this.top,
    right: right ?? this.right,
    bottom: bottom ?? this.bottom,
  );

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };

  /// The saved crop, or null for no crop (missing, full, or not valid —
  /// a broken value shows the whole picture rather than nothing).
  static LayerCrop? fromJson(Object? json) {
    if (json is! Map) return null;
    double? number(String key) => (json[key] as num?)?.toDouble();
    final crop = LayerCrop(
      left: number('left') ?? 0,
      top: number('top') ?? 0,
      right: number('right') ?? 1,
      bottom: number('bottom') ?? 1,
    );
    return crop.isValid && !crop.isFull ? crop : null;
  }

  @override
  bool operator ==(Object other) =>
      other is LayerCrop &&
      left == other.left &&
      top == other.top &&
      right == other.right &&
      bottom == other.bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'LayerCrop($left, $top, $right, $bottom)';
}
