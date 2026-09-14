import 'brush.dart';

class ResolvedBrushPressure {
  final double sizeScale;
  final double opacityScale;
  final int blur;
  final bool edgeJitterEnabled;
  final int edgeJitterStrength;
  final BrushMixingMode mixingMode;
  final int mixingRate;

  const ResolvedBrushPressure({
    required this.sizeScale,
    required this.opacityScale,
    required this.blur,
    required this.edgeJitterEnabled,
    required this.edgeJitterStrength,
    required this.mixingMode,
    required this.mixingRate,
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
      mixingRate == other.mixingRate;

  @override
  int get hashCode => Object.hash(
        sizeScale,
        opacityScale,
        blur,
        edgeJitterEnabled,
        edgeJitterStrength,
        mixingMode,
        mixingRate,
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
      edgeJitterStrength:
          off.edgeJitter.enabled ? off.edgeJitter.value.clamp(0, 100) : 0,
      mixingMode: off.mixing.enabled ? off.mixing.mode : BrushMixingMode.off,
      mixingRate: off.mixing.enabled ? off.mixing.rate.clamp(0, 100) : 0,
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
  );
}
