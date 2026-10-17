/// マスクの形。
enum LayerMaskShape { rectangle, ellipse }

/// タイムラインの素材（テキスト・画像・動画）やフレーム（イラスト）の
/// 見える範囲を限る形。形の内側だけ（[invert]なら外側だけ）が見え、
/// 境目は[feather]だけなめらかに薄れる。
///
/// 位置と大きさはキャンバスに対する割合（0〜100）で持つので、描画エリアの
/// 解像度を変えても同じ所を隠す。素材のマスクは素材と一緒に動く（素材の
/// 位置・回転・拡大を当てる前の向きで指定する）。
class LayerMask {
  final LayerMaskShape shape;

  /// 中心（キャンバスの幅・高さに対する%）。
  final double centerX;
  final double centerY;

  /// 幅・高さ（キャンバスの幅・高さに対する%）。
  final double width;
  final double height;

  /// 回転（度）。
  final double rotation;

  /// 境目のぼかし（キャンバスの短い辺に対する%）。
  final double feather;

  /// 形の外側を見せる。
  final bool invert;

  const LayerMask({
    this.shape = LayerMaskShape.rectangle,
    this.centerX = 50,
    this.centerY = 50,
    this.width = 60,
    this.height = 60,
    this.rotation = 0,
    this.feather = 0,
    this.invert = false,
  });

  LayerMask copyWith({
    LayerMaskShape? shape,
    double? centerX,
    double? centerY,
    double? width,
    double? height,
    double? rotation,
    double? feather,
    bool? invert,
  }) => LayerMask(
    shape: shape ?? this.shape,
    centerX: centerX ?? this.centerX,
    centerY: centerY ?? this.centerY,
    width: width ?? this.width,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    feather: feather ?? this.feather,
    invert: invert ?? this.invert,
  );

  Map<String, dynamic> toJson() => {
    'shape': shape.name,
    'centerX': centerX,
    'centerY': centerY,
    'width': width,
    'height': height,
    'rotation': rotation,
    'feather': feather,
    'invert': invert,
  };

  static LayerMask? fromJson(Object? json) {
    if (json is! Map) return null;
    double number(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    return LayerMask(
      shape: LayerMaskShape.values.firstWhere(
        (s) => s.name == json['shape'],
        orElse: () => LayerMaskShape.rectangle,
      ),
      centerX: number('centerX', 50),
      centerY: number('centerY', 50),
      width: number('width', 60),
      height: number('height', 60),
      rotation: number('rotation', 0),
      feather: number('feather', 0),
      invert: json['invert'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LayerMask &&
      shape == other.shape &&
      centerX == other.centerX &&
      centerY == other.centerY &&
      width == other.width &&
      height == other.height &&
      rotation == other.rotation &&
      feather == other.feather &&
      invert == other.invert;

  @override
  int get hashCode => Object.hash(
    shape,
    centerX,
    centerY,
    width,
    height,
    rotation,
    feather,
    invert,
  );
}
