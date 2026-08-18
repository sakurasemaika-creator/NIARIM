/// 自動塗りプリセットの塗り色グラデーション（仕様書20：色管理仕様）。
/// nullの場合はAutofillPart.colorの単色塗りを使用する。
enum AutofillGradientType {
  linear,          // 直線（角度指定）
  radialCenterOut, // 放射状：中央→外側
  radialOutCenter, // 放射状：外側→中央
}

class AutofillGradient {
  final AutofillGradientType type;
  final double angle; // 度数（0〜360）。typeがlinearのみ使用
  final double centerX; // 0.0〜1.0（キャンバス比率）。typeがradial系のみ使用
  final double centerY;
  final List<int> colors; // ARGB、2〜10色。アルファ値＝その色の不透明度
  final List<double> stops; // 0.0〜1.0、colorsと同じ数。境界（色比率）
  // ぼかしの強さ（0.0〜1.0、既定1.0＝従来通りの滑らかなブレンド）。値を
  // 下げるほど各色の境界がはっきりした帯状（バンド）表示に近づく（仕様書20）。
  final double feather;

  const AutofillGradient({
    this.type = AutofillGradientType.linear,
    this.angle = 0,
    this.centerX = 0.5,
    this.centerY = 0.5,
    required this.colors,
    required this.stops,
    this.feather = 1.0,
  });

  /// 2色のデフォルトグラデーションを生成する。
  factory AutofillGradient.defaultTwoColor(int colorA, int colorB) => AutofillGradient(
        colors: [colorA, colorB],
        stops: const [0.0, 1.0],
      );

  AutofillGradient copyWith({
    AutofillGradientType? type,
    double? angle,
    double? centerX,
    double? centerY,
    List<int>? colors,
    List<double>? stops,
    double? feather,
  }) {
    return AutofillGradient(
      type: type ?? this.type,
      angle: angle ?? this.angle,
      centerX: centerX ?? this.centerX,
      centerY: centerY ?? this.centerY,
      colors: colors ?? this.colors,
      stops: stops ?? this.stops,
      feather: feather ?? this.feather,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'angle': angle,
        'centerX': centerX,
        'centerY': centerY,
        'colors': colors,
        'stops': stops,
        'feather': feather,
      };

  factory AutofillGradient.fromJson(Map<String, dynamic> j) => AutofillGradient(
        type: AutofillGradientType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => AutofillGradientType.linear),
        angle: (j['angle'] as num?)?.toDouble() ?? 0,
        centerX: (j['centerX'] as num?)?.toDouble() ?? 0.5,
        centerY: (j['centerY'] as num?)?.toDouble() ?? 0.5,
        colors: (j['colors'] as List<dynamic>).map((e) => e as int).toList(),
        stops: (j['stops'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        feather: (j['feather'] as num?)?.toDouble() ?? 1.0,
      );
}
