from pathlib import Path
import json


def replace(path, old, new):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    if old not in s:
        raise SystemExit(f'pattern not found: {path}: {old[:100]!r}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')

# One seed should represent one junction. If several neighboring candidate pixels
# around the same corner become seeds, each seed restarts the taper and prevents
# the range edge from approaching 1px. Suppress over the whole directional
# sampling neighborhood so one acute/intersection has one taper origin.
replace(
    'lib/engine/filter_engine.dart',
    '    final suppress = math.max(2, centerWidth ~/ 2);',
    '    final suppress = math.max(sampleRadius * 2, centerWidth);',
)

# Measure local thickness around the known horizontal branch instead of the
# whole image column (which also intersects the second oblique branch).
p = Path('test/niarim_unique_visual_evidence_v3_test.dart')
s = p.read_text(encoding='utf-8')
old = '''    // 中心付近は横断方向に複数px、範囲端近くは中心より細いことを数値確認。\n    final cx = w ~/ 2, cy = h ~/ 2;\n    final centerSpan = _verticalInkSpan(thickCenter, w, h, cx);\n    final edgeX = cx - 24;\n    final edgeSpan = _verticalInkSpan(thickCenter, w, h, edgeX);\n    expect(centerSpan, greaterThanOrEqualTo(8));\n    expect(edgeSpan, lessThan(centerSpan));\n'''
new = '''    // テーパーは、他方の斜線まで含む「列全体の高さ」ではなく、既知の\n    // 水平枝を横切る局所連結成分の太さで測る。中心は指定太さに近く、\n    // range=28 の端（26px先）では1px近くまで細くなる必要がある。\n    final cx = w ~/ 2, cy = h ~/ 2;\n    final centerSpan = _localVerticalInkThickness(\n      thickCenter,\n      w,\n      h,\n      cx,\n      cy,\n      20,\n    );\n    final edgeSpan = _localVerticalInkThickness(\n      thickCenter,\n      w,\n      h,\n      cx - 26,\n      cy,\n      8,\n    );\n    expect(centerSpan, greaterThanOrEqualTo(8));\n    expect(edgeSpan, inInclusiveRange(1, 4));\n    expect(edgeSpan, lessThan(centerSpan));\n'''
if old not in s:
    raise SystemExit('taper assertion block not found')
s = s.replace(old, new, 1)
old_helper = '''int _verticalInkSpan(Uint8List b, int w, int h, int x) {\n  var minY = h, maxY = -1;\n  for (var y = 0; y < h; y++) {\n    if (b[(y * w + x) * 4 + 3] == 0) continue;\n    minY = math.min(minY, y);\n    maxY = math.max(maxY, y);\n  }\n  return maxY >= minY ? maxY - minY + 1 : 0;\n}\n'''
new_helper = '''int _localVerticalInkThickness(\n  Uint8List b,\n  int w,\n  int h,\n  int x,\n  int centerY,\n  int radius,\n) {\n  if (x < 0 || x >= w || centerY < 0 || centerY >= h) return 0;\n  bool inkAt(int y) =>\n      y >= 0 && y < h && b[(y * w + x) * 4 + 3] != 0;\n  if (!inkAt(centerY)) {\n    // Rasterization may move the branch by a pixel; find the nearest local ink.\n    var found = -1;\n    for (var d = 1; d <= radius && found < 0; d++) {\n      if (inkAt(centerY - d)) found = centerY - d;\n      if (found < 0 && inkAt(centerY + d)) found = centerY + d;\n    }\n    if (found < 0) return 0;\n    centerY = found;\n  }\n  var top = centerY, bottom = centerY;\n  while (top - 1 >= math.max(0, centerY - radius) && inkAt(top - 1)) {\n    top--;\n  }\n  while (bottom + 1 <= math.min(h - 1, centerY + radius) &&\n      inkAt(bottom + 1)) {\n    bottom++;\n  }\n  return bottom - top + 1;\n}\n'''
if old_helper not in s:
    raise SystemExit('old helper not found')
s = s.replace(old_helper, new_helper, 1)
p.write_text(s, encoding='utf-8')

# Complete translations for the newly added public UI strings.
translations = {
    'lib/l10n/app_es.arb': {
        'filterNameInkPool': 'Acumulación de tinta',
        'filterInkPoolColor': 'Color',
        'filterInkPoolRange': 'Rango',
        'filterInkPoolCenterWidth': 'Grosor central',
        'filterInkPoolLayerNameSuffix': '{name} Acumulación de tinta',
    },
    'lib/l10n/app_fr.arb': {
        'filterNameInkPool': "Accumulation d’encre",
        'filterInkPoolColor': 'Couleur',
        'filterInkPoolRange': 'Étendue',
        'filterInkPoolCenterWidth': 'Épaisseur centrale',
        'filterInkPoolLayerNameSuffix': "{name} Accumulation d’encre",
    },
    'lib/l10n/app_ko.arb': {
        'filterNameInkPool': '먹물 고임',
        'filterInkPoolColor': '색상',
        'filterInkPoolRange': '범위',
        'filterInkPoolCenterWidth': '중앙 두께',
        'filterInkPoolLayerNameSuffix': '{name} 먹물 고임',
    },
    'lib/l10n/app_zh.arb': {
        'filterNameInkPool': '积墨',
        'filterInkPoolColor': '颜色',
        'filterInkPoolRange': '范围',
        'filterInkPoolCenterWidth': '中央粗细',
        'filterInkPoolLayerNameSuffix': '{name} 积墨',
    },
    'lib/l10n/app_zh_Hant.arb': {
        'filterNameInkPool': '積墨',
        'filterInkPoolColor': '顏色',
        'filterInkPoolRange': '範圍',
        'filterInkPoolCenterWidth': '中央粗細',
        'filterInkPoolLayerNameSuffix': '{name} 積墨',
    },
}
for path, values in translations.items():
    f = Path(path)
    obj = json.loads(f.read_text(encoding='utf-8'))
    for k, v in values.items():
        obj[k] = v
    obj['@filterInkPoolLayerNameSuffix'] = {
        'placeholders': {'name': {'type': 'String'}}
    }
    f.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

print('refined ink pooling taper audit and translations')
