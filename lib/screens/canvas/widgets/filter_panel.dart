import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../engine/filter_engine.dart';
import '../../../engine/tile_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/filter_def.dart';
import '../../../services/filter_service.dart';
import '../../../services/premium_service.dart';
import '../../../services/project_service.dart';
import '../../../widgets/premium_lock_widget.dart';
import '../../../widgets/progress_dialog.dart';
import 'color_picker_panel.dart';

/// 描画フィルターパネル（仕様書18）。
/// フィルターの選択・パラメータ調整・プレビュー・適用を行う。
/// [bulkFrameIndices]が指定された場合は「大量処理」として、指定した全フレームの
/// 同一レイヤーへフィルターを一括適用し、進捗をProgressDialog（正方形広告付き）
/// で表示する（仕様書13・18：大量処理実行時の広告表示）。
class FilterPanel extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final String? layerId;
  final int frameIndex;
  final Set<int>? bulkFrameIndices;
  final VoidCallback onClose;

  const FilterPanel({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.layerId,
    required this.frameIndex,
    this.bulkFrameIndices,
    required this.onClose,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  final FilterEngine _engine = FilterEngine();
  bool _showFavoritesOnly = false;
  bool _showSearch = false;
  bool _applying = false;

  Uint8List? _previewBase;
  int _previewW = 0;
  int _previewH = 0;
  ui.Image? _previewImage;
  String? _previewFilterId;

  @override
  void initState() {
    super.initState();
    _loadPreviewBase();
  }

  @override
  void dispose() {
    _previewImage?.dispose();
    super.dispose();
  }

  Future<void> _loadPreviewBase() async {
    final layerId = widget.layerId;
    if (layerId == null) return;
    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(widget.projectId);
    final w = tm.canvasWidth;
    final h = tm.canvasHeight;
    if (w <= 0 || h <= 0) return;
    final key = ps.tileKeyFor(widget.projectId, widget.sceneId, widget.frameIndex, layerId);
    final img = await tm.compositeLayerToImage(key);

    const maxSize = 150;
    final scale = maxSize / math.max(w, h);
    final pw = (w * scale).round().clamp(1, maxSize);
    final ph = (h * scale).round().clamp(1, maxSize);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble()),
      ui.Paint(),
    );
    img.dispose();
    final picture = recorder.endRecording();
    final small = await picture.toImage(pw, ph);
    final byteData = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    small.dispose();
    if (byteData == null || !mounted) return;
    _previewBase = byteData.buffer.asUint8List();
    _previewW = pw;
    _previewH = ph;
    await _updatePreview();
  }

  Future<void> _updatePreview() async {
    final base = _previewBase;
    final filter = context.read<FilterService>().currentFilter;
    if (base == null || filter == null || !mounted) return;
    final filtered = _runFilter(filter, base, _previewW, _previewH);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        filtered, _previewW, _previewH, ui.PixelFormat.rgba8888, completer.complete);
    final img = await completer.future;
    if (!mounted) {
      img.dispose();
      return;
    }
    setState(() {
      _previewImage?.dispose();
      _previewImage = img;
      _previewFilterId = filter.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filterService = context.watch<FilterService>();
    final filters = _showFavoritesOnly
        ? filterService.visibleFilters.where((f) => f.isFavorite).toList()
        : filterService.visibleFilters;
    final current = filterService.currentFilter;
    final bulk = widget.bulkFrameIndices;

    // 選択中フィルターの調整値が変わったらプレビューを再計算する
    if (current != null && current.id != _previewFilterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updatePreview());
    }

    return Card(
      elevation: 8,
      child: SizedBox(
        width: 280,
        height: 480,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    bulk != null ? l10n.filterPanelTitleBulk(bulk.length) : l10n.filterPanelTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showFavoritesOnly ? Icons.star : Icons.star_outline,
                      size: 16,
                      color: _showFavoritesOnly ? Colors.amber : null,
                    ),
                    onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                    tooltip: l10n.creativePanelFavoritesOnlyTooltip,
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, size: 16),
                    onPressed: () => setState(() => _showSearch = !_showSearch),
                  ),
                  IconButton(icon: const Icon(Icons.close, size: 16), onPressed: widget.onClose),
                ],
              ),
              if (_showSearch)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.filterSearchHint,
                      prefixIcon: const Icon(Icons.search, size: 16),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: filterService.setSearchQuery,
                  ),
                ),
              const Divider(),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  itemBuilder: (context, index) {
                    final f = filters[index];
                    final isSelected = f.id == current?.id;
                    final premiumFeature = _premiumFeatureFor(f.kind);
                    final isLocked = premiumFeature != null &&
                        !context.watch<PremiumService>().isFeatureAvailable(premiumFeature);
                    final chip = GestureDetector(
                      onTap: isLocked ? null : () => filterService.selectFilter(f.id),
                      child: Container(
                        width: 72,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[600]!,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey[800],
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_iconFor(f.kind), size: 22),
                                  const SizedBox(height: 2),
                                  Text(f.name,
                                      style: const TextStyle(fontSize: 9),
                                      textAlign: TextAlign.center,
                                      maxLines: 2),
                                ],
                              ),
                            ),
                            if (!isLocked)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => filterService.toggleFavorite(f.id),
                                  child: Icon(
                                    f.isFavorite ? Icons.star : Icons.star_outline,
                                    size: 12,
                                    color: f.isFavorite ? Colors.amber : Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                    return isLocked
                        ? PremiumLockWidget(feature: premiumFeature, child: chip)
                        : chip;
                  },
                ),
              ),
              const Divider(),
              if (current != null) ...[
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _previewImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: RawImage(image: _previewImage, fit: BoxFit.contain),
                                  )
                                : const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (current.kind == FilterKind.gaussianBlur ||
                            current.kind == FilterKind.lensBlur)
                          _paramSlider(
                            filterService,
                            l10n.filterStrengthBlurRadius,
                            current.strength,
                            1,
                            20,
                            (v) => filterService.updateFilterParams(current.id, strength: v),
                          ),
                        if (current.kind == FilterKind.animeStyle) ...[
                          _paramSlider(
                            filterService,
                            l10n.filterColorLevels,
                            current.colorLevels.toDouble(),
                            2,
                            32,
                            (v) => filterService.updateFilterParams(current.id, colorLevels: v.round()),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterEdgeStrength,
                            current.edgeStrength,
                            0,
                            1,
                            (v) => filterService.updateFilterParams(current.id, edgeStrength: v),
                            decimals: 2,
                          ),
                        ],
                        if (current.kind == FilterKind.outline) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(l10n.filterOutlineColor, style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _pickOutlineColor(filterService, current),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(current.outlineColor),
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterOutlineWidth,
                            current.outlineWidth,
                            1,
                            60,
                            (v) => filterService.updateFilterParams(current.id, outlineWidth: v),
                          ),
                        ],
                        if (current.kind == FilterKind.toneCurve)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: ToneCurvePreset.values.map((p) => ChoiceChip(
                                label: Text(_toneCurveLabel(l10n, p), style: const TextStyle(fontSize: 10)),
                                selected: current.toneCurvePreset == p,
                                onSelected: (selected) {
                                  if (!selected) return;
                                  filterService.updateFilterParams(current.id, toneCurvePreset: p);
                                  _updatePreview();
                                },
                              )).toList(),
                            ),
                          ),
                        if (current.kind == FilterKind.levels) ...[
                          _levelSlider(filterService, current, l10n.filterLevelsInputBlack, current.inputBlack,
                              (v) => filterService.updateFilterParams(current.id, inputBlack: v)),
                          _levelSlider(filterService, current, l10n.filterLevelsInputWhite, current.inputWhite,
                              (v) => filterService.updateFilterParams(current.id, inputWhite: v)),
                          _levelSlider(filterService, current, l10n.filterLevelsOutputBlack, current.outputBlack,
                              (v) => filterService.updateFilterParams(current.id, outputBlack: v)),
                          _levelSlider(filterService, current, l10n.filterLevelsOutputWhite, current.outputWhite,
                              (v) => filterService.updateFilterParams(current.id, outputWhite: v)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: (widget.layerId == null || _applying) ? null : _applyFilter,
                  icon: _applying
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 16),
                  label: Text(bulk != null ? l10n.filterApplyBulkButton(bulk.length) : l10n.filterApplyButton),
                ),
              ] else
                Expanded(child: Center(child: Text(l10n.filterEmpty))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelSlider(FilterService service, FilterDef current, String label, int value,
      ValueChanged<int> onChanged) {
    return _paramSlider(
      service,
      label,
      value.toDouble(),
      0,
      255,
      (v) { onChanged(v.round()); _updatePreview(); },
    );
  }

  /// 縁取り色の選択：アプリ標準のColorPickerPanel（HSV/RGB/HEX）を
  /// ダイアログ上に載せて表示する（仕様書20のカラーピッカーをそのまま流用）。
  void _pickOutlineColor(FilterService filterService, FilterDef current) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ColorPickerPanel(
          currentColor: Color(current.outlineColor),
          onColorChanged: (c) {
            filterService.updateFilterParams(current.id, outlineColor: c.toARGB32());
            _updatePreview();
          },
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  String _toneCurveLabel(AppLocalizations l10n, ToneCurvePreset preset) => switch (preset) {
        ToneCurvePreset.linear => l10n.filterToneCurveLinear,
        ToneCurvePreset.brighten => l10n.filterToneCurveBrighten,
        ToneCurvePreset.darken => l10n.filterToneCurveDarken,
        ToneCurvePreset.highContrast => l10n.filterToneCurveHighContrast,
        ToneCurvePreset.lowContrast => l10n.filterToneCurveLowContrast,
        ToneCurvePreset.invert => l10n.filterToneCurveInvert,
      };

  Widget _paramSlider(FilterService service, String label, double value, double min, double max,
      ValueChanged<double> onChanged, {int decimals = 0}) {
    final valueLabel = decimals > 0 ? value.toStringAsFixed(decimals) : value.round().toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $valueLabel', style: const TextStyle(fontSize: 11)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: (v) {
                onChanged(v);
                _updatePreview();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// [FilterDef]の種別・パラメータに応じてFilterEngineの各メソッドへ振り分ける
  /// （プレビュー・実適用の共通エントリーポイント）。
  Uint8List _runFilter(FilterDef filter, Uint8List data, int width, int height) {
    switch (filter.kind) {
      case FilterKind.gaussianBlur:
        return _engine.applyGaussianBlur(data, width, height, filter.strength);
      case FilterKind.lensBlur:
        return _engine.applyLensBlur(data, width, height, filter.strength);
      case FilterKind.animeStyle:
        return _engine.applyAnimeStyle(
          data,
          width,
          height,
          strength: filter.strength,
          colorCount: filter.colorLevels,
          edgeStrength: filter.edgeStrength,
        );
      case FilterKind.outline:
        return _engine.applyOutline(
          data,
          width,
          height,
          color: filter.outlineColor,
          widthPx: filter.outlineWidth,
        );
      case FilterKind.toneCurve:
        return _engine.applyToneCurve(data, width, height, toneCurvePoints(filter.toneCurvePreset));
      case FilterKind.levels:
        return _engine.applyLevels(
          data, width, height,
          inputBlack: filter.inputBlack,
          inputWhite: filter.inputWhite,
          outputBlack: filter.outputBlack,
          outputWhite: filter.outputWhite,
        );
    }
  }

  IconData _iconFor(FilterKind kind) {
    switch (kind) {
      case FilterKind.gaussianBlur:
        return Icons.blur_on;
      case FilterKind.lensBlur:
        return Icons.blur_circular;
      case FilterKind.animeStyle:
        return Icons.auto_awesome;
      case FilterKind.outline:
        return Icons.border_outer;
      case FilterKind.toneCurve:
        return Icons.show_chart;
      case FilterKind.levels:
        return Icons.bar_chart;
    }
  }

  /// プレミアム限定フィルターの対応PremiumFeatureを返す（対象外ならnull）。
  PremiumFeature? _premiumFeatureFor(FilterKind kind) {
    switch (kind) {
      case FilterKind.toneCurve:
        return PremiumFeature.toneCurve;
      case FilterKind.levels:
        return PremiumFeature.levelAdjustment;
      default:
        return null;
    }
  }

  Future<void> _applyFilter() async {
    final layerId = widget.layerId;
    final filter = context.read<FilterService>().currentFilter;
    if (layerId == null || filter == null) return;
    setState(() => _applying = true);

    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(widget.projectId);
    final bulk = widget.bulkFrameIndices;

    if (bulk != null && bulk.length > 1) {
      await _applyBulk(ps, tm, layerId, filter, bulk);
    } else {
      await _applyToFrame(ps, tm, layerId, filter, widget.frameIndex);
    }

    if (!mounted) return;
    setState(() => _applying = false);
    widget.onClose();
  }

  Future<void> _applyToFrame(
    ProjectService ps,
    TileManager tm,
    String layerId,
    FilterDef filter,
    int frameIndex,
  ) async {
    final key = ps.tileKeyFor(widget.projectId, widget.sceneId, frameIndex, layerId);
    final img = await tm.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null) return;
    final data = byteData.buffer.asUint8List();
    // 低スペック端末でのUIスレッドブロックを避けるため、本適用（フル解像度）は
    // バックグラウンドisolateで実行する。プレビュー（縮小画像）は_runFilterのまま
    // メインisolateで即時処理する（isolate起動コストの方が高くつくため）。
    final result =
        await compute(applyDrawFilterInIsolate, (data, tm.canvasWidth, tm.canvasHeight, filter));
    tm.replaceLayerPixels(key, result);

    // TileManager書き込み後にupdateLayer()を呼び直し、キャンバス側の合成表示を
    // 最新化する（画像読み込み・自動塗り適用と同じ手順）。
    final layer = ps
        .layersOf(widget.projectId, widget.sceneId, frameIndex)
        .where((l) => l.id == layerId)
        .firstOrNull;
    if (layer != null) {
      ps.updateLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: frameIndex,
        layer: layer,
      );
    }
  }

  /// 大量処理実行時（仕様書18）：選択した全フレームへ順に適用し、
  /// ProgressDialog（正方形広告付き）で進捗を表示する。
  Future<void> _applyBulk(
    ProjectService ps,
    TileManager tm,
    String layerId,
    FilterDef filter,
    Set<int> frames,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final sorted = frames.toList()..sort();
    double progress = 0;
    void Function(void Function())? setDialogState;

    if (!mounted) return;
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          setDialogState = setS;
          return ProgressDialog(
            title: l10n.filterApplyingTitle,
            progress: progress,
            subtitle: l10n.filterApplyingSubtitle(filter.name, sorted.length),
          );
        },
      ),
    ));
    // ダイアログのbuilderが最初に走るまで1フレーム待つ
    await Future.delayed(const Duration(milliseconds: 16));

    for (int i = 0; i < sorted.length; i++) {
      await _applyToFrame(ps, tm, layerId, filter, sorted[i]);
      progress = (i + 1) / sorted.length;
      setDialogState?.call(() {});
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
