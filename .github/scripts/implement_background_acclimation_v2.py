from pathlib import Path
import re


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise RuntimeError(f'anchor not found: {path}: {old[:120]!r}')
    p.write_text(s.replace(old, new, 1))


def regex_once(path: str, pattern: str, repl: str) -> None:
    p = Path(path)
    s = p.read_text()
    out, n = re.subn(pattern, repl, s, count=1, flags=re.S)
    if n != 1:
        raise RuntimeError(f'regex anchor not found: {path}: {pattern[:120]!r}')
    p.write_text(out)


# 1) Engine compatibility fixes.
p = Path('lib/engine/background_acclimation_engine.dart')
s = p.read_text()
s = s.replace(
    "final ambientColor = filter.bgBlendAmbientColor == -1\n        ? ambient.color\n        : filter.bgBlendAmbientColor;",
    "final ambientColor = filter.bgBlendAmbientColor != -1\n"
    "        ? filter.bgBlendAmbientColor\n"
    "        : (filter.bgBlendColor != -1 ? filter.bgBlendColor : ambient.color);",
)
s = s.replace(
    "  static int _argb(int r, int g, int b) =>\n"
    "      0xFF000000 |\n"
    "      (r.clamp(0, 255) << 16) |\n"
    "      (g.clamp(0, 255) << 8) |\n"
    "      b.clamp(0, 255);",
    "  static int _argb(int r, int g, int b) {\n"
    "    final rr = r < 0 ? 0 : (r > 255 ? 255 : r);\n"
    "    final gg = g < 0 ? 0 : (g > 255 ? 255 : g);\n"
    "    final bb = b < 0 ? 0 : (b > 255 ? 255 : b);\n"
    "    return 0xFF000000 | (rr << 16) | (gg << 8) | bb;\n"
    "  }",
)
p.write_text(s)

# 2) FilterDef fields/persistence.
fields = """  final bool bgBlendAutoLight;
  final double bgBlendStrength;
  final double bgBlendLightStrength;
  final double bgBlendShadowStrength;
  final double bgBlendAmbientStrength;
  final double bgBlendReflectionStrength;
  final double bgBlendColorBleed;
  final double bgBlendSoftness;
  final double bgBlendSecondaryStrength;
  final double bgBlendMaterialProtection;
  final double bgBlendSamplingBand;
  final int bgBlendLightColor;
  final int bgBlendAmbientColor;
  final int bgBlendShadowColor;
  final int bgBlendReflectionColor;
  final bool bgBlendShowAnalysis;
"""
replace_once(
    'lib/models/filter_def.dart',
    '  final double bgBlendBlur;\n  // 墨溜まり',
    '  final double bgBlendBlur;\n' + fields + '  // 墨溜まり',
)
constructor = """    this.bgBlendAutoLight = true,
    this.bgBlendStrength = 70,
    this.bgBlendLightStrength = 65,
    this.bgBlendShadowStrength = 45,
    this.bgBlendAmbientStrength = 18,
    this.bgBlendReflectionStrength = 22,
    this.bgBlendColorBleed = 35,
    this.bgBlendSoftness = 55,
    this.bgBlendSecondaryStrength = 35,
    this.bgBlendMaterialProtection = 75,
    this.bgBlendSamplingBand = 28,
    this.bgBlendLightColor = -1,
    this.bgBlendAmbientColor = -1,
    this.bgBlendShadowColor = -1,
    this.bgBlendReflectionColor = -1,
    this.bgBlendShowAnalysis = true,
"""
replace_once(
    'lib/models/filter_def.dart',
    '    this.bgBlendBlur = 6,\n    this.inkPoolColor',
    '    this.bgBlendBlur = 6,\n' + constructor + '    this.inkPoolColor',
)
params = """    bool? bgBlendAutoLight,
    double? bgBlendStrength,
    double? bgBlendLightStrength,
    double? bgBlendShadowStrength,
    double? bgBlendAmbientStrength,
    double? bgBlendReflectionStrength,
    double? bgBlendColorBleed,
    double? bgBlendSoftness,
    double? bgBlendSecondaryStrength,
    double? bgBlendMaterialProtection,
    double? bgBlendSamplingBand,
    int? bgBlendLightColor,
    int? bgBlendAmbientColor,
    int? bgBlendShadowColor,
    int? bgBlendReflectionColor,
    bool? bgBlendShowAnalysis,
"""
replace_once(
    'lib/models/filter_def.dart',
    '    double? bgBlendBlur,\n    int? inkPoolColor,',
    '    double? bgBlendBlur,\n' + params + '    int? inkPoolColor,',
)
copy_lines = """      bgBlendAutoLight: bgBlendAutoLight ?? this.bgBlendAutoLight,
      bgBlendStrength: bgBlendStrength ?? this.bgBlendStrength,
      bgBlendLightStrength: bgBlendLightStrength ?? this.bgBlendLightStrength,
      bgBlendShadowStrength: bgBlendShadowStrength ?? this.bgBlendShadowStrength,
      bgBlendAmbientStrength: bgBlendAmbientStrength ?? this.bgBlendAmbientStrength,
      bgBlendReflectionStrength: bgBlendReflectionStrength ?? this.bgBlendReflectionStrength,
      bgBlendColorBleed: bgBlendColorBleed ?? this.bgBlendColorBleed,
      bgBlendSoftness: bgBlendSoftness ?? this.bgBlendSoftness,
      bgBlendSecondaryStrength: bgBlendSecondaryStrength ?? this.bgBlendSecondaryStrength,
      bgBlendMaterialProtection: bgBlendMaterialProtection ?? this.bgBlendMaterialProtection,
      bgBlendSamplingBand: bgBlendSamplingBand ?? this.bgBlendSamplingBand,
      bgBlendLightColor: bgBlendLightColor ?? this.bgBlendLightColor,
      bgBlendAmbientColor: bgBlendAmbientColor ?? this.bgBlendAmbientColor,
      bgBlendShadowColor: bgBlendShadowColor ?? this.bgBlendShadowColor,
      bgBlendReflectionColor: bgBlendReflectionColor ?? this.bgBlendReflectionColor,
      bgBlendShowAnalysis: bgBlendShowAnalysis ?? this.bgBlendShowAnalysis,
"""
replace_once(
    'lib/models/filter_def.dart',
    '      bgBlendBlur: bgBlendBlur ?? this.bgBlendBlur,\n      inkPoolColor:',
    '      bgBlendBlur: bgBlendBlur ?? this.bgBlendBlur,\n' + copy_lines + '      inkPoolColor:',
)
json_lines = """    'bgBlendAutoLight': bgBlendAutoLight,
    'bgBlendStrength': bgBlendStrength,
    'bgBlendLightStrength': bgBlendLightStrength,
    'bgBlendShadowStrength': bgBlendShadowStrength,
    'bgBlendAmbientStrength': bgBlendAmbientStrength,
    'bgBlendReflectionStrength': bgBlendReflectionStrength,
    'bgBlendColorBleed': bgBlendColorBleed,
    'bgBlendSoftness': bgBlendSoftness,
    'bgBlendSecondaryStrength': bgBlendSecondaryStrength,
    'bgBlendMaterialProtection': bgBlendMaterialProtection,
    'bgBlendSamplingBand': bgBlendSamplingBand,
    'bgBlendLightColor': bgBlendLightColor,
    'bgBlendAmbientColor': bgBlendAmbientColor,
    'bgBlendShadowColor': bgBlendShadowColor,
    'bgBlendReflectionColor': bgBlendReflectionColor,
    'bgBlendShowAnalysis': bgBlendShowAnalysis,
"""
replace_once(
    'lib/models/filter_def.dart',
    "    'bgBlendBlur': bgBlendBlur,\n    'inkPoolColor':",
    "    'bgBlendBlur': bgBlendBlur,\n" + json_lines + "    'inkPoolColor':",
)
from_json = """    bgBlendAutoLight: j['bgBlendAutoLight'] as bool? ?? true,
    bgBlendStrength: (j['bgBlendStrength'] as num?)?.toDouble() ?? 70,
    bgBlendLightStrength: (j['bgBlendLightStrength'] as num?)?.toDouble() ?? 65,
    bgBlendShadowStrength: (j['bgBlendShadowStrength'] as num?)?.toDouble() ?? 45,
    bgBlendAmbientStrength: (j['bgBlendAmbientStrength'] as num?)?.toDouble() ?? 18,
    bgBlendReflectionStrength: (j['bgBlendReflectionStrength'] as num?)?.toDouble() ?? 22,
    bgBlendColorBleed: (j['bgBlendColorBleed'] as num?)?.toDouble() ?? 35,
    bgBlendSoftness: (j['bgBlendSoftness'] as num?)?.toDouble() ?? 55,
    bgBlendSecondaryStrength: (j['bgBlendSecondaryStrength'] as num?)?.toDouble() ?? 35,
    bgBlendMaterialProtection: (j['bgBlendMaterialProtection'] as num?)?.toDouble() ?? 75,
    bgBlendSamplingBand: (j['bgBlendSamplingBand'] as num?)?.toDouble() ?? 28,
    bgBlendLightColor: j['bgBlendLightColor'] as int? ?? -1,
    bgBlendAmbientColor: j['bgBlendAmbientColor'] as int? ?? -1,
    bgBlendShadowColor: j['bgBlendShadowColor'] as int? ?? -1,
    bgBlendReflectionColor: j['bgBlendReflectionColor'] as int? ?? -1,
    bgBlendShowAnalysis: j['bgBlendShowAnalysis'] as bool? ?? true,
"""
replace_once(
    'lib/models/filter_def.dart',
    "    bgBlendBlur: (j['bgBlendBlur'] as num?)?.toDouble() ?? 6,\n    inkPoolColor:",
    "    bgBlendBlur: (j['bgBlendBlur'] as num?)?.toDouble() ?? 6,\n" + from_json + '    inkPoolColor:',
)

# 3) FilterService passthrough.
replace_once(
    'lib/services/filter_service.dart',
    '    double? bgBlendBlur,\n    int? inkPoolColor,',
    '    double? bgBlendBlur,\n' + params + '    int? inkPoolColor,',
)
service_copy = """      bgBlendAutoLight: bgBlendAutoLight,
      bgBlendStrength: bgBlendStrength,
      bgBlendLightStrength: bgBlendLightStrength,
      bgBlendShadowStrength: bgBlendShadowStrength,
      bgBlendAmbientStrength: bgBlendAmbientStrength,
      bgBlendReflectionStrength: bgBlendReflectionStrength,
      bgBlendColorBleed: bgBlendColorBleed,
      bgBlendSoftness: bgBlendSoftness,
      bgBlendSecondaryStrength: bgBlendSecondaryStrength,
      bgBlendMaterialProtection: bgBlendMaterialProtection,
      bgBlendSamplingBand: bgBlendSamplingBand,
      bgBlendLightColor: bgBlendLightColor,
      bgBlendAmbientColor: bgBlendAmbientColor,
      bgBlendShadowColor: bgBlendShadowColor,
      bgBlendReflectionColor: bgBlendReflectionColor,
      bgBlendShowAnalysis: bgBlendShowAnalysis,
"""
replace_once(
    'lib/services/filter_service.dart',
    '      bgBlendBlur: bgBlendBlur,\n      inkPoolColor:',
    '      bgBlendBlur: bgBlendBlur,\n' + service_copy + '      inkPoolColor:',
)

# 4) Isolate engine receives background bytes for backgroundBlend.
replace_once(
    'lib/engine/filter_engine.dart',
    "import '../models/pixel_color_mode.dart';\n",
    "import '../models/pixel_color_mode.dart';\nimport 'background_acclimation_engine.dart';\n",
)
regex_once(
    'lib/engine/filter_engine.dart',
    r"    // 背景馴染ませ：呼び出し側.*?    FilterKind\.backgroundBlend => engine\.applyBackgroundBlend\(.*?    \),\n    // 墨溜まり",
    "    // 背景馴染ませv2：maskDataは対象外の表示中レイヤーを合成した背景RGBA。\n"
    "    FilterKind.backgroundBlend => BackgroundAcclimationEngine.apply(\n"
    "      data, maskData, width, height, filter,\n"
    "    ),\n"
    "    // 墨溜まり",
)

# 5) FilterPanel: preserve full background, preview using v2, full apply passes RGBA.
replace_once(
    'lib/screens/canvas/widgets/filter_panel.dart',
    "import '../../../engine/filter_engine.dart';\n",
    "import '../../../engine/filter_engine.dart';\nimport '../../../engine/background_acclimation_engine.dart';\n",
)
replace_once(
    'lib/screens/canvas/widgets/filter_panel.dart',
    '  int? _autoBlendColorArgb;\n',
    '  int? _autoBlendColorArgb;\n  Uint8List? _previewBackgroundBytes;\n  BackgroundAcclimationAnalysis? _lastBgBlendAnalysis;\n',
)
replace_once(
    'lib/screens/canvas/widgets/filter_panel.dart',
    '    _autoBlendColorArgb = otherBytes == null\n        ? null\n        : FilterEngine.mostFrequentOpaqueColor(otherBytes);\n',
    '    _previewBackgroundBytes = otherBytes;\n    _autoBlendColorArgb = otherBytes == null\n        ? null\n        : FilterEngine.mostFrequentOpaqueColor(otherBytes);\n',
)
regex_once(
    'lib/screens/canvas/widgets/filter_panel.dart',
    r"      case FilterKind\.backgroundBlend:\n.*?        return _engine\.applyBackgroundBlend\(.*?        \);\n    \}\n  \}\n\n  /// backgroundBlendの馴染ませ色",
    "      case FilterKind.backgroundBlend:\n"
    "        final background = _previewBackgroundBytes;\n"
    "        if (background == null) return Uint8List.fromList(data);\n"
    "        final previewFilter = filter.copyWith(\n"
    "          bgBlendLength: filter.bgBlendLength * _previewScale,\n"
    "          bgBlendSamplingBand: filter.bgBlendSamplingBand * _previewScale,\n"
    "        );\n"
    "        final analysis = BackgroundAcclimationEngine.analyze(\n"
    "          data, background, width, height, previewFilter,\n"
    "        );\n"
    "        _lastBgBlendAnalysis = analysis;\n"
    "        return BackgroundAcclimationEngine.apply(\n"
    "          data, background, width, height, previewFilter, analysis: analysis,\n"
    "        );\n"
    "    }\n"
    "  }\n\n"
    "  /// backgroundBlendの馴染ませ色",
)
regex_once(
    'lib/screens/canvas/widgets/filter_panel.dart',
    r"    // 背景馴染ませフィルター用：このフレームの選択レイヤー以外を全てフル.*?    var effectiveFilter = filter;\n    if \(filter\.kind == FilterKind\.backgroundBlend &&\n        filter\.bgBlendColor == -1\) \{.*?      effectiveFilter = filter\.copyWith\(bgBlendColor: autoColor \?\? 0xFF808080\);\n    \}\n",
    "    // 背景馴染ませv2：対象外の表示中レイヤーをRGBAのまま渡し、\n"
    "    // 代表1色へ潰さず方向別に環境を解析する。\n"
    "    if (filter.kind == FilterKind.backgroundBlend) {\n"
    "      final allLayers = ps.layersOf(widget.projectId, widget.sceneId, frameIndex);\n"
    "      final otherImg = await LayerCompositor.composite(\n"
    "        tm, allLayers,\n"
    "        (l) => ps.tileKeyFor(widget.projectId, widget.sceneId, frameIndex, l.id),\n"
    "        tm.canvasWidth, tm.canvasHeight,\n"
    "        shouldRender: (l, i) => l.id != layerId,\n"
    "      );\n"
    "      final otherByteData = await otherImg.toByteData(format: ui.ImageByteFormat.rawRgba);\n"
    "      otherImg.dispose();\n"
    "      maskData = otherByteData?.buffer.asUint8List();\n"
    "    }\n"
    "    final effectiveFilter = filter;\n",
)

# Full settings UI appended after existing blur control.
ui_anchor = """                          _paramSlider(
                            filterService,
                            l10n.filterBackgroundBlendBlur,
                            current.bgBlendBlur,
                            0,
                            40,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendBlur: v,
                            ),
                          ),
                        ],"""
ui = """                          _paramSlider(
                            filterService,
                            l10n.filterBackgroundBlendBlur,
                            current.bgBlendBlur,
                            0,
                            40,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendBlur: v,
                            ),
                          ),
                          SwitchListTile.adaptive(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('光源方向を自動推定', style: TextStyle(fontSize: 11)),
                            subtitle: const Text('OFF時は上の「向き」を手動方向として使用', style: TextStyle(fontSize: 9)),
                            value: current.bgBlendAutoLight,
                            onChanged: (v) {
                              filterService.updateFilterParams(current.id, bgBlendAutoLight: v);
                              _updatePreview();
                            },
                          ),
                          _paramSlider(filterService, '馴染み強度', current.bgBlendStrength, 0, 100,
                              (v) => filterService.updateFilterParams(current.id, bgBlendStrength: v)),
                          _paramSlider(filterService, '主光源の強さ', current.bgBlendLightStrength, 0, 100,
                              (v) => filterService.updateFilterParams(current.id, bgBlendLightStrength: v)),
                          _paramSlider(filterService, '影の強さ', current.bgBlendShadowStrength, 0, 100,
                              (v) => filterService.updateFilterParams(current.id, bgBlendShadowStrength: v)),
                          _paramSlider(filterService, '環境光', current.bgBlendAmbientStrength, 0, 100,
                              (v) => filterService.updateFilterParams(current.id, bgBlendAmbientStrength: v)),
                          _paramSlider(filterService, '下方反射光', current.bgBlendReflectionStrength, 0, 100,
                              (v) => filterService.updateFilterParams(current.id, bgBlendReflectionStrength: v)),
                          _paramSlider(filterService, '局所的な色移り', current.bgBlendColorBleed, 0, 100,
                              (v) => filterService.updateFilterParams(current.id, bgBlendColorBleed: v)),
                          _paramSlider(filterService, '光の柔らかさ', current.bgBlendSoftness, 0, 100,
                              (v) => filterService.updateFilterParams(current.id, bgBlendSoftness: v)),
                          _paramSlider(filterService, '副光源', current.bgBlendSecondaryStrength, 0, 100,
                              (v) => filterService.updateFilterParams(current.id, bgBlendSecondaryStrength: v)),
                          _paramSlider(filterService, '素材保護', current.bgBlendMaterialProtection, 0, 100,
                              (v) => filterService.updateFilterParams(current.id, bgBlendMaterialProtection: v)),
                          _paramSlider(filterService, '環境サンプリング帯', current.bgBlendSamplingBand, 4, 120,
                              (v) => filterService.updateFilterParams(current.id, bgBlendSamplingBand: v)),
                          _bgBlendColorControl(filterService, '主光源色', current.bgBlendLightColor,
                              _lastBgBlendAnalysis?.primaryColor ?? _resolvedBgBlendColor(current),
                              (v) => filterService.updateFilterParams(current.id, bgBlendLightColor: v)),
                          _bgBlendColorControl(filterService, '環境光色', current.bgBlendAmbientColor,
                              _lastBgBlendAnalysis?.ambientColor ?? _resolvedBgBlendColor(current),
                              (v) => filterService.updateFilterParams(current.id, bgBlendAmbientColor: v)),
                          _bgBlendColorControl(filterService, '影側の環境色', current.bgBlendShadowColor,
                              _lastBgBlendAnalysis?.shadowColor ?? 0xFF404040,
                              (v) => filterService.updateFilterParams(current.id, bgBlendShadowColor: v)),
                          _bgBlendColorControl(filterService, '下方反射色', current.bgBlendReflectionColor,
                              _lastBgBlendAnalysis?.reflectionColor ?? _resolvedBgBlendColor(current),
                              (v) => filterService.updateFilterParams(current.id, bgBlendReflectionColor: v)),
                          SwitchListTile.adaptive(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('解析情報を表示', style: TextStyle(fontSize: 11)),
                            value: current.bgBlendShowAnalysis,
                            onChanged: (v) => filterService.updateFilterParams(current.id, bgBlendShowAnalysis: v),
                          ),
                          if (current.bgBlendShowAnalysis) _bgBlendAnalysisCard(),
                        ],"""
replace_once('lib/screens/canvas/widgets/filter_panel.dart', ui_anchor, ui)

helpers = r'''  Widget _bgBlendColorControl(
    FilterService service,
    String label,
    int value,
    int autoColor,
    ValueChanged<int> onChanged,
  ) {
    final shown = value == -1 ? autoColor : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => Dialog(
                backgroundColor: Colors.transparent,
                child: ColorPickerPanel(
                  currentColor: Color(shown),
                  onColorChanged: (c) {
                    onChanged(c.toARGB32());
                    _updatePreview();
                  },
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Color(shown),
                border: Border.all(color: ThemeService.activeColorScheme.onSurfaceVariant),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: value == -1 ? null : () {
              onChanged(-1);
              _updatePreview();
            },
            child: const Text('自動', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _bgBlendAnalysisCard() {
    final a = _lastBgBlendAnalysis;
    if (a == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('背景解析待ち', style: TextStyle(fontSize: 10)),
      );
    }
    Widget dot(int color) => Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        color: Color(color),
        shape: BoxShape.circle,
        border: Border.all(color: ThemeService.activeColorScheme.onSurfaceVariant),
      ),
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: ThemeService.activeColorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '推定光源 ${a.primaryDirectionDegrees.toStringAsFixed(0)}°  信頼度 ${(a.confidence * 100).round()}%',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(children: [
            dot(a.primaryColor), const Text('光 ', style: TextStyle(fontSize: 9)),
            dot(a.ambientColor), const Text('環境 ', style: TextStyle(fontSize: 9)),
            dot(a.shadowColor), const Text('影 ', style: TextStyle(fontSize: 9)),
            dot(a.reflectionColor), const Text('反射', style: TextStyle(fontSize: 9)),
          ]),
          if (a.secondaryLights.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(children: [
              const Text('副光源 ', style: TextStyle(fontSize: 9)),
              ...a.secondaryLights.map((l) => dot(l.color)),
            ]),
          ],
        ],
      ),
    );
  }

'''
replace_once(
    'lib/screens/canvas/widgets/filter_panel.dart',
    '  Widget _levelSlider(\n',
    helpers + '  Widget _levelSlider(\n',
)

print('background acclimation v2 integration patched')
