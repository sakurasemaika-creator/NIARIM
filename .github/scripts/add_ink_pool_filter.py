from pathlib import Path
import json

ROOT = Path('.')

def replace(path: str, old: str, new: str):
    p = ROOT / path
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:120]!r}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')

# ── model ────────────────────────────────────────────────────────────────
replace('lib/models/filter_def.dart',
'''  backgroundBlend,\n}''',
'''  backgroundBlend,\n  /// 線の交差・90度以下の鋭角部だけを局所的に太らせる「墨溜まり」。\n  inkPool,\n}''')

replace('lib/models/filter_def.dart',
'''  final double bgBlendBlur;\n\n  const FilterDef({''',
'''  final double bgBlendBlur;\n  // 墨溜まり（inkPoolのみ使用）：指定色で、90度以下の線の交差/鋭角部を\n  // 中央から端へ向かって1pxまでテーパーさせる。\n  final int inkPoolColor;\n  final double inkPoolRange;\n  final double inkPoolCenterWidth;\n\n  const FilterDef({''')

replace('lib/models/filter_def.dart',
'''    this.bgBlendBlur = 6,\n  });''',
'''    this.bgBlendBlur = 6,\n    this.inkPoolColor = 0xFF000000,\n    this.inkPoolRange = 12,\n    this.inkPoolCenterWidth = 6,\n  });''')

replace('lib/models/filter_def.dart',
'''    double? bgBlendBlur,\n  }) {''',
'''    double? bgBlendBlur,\n    int? inkPoolColor,\n    double? inkPoolRange,\n    double? inkPoolCenterWidth,\n  }) {''')

replace('lib/models/filter_def.dart',
'''      bgBlendBlur: bgBlendBlur ?? this.bgBlendBlur,\n    );''',
'''      bgBlendBlur: bgBlendBlur ?? this.bgBlendBlur,\n      inkPoolColor: inkPoolColor ?? this.inkPoolColor,\n      inkPoolRange: inkPoolRange ?? this.inkPoolRange,\n      inkPoolCenterWidth: inkPoolCenterWidth ?? this.inkPoolCenterWidth,\n    );''')

replace('lib/models/filter_def.dart',
'''    'bgBlendBlur': bgBlendBlur,\n  };''',
'''    'bgBlendBlur': bgBlendBlur,\n    'inkPoolColor': inkPoolColor,\n    'inkPoolRange': inkPoolRange,\n    'inkPoolCenterWidth': inkPoolCenterWidth,\n  };''')

replace('lib/models/filter_def.dart',
'''    bgBlendBlur: (j['bgBlendBlur'] as num?)?.toDouble() ?? 6,\n  );''',
'''    bgBlendBlur: (j['bgBlendBlur'] as num?)?.toDouble() ?? 6,\n    inkPoolColor: j['inkPoolColor'] as int? ?? 0xFF000000,\n    inkPoolRange: (j['inkPoolRange'] as num?)?.toDouble() ?? 12,\n    inkPoolCenterWidth: (j['inkPoolCenterWidth'] as num?)?.toDouble() ?? 6,\n  );''')

# ── filter service ───────────────────────────────────────────────────────
replace('lib/services/filter_service.dart',
'''    FilterDef(\n      id: 'Filter0020',\n      name: '背景馴染ませ',\n      kind: FilterKind.backgroundBlend,\n    ),\n  ];''',
'''    FilterDef(\n      id: 'Filter0020',\n      name: '背景馴染ませ',\n      kind: FilterKind.backgroundBlend,\n    ),\n    FilterDef(\n      id: 'Filter0021',\n      name: '墨溜まり',\n      kind: FilterKind.inkPool,\n      inkPoolColor: 0xFF000000,\n      inkPoolRange: 12,\n      inkPoolCenterWidth: 6,\n    ),\n  ];''')

replace('lib/services/filter_service.dart',
'''    double? bgBlendBlur,\n  }) {''',
'''    double? bgBlendBlur,\n    int? inkPoolColor,\n    double? inkPoolRange,\n    double? inkPoolCenterWidth,\n  }) {''')

replace('lib/services/filter_service.dart',
'''      bgBlendBlur: bgBlendBlur,\n    );''',
'''      bgBlendBlur: bgBlendBlur,\n      inkPoolColor: inkPoolColor,\n      inkPoolRange: inkPoolRange,\n      inkPoolCenterWidth: inkPoolCenterWidth,\n    );''')

# ── engine: draw + effect dispatch ──────────────────────────────────────
replace('lib/engine/filter_engine.dart',
'''    FilterKind.backgroundBlend => engine.applyBackgroundBlend(\n      data,\n      width,\n      height,\n      filter.bgBlendColor == -1 ? 0xFF808080 : filter.bgBlendColor,\n      filter.bgBlendDirection,\n      filter.bgBlendLength,\n      filter.bgBlendBlur,\n    ),\n  };''',
'''    FilterKind.backgroundBlend => engine.applyBackgroundBlend(\n      data,\n      width,\n      height,\n      filter.bgBlendColor == -1 ? 0xFF808080 : filter.bgBlendColor,\n      filter.bgBlendDirection,\n      filter.bgBlendLength,\n      filter.bgBlendBlur,\n    ),\n    // 墨溜まりの本適用は参照レイヤーを書き換えず、墨溜まり部分だけを\n    // 新規レイヤーへ描くため透明背景の出力レイヤーを返す。\n    FilterKind.inkPool => engine.applyInkPoolLayer(\n      data,\n      width,\n      height,\n      color: filter.inkPoolColor,\n      rangePx: filter.inkPoolRange,\n      centerWidthPx: filter.inkPoolCenterWidth,\n    ),\n  };''')

replace('lib/engine/filter_engine.dart',
'''        EffectFilterType.auroraHologram => applyAuroraHologram(\n          result,\n          width,\n          height,\n          strength: e.param1,\n          brightness: e.param2,\n          saturation: e.param3,\n          preset:\n              AuroraHologramPreset.values[e.param4.round().clamp(\n                0,\n                AuroraHologramPreset.values.length - 1,\n              )],\n        ),\n      };''',
'''        EffectFilterType.auroraHologram => applyAuroraHologram(\n          result,\n          width,\n          height,\n          strength: e.param1,\n          brightness: e.param2,\n          saturation: e.param3,\n          preset:\n              AuroraHologramPreset.values[e.param4.round().clamp(\n                0,\n                AuroraHologramPreset.values.length - 1,\n              )],\n        ),\n        // 墨溜まり：param1=範囲(px)、param2=鋭角中央の太さ(px)、\n        // fadeColorスロットを色として共用する。演出フィルターでは\n        // レイヤー追加を行わず、フレーム合成結果へ非破壊で重ねる。\n        EffectFilterType.inkPool => applyInkPoolComposite(\n          result,\n          width,\n          height,\n          color: e.fadeColor.toARGB32(),\n          rangePx: e.param1,\n          centerWidthPx: e.param2,\n        ),\n      };''')

engine_methods = r'''
  /// 墨溜まりフィルターの「効果レイヤー」だけを生成する。
  ///
  /// 線画の不透明画素（全面不透明画像では暗い画素）を線として二値化し、各線上の
  /// 点から一定半径の円周を36方向サンプリングする。滑らかな1本線なら円周上の
  /// 方向クラスタはほぼ180°離れた2方向になるが、交差・折れ点では90°以下の
  /// 方向対が現れる。その点だけを墨溜まり中心として採用する。
  ///
  /// 採用した中心から[rangePx]以内の元線に沿って局所的な太線を描き、中心の
  /// 太さを[centerWidthPx]、範囲端を1pxとして線形にテーパーさせる。返り値は
  /// 透明背景＋墨溜まり色だけなので、描画フィルターでは参照レイヤーの直下へ
  /// そのまま新規レイヤーとして置ける。
  Uint8List applyInkPoolLayer(
    Uint8List data,
    int width,
    int height, {
    required int color,
    required double rangePx,
    required double centerWidthPx,
  }) {
    final result = Uint8List(data.length);
    if (width <= 2 || height <= 2 || data.length < width * height * 4) {
      return result;
    }
    final range = rangePx.round().clamp(1, 80);
    final centerWidth = centerWidthPx.round().clamp(1, 60);
    const alphaThreshold = 24;
    final pixels = width * height;
    var opaque = 0;
    for (var i = 3; i < data.length; i += 4) {
      if (data[i] > alphaThreshold) opaque++;
    }
    final mostlyOpaque = opaque / pixels > 0.85;
    final mask = Uint8List(pixels);
    for (var p = 0; p < pixels; p++) {
      final i = p * 4;
      final a = data[i + 3];
      if (a <= alphaThreshold) continue;
      if (!mostlyOpaque) {
        mask[p] = 1;
      } else {
        final lum = data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114;
        if (lum < 210) mask[p] = 1;
      }
    }

    const bins = 36;
    final sampleRadius = math.max(4, math.min(12, centerWidth + 2));
    if (width <= sampleRadius * 2 || height <= sampleRadius * 2) return result;

    List<double> clusterCenters(List<bool> hits) {
      if (!hits.any((v) => v) || hits.every((v) => v)) return const [];
      var start = hits.indexWhere((v) => !v);
      final centers = <double>[];
      var inRun = false;
      var sx = 0.0, sy = 0.0;
      for (var step = 1; step <= bins; step++) {
        final b = (start + step) % bins;
        if (hits[b]) {
          final a = 2 * math.pi * b / bins;
          sx += math.cos(a);
          sy += math.sin(a);
          inRun = true;
        } else if (inRun) {
          centers.add(math.atan2(sy, sx));
          sx = 0;
          sy = 0;
          inRun = false;
        }
      }
      if (inRun) centers.add(math.atan2(sy, sx));
      return centers;
    }

    final candidates = <({int x, int y, double score})>[];
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
              if (nx >= 0 && nx < width && ny >= 0 && ny < height && mask[ny * width + nx] != 0) {
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
          candidates.add((x: x, y: y, score: math.pi / 2 - minSep));
        }
      }
    }
    if (candidates.isEmpty) return result;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final seeds = <({int x, int y})>[];
    final suppress = math.max(2, centerWidth ~/ 2);
    final suppress2 = suppress * suppress;
    for (final c in candidates) {
      var near = false;
      for (final s in seeds) {
        final dx = c.x - s.x, dy = c.y - s.y;
        if (dx * dx + dy * dy <= suppress2) {
          near = true;
          break;
        }
      }
      if (!near) seeds.add((x: c.x, y: c.y));
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

    for (final s in seeds) {
      final minX = math.max(0, s.x - range);
      final maxX = math.min(width - 1, s.x + range);
      final minY = math.max(0, s.y - range);
      final maxY = math.min(height - 1, s.y + range);
      for (var y = minY; y <= maxY; y++) {
        for (var x = minX; x <= maxX; x++) {
          if (mask[y * width + x] == 0) continue;
          final dx = x - s.x, dy = y - s.y;
          final d = math.sqrt((dx * dx + dy * dy).toDouble());
          if (d > range) continue;
          final t = (d / range).clamp(0.0, 1.0);
          final thickness = 1.0 + (centerWidth - 1) * (1.0 - t);
          final radius = math.max(0.0, (thickness - 1.0) / 2.0);
          final rr = math.max(0, radius.ceil());
          for (var oy = -rr; oy <= rr; oy++) {
            for (var ox = -rr; ox <= rr; ox++) {
              if (ox * ox + oy * oy <= radius * radius + 0.35) put(x + ox, y + oy);
            }
          }
          if (rr == 0) put(x, y);
        }
      }
    }
    return result;
  }

  /// 演出フィルター向け墨溜まり。上の効果レイヤーをフレーム合成結果へ
  /// アルファ合成する。描画フィルター版と違いプロジェクトのレイヤー構造は
  /// 変更せず、指定フレーム範囲でだけ非破壊に見える。
  Uint8List applyInkPoolComposite(
    Uint8List data,
    int width,
    int height, {
    required int color,
    required double rangePx,
    required double centerWidthPx,
  }) {
    final ink = applyInkPoolLayer(
      data,
      width,
      height,
      color: color,
      rangePx: rangePx,
      centerWidthPx: centerWidthPx,
    );
    final out = Uint8List.fromList(data);
    for (var i = 0; i < out.length; i += 4) {
      final a = ink[i + 3] / 255.0;
      if (a <= 0) continue;
      out[i] = (ink[i] * a + out[i] * (1 - a)).round().clamp(0, 255);
      out[i + 1] = (ink[i + 1] * a + out[i + 1] * (1 - a)).round().clamp(0, 255);
      out[i + 2] = (ink[i + 2] * a + out[i + 2] * (1 - a)).round().clamp(0, 255);
      out[i + 3] = math.max(out[i + 3], ink[i + 3]);
    }
    return out;
  }

'''
replace('lib/engine/filter_engine.dart',
'''  Uint8List applyLevels(\n''',
engine_methods + '''  Uint8List applyLevels(\n''')

replace('lib/engine/filter_engine.dart',
'''  auroraHologram,\n}\n\nenum DrawFilterType''',
'''  auroraHologram,\n  inkPool,\n}\n\nenum DrawFilterType''')

# ── drawing filter UI / layer semantics ─────────────────────────────────
replace('lib/screens/canvas/widgets/filter_panel.dart',
'''                        if (current.kind == FilterKind.outline) ...[\n''',
'''                        if (current.kind == FilterKind.inkPool) ...[\n                          Padding(\n                            padding: const EdgeInsets.symmetric(vertical: 2),\n                            child: Row(\n                              children: [\n                                Text(l10n.filterInkPoolColor, style: const TextStyle(fontSize: 11)),\n                                const SizedBox(width: 8),\n                                GestureDetector(\n                                  onTap: () => _pickInkPoolColor(filterService, current),\n                                  child: Container(\n                                    width: 24,\n                                    height: 24,\n                                    decoration: BoxDecoration(\n                                      color: Color(current.inkPoolColor),\n                                      border: Border.all(color: ThemeService.activeColorScheme.onSurfaceVariant),\n                                      borderRadius: BorderRadius.circular(4),\n                                    ),\n                                  ),\n                                ),\n                              ],\n                            ),\n                          ),\n                          _integerStepperSlider(\n                            l10n.filterInkPoolRange,\n                            current.inkPoolRange.round(),\n                            1,\n                            80,\n                            (v) => filterService.updateFilterParams(current.id, inkPoolRange: v.toDouble()),\n                          ),\n                          _integerStepperSlider(\n                            l10n.filterInkPoolCenterWidth,\n                            current.inkPoolCenterWidth.round(),\n                            1,\n                            60,\n                            (v) => filterService.updateFilterParams(current.id, inkPoolCenterWidth: v.toDouble()),\n                          ),\n                        ],\n                        if (current.kind == FilterKind.outline) ...[\n''')

replace('lib/screens/canvas/widgets/filter_panel.dart',
'''  /// 周辺減光の減光先の色を選ぶ''',
'''  void _pickInkPoolColor(FilterService filterService, FilterDef current) {\n    showDialog(\n      context: context,\n      builder: (ctx) => Dialog(\n        backgroundColor: Colors.transparent,\n        child: ColorPickerPanel(\n          currentColor: Color(current.inkPoolColor),\n          onColorChanged: (c) {\n            filterService.updateFilterParams(current.id, inkPoolColor: c.toARGB32());\n            _updatePreview();\n          },\n          onClose: () => Navigator.of(ctx).pop(),\n        ),\n      ),\n    );\n  }\n\n  /// 周辺減光の減光先の色を選ぶ''')

stepper = r'''
  Widget _integerStepperSlider(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    void change(int next) {
      onChanged(next.clamp(min, max));
      _updatePreview();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value}px', style: const TextStyle(fontSize: 11)),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_rounded, size: 18),
                onPressed: value > min ? () => change(value - 1) : null,
              ),
              Expanded(
                child: SteppedSlider(
                  value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: max - min,
                  label: '${value}px',
                  onChanged: (v) => change(v.round()),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: value < max ? () => change(value + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

'''
replace('lib/screens/canvas/widgets/filter_panel.dart',
'''  /// フィルターの表示名を多言語対応で返す''',
stepper + '''  /// フィルターの表示名を多言語対応で返す''')

replace('lib/screens/canvas/widgets/filter_panel.dart',
'''        FilterKind.backgroundBlend => l10n.filterNameBackgroundBlend,\n      };''',
'''        FilterKind.backgroundBlend => l10n.filterNameBackgroundBlend,\n        FilterKind.inkPool => l10n.filterNameInkPool,\n      };''')

replace('lib/screens/canvas/widgets/filter_panel.dart',
'''      case FilterKind.backgroundBlend:\n        // lensDistortionのlensCenterOffsetと同じ理由で、長さ・ぼかし半径''',
'''      case FilterKind.inkPool:\n        return _engine.applyInkPoolComposite(\n          data,\n          width,\n          height,\n          color: filter.inkPoolColor,\n          rangePx: filter.inkPoolRange * _previewScale,\n          centerWidthPx: filter.inkPoolCenterWidth * _previewScale,\n        );\n      case FilterKind.backgroundBlend:\n        // lensDistortionのlensCenterOffsetと同じ理由で、長さ・ぼかし半径''')

replace('lib/screens/canvas/widgets/filter_panel.dart',
'''      case FilterKind.backgroundBlend:\n        return Icons.wb_twilight;\n    }''',
'''      case FilterKind.backgroundBlend:\n        return Icons.wb_twilight;\n      case FilterKind.inkPool:\n        return Icons.gesture_rounded;\n    }''')

replace('lib/screens/canvas/widgets/filter_panel.dart',
'''    final l10n = filter.kind == FilterKind.outline\n        ? AppLocalizations.of(context)!\n        : null;''',
'''    final l10n = filter.kind == FilterKind.outline || filter.kind == FilterKind.inkPool\n        ? AppLocalizations.of(context)!\n        : null;''')

replace('lib/screens/canvas/widgets/filter_panel.dart',
'''    if (filter.kind == FilterKind.outline) {\n      return _applyOutlineToNewLayer(\n        ps,\n        tm,\n        layerId,\n        filter,\n        frameIndex,\n        result,\n        outlineLayerId,\n        l10n!,\n      );\n    }\n\n    tm.replaceLayerPixels(key, result);''',
'''    if (filter.kind == FilterKind.outline) {\n      return _applyOutlineToNewLayer(\n        ps, tm, layerId, filter, frameIndex, result, outlineLayerId, l10n!,\n      );\n    }\n    if (filter.kind == FilterKind.inkPool) {\n      return _applyInkPoolToNewLayer(\n        ps, tm, layerId, filter, frameIndex, result, outlineLayerId, l10n!,\n      );\n    }\n\n    tm.replaceLayerPixels(key, result);''')

ink_layer_method = r'''
  Future<String> _applyInkPoolToNewLayer(
    ProjectService ps,
    TileManager tm,
    String sourceLayerId,
    FilterDef filter,
    int frameIndex,
    Uint8List inkData,
    String? inkLayerId,
    AppLocalizations l10n,
  ) async {
    final sourceLayer = ps
        .layersOf(widget.projectId, widget.sceneId, frameIndex)
        .where((l) => l.id == sourceLayerId)
        .firstOrNull;
    final sourceName = sourceLayer?.name ?? _filterDisplayName(l10n, filter);
    final created = ps.addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      type: model.LayerType.normal,
      name: l10n.filterInkPoolLayerNameSuffix(sourceName),
      id: inkLayerId,
    );
    final layers = ps.layersOf(widget.projectId, widget.sceneId, frameIndex);
    final createdIdx = layers.indexWhere((l) => l.id == created.id);
    final sourceIdx = layers.indexWhere((l) => l.id == sourceLayerId);
    final targetIdx = sourceIdx < 0 ? createdIdx : sourceIdx + 1;
    if (createdIdx >= 0 && targetIdx >= 0 && createdIdx != targetIdx) {
      ps.reorderLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: frameIndex,
        oldIndex: createdIdx,
        newIndex: targetIdx,
      );
    }
    final newKey = ps.tileKeyFor(widget.projectId, widget.sceneId, frameIndex, created.id);
    tm.replaceLayerPixels(newKey, inkData);
    ps.updateLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      layer: created,
    );
    return created.id;
  }

'''
replace('lib/screens/canvas/widgets/filter_panel.dart',
'''  /// 大量処理実行時：選択した全フレームへ順に適用し、''',
ink_layer_method + '''  /// 大量処理実行時：選択した全フレームへ順に適用し、''')

# ── timeline effect UI ──────────────────────────────────────────────────
replace('lib/screens/timeline/timeline_screen.dart',
'''        EffectFilterType.auroraHologram => l10n.filterNameAuroraHologram,\n      };''',
'''        EffectFilterType.auroraHologram => l10n.filterNameAuroraHologram,\n        EffectFilterType.inkPool => l10n.filterNameInkPool,\n      };''')

replace('lib/screens/timeline/timeline_screen.dart',
'''    EffectFilterType.auroraHologram: Icons.auto_awesome_mosaic,\n  };''',
'''    EffectFilterType.auroraHologram: Icons.auto_awesome_mosaic,\n    EffectFilterType.inkPool: Icons.gesture_rounded,\n  };''')

replace('lib/screens/timeline/timeline_screen.dart',
'''                else if (e.type == EffectFilterType.auroraHologram)\n                  ..._auroraHologramParams(context, l10n, e)\n                else''',
'''                else if (e.type == EffectFilterType.auroraHologram)\n                  ..._auroraHologramParams(context, l10n, e)\n                else if (e.type == EffectFilterType.inkPool)\n                  ..._inkPoolParams(context, l10n, e)\n                else''')

effect_methods = r'''
  List<Widget> _inkPoolParams(
    BuildContext context,
    AppLocalizations l10n,
    EffectFilterInstance e,
  ) {
    Widget stepRow(String label, double value, int min, int max, ValueChanged<double> onChanged) {
      final v = value.round().clamp(min, max);
      void change(int next) => onChanged(next.clamp(min, max).toDouble());
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${v}px', style: const TextStyle(fontSize: 11)),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_rounded, size: 18),
                onPressed: v > min ? () => change(v - 1) : null,
              ),
              Expanded(
                child: SteppedSlider(
                  value: v.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: max - min,
                  label: '${v}px',
                  onChanged: (n) => change(n.round()),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: v < max ? () => change(v + 1) : null,
              ),
            ],
          ),
        ],
      );
    }
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(l10n.filterInkPoolColor, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _pickInkPoolEffectColor(context, e),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: e.fadeColor,
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
      stepRow(
        l10n.filterInkPoolRange,
        e.param1,
        1,
        80,
        (v) => _update(context, e.copyWith(param1: v)),
      ),
      stepRow(
        l10n.filterInkPoolCenterWidth,
        e.param2,
        1,
        60,
        (v) => _update(context, e.copyWith(param2: v)),
      ),
    ];
  }

  void _pickInkPoolEffectColor(BuildContext context, EffectFilterInstance e) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ColorPickerPanel(
          currentColor: e.fadeColor,
          onColorChanged: (c) => _update(context, e.copyWith(fadeColor: c)),
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

'''
replace('lib/screens/timeline/timeline_screen.dart',
'''  /// 二値化のパラメータ（閾値スライダーのみ。0〜255）。''',
effect_methods + '''  /// 二値化のパラメータ（閾値スライダーのみ。0〜255）。''')

replace('lib/screens/timeline/timeline_screen.dart',
'''                            EffectFilterType.auroraHologram => 60.0,\n                            _ => 5.0,''',
'''                            EffectFilterType.auroraHologram => 60.0,\n                            EffectFilterType.inkPool => 12.0,\n                            _ => 5.0,''')

replace('lib/screens/timeline/timeline_screen.dart',
'''                              : type == EffectFilterType.auroraHologram\n                              ? 0.0\n                              : 50.0,''',
'''                              : type == EffectFilterType.auroraHologram\n                              ? 0.0\n                              : type == EffectFilterType.inkPool\n                              ? 6.0\n                              : 50.0,''')

# ── localization ────────────────────────────────────────────────────────
def add_l10n(path: str, values: dict):
    p = ROOT / path
    obj = json.loads(p.read_text(encoding='utf-8'))
    obj.update(values)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

add_l10n('lib/l10n/app_ja.arb', {
    'filterNameInkPool': '墨溜まり',
    'filterInkPoolColor': '色',
    'filterInkPoolRange': '範囲',
    'filterInkPoolCenterWidth': '中央の太さ',
    'filterInkPoolLayerNameSuffix': '{name} 墨溜まり',
    '@filterInkPoolLayerNameSuffix': {'placeholders': {'name': {'type': 'String'}}},
})
add_l10n('lib/l10n/app_en.arb', {
    'filterNameInkPool': 'Ink Pooling',
    'filterInkPoolColor': 'Color',
    'filterInkPoolRange': 'Range',
    'filterInkPoolCenterWidth': 'Center width',
    'filterInkPoolLayerNameSuffix': '{name} Ink Pooling',
    '@filterInkPoolLayerNameSuffix': {'placeholders': {'name': {'type': 'String'}}},
})

# ── strict test ─────────────────────────────────────────────────────────
test = r'''import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/effect_filter_instance.dart';

void main() {
  Uint8List lineCanvas(int w, int h, void Function(Uint8List b) draw) {
    final b = Uint8List(w * h * 4);
    draw(b);
    return b;
  }
  void px(Uint8List b, int w, int x, int y, [int thickness = 1]) {
    for (var oy = -thickness ~/ 2; oy <= thickness ~/ 2; oy++) {
      for (var ox = -thickness ~/ 2; ox <= thickness ~/ 2; ox++) {
        final xx = x + ox, yy = y + oy;
        if (xx < 0 || yy < 0 || xx >= w || yy >= b.length ~/ 4 ~/ w) continue;
        final i = (yy * w + xx) * 4;
        b[i] = b[i + 1] = b[i + 2] = 20;
        b[i + 3] = 255;
      }
    }
  }
  void line(Uint8List b, int w, int x0, int y0, int x1, int y1) {
    final steps = (x1 - x0).abs() > (y1 - y0).abs() ? (x1 - x0).abs() : (y1 - y0).abs();
    for (var s = 0; s <= steps; s++) {
      final t = steps == 0 ? 0.0 : s / steps;
      px(b, w, (x0 + (x1 - x0) * t).round(), (y0 + (y1 - y0) * t).round());
    }
  }
  int alphaCount(Uint8List b) {
    var n = 0;
    for (var i = 3; i < b.length; i += 4) if (b[i] != 0) n++;
    return n;
  }

  test('墨溜まり: 90度の交差だけに指定色のテーパー効果レイヤーを作る', () {
    const w = 80, h = 80;
    final src = lineCanvas(w, h, (b) {
      line(b, w, 15, 40, 40, 40);
      line(b, w, 40, 40, 40, 65);
    });
    final ink = FilterEngine().applyInkPoolLayer(
      src, w, h,
      color: 0xFF7A2038,
      rangePx: 16,
      centerWidthPx: 8,
    );
    expect(alphaCount(ink), greaterThan(30));
    final center = (40 * w + 40) * 4;
    expect(ink[center], 0x7A);
    expect(ink[center + 1], 0x20);
    expect(ink[center + 2], 0x38);
    expect(ink[center + 3], 255);
    // 元線から外れた中心近傍にも太りが発生する。
    expect(ink[((38) * w + 38) * 4 + 3], greaterThan(0));
    // 範囲外は透明。
    expect(ink[(10 * w + 10) * 4 + 3], 0);
  });

  test('墨溜まり: 直線だけでは発生しない', () {
    const w = 80, h = 80;
    final src = lineCanvas(w, h, (b) => line(b, w, 10, 40, 70, 40));
    final ink = FilterEngine().applyInkPoolLayer(
      src, w, h,
      color: 0xFF000000,
      rangePx: 12,
      centerWidthPx: 6,
    );
    expect(alphaCount(ink), 0);
  });

  test('墨溜まり演出: 指定フレーム範囲だけ非破壊で適用される', () {
    const w = 64, h = 64;
    final src = lineCanvas(w, h, (b) {
      line(b, w, 10, 32, 32, 32);
      line(b, w, 32, 32, 32, 54);
    });
    final effect = EffectFilterInstance(
      id: 'ink',
      type: EffectFilterType.inkPool,
      startFrame: 5,
      endFrame: 10,
      param1: 12,
      param2: 6,
      fadeColor: const ui.Color(0xFF5A1A30),
    );
    final engine = FilterEngine();
    final before = engine.applyEffectFilters(src, w, h, [effect], 4);
    final active = engine.applyEffectFilters(src, w, h, [effect], 7);
    expect(before, orderedEquals(src));
    expect(active, isNot(orderedEquals(src)));
  });
}
'''
(ROOT / 'test/ink_pool_filter_test.dart').write_text(test, encoding='utf-8')

print('ink pooling filter patches applied')
