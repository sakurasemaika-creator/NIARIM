import 'autofill_gradient.dart';
import 'layer.dart' show LayerBlendMode;

class AutofillPreset {
  final String id;
  final String name;
  final String? thumbnailPath;
  final List<AutofillPart> parts;
  final bool isFavorite;

  const AutofillPreset({
    required this.id,
    required this.name,
    this.thumbnailPath,
    this.parts = const [],
    this.isFavorite = false,
  });

  // thumbnailPathはsentinelパターンで明示的にnullへクリアできるようにする
  // （単純な`?? this.thumbnailPath`だとnullを渡してもクリアできないため。
  // サムネイル画像削除機能で必要）。
  AutofillPreset copyWith({
    String? id,
    String? name,
    Object? thumbnailPath = _sentinel,
    List<AutofillPart>? parts,
    bool? isFavorite,
  }) {
    return AutofillPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      thumbnailPath: thumbnailPath == _sentinel ? this.thumbnailPath : thumbnailPath as String?,
      parts: parts ?? this.parts,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'thumbnailPath': thumbnailPath,
        'parts': parts.map((p) => p.toJson()).toList(),
        'isFavorite': isFavorite,
      };

  factory AutofillPreset.fromJson(Map<String, dynamic> j) => AutofillPreset(
        id: j['id'] as String,
        name: j['name'] as String,
        thumbnailPath: j['thumbnailPath'] as String?,
        parts: (j['parts'] as List<dynamic>? ?? const [])
            .map((e) => AutofillPart.fromJson(e as Map<String, dynamic>))
            .toList(),
        isFavorite: j['isFavorite'] as bool? ?? false,
      );
}

/// 線画色の決定方法（仕様書20：線画色設定）。
enum AutofillLineColorMode {
  specified,     // 指定色
  sameAsFill,    // 塗り色と同じ
  traceAdjust,   // 色トレス・線画馴染ませ（元の線画色をHSLシフトして塗り色に馴染ませる）
}

class AutofillPart {
  final String id;
  final String name;
  // ARGB int値（例: 0xFFFF0000 = 赤）。gradientが設定されている場合は
  // グラデーションが優先され、colorは使用されない（仕様書20：塗り色設定）。
  final int color;
  final AutofillGradient? gradient;

  // レイヤー不透明度（仕様書20：「自動塗りプリセットで設定する不透明度は
  // レイヤー不透明度として反映する。塗り色の不透明度は100%固定」）
  final int opacity; // 0〜100
  // ブレンドモード（仕様書20：「自動塗りレイヤー・対応する自動塗り用線画レイヤーの
  // 両方へ反映する」）
  final LayerBlendMode blendMode;

  // トーン設定（仕様書20：ONにするとトーン一覧が表示され、選択したトーンを
  // 現在色で描画する。バケツトーンエンジンを使用）
  final bool useTone;
  final String? toneId;

  // 線画色設定（仕様書20）
  final AutofillLineColorMode lineColorMode;
  final int lineColor; // lineColorMode==specified で使用
  final int lineOpacity; // 0〜100（線画レイヤー不透明度）
  // 色トレス・線画馴染ませ用スライダー（デフォルト値は仕様書20の既定値）。
  // 色相・明度と同じく、彩度も「塗り色そのものからのオフセット」として
  // 扱う（0＝塗り色と同じ彩度）。3項目とも塗り色からのオフセットとして
  // 統一されており、挙動が揃っている。
  final double traceHue; // -180〜180、既定 -10
  final double traceSaturation; // -100〜100、既定 +60（塗り色からのオフセット）
  final double traceLightness; // -100〜100、既定 -50

  final bool isFavorite;

  const AutofillPart({
    required this.id,
    required this.name,
    required this.color,
    this.gradient,
    this.opacity = 100,
    this.blendMode = LayerBlendMode.normal,
    this.useTone = false,
    this.toneId,
    this.lineColorMode = AutofillLineColorMode.specified,
    this.lineColor = 0xFF000000,
    this.lineOpacity = 100,
    this.traceHue = -10,
    this.traceSaturation = 60,
    this.traceLightness = -50,
    this.isFavorite = false,
  });

  AutofillPart copyWith({
    String? id,
    String? name,
    int? color,
    Object? gradient = _sentinel,
    int? opacity,
    LayerBlendMode? blendMode,
    bool? useTone,
    Object? toneId = _sentinel,
    AutofillLineColorMode? lineColorMode,
    int? lineColor,
    int? lineOpacity,
    double? traceHue,
    double? traceSaturation,
    double? traceLightness,
    bool? isFavorite,
  }) {
    return AutofillPart(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      gradient: identical(gradient, _sentinel) ? this.gradient : gradient as AutofillGradient?,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      useTone: useTone ?? this.useTone,
      toneId: identical(toneId, _sentinel) ? this.toneId : toneId as String?,
      lineColorMode: lineColorMode ?? this.lineColorMode,
      lineColor: lineColor ?? this.lineColor,
      lineOpacity: lineOpacity ?? this.lineOpacity,
      traceHue: traceHue ?? this.traceHue,
      traceSaturation: traceSaturation ?? this.traceSaturation,
      traceLightness: traceLightness ?? this.traceLightness,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// ✓設定完了マーク判定用（仕様書20：「未設定項目が1つでもある場合は保存不可。
  /// すべて設定完了になると保存可能」）。トーンONなのにトーン未選択の場合のみ
  /// 未設定として扱う（色は常にデフォルト値を持つため必ず設定済みとみなす）。
  bool get isConfigured => !useTone || toneId != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'gradient': gradient?.toJson(),
        'opacity': opacity,
        'blendMode': blendMode.name,
        'useTone': useTone,
        'toneId': toneId,
        'lineColorMode': lineColorMode.name,
        'lineColor': lineColor,
        'lineOpacity': lineOpacity,
        'traceHue': traceHue,
        'traceSaturation': traceSaturation,
        'traceLightness': traceLightness,
        'isFavorite': isFavorite,
      };

  factory AutofillPart.fromJson(Map<String, dynamic> j) => AutofillPart(
        id: j['id'] as String,
        name: j['name'] as String,
        color: j['color'] as int,
        gradient: j['gradient'] == null
            ? null
            : AutofillGradient.fromJson(j['gradient'] as Map<String, dynamic>),
        opacity: j['opacity'] as int? ?? 100,
        blendMode: LayerBlendMode.values.firstWhere((e) => e.name == j['blendMode'],
            orElse: () => LayerBlendMode.normal),
        useTone: j['useTone'] as bool? ?? false,
        toneId: j['toneId'] as String?,
        lineColorMode: AutofillLineColorMode.values.firstWhere((e) => e.name == j['lineColorMode'],
            orElse: () => AutofillLineColorMode.specified),
        lineColor: j['lineColor'] as int? ?? 0xFF000000,
        lineOpacity: j['lineOpacity'] as int? ?? 100,
        traceHue: (j['traceHue'] as num?)?.toDouble() ?? -10,
        traceSaturation: (j['traceSaturation'] as num?)?.toDouble() ?? 60,
        traceLightness: (j['traceLightness'] as num?)?.toDouble() ?? -50,
        isFavorite: j['isFavorite'] as bool? ?? false,
      );
}

const Object _sentinel = Object();
