from pathlib import Path
import json

ROOT = Path('.')

def rep(path, old, new):
    p = ROOT / path
    s = p.read_text(encoding='utf-8')
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one marker, got {count}: {old[:80]!r}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')

def add_arb(path, values):
    p = ROOT / path
    s = p.read_text(encoding='utf-8')
    if '"filterNameVhsNoise"' in s:
        return
    idx = s.rfind('\n}')
    if idx < 0:
        raise SystemExit(f'{path}: final object brace not found')
    lines = [f'  {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}' for k, v in values.items()]
    s = s[:idx] + ',\n' + ',\n'.join(lines) + s[idx:]
    p.write_text(s, encoding='utf-8')

# Stable seed helper.
rep('lib/engine/vhs_noise_engine.dart',
    '  static int _mix(int seed, int frame, int salt) {',
    '''  /// Stable cross-run seed for timeline effect instances.\n  static int seedFromString(String value) {\n    var hash = 2166136261;\n    for (final codeUnit in value.codeUnits) {\n      hash ^= codeUnit;\n      hash = (hash * 16777619) & 0x7fffffff;\n    }\n    return hash;\n  }\n\n  static int _mix(int seed, int frame, int salt) {''')

# Drawing preset: reuse generic FilterDef slots under a stable ID to avoid enum/save migration.
rep('lib/services/filter_service.dart',
    "  static const prismFilterId = 'Filter0022';",
    "  static const prismFilterId = 'Filter0022';\n  static const vhsNoiseFilterId = 'Filter0024';")
rep('lib/services/filter_service.dart',
    "    FilterDef(\n      id: prismFilterId,\n      name: 'プリズム',\n      kind: FilterKind.auroraHologram,\n      prismBlurPx: 8,\n      prismDirectionDegrees: 45,\n    ),",
    """    FilterDef(\n      id: prismFilterId,\n      name: 'プリズム',\n      kind: FilterKind.auroraHologram,\n      prismBlurPx: 8,\n      prismDirectionDegrees: 45,\n    ),\n    // VHS noise uses the generic slots only under this stable built-in ID:\n    // strength=noise, caSaturation=scanlines, caBrightness=color bleed,\n    // caContrast=tracking, thresholdValue=deterministic seed.\n    FilterDef(\n      id: vhsNoiseFilterId,\n      name: 'VHSノイズ',\n      kind: FilterKind.noise,\n      strength: 35,\n      caSaturation: 35,\n      caBrightness: 35,\n      caContrast: 25,\n      thresholdValue: 1984,\n    ),""")

# Shared engine integration covers direct drawing application and recorded automation replay.
rep('lib/engine/filter_engine.dart',
    "import 'auto_lineart_engine.dart';",
    "import 'auto_lineart_engine.dart';\nimport 'vhs_noise_engine.dart';")
rep('lib/engine/filter_engine.dart',
    "  final engine = FilterEngine();\n  return switch (filter.kind) {",
    """  final engine = FilterEngine();\n  if (filter.id == 'Filter0024') {\n    return VhsNoiseEngine.apply(\n      data,\n      width,\n      height,\n      noiseStrength: filter.strength,\n      scanlineStrength: filter.caSaturation,\n      colorBleed: filter.caBrightness,\n      tracking: filter.caContrast,\n      seed: filter.thresholdValue.round(),\n      frameIndex: 0,\n    );\n  }\n  return switch (filter.kind) {""")
rep('lib/engine/filter_engine.dart',
    "        EffectFilterType.inkPool => applyInkPoolComposite(\n          result,\n          width,\n          height,\n          color: e.fadeColor.toARGB32(),\n          rangePx: e.param1,\n          centerWidthPx: e.param2,\n        ),",
    """        EffectFilterType.inkPool => applyInkPoolComposite(\n          result,\n          width,\n          height,\n          color: e.fadeColor.toARGB32(),\n          rangePx: e.param1,\n          centerWidthPx: e.param2,\n        ),\n        EffectFilterType.vhsNoise => VhsNoiseEngine.apply(\n          result,\n          width,\n          height,\n          noiseStrength: e.param1,\n          scanlineStrength: e.param2,\n          colorBleed: e.param3,\n          tracking: e.param4,\n          seed: VhsNoiseEngine.seedFromString(e.id),\n          frameIndex: frameIndex,\n        ),""")
rep('lib/engine/filter_engine.dart',
    "  inkPool,\n}",
    "  inkPool,\n  vhsNoise,\n}")

# Drawing filter panel.
rep('lib/screens/canvas/widgets/filter_panel.dart',
    "import '../../../engine/tile_manager.dart';",
    "import '../../../engine/tile_manager.dart';\nimport '../../../engine/vhs_noise_engine.dart';")
rep('lib/screens/canvas/widgets/filter_panel.dart',
    "  bool _isPrism(FilterDef filter) => filter.id == FilterService.prismFilterId;",
    "  bool _isPrism(FilterDef filter) => filter.id == FilterService.prismFilterId;\n  bool _isVhs(FilterDef filter) => filter.id == FilterService.vhsNoiseFilterId;")
rep('lib/screens/canvas/widgets/filter_panel.dart',
    "    switch (current.kind) {",
    """    if (_isVhs(current)) {\n      return Column(\n        children: [\n          _paramSlider(l10n.filterVhsNoiseStrength, current.strength, 0, 100,\n              (v) => service.updateFilterParams(current.id, strength: v)),\n          _paramSlider(l10n.filterVhsScanlineStrength, current.caSaturation, 0, 100,\n              (v) => service.updateFilterParams(current.id, caSaturation: v)),\n          _paramSlider(l10n.filterVhsColorBleed, current.caBrightness, 0, 100,\n              (v) => service.updateFilterParams(current.id, caBrightness: v)),\n          _paramSlider(l10n.filterVhsTracking, current.caContrast, 0, 100,\n              (v) => service.updateFilterParams(current.id, caContrast: v)),\n        ],\n      );\n    }\n\n    switch (current.kind) {""")
rep('lib/screens/canvas/widgets/filter_panel.dart',
    "    if (_isPrism(filter)) return 'プリズム';\n    return switch (filter.kind) {",
    "    if (_isPrism(filter)) return 'プリズム';\n    if (_isVhs(filter)) return l10n.filterNameVhsNoise;\n    return switch (filter.kind) {")
rep('lib/screens/canvas/widgets/filter_panel.dart',
    "    if (_isPrism(filter)) return Icons.gradient;\n    return switch (filter.kind) {",
    "    if (_isPrism(filter)) return Icons.gradient;\n    if (_isVhs(filter)) return Icons.video_settings;\n    return switch (filter.kind) {")
rep('lib/screens/canvas/widgets/filter_panel.dart',
    "    switch (filter.kind) {\n      case FilterKind.gaussianBlur:",
    """    if (_isVhs(filter)) {\n      return VhsNoiseEngine.apply(\n        data,\n        width,\n        height,\n        noiseStrength: filter.strength,\n        scanlineStrength: filter.caSaturation,\n        colorBleed: filter.caBrightness,\n        tracking: filter.caContrast,\n        seed: filter.thresholdValue.round(),\n        frameIndex: 0,\n      );\n    }\n    switch (filter.kind) {\n      case FilterKind.gaussianBlur:""")

# Timeline effect UI.
rep('lib/screens/timeline/timeline_screen.dart',
    "        EffectFilterType.inkPool => l10n.filterNameInkPool,\n      };",
    "        EffectFilterType.inkPool => l10n.filterNameInkPool,\n        EffectFilterType.vhsNoise => l10n.timelineEffectTypeVhsNoise,\n      };")
rep('lib/screens/timeline/timeline_screen.dart',
    "    EffectFilterType.inkPool: Icons.gesture_rounded,\n  };",
    "    EffectFilterType.inkPool: Icons.gesture_rounded,\n    EffectFilterType.vhsNoise: Icons.video_settings,\n  };")
rep('lib/screens/timeline/timeline_screen.dart',
    "                else if (e.type == EffectFilterType.inkPool)\n                  ..._inkPoolParams(context, l10n, e)\n                else",
    """                else if (e.type == EffectFilterType.inkPool)\n                  ..._inkPoolParams(context, l10n, e)\n                else if (e.type == EffectFilterType.vhsNoise)\n                  ..._vhsNoiseParams(context, l10n, e)\n                else""")
rep('lib/screens/timeline/timeline_screen.dart',
    "  List<Widget> _fadeParams(\n",
    """  List<Widget> _vhsNoiseParams(\n    BuildContext context,\n    AppLocalizations l10n,\n    EffectFilterInstance e,\n  ) {\n    return [\n      _paramRow(l10n.filterVhsNoiseStrength, e.param1, 0, 100, 100,\n          (v) => _update(context, e.copyWith(param1: v))),\n      _paramRow(l10n.filterVhsScanlineStrength, e.param2, 0, 100, 100,\n          (v) => _update(context, e.copyWith(param2: v))),\n      _paramRow(l10n.filterVhsColorBleed, e.param3, 0, 100, 100,\n          (v) => _update(context, e.copyWith(param3: v))),\n      _paramRow(l10n.filterVhsTracking, e.param4, 0, 100, 100,\n          (v) => _update(context, e.copyWith(param4: v))),\n    ];\n  }\n\n  List<Widget> _fadeParams(\n""")
rep('lib/screens/timeline/timeline_screen.dart',
    "                            EffectFilterType.inkPool => 12.0,\n                            _ => 5.0,",
    "                            EffectFilterType.inkPool => 12.0,\n                            EffectFilterType.vhsNoise => 35.0,\n                            _ => 5.0,")
rep('lib/screens/timeline/timeline_screen.dart',
    "                              : type == EffectFilterType.inkPool\n                              ? 6.0\n                              : 50.0,",
    "                              : type == EffectFilterType.inkPool\n                              ? 6.0\n                              : type == EffectFilterType.vhsNoise\n                              ? 35.0\n                              : 50.0,")
rep('lib/screens/timeline/timeline_screen.dart',
    "                          param3:\n                              type == EffectFilterType.colorAdjust ||\n                                  type == EffectFilterType.auroraHologram\n                              ? 0.0\n                              : 2.0,",
    """                          param3: type == EffectFilterType.vhsNoise\n                              ? 35.0\n                              : type == EffectFilterType.colorAdjust ||\n                                    type == EffectFilterType.auroraHologram\n                              ? 0.0\n                              : 2.0,\n                          param4: type == EffectFilterType.vhsNoise ? 25.0 : 0.0,""")

# Localized UI labels, kept neutral and aligned with the Japanese source tone.
translations = {
  'app_ja.arb': {'filterNameVhsNoise':'VHSノイズ','filterVhsNoiseStrength':'ノイズ','filterVhsScanlineStrength':'走査線','filterVhsColorBleed':'色にじみ','filterVhsTracking':'トラッキング','timelineEffectTypeVhsNoise':'VHSノイズ'},
  'app_en.arb': {'filterNameVhsNoise':'VHS Noise','filterVhsNoiseStrength':'Noise','filterVhsScanlineStrength':'Scanlines','filterVhsColorBleed':'Color bleed','filterVhsTracking':'Tracking','timelineEffectTypeVhsNoise':'VHS Noise'},
  'app_es.arb': {'filterNameVhsNoise':'Ruido VHS','filterVhsNoiseStrength':'Ruido','filterVhsScanlineStrength':'Líneas de barrido','filterVhsColorBleed':'Sangrado de color','filterVhsTracking':'Seguimiento','timelineEffectTypeVhsNoise':'Ruido VHS'},
  'app_fr.arb': {'filterNameVhsNoise':'Bruit VHS','filterVhsNoiseStrength':'Bruit','filterVhsScanlineStrength':'Lignes de balayage','filterVhsColorBleed':'Bavure des couleurs','filterVhsTracking':'Suivi','timelineEffectTypeVhsNoise':'Bruit VHS'},
  'app_ko.arb': {'filterNameVhsNoise':'VHS 노이즈','filterVhsNoiseStrength':'노이즈','filterVhsScanlineStrength':'주사선','filterVhsColorBleed':'색 번짐','filterVhsTracking':'트래킹','timelineEffectTypeVhsNoise':'VHS 노이즈'},
  'app_zh.arb': {'filterNameVhsNoise':'VHS 噪点','filterVhsNoiseStrength':'噪点','filterVhsScanlineStrength':'扫描线','filterVhsColorBleed':'色彩溢出','filterVhsTracking':'跟踪抖动','timelineEffectTypeVhsNoise':'VHS 噪点'},
  'app_zh_Hant.arb': {'filterNameVhsNoise':'VHS 雜訊','filterVhsNoiseStrength':'雜訊','filterVhsScanlineStrength':'掃描線','filterVhsColorBleed':'色彩溢出','filterVhsTracking':'追蹤抖動','timelineEffectTypeVhsNoise':'VHS 雜訊'},
}
for name, vals in translations.items():
    add_arb(f'lib/l10n/{name}', vals)

# Integration tests: drawing ID route + timeline route.
Path('test/engine/vhs_filter_integration_test.dart').write_text(r'''import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  Uint8List sample() => Uint8List.fromList(List<int>.generate(8 * 8 * 4, (i) {
        if (i % 4 == 3) return 255;
        return (i * 17) & 0xff;
      }));

  test('drawing VHS stable ID routes through deterministic VHS engine', () {
    final f = FilterDef(
      id: 'Filter0024',
      name: 'VHS',
      kind: FilterKind.noise,
      strength: 45,
      caSaturation: 30,
      caBrightness: 40,
      caContrast: 20,
      thresholdValue: 1984,
    );
    final a = applyDrawFilterInIsolate((sample(), 8, 8, f, null));
    final b = applyDrawFilterInIsolate((sample(), 8, 8, f, null));
    expect(a, orderedEquals(b));
  });

  test('timeline VHS changes by frame but stays deterministic per frame', () {
    const effect = EffectFilterInstance(
      id: 'vhs_test',
      type: EffectFilterType.vhsNoise,
      startFrame: 0,
      endFrame: 10,
      param1: 45,
      param2: 30,
      param3: 40,
      param4: 20,
    );
    final engine = FilterEngine();
    final a = engine.applyEffectFilters(sample(), 8, 8, const [effect], 2);
    final b = engine.applyEffectFilters(sample(), 8, 8, const [effect], 2);
    final c = engine.applyEffectFilters(sample(), 8, 8, const [effect], 3);
    expect(a, orderedEquals(b));
    expect(a, isNot(orderedEquals(c)));
  });
}
''', encoding='utf-8')

print('VHS integration patch applied')
