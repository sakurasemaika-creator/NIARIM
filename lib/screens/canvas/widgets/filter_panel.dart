import 'package:niarim/services/theme_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../engine/filter_engine.dart';
import '../../../engine/background_acclimation_engine.dart';
import '../../../engine/layer_compositor.dart';
import '../../../engine/tile_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/filter_def.dart';
import '../../../models/layer.dart' as model;
import '../../../services/filter_service.dart';
import '../../../services/premium_service.dart';
import '../../../services/project_service.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/pixel_color_mode_selector.dart';
import '../../../widgets/premium_lock_widget.dart';
import '../../../widgets/progress_dialog.dart';
import '../../../widgets/stepped_slider.dart';
import 'color_picker_panel.dart';
import 'panel_close_bar.dart';
import '../../../config/font_fallback.dart';

enum FilterColorEyedropperTarget { inkPool, outline }

/// 描画フィルターパネル。
/// フィルターの選択・パラメータ調整・プレビュー・適用を行う。
/// [bulkFrameIndices]が指定された場合は「大量処理」として、指定した全フレームの
/// 同一レイヤーへフィルターを一括適用し、進捗をProgressDialog（正方形広告付き）
/// で表示する（大量処理実行時の広告表示）。
class FilterPanel extends StatefulWidget {
  final String projectId;
  final String sceneId;
  final String? layerId;
  final int frameIndex;
  final Set<int>? bulkFrameIndices;
  final VoidCallback onClose;
  final ValueChanged<FilterColorEyedropperTarget>? onStartCanvasEyedropper;
  final FilterColorEyedropperTarget? activeCanvasEyedropperTarget;

  const FilterPanel({
    super.key,
    required this.projectId,
    required this.sceneId,
    required this.layerId,
    required this.frameIndex,
    this.bulkFrameIndices,
    required this.onClose,
    this.onStartCanvasEyedropper,
    this.activeCanvasEyedropperTarget,
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
  double _previewScale = 1;
  ui.Image? _previewImage;
  String? _previewFilterId;
  // 眼鏡断層フィルター（lensDistortion）専用：選択レイヤー
  // （LayerType.selection）を単体合成しプレビュー解像度へ縮小したもの。
  // 選択レイヤーが存在しない場合はnull（=対象範囲なし、フィルター無効）。
  Uint8List? _previewMask;
  // 背景馴染ませフィルター（backgroundBlend、Task#162）専用：選択レイヤー
  // 以外の全ての表示中レイヤーをプレビュー解像度へ合成したもの。
  // FilterEngine.mostFrequentOpaqueColorへ渡し、自動検出した馴染ませ色を
  // _autoBlendColorArgbへ保持する（ユーザーがカラーチップで手動指定
  // していない間、プレビュー・本適用の両方でこの色を使う）。
  int? _autoBlendColorArgb;
  Uint8List? _previewBackgroundBytes;
  BackgroundAcclimationAnalysis? _lastBgBlendAnalysis;

  Widget _canvasEyedropperButton(
    BuildContext context,
    FilterColorEyedropperTarget target,
  ) {
    final active = widget.activeCanvasEyedropperTarget == target;
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(Icons.colorize, size: 18),
      tooltip: l10n.filterCanvasEyedropperTooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        foregroundColor: active
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : null,
      ),
      onPressed: () => widget.onStartCanvasEyedropper?.call(target),
    );
  }

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

  /// [img]（[w]×[h]）を[pw]×[ph]へ縮小し、rawRgbaのバイト列を返す
  /// （プレビュー用の対象レイヤー・選択レイヤーマスクの縮小で共通利用）。
  /// [img]は呼び出し側の責任でdispose済みとして扱ってよい状態で渡すこと
  /// （このメソッド内でdisposeする）。
  Future<Uint8List?> _downscaleToBytes(
    ui.Image img,
    int w,
    int h,
    int pw,
    int ph,
  ) async {
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
    return byteData?.buffer.asUint8List();
  }

  Future<void> _loadPreviewBase() async {
    final layerId = widget.layerId;
    if (layerId == null) return;
    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(widget.projectId);
    final w = tm.canvasWidth;
    final h = tm.canvasHeight;
    if (w <= 0 || h <= 0) return;
    final key = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
      layerId,
    );
    final img = await tm.compositeLayerToImage(key);

    const maxSize = 150;
    final scale = maxSize / math.max(w, h);
    final pw = (w * scale).round().clamp(1, maxSize);
    final ph = (h * scale).round().clamp(1, maxSize);

    final bytes = await _downscaleToBytes(img, w, h, pw, ph);
    if (!mounted) return;

    // 眼鏡断層フィルター用：選択レイヤー（LayerType.selection）があれば
    // 同じ解像度へ縮小してマスクとして保持する（無ければnullのまま、
    // applyLensDistortion側で「対象範囲なし」として無効化される）。
    final selectionLayer = ps
        .layersOf(widget.projectId, widget.sceneId, widget.frameIndex)
        .where((l) => l.type == model.LayerType.selection)
        .firstOrNull;
    Uint8List? maskBytes;
    if (selectionLayer != null) {
      final maskKey = ps.tileKeyFor(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
        selectionLayer.id,
      );
      final maskImg = await tm.compositeLayerToImage(maskKey);
      maskBytes = await _downscaleToBytes(maskImg, w, h, pw, ph);
      if (!mounted) return;
    }

    // 背景馴染ませフィルター用：選択レイヤー以外の全ての表示中レイヤーを
    // プレビュー解像度へ合成し、最頻色を自動検出しておく（選択・眼鏡断層
    // フィルターのマスクと同じく、選択中のフィルター種別によらず常に
    // 読み込んでおく方式に揃えている）。レイヤー一覧自体は絞り込まず
    // shouldRenderで選択レイヤーだけ描画をスキップする方式にし、他レイヤーの
    // クリッピング元として選択レイヤーが参照され続けられるようにする
    // （LayerCompositor.compositeのドキュメントコメント参照）。
    final allLayers = ps.layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final otherImg = await LayerCompositor.composite(
      tm,
      allLayers,
      (l) => ps.tileKeyFor(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
        l.id,
      ),
      w,
      h,
      shouldRender: (l, i) => l.id != layerId,
    );
    final otherBytes = await _downscaleToBytes(otherImg, w, h, pw, ph);
    if (!mounted) return;

    if (bytes == null || !mounted) return;
    _previewScale = scale;
    _previewMask = maskBytes;
    _previewBase = bytes;
    _previewW = pw;
    _previewH = ph;
    _previewBackgroundBytes = otherBytes;
    _autoBlendColorArgb = otherBytes == null
        ? null
        : FilterEngine.mostFrequentOpaqueColor(otherBytes);
    await _updatePreview();
  }

  Future<void> _updatePreview() async {
    final base = _previewBase;
    final filter = context.read<FilterService>().currentFilter;
    if (base == null || filter == null || !mounted) return;
    final filtered = _runFilter(filter, base, _previewW, _previewH);
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      filtered,
      _previewW,
      _previewH,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
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
    // フィルター名は多言語対応のためl10n側で保持し（_filterDisplayName）、
    // 検索・お気に入り絞込もその表示名に対して行う（FilterServiceは
    // ChangeNotifierでBuildContext/l10nを持たないため、ローカライズが
    // 絡む絞込はUI層で行う）。
    final query = filterService.searchQuery;
    final filters = filterService.filters.where((f) {
      if (_showFavoritesOnly && !f.isFavorite) return false;
      if (query.isEmpty) return true;
      return _filterDisplayName(l10n, f).contains(query);
    }).toList();
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
              PanelCenterCloseBar(onClose: widget.onClose),
              Row(
                children: [
                  Text(
                    bulk != null
                        ? l10n.filterPanelTitleBulk(bulk.length)
                        : l10n.filterPanelTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(
                      _showFavoritesOnly ? Icons.star : Icons.star_outline,
                      size: 16,
                      color: _showFavoritesOnly
                          ? ThemeService.activeColorScheme.tertiary
                          : null,
                    ),
                    onPressed: () => setState(
                      () => _showFavoritesOnly = !_showFavoritesOnly,
                    ),
                    tooltip: l10n.creativePanelFavoritesOnlyTooltip,
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, size: 16),
                    tooltip: l10n.commonSearch,
                    onPressed: () => setState(() => _showSearch = !_showSearch),
                  ),
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
              // 検索・お気に入り絞込中は表示順とFilterService内の実際の並び順が
              // 一致しないため、並べ替え（ドラッグハンドル）は絞込なしの
              // ときだけ有効にする（並び替え結果の意味が曖昧にならないように）。
              Builder(
                builder: (context) {
                  final reorderable = query.isEmpty && !_showFavoritesOnly;
                  Widget buildChip(int index) {
                    final f = filters[index];
                    final isSelected = f.id == current?.id;
                    final premiumFeature = _premiumFeatureFor(f.kind);
                    final isLocked =
                        premiumFeature != null &&
                        !context.watch<PremiumService>().isFeatureAvailable(
                          premiumFeature,
                        );
                    final chip = GestureDetector(
                      onTap: isLocked
                          ? null
                          : () => filterService.selectFilter(f.id),
                      child: Container(
                        width: 72,
                        margin: EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : ThemeService
                                      .activeColorScheme
                                      .onSurfaceVariant,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color:
                              ThemeService.activeColorScheme.onSurfaceVariant,
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_iconFor(f.kind), size: 22),
                                  const SizedBox(height: 2),
                                  Text(
                                    _filterDisplayName(l10n, f),
                                    style: const TextStyle(fontSize: 9),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                            if (!isLocked)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () =>
                                      filterService.toggleFavorite(f.id),
                                  child: Icon(
                                    f.isFavorite
                                        ? Icons.star
                                        : Icons.star_outline,
                                    size: 12,
                                    color: f.isFavorite
                                        ? ThemeService
                                              .activeColorScheme
                                              .tertiary
                                        : ThemeService
                                              .activeColorScheme
                                              .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            // プリインストールではない（色調調整等から新規追加した）
                            // フィルターにのみ、削除・複製の三点メニューを出す。
                            // お気に入りアイコンと重ならないよう左上に配置する。
                            if (!isLocked && !filterService.isBuiltIn(f.id))
                              Positioned(
                                top: 0,
                                left: 0,
                                child: GestureDetector(
                                  onTap: () => _showCustomFilterMenu(
                                    context,
                                    filterService,
                                    f,
                                  ),
                                  child: Icon(
                                    Icons.more_vert,
                                    size: 14,
                                    color: ThemeService
                                        .activeColorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            // ドラッグハンドル：フィルターの表示順を自由に入れ替えられる
                            // （並び順はFilterService経由でSharedPreferencesへ永続化され、
                            // アプリ内共通・プロジェクトをまたいで共有される）。
                            if (reorderable)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: ReorderableDragStartListener(
                                    index: index,
                                    child: Icon(
                                      Icons.drag_indicator,
                                      size: 12,
                                      color: ThemeService
                                          .activeColorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                    return isLocked
                        ? PremiumLockWidget(
                            feature: premiumFeature,
                            child: chip,
                          )
                        : chip;
                  }

                  return SizedBox(
                    height: 90,
                    child: reorderable
                        ? ReorderableListView.builder(
                            scrollDirection: Axis.horizontal,
                            buildDefaultDragHandles: false,
                            itemCount: filters.length,
                            itemBuilder: (context, index) => KeyedSubtree(
                              key: ValueKey(filters[index].id),
                              child: buildChip(index),
                            ),
                            // onReorderItemはnewIndexを「削除後の位置」へ調整済みで
                            // 渡すため、従来の `newIndex -= 1` 補正は不要。
                            // reorderFilter側は挿入先indexをそのまま使う実装
                            // （内部で補正しない）ので、この呼び方で整合する。
                            onReorderItem: (oldIndex, newIndex) {
                              filterService.reorderFilter(
                                filters[oldIndex].id,
                                newIndex,
                              );
                            },
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: filters.length,
                            itemBuilder: (context, index) => buildChip(index),
                          ),
                  );
                },
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
                              color: ThemeService
                                  .activeColorScheme
                                  .onSurfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: _previewImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: RawImage(
                                      image: _previewImage,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
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
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                        if (current.kind == FilterKind.pixelate) ...[
                          _paramSlider(
                            filterService,
                            l10n.filterPixelateBlockSize,
                            current.strength,
                            1,
                            64,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                          PixelColorModeSelector(
                            mode: current.pixelColorMode,
                            colorLevels: current.colorLevels,
                            explicitColors: current.pixelExplicitColors,
                            onModeChanged: (m) {
                              filterService.updateFilterParams(
                                current.id,
                                pixelColorMode: m,
                              );
                              _updatePreview();
                            },
                            onColorLevelsChanged: (v) {
                              filterService.updateFilterParams(
                                current.id,
                                colorLevels: v,
                              );
                              _updatePreview();
                            },
                            onExplicitColorsChanged: (c) {
                              filterService.updateFilterParams(
                                current.id,
                                pixelExplicitColors: c,
                              );
                              _updatePreview();
                            },
                          ),
                        ],
                        if (current.kind == FilterKind.auroraHologram) ...[
                          _paramSlider(
                            filterService,
                            l10n.filterAuroraHologramStrength,
                            current.strength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterAuroraHologramBrightness,
                            current.hologramBrightness,
                            -100,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              hologramBrightness: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterAuroraHologramSaturation,
                            current.hologramSaturation,
                            -100,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              hologramSaturation: v,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: AuroraHologramPreset.values
                                  .map(
                                    (p) => ChoiceChip(
                                      label: Text(
                                        _auroraHologramPresetLabel(l10n, p),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      selected: current.hologramPreset == p,
                                      onSelected: (selected) {
                                        if (!selected) return;
                                        filterService.updateFilterParams(
                                          current.id,
                                          hologramPreset: p,
                                        );
                                        _updatePreview();
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                        if (current.kind == FilterKind.animeStyle) ...[
                          _paramSlider(
                            filterService,
                            l10n.filterColorLevels,
                            current.colorLevels.toDouble(),
                            2,
                            32,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              colorLevels: v.round(),
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterEdgeStrength,
                            current.edgeStrength,
                            0,
                            1,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              edgeStrength: v,
                            ),
                            decimals: 2,
                          ),
                        ],
                        if (current.kind == FilterKind.inkPool) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  l10n.filterInkPoolColor,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () =>
                                      _pickInkPoolColor(filterService, current),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(current.inkPoolColor),
                                      border: Border.all(
                                        color: ThemeService
                                            .activeColorScheme
                                            .onSurfaceVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                _canvasEyedropperButton(
                                  context,
                                  FilterColorEyedropperTarget.inkPool,
                                ),
                              ],
                            ),
                          ),
                          _integerStepperSlider(
                            l10n.filterInkPoolRange,
                            current.inkPoolRange.round(),
                            1,
                            80,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              inkPoolRange: v.toDouble(),
                            ),
                          ),
                          _integerStepperSlider(
                            l10n.filterInkPoolCenterWidth,
                            current.inkPoolCenterWidth.round(),
                            1,
                            60,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              inkPoolCenterWidth: v.toDouble(),
                            ),
                          ),
                        ],
                        if (current.kind == FilterKind.outline) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  l10n.filterOutlineColor,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () =>
                                      _pickOutlineColor(filterService, current),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(current.outlineColor),
                                      border: Border.all(
                                        color: ThemeService
                                            .activeColorScheme
                                            .onSurfaceVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                _canvasEyedropperButton(
                                  context,
                                  FilterColorEyedropperTarget.outline,
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
                            (v) => filterService.updateFilterParams(
                              current.id,
                              outlineWidth: v,
                            ),
                          ),
                        ],
                        if (current.kind == FilterKind.toneCurve)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: ToneCurvePreset.values
                                  .map(
                                    (p) => ChoiceChip(
                                      label: Text(
                                        _toneCurveLabel(l10n, p),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      selected: current.toneCurvePreset == p,
                                      onSelected: (selected) {
                                        if (!selected) return;
                                        filterService.updateFilterParams(
                                          current.id,
                                          toneCurvePreset: p,
                                        );
                                        _updatePreview();
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        if (current.kind == FilterKind.levels) ...[
                          _levelSlider(
                            filterService,
                            current,
                            l10n.filterLevelsInputBlack,
                            current.inputBlack,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              inputBlack: v,
                            ),
                          ),
                          _levelSlider(
                            filterService,
                            current,
                            l10n.filterLevelsInputWhite,
                            current.inputWhite,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              inputWhite: v,
                            ),
                          ),
                          _levelSlider(
                            filterService,
                            current,
                            l10n.filterLevelsOutputBlack,
                            current.outputBlack,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              outputBlack: v,
                            ),
                          ),
                          _levelSlider(
                            filterService,
                            current,
                            l10n.filterLevelsOutputWhite,
                            current.outputWhite,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              outputWhite: v,
                            ),
                          ),
                        ],
                        if (current.kind == FilterKind.sharpen)
                          _paramSlider(
                            filterService,
                            l10n.filterSharpenStrength,
                            current.strength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                        if (current.kind == FilterKind.vignette) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  l10n.filterVignetteColor,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _pickVignetteColor(
                                    filterService,
                                    current,
                                  ),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(current.vignetteColor),
                                      border: Border.all(
                                        color: ThemeService
                                            .activeColorScheme
                                            .onSurfaceVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterVignetteStrength,
                            current.strength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                        ],
                        if (current.kind == FilterKind.noise)
                          _paramSlider(
                            filterService,
                            l10n.filterNoiseStrength,
                            current.strength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                        if (current.kind == FilterKind.retroAnime ||
                            current.kind == FilterKind.crt)
                          _paramSlider(
                            filterService,
                            l10n.filterRetroStrength,
                            current.strength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                        if (current.kind == FilterKind.fisheye)
                          _paramSlider(
                            filterService,
                            l10n.filterFisheyeStrength,
                            current.strength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                        if (current.kind == FilterKind.chromaticAberration)
                          _paramSlider(
                            filterService,
                            l10n.filterChromaticAberrationStrength,
                            current.strength,
                            1,
                            30,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                        if (current.kind == FilterKind.lensDistortion) ...[
                          // 選択レイヤーが無い・空の場合はフィルターが無効に
                          // なるため、その旨を案内する（キャンバス上には
                          // テーマの選択色でオーバーレイ表示されている
                          // はずなので、レイヤーパネル参照を促す）。
                          if (_previewMask == null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                l10n.filterLensDistortionNoMaskHint,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          _paramSlider(
                            filterService,
                            l10n.filterLensDistortionStrength,
                            current.strength,
                            -100,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterLensDistortionOffsetX,
                            current.lensCenterOffsetX,
                            -100,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              lensCenterOffsetX: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterLensDistortionOffsetY,
                            current.lensCenterOffsetY,
                            -100,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              lensCenterOffsetY: v,
                            ),
                          ),
                        ],
                        if (current.kind == FilterKind.colorAdjust) ...[
                          _paramSlider(
                            filterService,
                            l10n.filterColorAdjustSaturationLabel,
                            current.caSaturation,
                            -100,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              caSaturation: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterColorAdjustBrightnessLabel,
                            current.caBrightness,
                            -100,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              caBrightness: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterColorAdjustContrastLabel,
                            current.caContrast,
                            -100,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              caContrast: v,
                            ),
                          ),
                        ],
                        if (current.kind == FilterKind.monochrome) ...[
                          _paramSlider(
                            filterService,
                            l10n.filterMonochromeStrength,
                            current.strength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  l10n.filterMonochromeColorLabel,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _pickMonochromeColor(
                                    filterService,
                                    current,
                                  ),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(current.monochromeColor),
                                      border: Border.all(
                                        color: ThemeService
                                            .activeColorScheme
                                            .onSurfaceVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (current.kind == FilterKind.threshold)
                          _paramSlider(
                            filterService,
                            l10n.filterThresholdLabel,
                            current.thresholdValue,
                            0,
                            255,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              thresholdValue: v,
                            ),
                          ),
                        if (current.kind == FilterKind.unsharpMask) ...[
                          _paramSlider(
                            filterService,
                            l10n.filterStrengthBlurRadius,
                            current.strength,
                            1,
                            20,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              strength: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterUnsharpAmount,
                            current.edgeStrength,
                            0,
                            3,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              edgeStrength: v,
                            ),
                            decimals: 2,
                          ),
                        ],
                        if (current.kind == FilterKind.backgroundBlend) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  l10n.filterBackgroundBlendColorLabel,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () =>
                                      _pickBgBlendColor(filterService, current),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(
                                        _resolvedBgBlendColor(current),
                                      ),
                                      border: Border.all(
                                        color: ThemeService
                                            .activeColorScheme
                                            .onSurfaceVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (current.bgBlendColor != -1)
                                  TextButton(
                                    onPressed: () {
                                      filterService.updateFilterParams(
                                        current.id,
                                        bgBlendColor: -1,
                                      );
                                      _updatePreview();
                                    },
                                    child: Text(
                                      l10n.filterBackgroundBlendAutoReset,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: Text(
                                      l10n.filterBackgroundBlendAutoLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterBackgroundBlendDirection,
                            current.bgBlendDirection,
                            0,
                            360,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendDirection: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            l10n.filterBackgroundBlendLength,
                            current.bgBlendLength,
                            1,
                            80,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendLength: v,
                            ),
                          ),
                          _paramSlider(
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
                            title: const Text(
                              '光源方向を自動推定',
                              style: TextStyle(fontSize: 11),
                            ),
                            subtitle: const Text(
                              'OFF時は上の「向き」を手動方向として使用',
                              style: TextStyle(fontSize: 9),
                            ),
                            value: current.bgBlendAutoLight,
                            onChanged: (v) {
                              filterService.updateFilterParams(
                                current.id,
                                bgBlendAutoLight: v,
                              );
                              _updatePreview();
                            },
                          ),
                          _paramSlider(
                            filterService,
                            '馴染み強度',
                            current.bgBlendStrength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendStrength: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            '主光源の強さ',
                            current.bgBlendLightStrength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendLightStrength: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            '影の強さ',
                            current.bgBlendShadowStrength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendShadowStrength: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            '環境光',
                            current.bgBlendAmbientStrength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendAmbientStrength: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            '下方反射光',
                            current.bgBlendReflectionStrength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendReflectionStrength: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            '局所的な色移り',
                            current.bgBlendColorBleed,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendColorBleed: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            '光の柔らかさ',
                            current.bgBlendSoftness,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendSoftness: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            '副光源',
                            current.bgBlendSecondaryStrength,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendSecondaryStrength: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            '素材保護',
                            current.bgBlendMaterialProtection,
                            0,
                            100,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendMaterialProtection: v,
                            ),
                          ),
                          _paramSlider(
                            filterService,
                            '環境サンプリング帯',
                            current.bgBlendSamplingBand,
                            4,
                            120,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendSamplingBand: v,
                            ),
                          ),
                          _bgBlendColorControl(
                            filterService,
                            '主光源色',
                            current.bgBlendLightColor,
                            _lastBgBlendAnalysis?.primaryColor ??
                                _resolvedBgBlendColor(current),
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendLightColor: v,
                            ),
                          ),
                          _bgBlendColorControl(
                            filterService,
                            '環境光色',
                            current.bgBlendAmbientColor,
                            _lastBgBlendAnalysis?.ambientColor ??
                                _resolvedBgBlendColor(current),
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendAmbientColor: v,
                            ),
                          ),
                          _bgBlendColorControl(
                            filterService,
                            '影側の環境色',
                            current.bgBlendShadowColor,
                            _lastBgBlendAnalysis?.shadowColor ?? 0xFF404040,
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendShadowColor: v,
                            ),
                          ),
                          _bgBlendColorControl(
                            filterService,
                            '下方反射色',
                            current.bgBlendReflectionColor,
                            _lastBgBlendAnalysis?.reflectionColor ??
                                _resolvedBgBlendColor(current),
                            (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendReflectionColor: v,
                            ),
                          ),
                          SwitchListTile.adaptive(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              '解析情報を表示',
                              style: TextStyle(fontSize: 11),
                            ),
                            value: current.bgBlendShowAnalysis,
                            onChanged: (v) => filterService.updateFilterParams(
                              current.id,
                              bgBlendShowAnalysis: v,
                            ),
                          ),
                          if (current.bgBlendShowAnalysis)
                            _bgBlendAnalysisCard(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: (widget.layerId == null || _applying)
                      ? null
                      : _applyFilter,
                  icon: _applying
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          // FilledButtonの背景はテーマの差し色（primary）のため、
                          // 白固定ではなくonPrimaryでコントラストを保つ。
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: Text(
                    bulk != null
                        ? l10n.filterApplyBulkButton(bulk.length)
                        : l10n.filterApplyButton,
                  ),
                ),
              ] else
                Expanded(child: Center(child: Text(l10n.filterEmpty))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bgBlendColorControl(
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
                border: Border.all(
                  color: ThemeService.activeColorScheme.onSurfaceVariant,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: value == -1
                ? null
                : () {
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
        border: Border.all(
          color: ThemeService.activeColorScheme.onSurfaceVariant,
        ),
      ),
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(
          color: ThemeService.activeColorScheme.outlineVariant,
        ),
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
          Row(
            children: [
              dot(a.primaryColor),
              const Text('光 ', style: TextStyle(fontSize: 9)),
              dot(a.ambientColor),
              const Text('環境 ', style: TextStyle(fontSize: 9)),
              dot(a.shadowColor),
              const Text('影 ', style: TextStyle(fontSize: 9)),
              dot(a.reflectionColor),
              const Text('反射', style: TextStyle(fontSize: 9)),
            ],
          ),
          if (a.secondaryLights.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Text('副光源 ', style: TextStyle(fontSize: 9)),
                ...a.secondaryLights.map((l) => dot(l.color)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _levelSlider(
    FilterService service,
    FilterDef current,
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return _paramSlider(service, label, value.toDouble(), 0, 255, (v) {
      onChanged(v.round());
      _updatePreview();
    });
  }

  /// 縁取り色の選択：アプリ標準のColorPickerPanel（HSV/RGB/HEX）を
  /// ダイアログ上に載せて表示する（カラーピッカーをそのまま流用）。
  void _pickOutlineColor(FilterService filterService, FilterDef current) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ColorPickerPanel(
          currentColor: Color(current.outlineColor),
          onColorChanged: (c) {
            filterService.updateFilterParams(
              current.id,
              outlineColor: c.toARGB32(),
            );
            _updatePreview();
          },
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _pickInkPoolColor(FilterService filterService, FilterDef current) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ColorPickerPanel(
          currentColor: Color(current.inkPoolColor),
          onColorChanged: (c) {
            filterService.updateFilterParams(
              current.id,
              inkPoolColor: c.toARGB32(),
            );
            _updatePreview();
          },
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  /// 周辺減光の減光先の色を選ぶ（縁取り色と同じくアプリ標準の
  /// ColorPickerPanelを流用。黒以外を選べば、暗くする代わりに指定色を
  /// 周辺へかぶせる演出にできる）。
  void _pickVignetteColor(FilterService filterService, FilterDef current) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ColorPickerPanel(
          currentColor: Color(current.vignetteColor),
          onColorChanged: (c) {
            filterService.updateFilterParams(
              current.id,
              vignetteColor: c.toARGB32(),
            );
            _updatePreview();
          },
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  /// 単色化の色を選ぶ（縁取り・周辺減光と同じくアプリ標準のColorPickerPanel
  /// を流用。既定は白＝通常のグレースケール、色を変えるとセピア調など
  /// 任意の単色トーンにできる）。
  void _pickMonochromeColor(FilterService filterService, FilterDef current) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ColorPickerPanel(
          currentColor: Color(current.monochromeColor),
          onColorChanged: (c) {
            filterService.updateFilterParams(
              current.id,
              monochromeColor: c.toARGB32(),
            );
            _updatePreview();
          },
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  /// 背景馴染ませの馴染ませ色を選ぶ（縁取り・周辺減光・単色化と同じく
  /// アプリ標準のColorPickerPanelを流用）。表示中の色は自動検出中なら
  /// その検出結果、既に手動指定済みならその色（_resolvedBgBlendColor）。
  /// ここでピッカーから色を選ぶと自動検出をやめてその色に固定される
  /// （-1以外の具体的なARGB値がbgBlendColorへ入る）。
  void _pickBgBlendColor(FilterService filterService, FilterDef current) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ColorPickerPanel(
          currentColor: Color(_resolvedBgBlendColor(current)),
          onColorChanged: (c) {
            filterService.updateFilterParams(
              current.id,
              bgBlendColor: c.toARGB32(),
            );
            _updatePreview();
          },
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  /// プリインストールではないフィルターの三点メニュー（複製・削除）。
  /// お気に入り登録中は削除できないため、その旨のポップアップを出す。
  void _showCustomFilterMenu(
    BuildContext context,
    FilterService filterService,
    FilterDef f,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.filterCustomMenuDuplicate),
              onTap: () {
                filterService.duplicateFilter(f.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: ThemeService.activeColorScheme.error,
              ),
              title: Text(l10n.commonDelete),
              onTap: () {
                Navigator.pop(ctx);
                if (f.isFavorite) {
                  showDialog(
                    context: context,
                    builder: (ctx2) => AlertDialog(
                      title: Text(l10n.filterCustomMenuFavoriteBlockTitle),
                      content: Text(l10n.filterCustomMenuFavoriteBlockBody),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx2),
                          child: Text(l10n.commonOk),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                filterService.removeFilter(f.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _toneCurveLabel(AppLocalizations l10n, ToneCurvePreset preset) =>
      switch (preset) {
        ToneCurvePreset.linear => l10n.filterToneCurveLinear,
        ToneCurvePreset.brighten => l10n.filterToneCurveBrighten,
        ToneCurvePreset.darken => l10n.filterToneCurveDarken,
        ToneCurvePreset.highContrast => l10n.filterToneCurveHighContrast,
        ToneCurvePreset.lowContrast => l10n.filterToneCurveLowContrast,
        ToneCurvePreset.invert => l10n.filterToneCurveInvert,
      };

  String _auroraHologramPresetLabel(
    AppLocalizations l10n,
    AuroraHologramPreset p,
  ) => switch (p) {
    AuroraHologramPreset.aurora => l10n.filterAuroraHologramPresetAurora,
    AuroraHologramPreset.soapBubble =>
      l10n.filterAuroraHologramPresetSoapBubble,
    AuroraHologramPreset.cyberNeon => l10n.filterAuroraHologramPresetCyberNeon,
    AuroraHologramPreset.pastelDream =>
      l10n.filterAuroraHologramPresetPastelDream,
    AuroraHologramPreset.sunsetGold =>
      l10n.filterAuroraHologramPresetSunsetGold,
    AuroraHologramPreset.silverFoil =>
      l10n.filterAuroraHologramPresetSilverFoil,
  };

  Widget _paramSlider(
    FilterService service,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int decimals = 0,
  }) {
    final valueLabel = decimals > 0
        ? value.toStringAsFixed(decimals)
        : value.round().toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditableSliderValue(
            text: '$label: $valueLabel',
            style: const TextStyle(fontSize: 11),
            value: value,
            min: min,
            max: max,
            isInt: decimals == 0,
            onChanged: (v) {
              onChanged(v.toDouble());
              _updatePreview();
            },
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: SteppedSlider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              step: decimals > 0 ? 0.1 : 1,
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

  /// フィルターの表示名を多言語対応で返す（初期実装フィルターは
  /// 種別ごとに1つずつの固定セットで、ユーザーが新規フィルターを追加できる
  /// UIは無いため、kindから一意に決まる）。永続化される[FilterDef.name]
  /// 自体は内部識別用の日本語文字列のまま残し、表示のみここで差し替える。
  String _filterDisplayName(AppLocalizations l10n, FilterDef f) =>
      switch (f.kind) {
        FilterKind.gaussianBlur => l10n.filterNameGaussianBlur,
        FilterKind.lensBlur => l10n.filterNameLensBlur,
        FilterKind.animeStyle => l10n.filterNameAnimeStyle,
        FilterKind.outline => l10n.filterNameOutline,
        FilterKind.toneCurve => l10n.filterNameToneCurve,
        FilterKind.levels => l10n.filterNameLevels,
        FilterKind.sharpen => l10n.filterNameSharpen,
        FilterKind.unsharpMask => l10n.filterNameUnsharpMask,
        FilterKind.vignette => l10n.filterNameVignette,
        FilterKind.noise => l10n.filterNameNoise,
        FilterKind.retroAnime => l10n.filterNameRetroAnime,
        FilterKind.crt => l10n.filterNameCrt,
        FilterKind.monochrome => l10n.filterNameMonochrome,
        FilterKind.colorAdjust => l10n.filterNameColorAdjust,
        FilterKind.threshold => l10n.filterNameThreshold,
        FilterKind.fisheye => l10n.filterNameFisheye,
        FilterKind.chromaticAberration => l10n.filterNameChromaticAberration,
        FilterKind.lensDistortion => l10n.filterNameLensDistortion,
        FilterKind.pixelate => l10n.filterNamePixelate,
        FilterKind.auroraHologram => l10n.filterNameAuroraHologram,
        FilterKind.backgroundBlend => l10n.filterNameBackgroundBlend,
        FilterKind.inkPool => l10n.filterNameInkPool,
      };

  /// [FilterDef]の種別・パラメータに応じてFilterEngineの各メソッドへ振り分ける
  /// （プレビュー・実適用の共通エントリーポイント）。
  Uint8List _runFilter(
    FilterDef filter,
    Uint8List data,
    int width,
    int height,
  ) {
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
        return _engine.applyToneCurve(
          data,
          width,
          height,
          toneCurvePoints(filter.toneCurvePreset),
        );
      case FilterKind.levels:
        return _engine.applyLevels(
          data,
          width,
          height,
          inputBlack: filter.inputBlack,
          inputWhite: filter.inputWhite,
          outputBlack: filter.outputBlack,
          outputWhite: filter.outputWhite,
        );
      case FilterKind.sharpen:
        return _engine.applySharpen(data, width, height, filter.strength);
      case FilterKind.unsharpMask:
        return _engine.applyUnsharpMask(
          data,
          width,
          height,
          filter.strength,
          filter.edgeStrength,
        );
      case FilterKind.vignette:
        return _engine.applyVignette(
          data,
          width,
          height,
          filter.strength,
          color: filter.vignetteColor,
        );
      case FilterKind.noise:
        return _engine.applyNoise(
          data,
          width,
          height,
          (filter.strength / 100).clamp(0.0, 1.0),
          NoiseType.gaussian,
        );
      case FilterKind.retroAnime:
        return _engine.applyRetroAnime(data, width, height, filter.strength);
      case FilterKind.crt:
        return _engine.applyCrt(data, width, height, filter.strength);
      case FilterKind.monochrome:
        return _engine.applyMonochrome(
          data,
          width,
          height,
          (filter.strength / 100).clamp(0.0, 1.0),
          targetColor: filter.monochromeColor,
        );
      case FilterKind.colorAdjust:
        return _engine.applyColorAdjust(
          data,
          width,
          height,
          saturation: filter.caSaturation,
          brightness: filter.caBrightness,
          contrast: filter.caContrast,
        );
      case FilterKind.threshold:
        return _engine.applyThreshold(
          data,
          width,
          height,
          filter.thresholdValue,
        );
      case FilterKind.fisheye:
        return _engine.applyFisheye(data, width, height, filter.strength);
      case FilterKind.chromaticAberration:
        return _engine.applyChromaticAberration(
          data,
          width,
          height,
          filter.strength,
          0,
        );
      case FilterKind.lensDistortion:
        // lensCenterOffsetX/Yはフル解像度px単位で保存されているため、
        // 縮小プレビュー用に_previewScale（_loadPreviewBaseで算出した
        // 縮小率）を掛けて同じ相対位置になるよう変換する。
        return _engine.applyLensDistortion(
          data,
          width,
          height,
          filter.strength,
          _previewMask,
          centerOffsetX: filter.lensCenterOffsetX * _previewScale,
          centerOffsetY: filter.lensCenterOffsetY * _previewScale,
        );
      case FilterKind.pixelate:
        return _engine.applyPixelate(
          data,
          width,
          height,
          mosaicSize: filter.strength.round().clamp(1, 64),
          colorMode: filter.pixelColorMode,
          colorLevels: filter.colorLevels,
          paletteColors: filter.pixelExplicitColors,
        );
      case FilterKind.auroraHologram:
        return _engine.applyAuroraHologram(
          data,
          width,
          height,
          strength: filter.strength,
          brightness: filter.hologramBrightness,
          saturation: filter.hologramSaturation,
          preset: filter.hologramPreset,
        );
      case FilterKind.inkPool:
        return _engine.applyInkPoolComposite(
          data,
          width,
          height,
          color: filter.inkPoolColor,
          rangePx: filter.inkPoolRange * _previewScale,
          centerWidthPx: filter.inkPoolCenterWidth * _previewScale,
        );
      case FilterKind.backgroundBlend:
        final background = _previewBackgroundBytes;
        if (background == null) return Uint8List.fromList(data);
        final previewFilter = filter.copyWith(
          bgBlendLength: filter.bgBlendLength * _previewScale,
          bgBlendSamplingBand: filter.bgBlendSamplingBand * _previewScale,
        );
        final analysis = BackgroundAcclimationEngine.analyze(
          data,
          background,
          width,
          height,
          previewFilter,
        );
        _lastBgBlendAnalysis = analysis;
        return BackgroundAcclimationEngine.apply(
          data,
          background,
          width,
          height,
          previewFilter,
          analysis: analysis,
        );
    }
  }

  /// backgroundBlendの馴染ませ色を解決する：ユーザーが手動指定していれば
  /// その色（[FilterDef.bgBlendColor]が-1以外）、そうでなければ
  /// _loadPreviewBaseで自動検出した色（_autoBlendColorArgb）、それも
  /// 無ければ（不透明画素が1つも無い等）中間グレーへフォールバックする。
  int _resolvedBgBlendColor(FilterDef filter) {
    if (filter.bgBlendColor != -1) return filter.bgBlendColor;
    return _autoBlendColorArgb ?? 0xFF808080;
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
      case FilterKind.sharpen:
        return Icons.filter_center_focus;
      case FilterKind.unsharpMask:
        return Icons.blur_off;
      case FilterKind.vignette:
        return Icons.vignette;
      case FilterKind.noise:
        return Icons.grain;
      case FilterKind.retroAnime:
        return Icons.movie_filter;
      case FilterKind.crt:
        return Icons.tv;
      case FilterKind.monochrome:
        return Icons.filter_b_and_w;
      case FilterKind.colorAdjust:
        return Icons.tune;
      case FilterKind.threshold:
        return Icons.contrast;
      case FilterKind.fisheye:
        return Icons.panorama_fish_eye;
      case FilterKind.chromaticAberration:
        return Icons.color_lens;
      case FilterKind.lensDistortion:
        return Icons.remove_red_eye;
      case FilterKind.pixelate:
        return Icons.grid_view;
      case FilterKind.auroraHologram:
        return Icons.auto_awesome_mosaic;
      case FilterKind.backgroundBlend:
        return Icons.wb_twilight;
      case FilterKind.inkPool:
        return Icons.gesture_rounded;
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

  /// フィルターを1フレームへ適用する。縁取りフィルターの場合は新規レイヤーを
  /// 作成するため、そのレイヤーIDを返す（複数フレーム一括適用時、
  /// [outlineLayerId]としてこの戻り値を後続フレームへ渡すと、全フレームで
  /// 同一IDの新規レイヤーとなり1つの連続したレイヤートラックとして扱える。
  /// それ以外のフィルター種別ではnullを返す）。
  Future<String?> _applyToFrame(
    ProjectService ps,
    TileManager tm,
    String layerId,
    FilterDef filter,
    int frameIndex, {
    String? outlineLayerId,
  }) async {
    // BuildContextをasyncギャップ（await）をまたいで参照しないよう、
    // 縁取りフィルターの新規レイヤー命名に使うl10nはawaitの前に取得しておく。
    final l10n =
        filter.kind == FilterKind.outline || filter.kind == FilterKind.inkPool
        ? AppLocalizations.of(context)!
        : null;
    final key = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      frameIndex,
      layerId,
    );
    final img = await tm.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null) return null;
    final data = byteData.buffer.asUint8List();
    // 眼鏡断層フィルター用：このフレームの選択レイヤー（LayerType.selection）を
    // フル解像度で単体合成し、マスクとしてisolateへ渡す（他フィルター種別では
    // applyDrawFilterInIsolate側で無視される）。
    Uint8List? maskData;
    if (filter.kind == FilterKind.lensDistortion) {
      final selectionLayer = ps
          .layersOf(widget.projectId, widget.sceneId, frameIndex)
          .where((l) => l.type == model.LayerType.selection)
          .firstOrNull;
      if (selectionLayer != null) {
        final maskKey = ps.tileKeyFor(
          widget.projectId,
          widget.sceneId,
          frameIndex,
          selectionLayer.id,
        );
        final maskImg = await tm.compositeLayerToImage(maskKey);
        final maskByteData = await maskImg.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        maskImg.dispose();
        maskData = maskByteData?.buffer.asUint8List();
      }
    }
    // 背景馴染ませv2：対象外の表示中レイヤーをRGBAのまま渡し、
    // 代表1色へ潰さず方向別に環境を解析する。
    if (filter.kind == FilterKind.backgroundBlend) {
      final allLayers = ps.layersOf(
        widget.projectId,
        widget.sceneId,
        frameIndex,
      );
      final otherImg = await LayerCompositor.composite(
        tm,
        allLayers,
        (l) =>
            ps.tileKeyFor(widget.projectId, widget.sceneId, frameIndex, l.id),
        tm.canvasWidth,
        tm.canvasHeight,
        shouldRender: (l, i) => l.id != layerId,
      );
      final otherByteData = await otherImg.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      otherImg.dispose();
      maskData = otherByteData?.buffer.asUint8List();
    }
    final effectiveFilter = filter;
    // 低スペック端末でのUIスレッドブロックを避けるため、本適用（フル解像度）は
    // バックグラウンドisolateで実行する。プレビュー（縮小画像）は_runFilterのまま
    // メインisolateで即時処理する（isolate起動コストの方が高くつくため）。
    final result = await compute(applyDrawFilterInIsolate, (
      data,
      tm.canvasWidth,
      tm.canvasHeight,
      effectiveFilter,
      maskData,
    ));

    if (filter.kind == FilterKind.outline) {
      return _applyOutlineToNewLayer(
        ps,
        tm,
        layerId,
        filter,
        frameIndex,
        result,
        outlineLayerId,
        l10n!,
      );
    }
    if (filter.kind == FilterKind.inkPool) {
      return _applyInkPoolToNewLayer(
        ps,
        tm,
        layerId,
        filter,
        frameIndex,
        result,
        outlineLayerId,
        l10n!,
      );
    }

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
    return null;
  }

  /// 縁取りフィルターの本適用（選択中のレイヤーとは別に、縁どった内容は
  /// 新規レイヤーに描画する）。選択レイヤー自体は
  /// 書き換えず、[ringData]（縁取りリング部分のみ・それ以外は透明。
  /// applyDrawFilterInIsolate経由のapplyOutlineLayerの結果）を新規の
  /// 通常レイヤーへ描画し、選択レイヤーの直下（背面側）へ挿入する。
  /// 新規レイヤー作成は自動塗りレイヤー作成（layer_panel.dart）
  /// と同じ手順：addLayer()で追加した後、目的の位置へreorderLayer()で
  /// 移動する（addLayer()は常に最前面へ挿入するため）。
  /// [outlineLayerId]を渡した場合はそのIDでレイヤーを作成する（複数フレーム
  /// 一括適用時、1フレーム目で採番されたIDを後続フレームへも使い回すことで
  /// 全フレームで同一IDの1つのレイヤートラックにするための引数）。
  Future<String> _applyOutlineToNewLayer(
    ProjectService ps,
    TileManager tm,
    String sourceLayerId,
    FilterDef filter,
    int frameIndex,
    Uint8List ringData,
    String? outlineLayerId,
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
      name: l10n.filterOutlineLayerNameSuffix(sourceName),
      id: outlineLayerId,
    );

    final layers = ps.layersOf(widget.projectId, widget.sceneId, frameIndex);
    final createdIdx = layers.indexWhere((l) => l.id == created.id);
    final targetIdx = layers.indexWhere((l) => l.id == sourceLayerId) + 1;
    if (createdIdx >= 0 && targetIdx >= 0 && createdIdx != targetIdx) {
      ps.reorderLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: frameIndex,
        oldIndex: createdIdx,
        newIndex: targetIdx,
      );
    }

    final newKey = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      frameIndex,
      created.id,
    );
    tm.replaceLayerPixels(newKey, ringData);
    ps.updateLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      layer: created,
    );
    return created.id;
  }

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
    final newKey = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      frameIndex,
      created.id,
    );
    tm.replaceLayerPixels(newKey, inkData);
    ps.updateLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      layer: created,
    );
    return created.id;
  }

  /// 大量処理実行時：選択した全フレームへ順に適用し、
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
    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) {
            setDialogState = setS;
            return ProgressDialog(
              title: l10n.filterApplyingTitle,
              progress: progress,
              subtitle: l10n.filterApplyingSubtitle(
                _filterDisplayName(l10n, filter),
                sorted.length,
              ),
            );
          },
        ),
      ),
    );
    // ダイアログのbuilderが最初に走るまで1フレーム待つ
    await Future.delayed(const Duration(milliseconds: 16));

    // 縁取りフィルターは新規レイヤーを作成するため、1フレーム目で採番された
    // レイヤーIDを以降のフレームへも使い回し、全フレームで同一IDの1つの
    // レイヤートラックになるようにする。
    String? outlineLayerId;
    for (int i = 0; i < sorted.length; i++) {
      final createdId = await _applyToFrame(
        ps,
        tm,
        layerId,
        filter,
        sorted[i],
        outlineLayerId: outlineLayerId,
      );
      outlineLayerId ??= createdId;
      progress = (i + 1) / sorted.length;
      setDialogState?.call(() {});
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
