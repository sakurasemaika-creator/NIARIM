from pathlib import Path
import json

# Complete the auto-lineart patch after add_auto_lineart_filter.py has applied
# its model/service/preview/control changes. This file deliberately anchors on
# small structural markers rather than a whole formatted switch block.

panel = Path('lib/screens/canvas/widgets/filter_panel.dart')
s = panel.read_text(encoding='utf-8')

# _runFilter: insert the auto-lineart case immediately before the ink-pool case
# inside this method only. Ink Pool scales its preview parameters, so the exact
# older full block is not a stable anchor.
run_start = s.index('  Uint8List _runFilter(')
run_end = s.index('\n  Widget _', run_start) if '\n  Widget _' in s[run_start:] else len(s)
run = s[run_start:run_end]
if 'case FilterKind.autoLineart:' not in run:
    marker = '      case FilterKind.inkPool:\n'
    pos = run.find(marker)
    if pos < 0:
        raise SystemExit('inkPool case not found inside _runFilter')
    addition = '''      case FilterKind.autoLineart:\n        return AutoLineartEngine.render(\n          AutoLineartEngine.analyze(\n            data,\n            width,\n            height,\n            roughWidthPx: filter.autoLineartRoughWidth * _previewScale,\n          ),\n          width,\n          height,\n          outputWidthPx:\n              math.max(1.0, filter.autoLineartOutputWidth * _previewScale),\n          taperLengthPx: filter.autoLineartTaperLength * _previewScale,\n          smoothing: filter.autoLineartSmoothing,\n        );\n'''
    run = run[:pos] + addition + run[pos:]
    s = s[:run_start] + run + s[run_end:]

# Display name / icon switches appear more than once in generated historical
# sections, so replacing all occurrences is intentional and keeps switches
# exhaustive everywhere.
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

# Generated layer needs localization and must be a new normal raster layer just
# like Outline / Ink Pool. Never overwrite the selected rough layer.
s = s.replace(
    'filter.kind == FilterKind.outline || filter.kind == FilterKind.inkPool',
    'filter.kind == FilterKind.outline ||\n'
    '            filter.kind == FilterKind.inkPool ||\n'
    '            filter.kind == FilterKind.autoLineart',
)
if 'l10n!.filterAutoLineartLayerNameSuffix' not in s:
    marker = '''    if (!_isPrism(filter) && filter.kind == FilterKind.inkPool) {\n      return _applyGeneratedLayer(\n        ps,\n        tm,\n        layerId,\n        frameIndex,\n        result,\n        generatedLayerId,\n        l10n!.filterInkPoolLayerNameSuffix,\n      );\n    }\n'''
    addition = '''    if (!_isPrism(filter) && filter.kind == FilterKind.autoLineart) {\n      return _applyGeneratedLayer(\n        ps,\n        tm,\n        layerId,\n        frameIndex,\n        result,\n        generatedLayerId,\n        l10n!.filterAutoLineartLayerNameSuffix,\n      );\n    }\n'''
    if marker not in s:
        raise SystemExit('generated inkPool layer block not found')
    s = s.replace(marker, marker + addition)

panel.write_text(s, encoding='utf-8')

# Localization keys (the first script stops before its localization section).
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

print('auto-lineart structural follow-up applied')
