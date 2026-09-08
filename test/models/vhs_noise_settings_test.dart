import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/vhs_noise_settings.dart';

void main() {
  test('VHS settings round-trip through JSON', () {
    const source = VhsNoiseSettings(
      noiseStrength: 12.5,
      scanlineStrength: 34,
      colorBleed: 56,
      tracking: 78,
      seed: 2026,
    );

    expect(VhsNoiseSettings.fromJson(source.toJson()), source);
  });

  test('VHS settings clamp UI percentages during deserialization', () {
    final parsed = VhsNoiseSettings.fromJson({
      'noiseStrength': -20,
      'scanlineStrength': 130,
      'colorBleed': 999,
      'tracking': -1,
      'seed': 42,
    });

    expect(parsed.noiseStrength, 0);
    expect(parsed.scanlineStrength, 100);
    expect(parsed.colorBleed, 100);
    expect(parsed.tracking, 0);
    expect(parsed.seed, 42);
  });

  test('missing JSON values retain documented defaults', () {
    final parsed = VhsNoiseSettings.fromJson(const {});

    expect(parsed, const VhsNoiseSettings());
    expect(parsed.seed, VhsNoiseSettings.defaultSeed);
  });
}
