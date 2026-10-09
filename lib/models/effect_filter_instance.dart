import 'package:flutter/material.dart' show Color;
import '../engine/filter_engine.dart' show EffectFilterType;
import 'pixel_color_mode.dart';

/// タイムラインへ適用する演出フィルターの1インスタンス。
/// シーンごとに保持し、指定した開始〜終了フレームの範囲でのみ・非破壊で適用される。
class EffectFilterInstance {
  final String id;
  final EffectFilterType type;
  final int startFrame;
  final int endFrame;
  final bool enabled;
  // ぼかし強度・モザイクサイズ・色収差強度・ノイズ強度など種別ごとの主パラメータ
  final double param1;
  // 動くノイズ・雨など、パラメータを複数持つフィルター用の追加スロット
  // （動くノイズ：param2=粒の量、param3=粒の大きさ。雨：param2=速さ、
  // param3=粒の大きさ、param4=風向きの角度）。未使用の種別では既定値のまま。
  final double param2;
  final double param3;
  final double param4;
  // レベル補正の出力の白（0〜255）。他の種別では使わない。
  final double param5;
  final Color fadeColor;
  // ドット絵演出フィルター（pixelate）の配色方式。countの場合はparam2
  // （色数）を、explicit（パレットから選んだ直後もこれになる。
  // PixelColorMode参照）の場合はpixelExplicitColorsを使う。
  final PixelColorMode pixelColorMode;
  final List<int> pixelExplicitColors;
  // ドット絵演出フィルターで色を限るとき、1色では遠い所を数色の規則的な
  // 並び（ディザリング）で近づけるか。オフなら最も近い1色で塗る。
  final bool pixelDither;

  const EffectFilterInstance({
    required this.id,
    required this.type,
    required this.startFrame,
    required this.endFrame,
    this.enabled = true,
    this.param1 = 5.0,
    this.param2 = 50.0,
    this.param3 = 2.0,
    this.param4 = 0.0,
    this.param5 = 255.0,
    this.fadeColor = const Color(0xFF000000),
    this.pixelColorMode = PixelColorMode.count,
    this.pixelExplicitColors = const [0xFF000000],
    this.pixelDither = true,
  });

  EffectFilterInstance copyWith({
    EffectFilterType? type,
    int? startFrame,
    int? endFrame,
    bool? enabled,
    double? param1,
    double? param2,
    double? param3,
    double? param4,
    double? param5,
    Color? fadeColor,
    PixelColorMode? pixelColorMode,
    List<int>? pixelExplicitColors,
    bool? pixelDither,
  }) {
    return EffectFilterInstance(
      id: id,
      type: type ?? this.type,
      startFrame: startFrame ?? this.startFrame,
      endFrame: endFrame ?? this.endFrame,
      enabled: enabled ?? this.enabled,
      param1: param1 ?? this.param1,
      param2: param2 ?? this.param2,
      param3: param3 ?? this.param3,
      param4: param4 ?? this.param4,
      param5: param5 ?? this.param5,
      fadeColor: fadeColor ?? this.fadeColor,
      pixelColorMode: pixelColorMode ?? this.pixelColorMode,
      pixelExplicitColors: pixelExplicitColors ?? this.pixelExplicitColors,
      pixelDither: pixelDither ?? this.pixelDither,
    );
  }
}
