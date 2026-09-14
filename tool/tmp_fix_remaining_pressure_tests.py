from pathlib import Path


def replace(path, old, new, count=1):
    p = Path(path)
    s = p.read_text()
    if s.count(old) < count:
        raise RuntimeError(f'{path}: expected snippet not found: {old[:80]!r}')
    s = s.replace(old, new, count)
    p.write_text(s)

# final_remaining_strict_evidence_test: express the same response directly as weak/strong profile values.
replace(
    'test/final_remaining_strict_evidence_test.dart',
    """  test('筆圧サイズ: strength 0/50/100 が同一pressure=0.25の実線幅へ段階追従', () async {
    final spans = <int, int>{};
    for (final strength in [0, 50, 100]) {
      final tm = TileManager(canvasWidth: 80, canvasHeight: 80);
      final e = DrawingEngine(tileManager: tm)
        ..currentBrush = _brush(
          size: 32,
          pressureMode: PressureMode.size,
          pressureStrength: strength,
        )
""",
    """  test('筆圧サイズ: weak 100/50/0 が同一pressure=0.25の実線幅へ段階追従', () async {
    final spans = <int, int>{};
    for (final weak in [100, 50, 0]) {
      final tm = TileManager(canvasWidth: 80, canvasHeight: 80);
      final e = DrawingEngine(tileManager: tm)
        ..currentBrush = _brush(
          size: 32,
          sizePressure: PressureRangeSetting(
            enabled: true,
            weak: weak,
            strong: 100,
          ),
        )
""",
)
replace('test/final_remaining_strict_evidence_test.dart', "'${out.path}/pressure_size_strength_$strength.png'", "'${out.path}/pressure_size_weak_$weak.png'")
replace('test/final_remaining_strict_evidence_test.dart', 'spans[strength] = _verticalSpan(rgba, 80, 40);', 'spans[weak] = _verticalSpan(rgba, 80, 40);')
replace(
    'test/final_remaining_strict_evidence_test.dart',
    """    expect(spans[0]!, greaterThan(spans[50]!));
    expect(spans[50]!, greaterThan(spans[100]!));
    expect(spans[0]!, greaterThanOrEqualTo(28));
    expect(spans[100]!, lessThanOrEqualTo(12));
""",
    """    expect(spans[100]!, greaterThan(spans[50]!));
    expect(spans[50]!, greaterThan(spans[0]!));
    expect(spans[100]!, greaterThanOrEqualTo(28));
    expect(spans[0]!, lessThanOrEqualTo(12));
""",
)
replace(
    'test/final_remaining_strict_evidence_test.dart',
    """Brush _brush({
  double size = 12,
  PressureMode pressureMode = PressureMode.off,
  int pressureStrength = 100,
  FadeMode fadeMode = FadeMode.off,
  FadeCustomSettings? fadeCustom,
}) => Brush(
""",
    """Brush _brush({
  double size = 12,
  PressureRangeSetting sizePressure = const PressureRangeSetting(
    enabled: false,
    weak: 50,
    strong: 100,
  ),
  FadeMode fadeMode = FadeMode.off,
  FadeCustomSettings? fadeCustom,
}) => Brush(
""",
)
replace(
    'test/final_remaining_strict_evidence_test.dart',
    """  spacing: 1,
  blurRadius: 0,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureMode: pressureMode,
  pressureStrength: pressureStrength,
  fadeMode: fadeMode,
""",
    """  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: sizePressure,
    opacity: const PressureRangeSetting(enabled: false, weak: 50, strong: 100),
  ),
  fadeMode: fadeMode,
""",
)
replace(
    'test/final_remaining_strict_evidence_test.dart',
    """  strokeDecay: false,
  mixingMode: BrushMixingMode.off,
  mixingRate: 0,
);
""",
    """  strokeDecay: false,
);
""",
)

# batch10: new opacity pressure range + current mixing profile.
replace(
    'test/functional_audit_batch10_test.dart',
    """  test('筆圧強度：0/50/100で同じpressure=0.25の効き方が段階的に変わる', () async {
    final alphas = <int, int>{};
    for (final strength in [0, 50, 100]) {
""",
    """  test('筆圧不透明度：weak 100/50/0で同じpressure=0.25の効き方が段階的に変わる', () async {
    final alphas = <int, int>{};
    for (final weak in [100, 50, 0]) {
""",
)
replace(
    'test/functional_audit_batch10_test.dart',
    """          pressureMode: PressureMode.opacity,
          pressureStrength: strength,
""",
    """          opacityPressure: PressureRangeSetting(
            enabled: true,
            weak: weak,
            strong: 100,
          ),
""",
)
replace('test/functional_audit_batch10_test.dart', "'${out.path}/pressure_strength_$strength.png'", "'${out.path}/pressure_opacity_weak_$weak.png'")
replace('test/functional_audit_batch10_test.dart', 'alphas[strength] = _pixel(await _rgba(image), 72, 36, 36)[3];', 'alphas[weak] = _pixel(await _rgba(image), 72, 36, 36)[3];')
replace(
    'test/functional_audit_batch10_test.dart',
    """    // strength=0 は筆圧影響なし、100 は入力pressureを完全反映、50 はその中間。
    expect(alphas[0]!, inInclusiveRange(250, 255));
    expect(alphas[100]!, inInclusiveRange(60, 68));
    expect(alphas[50]!, greaterThan(alphas[100]!));
    expect(alphas[50]!, lessThan(alphas[0]!));
""",
    """    // weak=100 は筆圧影響なし、0 は入力pressureを完全反映、50 はその中間。
    expect(alphas[100]!, inInclusiveRange(250, 255));
    expect(alphas[0]!, inInclusiveRange(60, 68));
    expect(alphas[50]!, greaterThan(alphas[0]!));
    expect(alphas[50]!, lessThan(alphas[100]!));
""",
)
replace(
    'test/functional_audit_batch10_test.dart',
    """  PressureMode pressureMode = PressureMode.off,
  int pressureStrength = 100,
  BrushMixingMode mixingMode = BrushMixingMode.off,
""",
    """  PressureRangeSetting opacityPressure = const PressureRangeSetting(
    enabled: false,
    weak: 50,
    strong: 100,
  ),
  BrushMixingMode mixingMode = BrushMixingMode.off,
""",
)
replace(
    'test/functional_audit_batch10_test.dart',
    """  spacing: 1,
  blurRadius: 0,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureMode: pressureMode,
  pressureStrength: pressureStrength,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  mixingMode: mixingMode,
  mixingRate: mixingRate,
);
""",
    """  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: const PressureRangeSetting(enabled: false, weak: 50, strong: 100),
    opacity: opacityPressure,
    mixing: PressureMixingOnSetting(
      enabled: mixingMode != BrushMixingMode.off,
      mode: mixingMode == BrushMixingMode.off ? BrushMixingMode.simple : mixingMode,
      weakRate: mixingRate,
      strongRate: mixingRate,
    ),
  ),
  pressureOff: BrushPressureOffSettings.defaults.copyWith(
    mixing: PressureMixingOffSetting(
      enabled: mixingMode != BrushMixingMode.off,
      mode: mixingMode == BrushMixingMode.off ? BrushMixingMode.simple : mixingMode,
      rate: mixingRate,
    ),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
);
""",
)

# batch9: explicit opacity pressure range; mixing uses current profile.
replace(
    'test/functional_audit_batch9_test.dart',
    '        pressureMode: PressureMode.opacity,',
    '        opacityPressure: const PressureRangeSetting(enabled: true, weak: 0, strong: 100),',
)
replace(
    'test/functional_audit_batch9_test.dart',
    """  PressureMode pressureMode = PressureMode.off,
  bool stabilization = false,
""",
    """  PressureRangeSetting opacityPressure = const PressureRangeSetting(
    enabled: false,
    weak: 50,
    strong: 100,
  ),
  bool stabilization = false,
""",
)
replace(
    'test/functional_audit_batch9_test.dart',
    """  spacing: 1,
  blurRadius: 0,
  stabilization: stabilization,
  stabilizationStrength: stabilizationStrength,
  pixelMode: false,
  pressureMode: pressureMode,
  pressureStrength: 100,
  fadeMode: fadeMode,
  fadeCustom: fadeCustom,
  strokeDecay: false,
  mixingMode: mixingMode,
  mixingRate: mixingRate,
);
""",
    """  spacing: 1,
  stabilization: stabilization,
  stabilizationStrength: stabilizationStrength,
  pixelMode: false,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: const PressureRangeSetting(enabled: false, weak: 50, strong: 100),
    opacity: opacityPressure,
    mixing: PressureMixingOnSetting(
      enabled: mixingMode != BrushMixingMode.off,
      mode: mixingMode == BrushMixingMode.off ? BrushMixingMode.simple : mixingMode,
      weakRate: mixingRate,
      strongRate: mixingRate,
    ),
  ),
  pressureOff: BrushPressureOffSettings.defaults.copyWith(
    mixing: PressureMixingOffSetting(
      enabled: mixingMode != BrushMixingMode.off,
      mode: mixingMode == BrushMixingMode.off ? BrushMixingMode.simple : mixingMode,
      rate: mixingRate,
    ),
  ),
  fadeMode: fadeMode,
  fadeCustom: fadeCustom,
  strokeDecay: false,
);
""",
)

# batch12: size + opacity ranges replace old sizeAndOpacity mode.
replace(
    'test/functional_audit_batch12_test.dart',
    """        pressureMode: PressureMode.sizeAndOpacity,
        pressureStrength: 100,
""",
    """        sizePressure: const PressureRangeSetting(enabled: true, weak: 0, strong: 100),
        opacityPressure: const PressureRangeSetting(enabled: true, weak: 0, strong: 100),
""",
)
replace(
    'test/functional_audit_batch12_test.dart',
    """  PressureMode pressureMode = PressureMode.off,
  int pressureStrength = 100,
  bool strokeDecay = false,
""",
    """  PressureRangeSetting sizePressure = const PressureRangeSetting(
    enabled: false,
    weak: 50,
    strong: 100,
  ),
  PressureRangeSetting opacityPressure = const PressureRangeSetting(
    enabled: false,
    weak: 50,
    strong: 100,
  ),
  bool strokeDecay = false,
""",
)
replace(
    'test/functional_audit_batch12_test.dart',
    """  spacing: 1,
  blurRadius: 0,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureMode: pressureMode,
  pressureStrength: pressureStrength,
  fadeMode: fadeMode,
  fadeCustom: fadeCustom,
  strokeDecay: strokeDecay,
  mixingMode: BrushMixingMode.off,
  mixingRate: 0,
);
""",
    """  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: false,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: sizePressure,
    opacity: opacityPressure,
  ),
  fadeMode: fadeMode,
  fadeCustom: fadeCustom,
  strokeDecay: strokeDecay,
);
""",
)

# real async render: blur profile and size pressure profile.
replace(
    'test/functional_render_real_async_test.dart',
    '_brush(size: 28, pressureMode: PressureMode.size)',
    '_brush(size: 28, sizePressure: const PressureRangeSetting(enabled: true, weak: 0, strong: 100))',
)
replace(
    'test/functional_render_real_async_test.dart',
    """  int blurRadius = 0,
  bool pixelMode = false,
  PressureMode pressureMode = PressureMode.off,
  double? calligraphyAngle,
""",
    """  int blurRadius = 0,
  bool pixelMode = false,
  PressureRangeSetting sizePressure = const PressureRangeSetting(
    enabled: false,
    weak: 50,
    strong: 100,
  ),
  double? calligraphyAngle,
""",
)
replace(
    'test/functional_render_real_async_test.dart',
    """  spacing: 1,
  blurRadius: blurRadius,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: pixelMode,
  pressureMode: pressureMode,
  pressureStrength: 100,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  mixingMode: BrushMixingMode.off,
  mixingRate: 0,
  calligraphyAngle: calligraphyAngle,
);
""",
    """  spacing: 1,
  stabilization: false,
  stabilizationStrength: 0,
  pixelMode: pixelMode,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: sizePressure,
    opacity: const PressureRangeSetting(enabled: false, weak: 50, strong: 100),
    blur: PressureRangeSetting(enabled: blurRadius > 0, weak: blurRadius, strong: blurRadius),
  ),
  pressureOff: BrushPressureOffSettings.defaults.copyWith(
    blur: FixedBrushSetting(enabled: blurRadius > 0, value: blurRadius),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
  calligraphyAngle: calligraphyAngle,
);
""",
)

# strict visual evidence: fixed mixing profile in both ON/OFF cases.
replace(
    'test/strict_visual_evidence_audit_test.dart',
    """  spacing: 1,
  blurRadius: 0,
  stabilization: stabilization,
  stabilizationStrength: stabilizationStrength,
  pixelMode: false,
  pressureMode: PressureMode.off,
  pressureStrength: 100,
  fadeMode: FadeMode.off,
  strokeDecay: false,
  mixingMode: mixingMode,
  mixingRate: mixingRate,
);
""",
    """  spacing: 1,
  stabilization: stabilization,
  stabilizationStrength: stabilizationStrength,
  pixelMode: false,
  pressureOn: BrushPressureOnSettings.defaults.copyWith(
    size: const PressureRangeSetting(enabled: false, weak: 50, strong: 100),
    opacity: const PressureRangeSetting(enabled: false, weak: 50, strong: 100),
    mixing: PressureMixingOnSetting(
      enabled: mixingMode != BrushMixingMode.off,
      mode: mixingMode == BrushMixingMode.off ? BrushMixingMode.simple : mixingMode,
      weakRate: mixingRate,
      strongRate: mixingRate,
    ),
  ),
  pressureOff: BrushPressureOffSettings.defaults.copyWith(
    mixing: PressureMixingOffSetting(
      enabled: mixingMode != BrushMixingMode.off,
      mode: mixingMode == BrushMixingMode.off ? BrushMixingMode.simple : mixingMode,
      rate: mixingRate,
    ),
  ),
  fadeMode: FadeMode.off,
  strokeDecay: false,
);
""",
)

# creative persistence now asserts current profile fields.
replace(
    'test/creative_asset_persistence_test.dart',
    '      expect(restored.mixingMode, BrushMixingMode.bleed);',
    """      expect(restored.pressureOn.mixing.mode, BrushMixingMode.bleed);
      expect(restored.pressureOff.mixing.mode, BrushMixingMode.bleed);""",
)

# NIATRA bundle fixture and JSON assertions use only current schema.
replace(
    'test/niatra_asset_bundle_test.dart',
    """          spacing: 12,
          blurRadius: 4,
          stabilization: true,
          stabilizationStrength: 41,
          pixelMode: false,
          pressureMode: PressureMode.sizeAndOpacity,
          pressureStrength: 66,
          fadeMode: FadeMode.custom,
""",
    """          spacing: 12,
          stabilization: true,
          stabilizationStrength: 41,
          pixelMode: false,
          pressureOn: const BrushPressureOnSettings(
            size: PressureRangeSetting(enabled: true, weak: 34, strong: 100),
            opacity: PressureRangeSetting(enabled: true, weak: 34, strong: 100),
            blur: PressureRangeSetting(enabled: true, weak: 4, strong: 4),
            edgeJitter: PressureRangeSetting(enabled: true, weak: 77, strong: 77),
            mixing: PressureMixingOnSetting(
              enabled: true,
              mode: BrushMixingMode.bleed,
              weakRate: 60,
              strongRate: 60,
            ),
          ),
          pressureOff: const BrushPressureOffSettings(
            blur: FixedBrushSetting(enabled: true, value: 4),
            edgeJitter: FixedBrushSetting(enabled: true, value: 77),
            mixing: PressureMixingOffSetting(
              enabled: true,
              mode: BrushMixingMode.bleed,
              rate: 60,
            ),
          ),
          fadeMode: FadeMode.custom,
""",
)
replace(
    'test/niatra_asset_bundle_test.dart',
    """          strokeDecay: true,
          mixingMode: BrushMixingMode.bleed,
          mixingRate: 60,
          customImagePath: brushImage,
          edgeJitter: true,
          edgeJitterStrength: 77,
""",
    """          strokeDecay: true,
          customImagePath: brushImage,
""",
)
replace(
    'test/niatra_asset_bundle_test.dart',
    """      expect(brushJson['edgeJitter'], true);
      expect(brushJson['edgeJitterStrength'], 77);
""",
    """      final pressureOn = brushJson['pressureOn'] as Map<String, dynamic>;
      final pressureOff = brushJson['pressureOff'] as Map<String, dynamic>;
      expect((pressureOn['edgeJitter'] as Map<String, dynamic>)['enabled'], true);
      expect((pressureOn['edgeJitter'] as Map<String, dynamic>)['weak'], 77);
      expect((pressureOff['edgeJitter'] as Map<String, dynamic>)['value'], 77);
""",
)

# Built-in preset bounds and stored fixture use current pressure schema only.
replace(
    'test/builtin_presets_test.dart',
    """        expect(b.blurRadius, inInclusiveRange(0, 100), reason: b.name);
        expect(b.density, inInclusiveRange(0.1, 5.0), reason: b.name);
        expect(b.scatter, inInclusiveRange(0.0, 1.0), reason: b.name);
        expect(b.edgeJitterStrength, inInclusiveRange(0, 100), reason: b.name);
""",
    """        for (final range in [
          b.pressureOn.size,
          b.pressureOn.opacity,
          b.pressureOn.blur,
          b.pressureOn.edgeJitter,
        ]) {
          expect(range.weak, inInclusiveRange(0, 100), reason: b.name);
          expect(range.strong, inInclusiveRange(0, 100), reason: b.name);
        }
        expect(b.pressureOn.mixing.weakRate, inInclusiveRange(0, 100), reason: b.name);
        expect(b.pressureOn.mixing.strongRate, inInclusiveRange(0, 100), reason: b.name);
        expect(b.pressureOff.blur.value, inInclusiveRange(0, 100), reason: b.name);
        expect(b.pressureOff.edgeJitter.value, inInclusiveRange(0, 100), reason: b.name);
        expect(b.pressureOff.mixing.rate, inInclusiveRange(0, 100), reason: b.name);
        expect(b.density, inInclusiveRange(0.1, 5.0), reason: b.name);
        expect(b.scatter, inInclusiveRange(0.0, 1.0), reason: b.name);
""",
)
replace(
    'test/builtin_presets_test.dart',
    """          '{\"id\":\"Brush0001\",\"name\":\"ペン\",\"size\":5,\"opacity\":100,'
              '\"spacing\":1,\"blurRadius\":0,\"stabilization\":true,'
              '\"stabilizationStrength\":50,\"pixelMode\":false,'
              '\"pressureMode\":\"size\",\"pressureStrength\":80,\"fadeMode\":\"off\",'
              '\"strokeDecay\":false,\"mixingMode\":\"off\",\"mixingRate\":0}',
""",
    """          '{\"id\":\"Brush0001\",\"name\":\"ペン\",\"size\":5,\"opacity\":100,'
              '\"spacing\":1,\"stabilization\":true,\"stabilizationStrength\":50,'
              '\"pixelMode\":false,\"pressureOn\":{\"size\":{\"enabled\":true,\"weak\":50,\"strong\":100},'
              '\"opacity\":{\"enabled\":true,\"weak\":50,\"strong\":100},'
              '\"blur\":{\"enabled\":false,\"weak\":50,\"strong\":0},'
              '\"edgeJitter\":{\"enabled\":false,\"weak\":50,\"strong\":0},'
              '\"mixing\":{\"enabled\":false,\"mode\":\"simple\",\"weakRate\":50,\"strongRate\":0}},'
              '\"pressureOff\":{\"blur\":{\"enabled\":false,\"value\":0},'
              '\"edgeJitter\":{\"enabled\":false,\"value\":0},'
              '\"mixing\":{\"enabled\":false,\"mode\":\"simple\",\"rate\":0}},'
              '\"fadeMode\":\"off\",\"strokeDecay\":false}',
""",
)
