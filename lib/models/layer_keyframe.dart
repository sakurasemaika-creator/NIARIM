/// レイヤー単位の位置・拡大縮小・回転キーフレーム。カメラキーフレーム
/// （画面全体に対する変換）と同じ考え方で、こちらは個々のレイヤーの
/// 表示位置だけを動かす。レイヤーのピクセル内容自体は変更しない。
class LayerKeyframe {
  final int frameIndex;
  final double x;
  final double y;
  final double scale;
  final double rotation; // 度数法

  const LayerKeyframe({
    required this.frameIndex,
    this.x = 0,
    this.y = 0,
    this.scale = 1.0,
    this.rotation = 0,
  });

  LayerKeyframe copyWith({
    int? frameIndex,
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return LayerKeyframe(
      frameIndex: frameIndex ?? this.frameIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  static LayerKeyframe lerp(LayerKeyframe a, LayerKeyframe b, double t) {
    return LayerKeyframe(
      frameIndex: (a.frameIndex + (b.frameIndex - a.frameIndex) * t).round(),
      x: a.x + (b.x - a.x) * t,
      y: a.y + (b.y - a.y) * t,
      scale: a.scale + (b.scale - a.scale) * t,
      rotation: a.rotation + (b.rotation - a.rotation) * t,
    );
  }

  Map<String, dynamic> toJson() => {
        'frameIndex': frameIndex,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
      };

  factory LayerKeyframe.fromJson(Map<String, dynamic> j) => LayerKeyframe(
        frameIndex: j['frameIndex'] as int,
        x: (j['x'] as num?)?.toDouble() ?? 0,
        y: (j['y'] as num?)?.toDouble() ?? 0,
        scale: (j['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
      );
}
