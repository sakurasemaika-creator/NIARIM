import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../engine/filter_engine.dart';
import '../../../engine/tile_manager.dart';
import '../../../models/filter_def.dart';
import '../../../services/filter_service.dart';
import '../../../services/project_service.dart';
import '../../../widgets/progress_dialog.dart';

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
    final key = frameLayerKey(widget.sceneId, widget.frameIndex, layerId);
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
                    bulk != null ? 'フィルター（${bulk.length}フレームへ一括適用）' : 'フィルター',
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
                    tooltip: 'お気に入りのみ表示',
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
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'フィルター検索',
                      prefixIcon: Icon(Icons.search, size: 16),
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
                    return GestureDetector(
                      onTap: () => filterService.selectFilter(f.id),
                      child: Container(
                        width: 72,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey[600]!,
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
                            '強さ（ぼかし半径）',
                            current.strength,
                            1,
                            20,
                            (v) => filterService.updateFilterParams(current.id, strength: v),
                          ),
                        if (current.kind == FilterKind.animeStyle) ...[
                          _paramSlider(
                            filterService,
                            '色数',
                            current.colorLevels.toDouble(),
                            2,
                            32,
                            (v) => filterService.updateFilterParams(current.id, colorLevels: v.round()),
                          ),
                          _paramSlider(
                            filterService,
                            'エッジ強調',
                            current.edgeStrength,
                            0,
                            1,
                            (v) => filterService.updateFilterParams(current.id, edgeStrength: v),
                            decimals: 2,
                          ),
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
                  label: Text(bulk != null ? '${bulk.length}フレームへ適用' : '適用'),
                ),
              ] else
                const Expanded(child: Center(child: Text('フィルターがありません'))),
            ],
          ),
        ),
      ),
    );
  }

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
    final key = frameLayerKey(widget.sceneId, frameIndex, layerId);
    final img = await tm.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null) return;
    final data = byteData.buffer.asUint8List();
    final result = _runFilter(filter, data, tm.canvasWidth, tm.canvasHeight);
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
            title: 'フィルター適用中',
            progress: progress,
            subtitle: '${filter.name}　${sorted.length}フレーム',
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
