import 'dart:typed_data';

import '../models/vhs_noise_settings.dart';
import 'vhs_noise_engine.dart';

/// Thin shared adapter used by both destructive drawing-filter application and
/// non-destructive timeline effect rendering.
///
/// Keeping this top-level makes it safe to pass to Flutter's `compute()` when a
/// caller needs isolate execution. Drawing filters use [frameIndex] = 0 so the
/// result is stable; timeline effects pass the actual frame index to animate the
/// tape noise deterministically.
Uint8List applyVhsFilterInIsolate(
  (Uint8List data, int width, int height, VhsNoiseSettings settings, int frameIndex)
  args,
) {
  final (data, width, height, settings, frameIndex) = args;
  final normalized = settings.normalized();
  return VhsNoiseEngine.apply(
    data,
    width,
    height,
    noiseStrength: normalized.noiseStrength,
    scanlineStrength: normalized.scanlineStrength,
    colorBleed: normalized.colorBleed,
    tracking: normalized.tracking,
    seed: normalized.seed,
    frameIndex: frameIndex,
  );
}
