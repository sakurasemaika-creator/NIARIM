import 'dart:math' as math;
import 'dart:typed_data';

/// Shared pixel engine for the drawing/effect VHS noise filters.
///
/// The implementation is deliberately deterministic: [seed] and [frameIndex]
/// fully determine the generated noise/tracking pattern. Drawing filters pass a
/// stable frameIndex (normally 0), while effect filters pass the timeline frame.
/// This keeps previews, exports and recorded automation reproducible.
class VhsNoiseEngine {
  const VhsNoiseEngine._();

  static Uint8List apply(
    Uint8List data,
    int width,
    int height, {
    double noiseStrength = 35,
    double scanlineStrength = 35,
    double colorBleed = 35,
    double tracking = 25,
    int seed = 1984,
    int frameIndex = 0,
  }) {
    if (width <= 0 || height <= 0 || data.length < width * height * 4) {
      return Uint8List.fromList(data);
    }

    final noise = (noiseStrength / 100).clamp(0.0, 1.0);
    final scanlines = (scanlineStrength / 100).clamp(0.0, 1.0);
    final bleed = (colorBleed / 100).clamp(0.0, 1.0);
    final trackingAmount = (tracking / 100).clamp(0.0, 1.0);
    if (noise == 0 && scanlines == 0 && bleed == 0 && trackingAmount == 0) {
      return Uint8List.fromList(data);
    }

    final result = Uint8List.fromList(data);
    final frameSeed = _mix(seed, frameIndex, width ^ (height << 8));
    // A zero bleed control must mean zero channel displacement even when other
    // VHS components remain enabled. The previous `1 + ...` formulation kept a
    // hidden 1 px red/blue split whenever scanlines/noise/tracking were active.
    final channelShift = bleed == 0 ? 0 : (1 + bleed * 5).round();
    final maxTrackingShift = math.max(
      1,
      (width * 0.035 * trackingAmount).round(),
    );

    // A small number of horizontal bands emulate unstable VHS tracking.
    final bandCount = trackingAmount == 0
        ? 0
        : 1 + (trackingAmount * 4).round();
    final bandStarts = <int>[];
    final bandHeights = <int>[];
    final bandShifts = <int>[];
    for (var band = 0; band < bandCount; band++) {
      final h0 = _hash(frameSeed ^ (band * 0x45d9f3b));
      final h1 = _hash(h0 ^ 0x27d4eb2d);
      final h2 = _hash(h1 ^ 0x165667b1);
      final bandHeight = math.max(
        1,
        (height * (0.01 + _unit(h1) * 0.055)).round(),
      );
      bandStarts.add((_unit(h0) * math.max(1, height - bandHeight)).round());
      bandHeights.add(bandHeight);
      final signed = _unit(h2) * 2 - 1;
      bandShifts.add((signed * maxTrackingShift).round());
    }

    for (var y = 0; y < height; y++) {
      var rowShift = 0;
      for (var band = 0; band < bandCount; band++) {
        if (y >= bandStarts[band] && y < bandStarts[band] + bandHeights[band]) {
          rowShift += bandShifts[band];
        }
      }

      // Low-frequency horizontal jitter is intentionally subtle outside the
      // tracking bands so the filter reads as VHS rather than generic glitch.
      if (trackingAmount > 0) {
        final jitterHash = _hash(frameSeed ^ (y * 0x1f123bb5));
        if (_unit(jitterHash) < trackingAmount * 0.08) {
          rowShift +=
              ((_unit(_hash(jitterHash ^ 0x6d2b79f5)) * 2 - 1) *
                      math.max(1, maxTrackingShift ~/ 2))
                  .round();
        }
      }

      final scanlineFactor = y.isOdd ? 1.0 - scanlines * 0.22 : 1.0;
      for (var x = 0; x < width; x++) {
        final outIndex = (y * width + x) * 4;
        final alpha = data[outIndex + 3];
        if (alpha == 0) continue;

        final baseX = (x + rowShift).clamp(0, width - 1);
        final redX = (baseX + channelShift).clamp(0, width - 1);
        final blueX = (baseX - channelShift).clamp(0, width - 1);
        final baseIndex = (y * width + baseX) * 4;
        final redIndex = (y * width + redX) * 4;
        final blueIndex = (y * width + blueX) * 4;

        var r = data[redIndex].toDouble();
        var g = data[baseIndex + 1].toDouble();
        var b = data[blueIndex + 2].toDouble();

        // Deterministic luminance noise. Keeping the same noise sample for RGB
        // avoids turning film grain into colored confetti; channel separation
        // above provides the characteristic analog color bleed instead.
        if (noise > 0) {
          final pixelHash = _hash(frameSeed ^ (y * width + x));
          final grain = (_unit(pixelHash) * 2 - 1) * 48 * noise;
          r += grain;
          g += grain;
          b += grain;
        }

        r *= scanlineFactor;
        g *= scanlineFactor;
        b *= scanlineFactor;

        result[outIndex] = r.round().clamp(0, 255);
        result[outIndex + 1] = g.round().clamp(0, 255);
        result[outIndex + 2] = b.round().clamp(0, 255);
        // VHS is a color/image-space effect. Never create, erase or blur alpha.
        result[outIndex + 3] = alpha;
      }
    }
    return result;
  }

  /// Stable cross-run seed for timeline effect instances.
  static int seedFromString(String value) {
    var hash = 2166136261;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  static int _mix(int seed, int frame, int salt) {
    var v = seed & 0x7fffffff;
    v ^= (frame * 0x45d9f3b) & 0x7fffffff;
    v ^= salt & 0x7fffffff;
    return _hash(v);
  }

  static int _hash(int value) {
    var x = value & 0x7fffffff;
    x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0x7fffffff;
    x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0x7fffffff;
    return (x ^ (x >> 16)) & 0x7fffffff;
  }

  static double _unit(int value) => (value & 0x7fffffff) / 0x7fffffff;
}
