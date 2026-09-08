/// Serializable, surface-independent parameters for the VHS noise effect.
///
/// Both drawing filters and timeline effect filters should convert their UI/model
/// state through this class before invoking `VhsNoiseEngine`. Keeping the range
/// normalization here prevents preview/export differences caused by one surface
/// accepting values outside the documented 0..100 controls.
class VhsNoiseSettings {
  static const int defaultSeed = 1984;

  final double noiseStrength;
  final double scanlineStrength;
  final double colorBleed;
  final double tracking;
  final int seed;

  const VhsNoiseSettings({
    this.noiseStrength = 35,
    this.scanlineStrength = 35,
    this.colorBleed = 35,
    this.tracking = 25,
    this.seed = defaultSeed,
  });

  VhsNoiseSettings normalized() => VhsNoiseSettings(
    noiseStrength: noiseStrength.clamp(0.0, 100.0),
    scanlineStrength: scanlineStrength.clamp(0.0, 100.0),
    colorBleed: colorBleed.clamp(0.0, 100.0),
    tracking: tracking.clamp(0.0, 100.0),
    seed: seed,
  );

  VhsNoiseSettings copyWith({
    double? noiseStrength,
    double? scanlineStrength,
    double? colorBleed,
    double? tracking,
    int? seed,
  }) => VhsNoiseSettings(
    noiseStrength: noiseStrength ?? this.noiseStrength,
    scanlineStrength: scanlineStrength ?? this.scanlineStrength,
    colorBleed: colorBleed ?? this.colorBleed,
    tracking: tracking ?? this.tracking,
    seed: seed ?? this.seed,
  );

  Map<String, dynamic> toJson() => {
    'noiseStrength': noiseStrength,
    'scanlineStrength': scanlineStrength,
    'colorBleed': colorBleed,
    'tracking': tracking,
    'seed': seed,
  };

  factory VhsNoiseSettings.fromJson(Map<String, dynamic> json) =>
      VhsNoiseSettings(
        noiseStrength: (json['noiseStrength'] as num?)?.toDouble() ?? 35,
        scanlineStrength: (json['scanlineStrength'] as num?)?.toDouble() ?? 35,
        colorBleed: (json['colorBleed'] as num?)?.toDouble() ?? 35,
        tracking: (json['tracking'] as num?)?.toDouble() ?? 25,
        seed: (json['seed'] as num?)?.toInt() ?? defaultSeed,
      ).normalized();

  @override
  bool operator ==(Object other) =>
      other is VhsNoiseSettings &&
      other.noiseStrength == noiseStrength &&
      other.scanlineStrength == scanlineStrength &&
      other.colorBleed == colorBleed &&
      other.tracking == tracking &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(
    noiseStrength,
    scanlineStrength,
    colorBleed,
    tracking,
    seed,
  );
}
