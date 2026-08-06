import 'package:flutter/material.dart' show Color;
import '../engine/filter_engine.dart' show EffectFilterType;

/// タイムラインへ適用する演出フィルターの1インスタンス（仕様書18：演出フィルター）。
/// シーンごとに保持し、指定した開始〜終了フレームの範囲でのみ・非破壊で適用される。
class EffectFilterInstance {
  final String id;
  final EffectFilterType type;
  final int startFrame;
  final int endFrame;
  final bool enabled;
  // ぼかし強度・モザイクサイズ・色収差強度・ノイズ強度など種別ごとの主パラメータ
  final double param1;
  final Color fadeColor;

  const EffectFilterInstance({
    required this.id,
    required this.type,
    required this.startFrame,
    required this.endFrame,
    this.enabled = true,
    this.param1 = 5.0,
    this.fadeColor = const Color(0xFF000000),
  });

  EffectFilterInstance copyWith({
    EffectFilterType? type,
    int? startFrame,
    int? endFrame,
    bool? enabled,
    double? param1,
    Color? fadeColor,
  }) {
    return EffectFilterInstance(
      id: id,
      type: type ?? this.type,
      startFrame: startFrame ?? this.startFrame,
      endFrame: endFrame ?? this.endFrame,
      enabled: enabled ?? this.enabled,
      param1: param1 ?? this.param1,
      fadeColor: fadeColor ?? this.fadeColor,
    );
  }
}
