/// キーフレーム間の補間カーブ（Task#137：イージング）。このキーフレーム
/// から「次のキーフレームへ」つながる区間の変化の付き方を指定する
/// （After Effects等の「アウトゴーイングのイージング」と同じ考え方。
/// 一覧の末尾のキーフレームに設定しても、次のキーフレームが無いため
/// 効果は無い）。既定は[linear]（従来どおりの等速）で、既存の保存データ
/// との後方互換を保つ。
enum LayerKeyframeEasing {
  /// 等速（従来の挙動）。
  linear,
  /// ゆっくり始まり、加速しながら終わる。
  easeIn,
  /// 素早く始まり、減速しながら終わる。
  easeOut,
  /// ゆっくり始まり、ゆっくり終わる（中間だけ速い）。
  easeInOut,
  /// 終端でバウンドしてから収まる（弾むような動き）。
  bounceOut,
}

/// レイヤー単位の位置・拡大縮小・回転キーフレーム。カメラキーフレーム
/// （画面全体に対する変換）と同じ考え方で、こちらは個々のレイヤーの
/// 表示位置だけを動かす。レイヤーのピクセル内容自体は変更しない。
class LayerKeyframe {
  final int frameIndex;
  final double x;
  final double y;
  final double scale;
  final double rotation; // 度数法
  final LayerKeyframeEasing easing;

  const LayerKeyframe({
    required this.frameIndex,
    this.x = 0,
    this.y = 0,
    this.scale = 1.0,
    this.rotation = 0,
    this.easing = LayerKeyframeEasing.linear,
  });

  LayerKeyframe copyWith({
    int? frameIndex,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    LayerKeyframeEasing? easing,
  }) {
    return LayerKeyframe(
      frameIndex: frameIndex ?? this.frameIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      easing: easing ?? this.easing,
    );
  }

  /// [a]から[b]へ、既に補間カーブ適用済みの[t]（0〜1）で線形補間する。
  /// イージング自体の適用はLayerKeyframeEngine側（[t]を歪める側）が担い、
  /// ここは純粋な線形補間のみを行う。
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
        'easing': easing.name,
      };

  factory LayerKeyframe.fromJson(Map<String, dynamic> j) => LayerKeyframe(
        frameIndex: j['frameIndex'] as int,
        x: (j['x'] as num?)?.toDouble() ?? 0,
        y: (j['y'] as num?)?.toDouble() ?? 0,
        scale: (j['scale'] as num?)?.toDouble() ?? 1.0,
        rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
        // 未設定（古い保存データ）はlinear扱いにし、従来の挙動を保つ。
        easing: LayerKeyframeEasing.values
            .firstWhere((e) => e.name == j['easing'], orElse: () => LayerKeyframeEasing.linear),
      );
}
