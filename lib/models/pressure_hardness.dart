import 'brush.dart';

const int kMinPressureHardness = 1;
const int kMaxPressureHardness = 10;

/// Converts the ten-step UI hardness value to the existing 0-100 pressure
/// strength scale used by the drawing engine. Hardness 10 is exactly the
/// previous maximum pressure response.
int pressureStrengthForHardness(int hardness) =>
    hardness.clamp(kMinPressureHardness, kMaxPressureHardness).toInt() * 10;

/// Converts an existing pressure-strength value to the nearest UI hardness
/// step. Values below the editable range map to level 1.
int pressureHardnessForStrength(int strength) => (strength.clamp(10, 100) / 10)
    .round()
    .clamp(kMinPressureHardness, kMaxPressureHardness)
    .toInt();

/// The hardness control is intentionally read-only while pressure is OFF.
bool isPressureHardnessEnabled(PressureMode mode) => mode != PressureMode.off;
