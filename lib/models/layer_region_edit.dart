import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Path, Rect;

/// The shape of a part selected on a timeline image or video.
enum RegionShape { rectangle, ellipse, freehand }

/// What a [LayerRegionEdit] does with its selected part.
enum RegionEditKind {
  /// Lifts the part out (leaving it transparent) and puts it back moved,
  /// resized, turned or flipped.
  move,

  /// Leaves the part where it is and puts a copy of it moved, resized,
  /// turned or flipped.
  duplicate,

  /// Makes the part transparent.
  erase,
}

/// A part of a timeline image's or video's own layer: the canvas-size
/// picture the material is fitted into, before its position, scale, turn and
/// mask. Every coordinate is a fraction (0–1) of that picture's width or
/// height, so the same part is meant at any resolution (the preview draws
/// a smaller picture than the export) and on every frame of a video.
class RegionSelection {
  RegionSelection({
    required this.shape,
    required this.bounds,
    List<Offset> points = const [],
  }) : points = List.unmodifiable(points);

  /// A rectangle or an ellipse filling [bounds].
  factory RegionSelection.box(RegionShape shape, Rect bounds) =>
      RegionSelection(shape: shape, bounds: bounds);

  /// A freehand outline through [points] (closed back to the first).
  factory RegionSelection.freehand(List<Offset> points) {
    var left = double.infinity, top = double.infinity;
    var right = -double.infinity, bottom = -double.infinity;
    for (final p in points) {
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
    return RegionSelection(
      shape: RegionShape.freehand,
      bounds: points.isEmpty
          ? Rect.zero
          : Rect.fromLTRB(left, top, right, bottom),
      points: points,
    );
  }

  final RegionShape shape;

  /// The part's bounding box; a rectangle or an ellipse fills it.
  final Rect bounds;

  /// The freehand outline (empty for a rectangle or an ellipse).
  final List<Offset> points;

  /// The smallest part across and down.
  static const double minSize = 0.001;

  /// The most points a freehand outline keeps.
  static const int maxPoints = 2048;

  static bool _unit(double v) => v.isFinite && v >= 0 && v <= 1;

  /// Whether the part is inside the picture, at least [minSize] across and
  /// down, and (freehand) outlined by 3 to [maxPoints] points.
  bool get isValid {
    if (![bounds.left, bounds.top, bounds.right, bounds.bottom].every(_unit)) {
      return false;
    }
    if (bounds.width < minSize - 1e-9 || bounds.height < minSize - 1e-9) {
      return false;
    }
    if (shape != RegionShape.freehand) return points.isEmpty;
    return points.length >= 3 &&
        points.length <= maxPoints &&
        points.every((p) => _unit(p.dx) && _unit(p.dy));
  }

  /// The part's outline on a [width] × [height] picture.
  Path pathIn(double width, double height) {
    final rect = Rect.fromLTRB(
      bounds.left * width,
      bounds.top * height,
      bounds.right * width,
      bounds.bottom * height,
    );
    return switch (shape) {
      RegionShape.rectangle => Path()..addRect(rect),
      RegionShape.ellipse => Path()..addOval(rect),
      RegionShape.freehand =>
        Path()..addPolygon([
          for (final p in points) Offset(p.dx * width, p.dy * height),
        ], true),
    };
  }

  /// The outline as points on a [width] × [height] picture (an ellipse as
  /// [ellipseSteps] points), for drawing handles over the preview.
  List<Offset> outlineIn(double width, double height, {int ellipseSteps = 48}) {
    final l = bounds.left * width, t = bounds.top * height;
    final r = bounds.right * width, b = bounds.bottom * height;
    return switch (shape) {
      RegionShape.rectangle => [
        Offset(l, t),
        Offset(r, t),
        Offset(r, b),
        Offset(l, b),
      ],
      RegionShape.ellipse => [
        for (var i = 0; i < ellipseSteps; i++)
          Offset(
            (l + r) / 2 +
                (r - l) / 2 * math.cos(2 * math.pi * i / ellipseSteps),
            (t + b) / 2 +
                (b - t) / 2 * math.sin(2 * math.pi * i / ellipseSteps),
          ),
      ],
      RegionShape.freehand => [
        for (final p in points) Offset(p.dx * width, p.dy * height),
      ],
    };
  }

  /// This part moved by [delta] (fractions), kept inside the picture.
  RegionSelection translated(Offset delta) {
    final dx = delta.dx.clamp(-bounds.left, 1 - bounds.right);
    final dy = delta.dy.clamp(-bounds.top, 1 - bounds.bottom);
    final d = Offset(dx, dy);
    return RegionSelection(
      shape: shape,
      bounds: bounds.shift(d),
      points: [for (final p in points) p + d],
    );
  }

  Map<String, dynamic> toJson() => {
    'shape': shape.name,
    'left': bounds.left,
    'top': bounds.top,
    'right': bounds.right,
    'bottom': bounds.bottom,
    if (points.isNotEmpty)
      'points': [
        for (final p in points) ...[p.dx, p.dy],
      ],
  };

  /// The saved part, or null when it is missing or not valid.
  static RegionSelection? fromJson(Object? json) {
    if (json is! Map) return null;
    final shape = RegionShape.values
        .where((s) => s.name == json['shape'])
        .firstOrNull;
    if (shape == null) return null;
    double? number(Object? v) => v is num ? v.toDouble() : null;
    final RegionSelection region;
    if (shape == RegionShape.freehand) {
      final raw = json['points'];
      if (raw is! List || raw.length.isOdd) return null;
      final points = <Offset>[];
      for (var i = 0; i + 1 < raw.length; i += 2) {
        final x = number(raw[i]), y = number(raw[i + 1]);
        if (x == null || y == null) return null;
        points.add(Offset(x, y));
      }
      region = RegionSelection.freehand(points);
    } else {
      final l = number(json['left']), t = number(json['top']);
      final r = number(json['right']), b = number(json['bottom']);
      if (l == null || t == null || r == null || b == null) return null;
      region = RegionSelection.box(shape, Rect.fromLTRB(l, t, r, b));
    }
    return region.isValid ? region : null;
  }

  @override
  bool operator ==(Object other) {
    if (other is! RegionSelection ||
        other.shape != shape ||
        other.bounds != bounds ||
        other.points.length != points.length) {
      return false;
    }
    for (var i = 0; i < points.length; i++) {
      if (other.points[i] != points[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(shape, bounds, Object.hashAll(points));

  @override
  String toString() => 'RegionSelection(${shape.name}, $bounds)';
}

/// One edit of a selected part of a timeline image or video (範囲選択): the
/// part is moved and changed, copied, or erased. A material keeps its edits
/// in order and they are drawn one after another onto its own picture,
/// after the crop and before the material's position, scale, turn and mask,
/// in the preview and the export alike and on every frame of a video. The
/// material's file is not changed.
class LayerRegionEdit {
  const LayerRegionEdit({
    required this.id,
    required this.kind,
    required this.region,
    this.dx = 0,
    this.dy = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
  });

  final String id;
  final RegionEditKind kind;
  final RegionSelection region;

  /// How far the part's centre moves, as fractions of the picture's width
  /// and height.
  final double dx;
  final double dy;

  /// The part's size across and down (a negative value flips it).
  final double scaleX;
  final double scaleY;

  /// The part's turn about its centre, in degrees clockwise.
  final double rotation;

  /// The most edits a material keeps (each one is drawn on every frame).
  static const int maxCount = 24;

  /// The smallest and largest size of a moved or copied part.
  static const double minScale = 0.05;
  static const double maxScale = 10;

  /// The furthest a part's centre moves, in picture widths or heights.
  static const double maxShift = 2;

  /// Whether the part leaves its place (it is moved or erased).
  bool get clearsSource => kind != RegionEditKind.duplicate;

  /// Whether the part is drawn again, moved and changed.
  bool get drawsPiece => kind != RegionEditKind.erase;

  /// Whether the part is drawn exactly where it was.
  bool get isIdentityTransform =>
      dx == 0 && dy == 0 && scaleX == 1 && scaleY == 1 && rotation == 0;

  bool get isValid {
    if (id.isEmpty || !region.isValid) return false;
    if (![dx, dy, scaleX, scaleY, rotation].every((v) => v.isFinite)) {
      return false;
    }
    bool size(double s) => s.abs() >= minScale - 1e-9 && s.abs() <= maxScale;
    return dx.abs() <= maxShift &&
        dy.abs() <= maxShift &&
        size(scaleX) &&
        size(scaleY);
  }

  /// The part's centre on a [width] × [height] picture.
  Offset centreIn(double width, double height) =>
      region.bounds.center.scale(width, height);

  /// The matrix (column-major, as `Canvas.transform` takes it) that takes the
  /// part from where it was to where it is drawn on a [width] × [height]
  /// picture: scaled and turned about its centre, then moved.
  Float64List matrixIn(double width, double height) {
    final c = centreIn(width, height);
    final a = rotation * math.pi / 180;
    final cos = math.cos(a), sin = math.sin(a);
    // M = T(c + d) · R · S · T(−c)
    final m00 = cos * scaleX, m01 = -sin * scaleY;
    final m10 = sin * scaleX, m11 = cos * scaleY;
    final tx = c.dx + dx * width - (m00 * c.dx + m01 * c.dy);
    final ty = c.dy + dy * height - (m10 * c.dx + m11 * c.dy);
    return Float64List.fromList([
      m00, m10, 0, 0, //
      m01, m11, 0, 0, //
      0, 0, 1, 0, //
      tx, ty, 0, 1, //
    ]);
  }

  /// Where the point [p] of the part (picture pixels) is drawn.
  Offset mapPoint(Offset p, double width, double height) {
    final m = matrixIn(width, height);
    return Offset(
      m[0] * p.dx + m[4] * p.dy + m[12],
      m[1] * p.dx + m[5] * p.dy + m[13],
    );
  }

  LayerRegionEdit copyWith({
    RegionEditKind? kind,
    RegionSelection? region,
    double? dx,
    double? dy,
    double? scaleX,
    double? scaleY,
    double? rotation,
  }) => LayerRegionEdit(
    id: id,
    kind: kind ?? this.kind,
    region: region ?? this.region,
    dx: dx ?? this.dx,
    dy: dy ?? this.dy,
    scaleX: scaleX ?? this.scaleX,
    scaleY: scaleY ?? this.scaleY,
    rotation: rotation ?? this.rotation,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'region': region.toJson(),
    if (drawsPiece) ...{
      'dx': dx,
      'dy': dy,
      'scaleX': scaleX,
      'scaleY': scaleY,
      'rotation': rotation,
    },
  };

  /// The saved edit, or null when it is missing or not valid.
  static LayerRegionEdit? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final kind = RegionEditKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final region = RegionSelection.fromJson(json['region']);
    if (id is! String || kind == null || region == null) return null;
    double number(String key, double fallback) {
      final v = json[key];
      return v is num ? v.toDouble() : fallback;
    }

    final edit = LayerRegionEdit(
      id: id,
      kind: kind,
      region: region,
      dx: kind == RegionEditKind.erase ? 0 : number('dx', 0),
      dy: kind == RegionEditKind.erase ? 0 : number('dy', 0),
      scaleX: kind == RegionEditKind.erase ? 1 : number('scaleX', 1),
      scaleY: kind == RegionEditKind.erase ? 1 : number('scaleY', 1),
      rotation: kind == RegionEditKind.erase ? 0 : number('rotation', 0),
    );
    return edit.isValid ? edit : null;
  }

  /// The saved edits, leaving out any that cannot be read (a broken edit
  /// shows the picture without it rather than nothing), at most [maxCount].
  static List<LayerRegionEdit> listFromJson(Object? json) {
    if (json is! List) return const [];
    final edits = <LayerRegionEdit>[];
    final ids = <String>{};
    for (final item in json) {
      final edit = fromJson(item);
      if (edit == null || !ids.add(edit.id)) continue;
      edits.add(edit);
      if (edits.length == maxCount) break;
    }
    return List.unmodifiable(edits);
  }

  @override
  bool operator ==(Object other) =>
      other is LayerRegionEdit &&
      other.id == id &&
      other.kind == kind &&
      other.region == region &&
      other.dx == dx &&
      other.dy == dy &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY &&
      other.rotation == rotation;

  @override
  int get hashCode =>
      Object.hash(id, kind, region, dx, dy, scaleX, scaleY, rotation);

  @override
  String toString() =>
      'LayerRegionEdit($id, ${kind.name}, $region, '
      'd=($dx, $dy), s=($scaleX, $scaleY), r=$rotation)';
}
