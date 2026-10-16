import 'brush.dart';

class ResolvedBrushPressure {
  final double sizeScale;
  final double opacityScale;
  final int blur;
  final bool edgeJitterEnabled;
  final int edgeJitterStrength;
  final BrushMixingMode mixingMode;
  final int mixingRate;
  final int mixingBrightnessCorrection;

  /// 色延び・水分量・絵具量・にじみ・むら・境界のぼかし（0〜100）。
  final int mixingStretch;
  final int mixingWater;
  final int mixingPigment;
  final int mixingBleed;
  final int mixingTexture;
  final int mixingSoftEdge;

  const ResolvedBrushPressure({
    required this.sizeScale,
    required this.opacityScale,
    required this.blur,
    required this.edgeJitterEnabled,
    required this.edgeJitterStrength,
    required this.mixingMode,
    required this.mixingRate,
    required this.mixingBrightnessCorrection,
    this.mixingStretch = kDefaultMixingStretch,
    this.mixingWater = kDefaultMixingWater,
    this.mixingPigment = kDefaultMixingPigment,
    this.mixingBleed = kDefaultMixingBleed,
    this.mixingTexture = kDefaultMixingTexture,
    this.mixingSoftEdge = kDefaultMixingSoftEdge,
  });

  @override
  bool operator ==(Object other) =>
      other is ResolvedBrushPressure &&
      sizeScale == other.sizeScale &&
      opacityScale == other.opacityScale &&
      blur == other.blur &&
      edgeJitterEnabled == other.edgeJitterEnabled &&
      edgeJitterStrength == other.edgeJitterStrength &&
      mixingMode == other.mixingMode &&
      mixingRate == other.mixingRate &&
      mixingBrightnessCorrection == other.mixingBrightnessCorrection &&
      mixingStretch == other.mixingStretch &&
      mixingWater == other.mixingWater &&
      mixingPigment == other.mixingPigment &&
      mixingBleed == other.mixingBleed &&
      mixingTexture == other.mixingTexture &&
      mixingSoftEdge == other.mixingSoftEdge;

  @override
  int get hashCode => Object.hash(
    sizeScale,
    opacityScale,
    blur,
    edgeJitterEnabled,
    edgeJitterStrength,
    mixingMode,
    mixingRate,
    mixingBrightnessCorrection,
    mixingStretch,
    mixingWater,
    mixingPigment,
    mixingBleed,
    mixingTexture,
    mixingSoftEdge,
  );
}

int _interpolateInt(int weak, int strong, double t) =>
    (weak + (strong - weak) * t).round().clamp(0, 100);

double _interpolatePercent(PressureRangeSetting setting, double t) =>
    setting.enabled
    ? _interpolateInt(setting.weak, setting.strong, t) / 100.0
    : 1.0;

ResolvedBrushPressure resolveBrushPressure({
  required Brush brush,
  required bool pressureEnabled,
  required double curvedPressure,
}) {
  if (!pressureEnabled) {
    final off = brush.pressureOff;
    return ResolvedBrushPressure(
      sizeScale: 1,
      opacityScale: 1,
      blur: off.blur.enabled ? off.blur.value.clamp(0, 100) : 0,
      edgeJitterEnabled: off.edgeJitter.enabled,
      edgeJitterStrength: off.edgeJitter.enabled
          ? off.edgeJitter.value.clamp(0, 100)
          : 0,
      mixingMode: off.mixing.enabled ? off.mixing.mode : BrushMixingMode.off,
      mixingRate: off.mixing.enabled ? off.mixing.rate.clamp(0, 100) : 0,
      mixingBrightnessCorrection: off.mixing.enabled
          ? off.mixing.brightnessCorrection.clamp(1, 5).toInt()
          : 3,
      mixingStretch: off.mixing.stretch.clamp(0, 100).toInt(),
      mixingWater: off.mixing.water.clamp(0, 100).toInt(),
      mixingPigment: off.mixing.pigment.clamp(0, 100).toInt(),
      mixingBleed: off.mixing.bleed.clamp(0, 100).toInt(),
      mixingTexture: off.mixing.texture.clamp(0, 100).toInt(),
      mixingSoftEdge: off.mixing.softEdge.clamp(0, 100).toInt(),
    );
  }

  final on = brush.pressureOn;
  final t = curvedPressure.clamp(0.0, 1.0);
  return ResolvedBrushPressure(
    sizeScale: _interpolatePercent(on.size, t),
    opacityScale: _interpolatePercent(on.opacity, t),
    blur: on.blur.enabled
        ? _interpolateInt(on.blur.weak, on.blur.strong, t)
        : 0,
    edgeJitterEnabled: on.edgeJitter.enabled,
    edgeJitterStrength: on.edgeJitter.enabled
        ? _interpolateInt(on.edgeJitter.weak, on.edgeJitter.strong, t)
        : 0,
    mixingMode: on.mixing.enabled ? on.mixing.mode : BrushMixingMode.off,
    mixingRate: on.mixing.enabled
        ? _interpolateInt(on.mixing.weakRate, on.mixing.strongRate, t)
        : 0,
    mixingBrightnessCorrection: on.mixing.enabled
        ? on.mixing.brightnessCorrection.clamp(1, 5).toInt()
        : 3,
    mixingStretch: on.mixing.stretch.clamp(0, 100).toInt(),
    mixingWater: on.mixing.water.clamp(0, 100).toInt(),
    mixingPigment: on.mixing.pigment.clamp(0, 100).toInt(),
    mixingBleed: on.mixing.bleed.clamp(0, 100).toInt(),
    mixingTexture: on.mixing.texture.clamp(0, 100).toInt(),
    mixingSoftEdge: on.mixing.softEdge.clamp(0, 100).toInt(),
  );
}
