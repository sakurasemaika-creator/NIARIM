from pathlib import Path
import json


def replace(path, old, new):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    if old not in s:
        raise SystemExit(f'pattern not found: {path}: {old[:120]!r}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')

engine_path = Path('lib/engine/filter_engine.dart')
s = engine_path.read_text(encoding='utf-8')
start = s.index('    final candidates = <({int x, int y, double score})>[];')
end_marker = '    return result;\n  }\n\n  /// 演出フィルター向け墨溜まり。'
end = s.index(end_marker, start)
old_block = s[start:end]
new_block = r'''    final candidates =
        <({int x, int y, double score, List<double> directions})>[];
    for (var y = sampleRadius; y < height - sampleRadius; y++) {
      for (var x = sampleRadius; x < width - sampleRadius; x++) {
        if (mask[y * width + x] == 0) continue;
        final hits = List<bool>.filled(bins, false);
        for (var b = 0; b < bins; b++) {
          final a = 2 * math.pi * b / bins;
          final sx = (x + math.cos(a) * sampleRadius).round();
          final sy = (y + math.sin(a) * sampleRadius).round();
          // 1px線のアンチエイリアスや丸め誤差を吸収するため、サンプル点の
          // 3x3近傍に線があればその方向を「枝あり」とする。
          var hit = false;
          for (var oy = -1; oy <= 1 && !hit; oy++) {
            for (var ox = -1; ox <= 1; ox++) {
              final nx = sx + ox, ny = sy + oy;
              if (nx >= 0 &&
                  nx < width &&
                  ny >= 0 &&
                  ny < height &&
                  mask[ny * width + nx] != 0) {
                hit = true;
                break;
              }
            }
          }
          hits[b] = hit;
        }
        final centers = clusterCenters(hits);
        if (centers.length < 2) continue;
        var minSep = math.pi;
        for (var i = 0; i < centers.length; i++) {
          for (var j = i + 1; j < centers.length; j++) {
            var d = (centers[i] - centers[j]).abs();
            if (d > math.pi) d = 2 * math.pi - d;
            if (d < minSep) minSep = d;
          }
        }
        // 約5°の許容を持たせ、90°ジャストのラスタ線も確実に拾う。
        if (minSep <= math.pi / 2 + 0.09) {
          candidates.add((
            x: x,
            y: y,
            score: math.pi / 2 - minSep,
            directions: centers,
          ));
        }
      }
    }
    if (candidates.isEmpty) return result;
    candidates.sort((a, b) => b.score.compareTo(a.score));

    // 1つの交差/鋭角の周囲では複数の画素が候補になる。近傍候補を別々の
    // 起点にすると、それぞれで太さが最大へ戻ってしまい「範囲端で1px」が
    // 崩れるため、方向検出半径ぶんをまとめて1つのジャンクションにする。
    final seeds =
        <({int x, int y, List<double> directions})>[];
    final suppress = math.max(sampleRadius * 2, centerWidth);
    final suppress2 = suppress * suppress;
    for (final c in candidates) {
      var near = false;
      for (final seed in seeds) {
        final dx = c.x - seed.x, dy = c.y - seed.y;
        if (dx * dx + dy * dy <= suppress2) {
          near = true;
          break;
        }
      }
      if (!near) {
        seeds.add((x: c.x, y: c.y, directions: c.directions));
      }
    }

    final ca = (color >> 24) & 0xFF;
    final cr = (color >> 16) & 0xFF;
    final cg = (color >> 8) & 0xFF;
    final cb = color & 0xFF;
    void put(int x, int y) {
      if (x < 0 || x >= width || y < 0 || y >= height) return;
      final i = (y * width + x) * 4;
      result[i] = cr;
      result[i + 1] = cg;
      result[i + 2] = cb;
      result[i + 3] = ca;
    }

    void stamp(int cx, int cy, double thickness) {
      final radius = math.max(0.0, (thickness - 1.0) / 2.0);
      final rr = math.max(0, radius.ceil());
      for (var oy = -rr; oy <= rr; oy++) {
        for (var ox = -rr; ox <= rr; ox++) {
          if (ox * ox + oy * oy <= radius * radius + 0.35) {
            put(cx + ox, cy + oy);
          }
        }
      }
      if (rr == 0) put(cx, cy);
    }

    ({int x, int y})? nearestLinePixel(int px, int py, int searchRadius) {
      var bestD2 = 1 << 30;
      int? bestX, bestY;
      for (var oy = -searchRadius; oy <= searchRadius; oy++) {
        for (var ox = -searchRadius; ox <= searchRadius; ox++) {
          final x = px + ox, y = py + oy;
          if (x < 0 || x >= width || y < 0 || y >= height) continue;
          if (mask[y * width + x] == 0) continue;
          final d2 = ox * ox + oy * oy;
          if (d2 < bestD2) {
            bestD2 = d2;
            bestX = x;
            bestY = y;
          }
        }
      }
      return bestX == null ? null : (x: bestX!, y: bestY!);
    }

    for (final seed in seeds) {
      // 中央は指定太さ。そこから各検出枝の「中心線」だけを追い、元線の
      // 太さそのものは墨レイヤーへコピーしない。これにより太い参照線でも
      // 墨溜まり側は範囲端で本当に1pxまで細くできる。
      stamp(seed.x, seed.y, centerWidth.toDouble());
      for (final direction in seed.directions) {
        var misses = 0;
        ({int x, int y})? last;
        for (var step = 1; step <= range; step++) {
          final predictedX =
              (seed.x + math.cos(direction) * step).round();
          final predictedY =
              (seed.y + math.sin(direction) * step).round();
          final point = nearestLinePixel(predictedX, predictedY, 2);
          if (point == null) {
            misses++;
            if (misses >= 3) break;
            continue;
          }
          misses = 0;
          if (last != null && last.x == point.x && last.y == point.y) continue;
          last = point;
          final t = (step / range).clamp(0.0, 1.0);
          final thickness = 1.0 + (centerWidth - 1) * (1.0 - t);
          stamp(point.x, point.y, thickness);
        }
      }
    }
'''
s = s[:start] + new_block + s[end:]
engine_path.write_text(s, encoding='utf-8')

# Correct the visual assertion: measure only the local connected thickness around
# the known horizontal branch, never the full image column that also crosses the
# second branch.
test_path = Path('test/niarim_unique_visual_evidence_v3_test.dart')
t = test_path.read_text(encoding='utf-8')
old = '''    // 中心付近は横断方向に複数px、範囲端近くは中心より細いことを数値確認。\n    final cx = w ~/ 2, cy = h ~/ 2;\n    final centerSpan = _verticalInkSpan(thickCenter, w, h, cx);\n    final edgeX = cx - 24;\n    final edgeSpan = _verticalInkSpan(thickCenter, w, h, edgeX);\n    expect(centerSpan, greaterThanOrEqualTo(8));\n    expect(edgeSpan, lessThan(centerSpan));\n'''
new = '''    // 横断方向の「局所連結太さ」でテーパーを測る。元線自体の幅に関係なく\n    // range=28 の端付近では墨レイヤーが1px近くまで細くなることを確認。\n    final cx = w ~/ 2, cy = h ~/ 2;\n    final centerSpan = _localVerticalInkThickness(\n      thickCenter,\n      w,\n      h,\n      cx,\n      cy,\n      20,\n    );\n    final edgeSpan = _localVerticalInkThickness(\n      thickCenter,\n      w,\n      h,\n      cx - 27,\n      cy,\n      8,\n    );\n    expect(centerSpan, greaterThanOrEqualTo(8));\n    expect(edgeSpan, inInclusiveRange(1, 3));\n    expect(edgeSpan, lessThan(centerSpan));\n'''
if old not in t:
    raise SystemExit('old taper assertion not found')
t = t.replace(old, new, 1)
old_helper = '''int _verticalInkSpan(Uint8List b, int w, int h, int x) {\n  var minY = h, maxY = -1;\n  for (var y = 0; y < h; y++) {\n    if (b[(y * w + x) * 4 + 3] == 0) continue;\n    minY = math.min(minY, y);\n    maxY = math.max(maxY, y);\n  }\n  return maxY >= minY ? maxY - minY + 1 : 0;\n}\n'''
new_helper = '''int _localVerticalInkThickness(\n  Uint8List b,\n  int w,\n  int h,\n  int x,\n  int centerY,\n  int radius,\n) {\n  if (x < 0 || x >= w || centerY < 0 || centerY >= h) return 0;\n  bool inkAt(int y) =>\n      y >= 0 && y < h && b[(y * w + x) * 4 + 3] != 0;\n  if (!inkAt(centerY)) {\n    var found = -1;\n    for (var d = 1; d <= radius && found < 0; d++) {\n      if (inkAt(centerY - d)) found = centerY - d;\n      if (found < 0 && inkAt(centerY + d)) found = centerY + d;\n    }\n    if (found < 0) return 0;\n    centerY = found;\n  }\n  var top = centerY, bottom = centerY;\n  while (top - 1 >= math.max(0, centerY - radius) && inkAt(top - 1)) {\n    top--;\n  }\n  while (bottom + 1 <= math.min(h - 1, centerY + radius) &&\n      inkAt(bottom + 1)) {\n    bottom++;\n  }\n  return bottom - top + 1;\n}\n'''
if old_helper not in t:
    raise SystemExit('old vertical helper not found')
t = t.replace(old_helper, new_helper, 1)
test_path.write_text(t, encoding='utf-8')

translations = {
    'lib/l10n/app_es.arb': ('Acumulación de tinta', 'Color', 'Rango', 'Grosor central', '{name} Acumulación de tinta'),
    'lib/l10n/app_fr.arb': ('Accumulation d’encre', 'Couleur', 'Étendue', 'Épaisseur centrale', '{name} Accumulation d’encre'),
    'lib/l10n/app_ko.arb': ('먹물 고임', '색상', '범위', '중앙 두께', '{name} 먹물 고임'),
    'lib/l10n/app_zh.arb': ('积墨', '颜色', '范围', '中央粗细', '{name} 积墨'),
    'lib/l10n/app_zh_Hant.arb': ('積墨', '顏色', '範圍', '中央粗細', '{name} 積墨'),
}
for path, vals in translations.items():
    p = Path(path)
    obj = json.loads(p.read_text(encoding='utf-8'))
    obj['filterNameInkPool'] = vals[0]
    obj['filterInkPoolColor'] = vals[1]
    obj['filterInkPoolRange'] = vals[2]
    obj['filterInkPoolCenterWidth'] = vals[3]
    obj['filterInkPoolLayerNameSuffix'] = vals[4]
    obj['@filterInkPoolLayerNameSuffix'] = {'placeholders': {'name': {'type': 'String'}}}
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

print('ink pooling now follows branch centerlines and tapers independently of source width')
