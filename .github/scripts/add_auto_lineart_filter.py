from pathlib import Path
import json

# This script is intentionally idempotent. It patches the existing drawing-filter
# plumbing and writes the auto-lineart engine/test sources used by CI.


def replace_once(path: str, old: str, new: str):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


def insert_after(path: str, anchor: str, addition: str):
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if addition.strip() in text:
        return
    if anchor not in text:
        raise SystemExit(f'anchor not found in {path}: {anchor[:120]!r}')
    p.write_text(text.replace(anchor, anchor + addition, 1), encoding='utf-8')


# ---------------------------------------------------------------------------
# Model / serialization
# ---------------------------------------------------------------------------
model = Path('lib/models/filter_def.dart')
s = model.read_text(encoding='utf-8')
if 'autoLineart,' not in s:
    s = s.replace('  inkPool,\n}', '  inkPool,\n  autoLineart,\n}', 1)

if 'final double autoLineartRoughWidth;' not in s:
    s = s.replace(
        '  final double inkPoolCenterWidth;\n',
        '  final double inkPoolCenterWidth;\n'
        '  final double autoLineartRoughWidth;\n'
        '  final double autoLineartOutputWidth;\n'
        '  final double autoLineartTaperLength;\n'
        '  final double autoLineartSmoothing;\n',
        1,
    )
    s = s.replace(
        '    this.inkPoolCenterWidth = 6,\n',
        '    this.inkPoolCenterWidth = 6,\n'
        '    this.autoLineartRoughWidth = 12,\n'
        '    this.autoLineartOutputWidth = 2,\n'
        '    this.autoLineartTaperLength = 8,\n'
        '    this.autoLineartSmoothing = 45,\n',
        1,
    )
    s = s.replace(
        '    double? inkPoolCenterWidth,\n',
        '    double? inkPoolCenterWidth,\n'
        '    double? autoLineartRoughWidth,\n'
        '    double? autoLineartOutputWidth,\n'
        '    double? autoLineartTaperLength,\n'
        '    double? autoLineartSmoothing,\n',
        1,
    )
    s = s.replace(
        '      inkPoolCenterWidth: inkPoolCenterWidth ?? this.inkPoolCenterWidth,\n',
        '      inkPoolCenterWidth: inkPoolCenterWidth ?? this.inkPoolCenterWidth,\n'
        '      autoLineartRoughWidth:\n'
        '          autoLineartRoughWidth ?? this.autoLineartRoughWidth,\n'
        '      autoLineartOutputWidth:\n'
        '          autoLineartOutputWidth ?? this.autoLineartOutputWidth,\n'
        '      autoLineartTaperLength:\n'
        '          autoLineartTaperLength ?? this.autoLineartTaperLength,\n'
        '      autoLineartSmoothing:\n'
        '          autoLineartSmoothing ?? this.autoLineartSmoothing,\n',
        1,
    )
    s = s.replace(
        "    'inkPoolCenterWidth': inkPoolCenterWidth,\n",
        "    'inkPoolCenterWidth': inkPoolCenterWidth,\n"
        "    'autoLineartRoughWidth': autoLineartRoughWidth,\n"
        "    'autoLineartOutputWidth': autoLineartOutputWidth,\n"
        "    'autoLineartTaperLength': autoLineartTaperLength,\n"
        "    'autoLineartSmoothing': autoLineartSmoothing,\n",
        1,
    )
    # fromJson: insert before prism fields, which are stable and close to the end.
    s = s.replace(
        "    inkPoolCenterWidth: (j['inkPoolCenterWidth'] as num?)?.toDouble() ?? 6,\n",
        "    inkPoolCenterWidth: (j['inkPoolCenterWidth'] as num?)?.toDouble() ?? 6,\n"
        "    autoLineartRoughWidth:\n"
        "        (j['autoLineartRoughWidth'] as num?)?.toDouble() ?? 12,\n"
        "    autoLineartOutputWidth:\n"
        "        (j['autoLineartOutputWidth'] as num?)?.toDouble() ?? 2,\n"
        "    autoLineartTaperLength:\n"
        "        (j['autoLineartTaperLength'] as num?)?.toDouble() ?? 8,\n"
        "    autoLineartSmoothing:\n"
        "        (j['autoLineartSmoothing'] as num?)?.toDouble() ?? 45,\n",
        1,
    )
model.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# Filter service: built-in + parameter updates
# ---------------------------------------------------------------------------
svc = Path('lib/services/filter_service.dart')
s = svc.read_text(encoding='utf-8')
if "name: '自動線画'" not in s:
    anchor = "    FilterDef(id: 'Filter0021', name: '墨溜まり', kind: FilterKind.inkPool, inkPoolColor: 0xFF000000, inkPoolRange: 12, inkPoolCenterWidth: 6),\n"
    addition = (
        "    FilterDef(\n"
        "      id: 'Filter0023',\n"
        "      name: '自動線画',\n"
        "      kind: FilterKind.autoLineart,\n"
        "      autoLineartRoughWidth: 12,\n"
        "      autoLineartOutputWidth: 2,\n"
        "      autoLineartTaperLength: 8,\n"
        "      autoLineartSmoothing: 45,\n"
        "    ),\n"
    )
    if anchor not in s:
        raise SystemExit('Filter0021 anchor not found')
    s = s.replace(anchor, anchor + addition, 1)

if 'double? autoLineartRoughWidth,' not in s:
    s = s.replace(
        '    double? inkPoolCenterWidth,\n',
        '    double? inkPoolCenterWidth,\n'
        '    double? autoLineartRoughWidth,\n'
        '    double? autoLineartOutputWidth,\n'
        '    double? autoLineartTaperLength,\n'
        '    double? autoLineartSmoothing,\n',
        1,
    )
    s = s.replace(
        '      inkPoolCenterWidth: inkPoolCenterWidth,\n',
        '      inkPoolCenterWidth: inkPoolCenterWidth,\n'
        '      autoLineartRoughWidth: autoLineartRoughWidth,\n'
        '      autoLineartOutputWidth: autoLineartOutputWidth,\n'
        '      autoLineartTaperLength: autoLineartTaperLength,\n'
        '      autoLineartSmoothing: autoLineartSmoothing,\n',
        1,
    )
svc.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# Isolate dispatch
# ---------------------------------------------------------------------------
engine = Path('lib/engine/filter_engine.dart')
s = engine.read_text(encoding='utf-8')
if "import 'auto_lineart_engine.dart';" not in s:
    s = s.replace(
        "import 'background_acclimation_engine.dart';\n",
        "import 'background_acclimation_engine.dart';\nimport 'auto_lineart_engine.dart';\n",
        1,
    )
if 'FilterKind.autoLineart =>' not in s:
    anchor = '''    FilterKind.inkPool => engine.applyInkPoolLayer(\n      data,\n      width,\n      height,\n      color: filter.inkPoolColor,\n      rangePx: filter.inkPoolRange,\n      centerWidthPx: filter.inkPoolCenterWidth,\n    ),\n'''
    addition = '''    FilterKind.autoLineart => AutoLineartEngine.render(\n      AutoLineartEngine.analyze(\n        data,\n        width,\n        height,\n        roughWidthPx: filter.autoLineartRoughWidth,\n      ),\n      width,\n      height,\n      outputWidthPx: filter.autoLineartOutputWidth,\n      taperLengthPx: filter.autoLineartTaperLength,\n      smoothing: filter.autoLineartSmoothing,\n    ),\n'''
    if anchor not in s:
        raise SystemExit('inkPool isolate dispatch anchor not found')
    s = s.replace(anchor, anchor + addition, 1)
engine.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# Filter panel: cached vector-like analysis + controls + generated layer output
# ---------------------------------------------------------------------------
panel = Path('lib/screens/canvas/widgets/filter_panel.dart')
s = panel.read_text(encoding='utf-8')
if "import '../../../engine/auto_lineart_engine.dart';" not in s:
    s = s.replace(
        "import '../../../engine/background_acclimation_engine.dart';\n",
        "import '../../../engine/background_acclimation_engine.dart';\n"
        "import '../../../engine/auto_lineart_engine.dart';\n",
        1,
    )
if 'AutoLineartGraph? _autoLineartPreviewGraph;' not in s:
    s = s.replace(
        '  BackgroundAcclimationAnalysis? _lastBgBlendAnalysis;\n',
        '  BackgroundAcclimationAnalysis? _lastBgBlendAnalysis;\n'
        '  AutoLineartGraph? _autoLineartPreviewGraph;\n'
        '  double? _autoLineartPreviewRoughWidth;\n',
        1,
    )

# Preview path: replace inline _runFilter assignment with auto-lineart cached graph path.
old = '    final filtered = _runFilter(filter, base, _previewW, _previewH);\n'
new = '''    final Uint8List filtered;\n    if (filter.kind == FilterKind.autoLineart) {\n      if (_autoLineartPreviewGraph == null ||\n          _autoLineartPreviewRoughWidth != filter.autoLineartRoughWidth) {\n        _autoLineartPreviewGraph = AutoLineartEngine.analyze(\n          base,\n          _previewW,\n          _previewH,\n          roughWidthPx: filter.autoLineartRoughWidth * _previewScale,\n        );\n        _autoLineartPreviewRoughWidth = filter.autoLineartRoughWidth;\n      }\n      filtered = AutoLineartEngine.render(\n        _autoLineartPreviewGraph!,\n        _previewW,\n        _previewH,\n        outputWidthPx: math.max(1, filter.autoLineartOutputWidth * _previewScale),\n        taperLengthPx: filter.autoLineartTaperLength * _previewScale,\n        smoothing: filter.autoLineartSmoothing,\n      );\n    } else {\n      filtered = _runFilter(filter, base, _previewW, _previewH);\n    }\n'''
if new not in s:
    if old not in s:
        raise SystemExit('preview filter assignment anchor not found')
    s = s.replace(old, new, 1)

# Controls before inkPool case.
if 'case FilterKind.autoLineart:' not in s:
    anchor = '      case FilterKind.inkPool:\n'
    controls = '''      case FilterKind.autoLineart:\n        return Column(\n          children: [\n            _integerStepperSlider(\n              l10n.filterAutoLineartRoughWidth,\n              current.autoLineartRoughWidth.round(),\n              2,\n              80,\n              (v) {\n                service.updateFilterParams(\n                  current.id,\n                  autoLineartRoughWidth: v.toDouble(),\n                );\n                _autoLineartPreviewGraph = null;\n                _updatePreview();\n              },\n              suffix: 'px',\n            ),\n            _integerStepperSlider(\n              l10n.filterAutoLineartOutputWidth,\n              current.autoLineartOutputWidth.round(),\n              1,\n              30,\n              (v) {\n                service.updateFilterParams(\n                  current.id,\n                  autoLineartOutputWidth: v.toDouble(),\n                );\n                _updatePreview();\n              },\n              suffix: 'px',\n            ),\n            _integerStepperSlider(\n              l10n.filterAutoLineartTaperLength,\n              current.autoLineartTaperLength.round(),\n              0,\n              100,\n              (v) {\n                service.updateFilterParams(\n                  current.id,\n                  autoLineartTaperLength: v.toDouble(),\n                );\n                _updatePreview();\n              },\n              suffix: 'px',\n            ),\n            _integerStepperSlider(\n              l10n.filterAutoLineartSmoothing,\n              current.autoLineartSmoothing.round(),\n              0,\n              100,\n              (v) {\n                service.updateFilterParams(\n                  current.id,\n                  autoLineartSmoothing: v.toDouble(),\n                );\n                _updatePreview();\n              },\n            ),\n          ],\n        );\n'''
    if anchor not in s:
        raise SystemExit('inkPool controls case not found')
    s = s.replace(anchor, controls + anchor, 1)

# _runFilter preview switch fallback (not normally reached for autoLineart after above,
# but keep switch exhaustive).
if 'case FilterKind.autoLineart:' not in s[s.find('Uint8List _runFilter'):]:
    run_anchor = '''      case FilterKind.inkPool:\n        return _engine.applyInkPoolComposite(\n          data,\n          width,\n          height,\n          color: filter.inkPoolColor,\n          rangePx: filter.inkPoolRange,\n          centerWidthPx: filter.inkPoolCenterWidth,\n        );\n'''
    run_add = '''      case FilterKind.autoLineart:\n        return AutoLineartEngine.render(\n          AutoLineartEngine.analyze(\n            data,\n            width,\n            height,\n            roughWidthPx: filter.autoLineartRoughWidth * _previewScale,\n          ),\n          width,\n          height,\n          outputWidthPx: math.max(1, filter.autoLineartOutputWidth * _previewScale),\n          taperLengthPx: filter.autoLineartTaperLength * _previewScale,\n          smoothing: filter.autoLineartSmoothing,\n        );\n'''
    if run_anchor not in s:
        raise SystemExit('inkPool _runFilter case not found')
    s = s.replace(run_anchor, run_anchor + run_add, 1)

# display name and icon
if 'FilterKind.autoLineart => l10n.filterNameAutoLineart,' not in s:
    s = s.replace(
        '      FilterKind.inkPool => l10n.filterNameInkPool,\n',
        '      FilterKind.inkPool => l10n.filterNameInkPool,\n'
        '      FilterKind.autoLineart => l10n.filterNameAutoLineart,\n',
    )
if 'FilterKind.autoLineart => Icons.auto_fix_high,' not in s:
    s = s.replace(
        '      FilterKind.inkPool => Icons.gesture_rounded,\n',
        '      FilterKind.inkPool => Icons.gesture_rounded,\n'
        '      FilterKind.autoLineart => Icons.auto_fix_high,\n',
    )

# Generated layer localization gate and application path.
s = s.replace(
    'filter.kind == FilterKind.outline || filter.kind == FilterKind.inkPool',
    'filter.kind == FilterKind.outline ||\n            filter.kind == FilterKind.inkPool ||\n            filter.kind == FilterKind.autoLineart',
)
if 'l10n!.filterAutoLineartLayerNameSuffix' not in s:
    anchor = '''    if (!_isPrism(filter) && filter.kind == FilterKind.inkPool) {\n      return _applyGeneratedLayer(\n        ps,\n        tm,\n        layerId,\n        frameIndex,\n        result,\n        generatedLayerId,\n        l10n!.filterInkPoolLayerNameSuffix,\n      );\n    }\n'''
    addition = '''    if (!_isPrism(filter) && filter.kind == FilterKind.autoLineart) {\n      return _applyGeneratedLayer(\n        ps,\n        tm,\n        layerId,\n        frameIndex,\n        result,\n        generatedLayerId,\n        l10n!.filterAutoLineartLayerNameSuffix,\n      );\n    }\n'''
    count = s.count(anchor)
    if count == 0:
        raise SystemExit('inkPool generated-layer path not found')
    s = s.replace(anchor, anchor + addition)
panel.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# Timeline imports FilterKind only selectively in some paths; make exhaustive switches
# compile by exposing the enum value where needed. A generic replacement is safe.
# ---------------------------------------------------------------------------
timeline = Path('lib/screens/timeline/timeline_screen.dart')
s = timeline.read_text(encoding='utf-8')
if "show AuroraHologramPreset, FilterKind" not in s and "show AuroraHologramPreset;" in s:
    s = s.replace(
        "import '../../models/filter_def.dart' show AuroraHologramPreset;",
        "import '../../models/filter_def.dart' show AuroraHologramPreset, FilterKind;",
        1,
    )
timeline.write_text(s, encoding='utf-8')

# ---------------------------------------------------------------------------
# Localization keys in all ARB files.
# ---------------------------------------------------------------------------
translations = {
    'app_ja.arb': ('自動線画', '対象ラフ線幅', '線画の太さ', '入り抜きの長さ', 'なめらか補正', '{name} 自動線画'),
    'app_en.arb': ('Auto line art', 'Rough line width', 'Line art width', 'Taper length', 'Smoothing', '{name} Auto line art'),
    'app_es.arb': ('Entintado automático', 'Grosor del boceto', 'Grosor de línea', 'Longitud del afinado', 'Suavizado', '{name} Entintado automático'),
    'app_fr.arb': ('Encrage automatique', 'Épaisseur du brouillon', 'Épaisseur du trait', 'Longueur de l’effilé', 'Lissage', '{name} Encrage automatique'),
    'app_ko.arb': ('자동 선화', '러프 선 굵기', '선화 굵기', '테이퍼 길이', '부드럽게', '{name} 자동 선화'),
    'app_zh.arb': ('自动线稿', '草稿线宽', '线稿宽度', '收笔长度', '平滑修正', '{name} 自动线稿'),
    'app_zh_Hant.arb': ('自動線稿', '草稿線寬', '線稿寬度', '收筆長度', '平滑修正', '{name} 自動線稿'),
}
for filename, values in translations.items():
    p = Path('lib/l10n') / filename
    if not p.exists():
        continue
    obj = json.loads(p.read_text(encoding='utf-8'))
    obj['filterNameAutoLineart'] = values[0]
    obj['filterAutoLineartRoughWidth'] = values[1]
    obj['filterAutoLineartOutputWidth'] = values[2]
    obj['filterAutoLineartTaperLength'] = values[3]
    obj['filterAutoLineartSmoothing'] = values[4]
    obj['filterAutoLineartLayerNameSuffix'] = values[5]
    obj['@filterAutoLineartLayerNameSuffix'] = {
        'placeholders': {'name': {'type': 'String'}}
    }
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

print('auto-lineart filter plumbing patched')
