from pathlib import Path
import json
import re

ROOT = Path('.')


def replace_required(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing expected fragment: {label}')
    return text.replace(old, new, 1)


# 1) Brush model: remove legacy PressureMode/pressureStrength entirely.
p = ROOT / 'lib/models/brush.dart'
s = p.read_text()
s = s.replace('  final PressureMode pressureMode;\n  final int pressureStrength;\n', '')
s = s.replace('    required this.pressureMode,\n    required this.pressureStrength,\n', '')
s = s.replace('    PressureMode? pressureMode,\n    int? pressureStrength,\n', '')
s = s.replace('      pressureMode: pressureMode ?? this.pressureMode,\n      pressureStrength: pressureStrength ?? this.pressureStrength,\n', '')
s = s.replace("    'pressureMode': pressureMode.name,\n    'pressureStrength': pressureStrength,\n", '')
s = re.sub(
    r"\n    pressureMode: PressureMode\.values\.firstWhere\(\n      \(e\) => e\.name == j\['pressureMode'\],\n      orElse: \(\) => PressureMode\.off,\n    \),\n    pressureStrength: j\['pressureStrength'\] as int,",
    '',
    s,
)
s = s.replace('\nenum PressureMode { off, size, opacity, sizeAndOpacity }\n', '\n')
p.write_text(s)


# 2) Preserve built-in brush behavior by translating old settings to the new profiles.
p = ROOT / 'lib/services/brush_service.dart'
s = p.read_text()

def balanced_calls(text, needle='Brush('):
    starts = []
    pos = 0
    while True:
        start = text.find(needle, pos)
        if start < 0:
            break
        depth = 0
        i = start + len(needle) - 1
        quote = None
        escaped = False
        while i < len(text):
            ch = text[i]
            if quote:
                if escaped:
                    escaped = False
                elif ch == '\\':
                    escaped = True
                elif ch == quote:
                    quote = None
            else:
                if ch in ('\"', "'"):
                    quote = ch
                elif ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
                    if depth == 0:
                        starts.append((start, i + 1))
                        break
            i += 1
        pos = i + 1
    return starts

calls = balanced_calls(s)
for start, end in reversed(calls):
    block = s[start:end]
    mm = re.search(r'^\s*pressureMode:\s*PressureMode\.(\w+),\s*$', block, re.M)
    sm = re.search(r'^\s*pressureStrength:\s*(\d+),\s*$', block, re.M)
    if not mm or not sm:
        continue
    mode = mm.group(1)
    strength = int(sm.group(1))
    weak = max(0, min(100, 100 - strength))
    size_enabled = mode in ('size', 'sizeAndOpacity')
    opacity_enabled = mode in ('opacity', 'sizeAndOpacity')

    blur_m = re.search(r'^\s*blurRadius:\s*(\d+),\s*$', block, re.M)
    blur = int(blur_m.group(1)) if blur_m else 0
    edge_m = re.search(r'^\s*edgeJitter:\s*(true|false),\s*$', block, re.M)
    edge = edge_m and edge_m.group(1) == 'true'
    edge_strength_m = re.search(r'^\s*edgeJitterStrength:\s*(\d+),\s*$', block, re.M)
    edge_strength = int(edge_strength_m.group(1)) if edge_strength_m else 50
    mix_m = re.search(r'^\s*mixingMode:\s*BrushMixingMode\.(\w+),\s*$', block, re.M)
    mix_mode = mix_m.group(1) if mix_m else 'off'
    mix_rate_m = re.search(r'^\s*mixingRate:\s*(\d+),\s*$', block, re.M)
    mix_rate = int(mix_rate_m.group(1)) if mix_rate_m else 0
    mix_enabled = mix_mode != 'off' and mix_rate > 0

    profile = f'''      pressureOn: const BrushPressureOnSettings(\n        size: PressureRangeSetting(enabled: {str(size_enabled).lower()}, weak: {weak if size_enabled else 50}, strong: 100),\n        opacity: PressureRangeSetting(enabled: {str(opacity_enabled).lower()}, weak: {weak if opacity_enabled else 50}, strong: 100),\n        blur: PressureRangeSetting(enabled: {str(blur > 0).lower()}, weak: {blur}, strong: {blur}),\n        edgeJitter: PressureRangeSetting(enabled: {str(bool(edge)).lower()}, weak: {edge_strength}, strong: {edge_strength}),\n        mixing: PressureMixingOnSetting(\n          enabled: {str(mix_enabled).lower()},\n          mode: BrushMixingMode.{mix_mode if mix_mode != 'off' else 'simple'},\n          weakRate: {mix_rate},\n          strongRate: {mix_rate},\n        ),\n      ),\n      pressureOff: const BrushPressureOffSettings(\n        blur: FixedBrushSetting(enabled: {str(blur > 0).lower()}, value: {blur}),\n        edgeJitter: FixedBrushSetting(enabled: {str(bool(edge)).lower()}, value: {edge_strength}),\n        mixing: PressureMixingOffSetting(\n          enabled: {str(mix_enabled).lower()},\n          mode: BrushMixingMode.{mix_mode if mix_mode != 'off' else 'simple'},\n          rate: {mix_rate},\n        ),\n      ),\n'''
    block = re.sub(r'^\s*pressureMode:.*\n', '', block, flags=re.M)
    block = re.sub(r'^\s*pressureStrength:.*\n', '', block, flags=re.M)
    anchor = re.search(r'^(\s*)fadeMode:', block, re.M)
    if not anchor:
        raise SystemExit('Brush block missing fadeMode anchor')
    block = block[:anchor.start()] + profile + block[anchor.start():]
    s = s[:start] + block + s[end:]
p.write_text(s)


# 3) Update focused tests to the current schema; old migration/hardness tests are obsolete.
for rel in [
    'test/models/brush_pressure_profiles_test.dart',
    'test/models/brush_pressure_resolver_test.dart',
    'test/services/brush_pressure_profile_lifecycle_test.dart',
]:
    p = ROOT / rel
    s = p.read_text()
    s = re.sub(r'^\s*pressureMode:\s*PressureMode\.\w+,\s*\n', '', s, flags=re.M)
    s = re.sub(r'^\s*pressureStrength:\s*[^,]+,\s*\n', '', s, flags=re.M)
    p.write_text(s)

for rel in ['lib/models/pressure_hardness.dart', 'test/pressure_hardness_test.dart', 'test/models/brush_pressure_legacy_migration_test.dart']:
    p = ROOT / rel
    if p.exists():
        p.unlink()

# Settings comment no longer refers to per-brush PressureMode.
p = ROOT / 'lib/services/settings_service.dart'
s = p.read_text().replace(
    '  // 「ブラシ個別設定」であるため、ブラシ設定側(Brush.pressureMode)\n',
    '  // アプリ全体の筆圧入力ON/OFF。ブラシごとのON/OFFプロファイルとは独立して保持する。\n',
)
p.write_text(s)


# 4) Brush settings sheet: current three-section UI only.
p = ROOT / 'lib/screens/canvas/widgets/brush_panel.dart'
s = p.read_text().replace("import '../../../models/pressure_hardness.dart';\n", '')
children_start = s.index('          // サイズ\n')
save_anchor = s.index('          const SizedBox(height: 16),\n          FilledButton(', children_start)
common_and_profiles = '''          _settingsSection(\n            title: l10n.brushSettingsCommonSection,\n            children: [\n              _sliderRow(\n                l10n.brushSettingsSizeLabel,\n                _brush.size,\n                1,\n                500,\n                (v) => setState(() => _brush = _brush.copyWith(size: v)),\n              ),\n              _sliderRow(\n                l10n.brushSettingsOpacityLabel,\n                _brush.opacity.toDouble(),\n                1,\n                100,\n                (v) => setState(() => _brush = _brush.copyWith(opacity: v.round())),\n              ),\n              _sliderRow(\n                l10n.brushSettingsSpacingLabel,\n                _brush.spacing.toDouble(),\n                1,\n                100,\n                (v) => setState(() => _brush = _brush.copyWith(spacing: v.round())),\n              ),\n              SwitchListTile(\n                title: Text(l10n.stampRotationLabel),\n                value: _brush.rotation,\n                onChanged: (v) => setState(() => _brush = _brush.copyWith(rotation: v)),\n              ),\n              _decimalSliderRow(\n                l10n.stampDensityLabel,\n                _brush.density,\n                0.1,\n                5.0,\n                0.1,\n                (v) => setState(() => _brush = _brush.copyWith(density: v)),\n              ),\n              _decimalSliderRow(\n                l10n.stampScatterLabel,\n                _brush.scatter,\n                0.0,\n                1.0,\n                0.01,\n                (v) => setState(() => _brush = _brush.copyWith(scatter: v)),\n              ),\n              SwitchListTile(\n                title: Text(l10n.brushSettingsStabilizationTitle),\n                value: _brush.stabilization,\n                onChanged: (v) => setState(() => _brush = _brush.copyWith(stabilization: v)),\n              ),\n              if (_brush.stabilization)\n                _sliderRow(\n                  l10n.brushSettingsStabilizationStrengthLabel,\n                  _brush.stabilizationStrength.toDouble(),\n                  0,\n                  100,\n                  (v) => setState(() => _brush = _brush.copyWith(stabilizationStrength: v.round())),\n                ),\n              SwitchListTile(\n                title: Text(l10n.brushSettingsPixelModeTitle),\n                value: _brush.pixelMode,\n                onChanged: (v) => setState(() => _brush = _brush.copyWith(pixelMode: v)),\n              ),\n              if (_brush.pixelMode)\n                Padding(\n                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),\n                  child: PixelColorModeSelector(\n                    mode: _brush.pixelColorMode,\n                    colorLevels: _brush.pixelColorLevels,\n                    explicitColors: _brush.pixelExplicitColors,\n                    onModeChanged: (m) => setState(() => _brush = _brush.copyWith(pixelColorMode: m)),\n                    onColorLevelsChanged: (v) => setState(() => _brush = _brush.copyWith(pixelColorLevels: v)),\n                    onExplicitColorsChanged: (c) => setState(() => _brush = _brush.copyWith(pixelExplicitColors: c)),\n                  ),\n                ),\n              Text(\n                l10n.brushSettingsFadeModeTitle,\n                style: const TextStyle(fontWeight: FontWeight.bold),\n              ),\n              RadioGroup<FadeMode>(\n                groupValue: _brush.fadeMode,\n                onChanged: (v) => setState(() => _brush = _brush.copyWith(fadeMode: v)),\n                child: Column(\n                  children: FadeMode.values\n                      .map((mode) => RadioListTile<FadeMode>(\n                            title: Text(_fadeModeLabel(l10n, mode)),\n                            value: mode,\n                            dense: true,\n                          ))\n                      .toList(),\n                ),\n              ),\n              if (_brush.fadeMode == FadeMode.custom) ...[\n                _sliderRow(\n                  l10n.brushSettingsFadeStartValueLabel,\n                  _brush.fadeCustom?.startValue ?? 100,\n                  0,\n                  100,\n                  (v) => setState(() => _brush = _brush.copyWith(\n                        fadeCustom: FadeCustomSettings(\n                          startValue: v,\n                          endValue: _brush.fadeCustom?.endValue ?? 0,\n                          distancePx: _brush.fadeCustom?.distancePx ?? 500,\n                        ),\n                      )),\n                ),\n                _sliderRow(\n                  l10n.brushSettingsFadeEndValueLabel,\n                  _brush.fadeCustom?.endValue ?? 0,\n                  0,\n                  100,\n                  (v) => setState(() => _brush = _brush.copyWith(\n                        fadeCustom: FadeCustomSettings(\n                          startValue: _brush.fadeCustom?.startValue ?? 100,\n                          endValue: v,\n                          distancePx: _brush.fadeCustom?.distancePx ?? 500,\n                        ),\n                      )),\n                ),\n                _sliderRow(\n                  l10n.brushSettingsFadeDistanceLabel,\n                  _brush.fadeCustom?.distancePx ?? 500,\n                  10,\n                  2000,\n                  (v) => setState(() => _brush = _brush.copyWith(\n                        fadeCustom: FadeCustomSettings(\n                          startValue: _brush.fadeCustom?.startValue ?? 100,\n                          endValue: _brush.fadeCustom?.endValue ?? 0,\n                          distancePx: v,\n                        ),\n                      )),\n                ),\n              ],\n              SwitchListTile(\n                title: Text(l10n.brushSettingsStrokeDecayTitle),\n                subtitle: Text(l10n.brushSettingsStrokeDecaySubtitle, style: const TextStyle(fontSize: 11)),\n                value: _brush.strokeDecay,\n                onChanged: (v) => setState(() => _brush = _brush.copyWith(strokeDecay: v)),\n              ),\n            ],\n          ),\n          _settingsSection(\n            title: l10n.brushSettingsPressureOnSection,\n            children: [\n              _pressureRangeTile(\n                label: l10n.brushSettingsSizeLabel,\n                setting: _brush.pressureOn.size,\n                onChanged: (v) => _brush = _brush.copyWith(pressureOn: _brush.pressureOn.copyWith(size: v)),\n                l10n: l10n,\n              ),\n              _pressureRangeTile(\n                label: l10n.brushSettingsOpacityLabel,\n                setting: _brush.pressureOn.opacity,\n                onChanged: (v) => _brush = _brush.copyWith(pressureOn: _brush.pressureOn.copyWith(opacity: v)),\n                l10n: l10n,\n              ),\n              _pressureRangeTile(\n                label: l10n.brushSettingsBlurRadiusLabel,\n                setting: _brush.pressureOn.blur,\n                onChanged: (v) => _brush = _brush.copyWith(pressureOn: _brush.pressureOn.copyWith(blur: v)),\n                l10n: l10n,\n              ),\n              _pressureRangeTile(\n                label: l10n.brushSettingsEdgeJitterTitle,\n                setting: _brush.pressureOn.edgeJitter,\n                onChanged: (v) => _brush = _brush.copyWith(pressureOn: _brush.pressureOn.copyWith(edgeJitter: v)),\n                l10n: l10n,\n              ),\n              _pressureMixingOnTile(l10n),\n            ],\n          ),\n          _settingsSection(\n            title: l10n.brushSettingsPressureOffSection,\n            children: [\n              _fixedPressureTile(\n                label: l10n.brushSettingsBlurRadiusLabel,\n                setting: _brush.pressureOff.blur,\n                onChanged: (v) => _brush = _brush.copyWith(pressureOff: _brush.pressureOff.copyWith(blur: v)),\n                l10n: l10n,\n              ),\n              _fixedPressureTile(\n                label: l10n.brushSettingsEdgeJitterTitle,\n                setting: _brush.pressureOff.edgeJitter,\n                onChanged: (v) => _brush = _brush.copyWith(pressureOff: _brush.pressureOff.copyWith(edgeJitter: v)),\n                l10n: l10n,\n              ),\n              _pressureMixingOffTile(l10n),\n            ],\n          ),\n'''
s = s[:children_start] + common_and_profiles + s[save_anchor:]

hardness_start = s.index('  Widget _pressureHardnessRow(')
slider_start = s.index('  Widget _sliderRow(', hardness_start)
helpers = '''  Widget _settingsSection({required String title, required List<Widget> children}) {\n    return ExpansionTile(\n      title: Text(\n        title,\n        style: const TextStyle(\n          fontWeight: FontWeight.bold,\n          fontFamily: 'Kuramubon',\n          fontFamilyFallback: kHeadingFontFallback,\n        ),\n      ),\n      initiallyExpanded: true,\n      childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),\n      children: children,\n    );\n  }\n\n  Widget _pressureRangeTile({\n    required String label,\n    required PressureRangeSetting setting,\n    required ValueChanged<PressureRangeSetting> onChanged,\n    required AppLocalizations l10n,\n  }) {\n    return Column(\n      children: [\n        SwitchListTile(\n          dense: true,\n          title: Text(label),\n          value: setting.enabled,\n          onChanged: (v) => setState(() => onChanged(setting.copyWith(enabled: v))),\n        ),\n        if (setting.enabled) ...[\n          _sliderRow(\n            l10n.brushSettingsWeakPressureLabel,\n            setting.weak.toDouble(),\n            0,\n            100,\n            (v) => setState(() => onChanged(setting.copyWith(weak: v.round()))),\n          ),\n          _sliderRow(\n            l10n.brushSettingsStrongPressureLabel,\n            setting.strong.toDouble(),\n            0,\n            100,\n            (v) => setState(() => onChanged(setting.copyWith(strong: v.round()))),\n          ),\n        ],\n      ],\n    );\n  }\n\n  Widget _fixedPressureTile({\n    required String label,\n    required FixedBrushSetting setting,\n    required ValueChanged<FixedBrushSetting> onChanged,\n    required AppLocalizations l10n,\n  }) {\n    return Column(\n      children: [\n        SwitchListTile(\n          dense: true,\n          title: Text(label),\n          value: setting.enabled,\n          onChanged: (v) => setState(() => onChanged(setting.copyWith(enabled: v))),\n        ),\n        if (setting.enabled)\n          _sliderRow(\n            l10n.brushSettingsValueLabel,\n            setting.value.toDouble(),\n            0,\n            100,\n            (v) => setState(() => onChanged(setting.copyWith(value: v.round()))),\n          ),\n      ],\n    );\n  }\n\n  Widget _pressureMixingOnTile(AppLocalizations l10n) {\n    final setting = _brush.pressureOn.mixing;\n    return Column(\n      children: [\n        SwitchListTile(\n          dense: true,\n          title: Text(l10n.brushSettingsMixingTitle),\n          value: setting.enabled,\n          onChanged: (v) => setState(() => _brush = _brush.copyWith(\n                pressureOn: _brush.pressureOn.copyWith(mixing: setting.copyWith(enabled: v)),\n              )),\n        ),\n        if (setting.enabled) ...[\n          _pressureMixingModeSelector(\n            l10n: l10n,\n            mode: setting.mode,\n            onChanged: (mode) => setState(() => _brush = _brush.copyWith(\n                  pressureOn: _brush.pressureOn.copyWith(mixing: setting.copyWith(mode: mode)),\n                )),\n          ),\n          _sliderRow(\n            l10n.brushSettingsWeakPressureLabel,\n            setting.weakRate.toDouble(),\n            0,\n            100,\n            (v) => setState(() => _brush = _brush.copyWith(\n                  pressureOn: _brush.pressureOn.copyWith(mixing: setting.copyWith(weakRate: v.round())),\n                )),\n          ),\n          _sliderRow(\n            l10n.brushSettingsStrongPressureLabel,\n            setting.strongRate.toDouble(),\n            0,\n            100,\n            (v) => setState(() => _brush = _brush.copyWith(\n                  pressureOn: _brush.pressureOn.copyWith(mixing: setting.copyWith(strongRate: v.round())),\n                )),\n          ),\n        ],\n      ],\n    );\n  }\n\n  Widget _pressureMixingOffTile(AppLocalizations l10n) {\n    final setting = _brush.pressureOff.mixing;\n    return Column(\n      children: [\n        SwitchListTile(\n          dense: true,\n          title: Text(l10n.brushSettingsMixingTitle),\n          value: setting.enabled,\n          onChanged: (v) => setState(() => _brush = _brush.copyWith(\n                pressureOff: _brush.pressureOff.copyWith(mixing: setting.copyWith(enabled: v)),\n              )),\n        ),\n        if (setting.enabled) ...[\n          _pressureMixingModeSelector(\n            l10n: l10n,\n            mode: setting.mode,\n            onChanged: (mode) => setState(() => _brush = _brush.copyWith(\n                  pressureOff: _brush.pressureOff.copyWith(mixing: setting.copyWith(mode: mode)),\n                )),\n          ),\n          _sliderRow(\n            l10n.brushSettingsValueLabel,\n            setting.rate.toDouble(),\n            0,\n            100,\n            (v) => setState(() => _brush = _brush.copyWith(\n                  pressureOff: _brush.pressureOff.copyWith(mixing: setting.copyWith(rate: v.round())),\n                )),\n          ),\n        ],\n      ],\n    );\n  }\n\n  Widget _pressureMixingModeSelector({\n    required AppLocalizations l10n,\n    required BrushMixingMode mode,\n    required ValueChanged<BrushMixingMode> onChanged,\n  }) {\n    final modes = [BrushMixingMode.simple, BrushMixingMode.bleed];\n    return RadioGroup<BrushMixingMode>(\n      groupValue: mode == BrushMixingMode.off ? BrushMixingMode.simple : mode,\n      onChanged: (v) {\n        if (v != null) onChanged(v);\n      },\n      child: Column(\n        children: modes\n            .map((value) => RadioListTile<BrushMixingMode>(\n                  dense: true,\n                  title: Text(_mixingModeLabel(l10n, value)),\n                  value: value,\n                ))\n            .toList(),\n      ),\n    );\n  }\n\n'''
s = s[:hardness_start] + helpers + s[slider_start:]

# Drop the old pressure mode label helper.
s = re.sub(r"\n  String _pressureLabel\(AppLocalizations l10n, PressureMode mode\) =>\n      switch \(mode\) \{.*?\n      \};\n", '\n', s, flags=re.S)
p.write_text(s)


# 5) Add localized labels for the new three-section UI.
translations = {
    'app_ja.arb': ('共通', '筆圧ON', '筆圧OFF', '弱', '強', '値'),
    'app_en.arb': ('Common', 'Pressure ON', 'Pressure OFF', 'Weak', 'Strong', 'Value'),
    'app_es.arb': ('Común', 'Presión activada', 'Presión desactivada', 'Débil', 'Fuerte', 'Valor'),
    'app_fr.arb': ('Commun', 'Pression activée', 'Pression désactivée', 'Faible', 'Forte', 'Valeur'),
    'app_ko.arb': ('공통', '필압 ON', '필압 OFF', '약', '강', '값'),
    'app_zh.arb': ('通用', '笔压开启', '笔压关闭', '弱', '强', '值'),
    'app_zh_Hant.arb': ('共用', '筆壓開啟', '筆壓關閉', '弱', '強', '值'),
}
for name, values in translations.items():
    p = ROOT / 'lib/l10n' / name
    data = json.loads(p.read_text())
    data['brushSettingsCommonSection'] = values[0]
    data['brushSettingsPressureOnSection'] = values[1]
    data['brushSettingsPressureOffSection'] = values[2]
    data['brushSettingsWeakPressureLabel'] = values[3]
    data['brushSettingsStrongPressureLabel'] = values[4]
    data['brushSettingsValueLabel'] = values[5]
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
