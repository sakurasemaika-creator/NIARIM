import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/font_fallback.dart';
import '../../../engine/background_acclimation_engine.dart';
import '../../../engine/auto_lineart_engine.dart';
import '../../../engine/filter_engine.dart';
import '../../../engine/layer_compositor.dart';
import '../../../engine/prism_filter_engine.dart';
import '../../../engine/tile_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/filter_def.dart';
import '../../../models/layer.dart' as model;
import '../../../services/filter_service.dart';
import '../../../services/premium_service.dart';
import '../../../services/project_service.dart';
import '../../../services/theme_service.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/pixel_color_mode_selector.dart';
import '../../../widgets/premium_lock_widget.dart';
import '../../../widgets/progress_dialog.dart';
import '../../../widgets/stepped_slider.dart';
import 'auto_lineart_control_overlay.dart';
import 'color_picker_panel.dart';
import 'panel_close_bar.dart';

enum FilterColorEyedropperTarget { inkPool, outline }

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
  final PrismFilterEngine _prismEngine = PrismFilterEngine();
  bool _showFavoritesOnly = false;
  bool _showSearch = false;
  bool _applying = false;

  Uint8List? _previewBase;
  Uint8List? _previewMask;
  Uint8List? _previewBackgroundBytes;
  int? _autoBlendColorArgb;
  BackgroundAcclimationAnalysis? _lastBgBlendAnalysis;
  AutoLineartGraph? _autoLineartBaseGraph;
  AutoLineartGraph? _autoLineartPreviewGraph;
  double? _autoLineartPreviewRoughWidth;
  int? _autoLineartPreviewSmoothingLevel;
  bool _autoLineartManualEdited = false;
  bool _autoLineartPreviewUpdateScheduled = false;
  int _autoLineartPreviewRevision = 0;
  int _previewW = 0;
  int _previewH = 0;
  double _previewScale = 1;
  ui.Image? _previewImage;
  String? _previewFilterId;

  bool _isPrism(FilterDef filter) => filter.id == FilterService.prismFilterId;

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

  Future<Uint8List?> _downscaleToBytes(
    ui.Image image,
    int width,
    int height,
    int previewWidth,
    int previewHeight,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Rect.fromLTWH(0, 0, previewWidth.toDouble(), previewHeight.toDouble()),
      ui.Paint(),
    );
    image.dispose();
    final picture = recorder.endRecording();
    final small = await picture.toImage(previewWidth, previewHeight);
    final bytes = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    small.dispose();
    return bytes?.buffer.asUint8List();
  }

  Future<void> _loadPreviewBase() async {
    final layerId = widget.layerId;
    if (layerId == null) return;
    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(widget.projectId);
    final width = tm.canvasWidth;
    final height = tm.canvasHeight;
    if (width <= 0 || height <= 0) return;

    final key = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
      layerId,
    );
    final image = await tm.compositeLayerToImage(key);
    const maxSize = 150;
    final scale = math.min(1.0, maxSize / math.max(width, height));
    final previewWidth = (width * scale).round().clamp(1, maxSize);
    final previewHeight = (height * scale).round().clamp(1, maxSize);
    final bytes = await _downscaleToBytes(
      image,
      width,
      height,
      previewWidth,
      previewHeight,
    );
    if (!mounted || bytes == null) return;

    final layers = ps.layersOf(
      widget.projectId,
      widget.sceneId,
      widget.frameIndex,
    );
    final selectionLayer = layers
        .where((l) => l.type == model.LayerType.selection)
        .firstOrNull;
    Uint8List? maskBytes;
    if (selectionLayer != null) {
      final maskImage = await tm.compositeLayerToImage(
        ps.tileKeyFor(
          widget.projectId,
          widget.sceneId,
          widget.frameIndex,
          selectionLayer.id,
        ),
      );
      maskBytes = await _downscaleToBytes(
        maskImage,
        width,
        height,
        previewWidth,
        previewHeight,
      );
      if (!mounted) return;
    }

    final otherImage = await LayerCompositor.composite(
      tm,
      layers,
      (layer) => ps.tileKeyFor(
        widget.projectId,
        widget.sceneId,
        widget.frameIndex,
        layer.id,
      ),
      width,
      height,
      shouldRender: (layer, _) => layer.id != layerId,
    );
    final backgroundBytes = await _downscaleToBytes(
      otherImage,
      width,
      height,
      previewWidth,
      previewHeight,
    );
    if (!mounted) return;

    _previewScale = scale;
    _previewBase = bytes;
    _previewMask = maskBytes;
    _previewBackgroundBytes = backgroundBytes;
    _previewW = previewWidth;
    _previewH = previewHeight;
    _autoBlendColorArgb = backgroundBytes == null
        ? null
        : FilterEngine.mostFrequentOpaqueColor(backgroundBytes);
    await _updatePreview();
  }

  void _scheduleAutoLineartPreviewUpdate() {
    if (_autoLineartPreviewUpdateScheduled) return;
    _autoLineartPreviewUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLineartPreviewUpdateScheduled = false;
      if (mounted) _updatePreview();
    });
  }

  Future<void> _updatePreview() async {
    final base = _previewBase;
    final filter = context.read<FilterService>().currentFilter;
    if (base == null || filter == null || !mounted) return;
    final previewRevision = ++_autoLineartPreviewRevision;
    final Uint8List filtered;
    if (filter.kind == FilterKind.autoLineart) {
      final smoothingLevel = (filter.autoLineartSmoothing / 10).round().clamp(
        0,
        10,
      );
      if (_autoLineartBaseGraph == null ||
          _autoLineartPreviewRoughWidth != filter.autoLineartRoughWidth) {
        _autoLineartBaseGraph = AutoLineartEngine.analyze(
          base,
          _previewW,
          _previewH,
          roughWidthPx: math.max(
            2.0,
            filter.autoLineartRoughWidth * _previewScale,
          ),
        );
        _autoLineartPreviewRoughWidth = filter.autoLineartRoughWidth;
        _autoLineartPreviewGraph = null;
        _autoLineartPreviewSmoothingLevel = null;
        _autoLineartManualEdited = false;
      }
      if (_autoLineartPreviewGraph == null ||
          _autoLineartPreviewSmoothingLevel != smoothingLevel) {
        _autoLineartPreviewGraph = AutoLineartEngine.prepareEditableGraph(
          _autoLineartBaseGraph!,
          smoothingLevel: smoothingLevel,
        );
        _autoLineartPreviewSmoothingLevel = smoothingLevel;
        _autoLineartManualEdited = false;
      }
      filtered = AutoLineartEngine.render(
        _autoLineartPreviewGraph!,
        _previewW,
        _previewH,
        outputWidthPx: math.max(
          1.0,
          filter.autoLineartOutputWidth * _previewScale,
        ),
        taperLengthPx: filter.autoLineartTaperLength * _previewScale,
        smoothing: 0,
      );
    } else {
      filtered = _runFilter(filter, base, _previewW, _previewH);
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      filtered,
      _previewW,
      _previewH,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    if (!mounted || previewRevision != _autoLineartPreviewRevision) {
      image.dispose();
      return;
    }
    setState(() {
      _previewImage?.dispose();
      _previewImage = image;
      _previewFilterId = filter.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = context.watch<FilterService>();
    final query = service.searchQuery;
    final filters = service.filters.where((f) {
      if (_showFavoritesOnly && !f.isFavorite) return false;
      if (query.isEmpty) return true;
      return _filterDisplayName(l10n, f).contains(query);
    }).toList();
    final current = service.currentFilter;
    final bulk = widget.bulkFrameIndices;

    if (current != null && current.id != _previewFilterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updatePreview());
    }

    return Card(
      elevation: 8,
      child: SizedBox(
        width: 300,
        height: 520,
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
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _showFavoritesOnly ? Icons.star : Icons.star_outline,
                      size: 18,
                    ),
                    onPressed: () => setState(
                      () => _showFavoritesOnly = !_showFavoritesOnly,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.search, size: 18),
                    onPressed: () => setState(() => _showSearch = !_showSearch),
                  ),
                ],
              ),
              if (_showSearch)
                TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.filterSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 16),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: service.setSearchQuery,
                ),
              const Divider(),
              SizedBox(
                height: 88,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  itemBuilder: (context, index) {
                    final filter = filters[index];
                    final premium = _premiumFeatureFor(filter.kind);
                    final locked =
                        premium != null &&
                        !context.watch<PremiumService>().isFeatureAvailable(
                          premium,
                        );
                    final selected = filter.id == current?.id;
                    final child = GestureDetector(
                      onTap: locked
                          ? null
                          : () => service.selectFilter(filter.id),
                      child: Container(
                        width: 78,
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : ThemeService.activeColorScheme.outlineVariant,
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_iconForFilter(filter), size: 22),
                            const SizedBox(height: 4),
                            Text(
                              _filterDisplayName(l10n, filter),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9),
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: () => service.toggleFavorite(filter.id),
                              child: Icon(
                                filter.isFavorite
                                    ? Icons.star
                                    : Icons.star_outline,
                                size: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    return locked
                        ? PremiumLockWidget(feature: premium, child: child)
                        : child;
                  },
                ),
              ),
              const Divider(),
              if (current == null)
                Expanded(child: Center(child: Text(l10n.filterEmpty)))
              else ...[
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _previewImage == null
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child:
                                current.kind == FilterKind.autoLineart &&
                                    _autoLineartPreviewGraph != null &&
                                    (bulk == null || bulk.length <= 1)
                                ? AutoLineartControlOverlay(
                                    image: _previewImage!,
                                    graph: _autoLineartPreviewGraph!,
                                    onPointMoved:
                                        (pathIndex, pointIndex, point) {
                                          _autoLineartPreviewGraph =
                                              AutoLineartEngine.moveControlPoint(
                                                _autoLineartPreviewGraph!,
                                                pathIndex: pathIndex,
                                                pointIndex: pointIndex,
                                                point: point,
                                              );
                                          _autoLineartManualEdited = true;
                                          _scheduleAutoLineartPreviewUpdate();
                                        },
                                  )
                                : RawImage(
                                    image: _previewImage,
                                    fit: BoxFit.contain,
                                  ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildControls(l10n, service, current),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: widget.layerId == null || _applying
                      ? null
                      : _applyFilter,
                  icon: _applying
                      ? SizedBox(
                          width: 14,
                          height: 14,
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(
    AppLocalizations l10n,
    FilterService service,
    FilterDef current,
  ) {
    if (_isPrism(current)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '暗い虹色をクリッピング → レイヤー結合 → ガウスぼかし → 覆い焼きリニア',
            style: TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 6),
          _integerStepperSlider(
            'ぼかし量',
            current.prismBlurPx.round(),
            PrismFilterEngine.minBlurPx.toInt(),
            PrismFilterEngine.maxBlurPx.toInt(),
            (value) => service.updateFilterParams(
              current.id,
              prismBlurPx: value.toDouble(),
            ),
            suffix: 'px',
          ),
          _integerStepperSlider(
            '色方向',
            PrismFilterEngine.normalizeDirectionDegrees(
                  current.prismDirectionDegrees,
                ).round() %
                360,
            0,
            359,
            (value) => service.updateFilterParams(
              current.id,
              prismDirectionDegrees: value.toDouble(),
            ),
            suffix: '°',
            wrap: true,
          ),
        ],
      );
    }

    switch (current.kind) {
      case FilterKind.gaussianBlur:
      case FilterKind.lensBlur:
        return _paramSlider(
          l10n.filterStrengthBlurRadius,
          current.strength,
          1,
          20,
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.pixelate:
        return Column(
          children: [
            _paramSlider(
              l10n.filterPixelateBlockSize,
              current.strength,
              1,
              64,
              (v) => service.updateFilterParams(current.id, strength: v),
            ),
            PixelColorModeSelector(
              mode: current.pixelColorMode,
              colorLevels: current.colorLevels,
              explicitColors: current.pixelExplicitColors,
              onModeChanged: (v) {
                service.updateFilterParams(current.id, pixelColorMode: v);
                _updatePreview();
              },
              onColorLevelsChanged: (v) {
                service.updateFilterParams(current.id, colorLevels: v);
                _updatePreview();
              },
              onExplicitColorsChanged: (v) {
                service.updateFilterParams(current.id, pixelExplicitColors: v);
                _updatePreview();
              },
            ),
          ],
        );
      case FilterKind.auroraHologram:
        return Column(
          children: [
            _paramSlider(
              l10n.filterAuroraHologramStrength,
              current.strength,
              0,
              100,
              (v) => service.updateFilterParams(current.id, strength: v),
            ),
            _paramSlider(
              l10n.filterAuroraHologramBrightness,
              current.hologramBrightness,
              -100,
              100,
              (v) =>
                  service.updateFilterParams(current.id, hologramBrightness: v),
            ),
            _paramSlider(
              l10n.filterAuroraHologramSaturation,
              current.hologramSaturation,
              -100,
              100,
              (v) =>
                  service.updateFilterParams(current.id, hologramSaturation: v),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: AuroraHologramPreset.values
                  .map(
                    (preset) => ChoiceChip(
                      label: Text(
                        _auroraPresetLabel(l10n, preset),
                        style: const TextStyle(fontSize: 9),
                      ),
                      selected: current.hologramPreset == preset,
                      onSelected: (selected) {
                        if (!selected) return;
                        service.updateFilterParams(
                          current.id,
                          hologramPreset: preset,
                        );
                        _updatePreview();
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      case FilterKind.animeStyle:
        return Column(
          children: [
            _paramSlider(
              l10n.filterColorLevels,
              current.colorLevels.toDouble(),
              2,
              32,
              (v) => service.updateFilterParams(
                current.id,
                colorLevels: v.round(),
              ),
            ),
            _paramSlider(
              l10n.filterEdgeStrength,
              current.edgeStrength,
              0,
              1,
              (v) => service.updateFilterParams(current.id, edgeStrength: v),
              decimals: 2,
            ),
          ],
        );
      case FilterKind.outline:
        return Column(
          children: [
            _colorControl(
              l10n.filterOutlineColor,
              current.outlineColor,
              (c) => service.updateFilterParams(current.id, outlineColor: c),
              eyedropperTarget: FilterColorEyedropperTarget.outline,
            ),
            _paramSlider(
              l10n.filterOutlineWidth,
              current.outlineWidth,
              1,
              60,
              (v) => service.updateFilterParams(current.id, outlineWidth: v),
            ),
          ],
        );
      case FilterKind.autoLineart:
        return Column(
          children: [
            _integerStepperSlider(
              l10n.filterAutoLineartRoughWidth,
              current.autoLineartRoughWidth.round(),
              2,
              80,
              (v) {
                service.updateFilterParams(
                  current.id,
                  autoLineartRoughWidth: v.toDouble(),
                );
                _autoLineartBaseGraph = null;
                _autoLineartPreviewGraph = null;
                _autoLineartPreviewRoughWidth = null;
                _autoLineartPreviewSmoothingLevel = null;
                _autoLineartManualEdited = false;
                _updatePreview();
              },
              suffix: 'px',
            ),
            _integerStepperSlider(
              l10n.filterAutoLineartOutputWidth,
              current.autoLineartOutputWidth.round(),
              1,
              30,
              (v) {
                service.updateFilterParams(
                  current.id,
                  autoLineartOutputWidth: v.toDouble(),
                );
                _updatePreview();
              },
              suffix: 'px',
            ),
            _integerStepperSlider(
              l10n.filterAutoLineartTaperLength,
              current.autoLineartTaperLength.round(),
              0,
              100,
              (v) {
                service.updateFilterParams(
                  current.id,
                  autoLineartTaperLength: v.toDouble(),
                );
                _updatePreview();
              },
              suffix: 'px',
            ),
            _integerStepperSlider(
              l10n.filterAutoLineartSmoothing,
              (current.autoLineartSmoothing / 10).round().clamp(0, 10),
              0,
              10,
              (v) {
                service.updateFilterParams(
                  current.id,
                  autoLineartSmoothing: (v * 10).toDouble(),
                );
                _autoLineartPreviewGraph = null;
                _autoLineartPreviewSmoothingLevel = null;
                _autoLineartManualEdited = false;
                _updatePreview();
              },
            ),
          ],
        );
      case FilterKind.inkPool:
        return Column(
          children: [
            _colorControl(
              l10n.filterInkPoolColor,
              current.inkPoolColor,
              (c) => service.updateFilterParams(current.id, inkPoolColor: c),
              eyedropperTarget: FilterColorEyedropperTarget.inkPool,
            ),
            _integerStepperSlider(
              l10n.filterInkPoolRange,
              current.inkPoolRange.round(),
              1,
              80,
              (v) => service.updateFilterParams(
                current.id,
                inkPoolRange: v.toDouble(),
              ),
              suffix: 'px',
            ),
            _integerStepperSlider(
              l10n.filterInkPoolCenterWidth,
              current.inkPoolCenterWidth.round(),
              1,
              60,
              (v) => service.updateFilterParams(
                current.id,
                inkPoolCenterWidth: v.toDouble(),
              ),
              suffix: 'px',
            ),
          ],
        );
      case FilterKind.toneCurve:
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: ToneCurvePreset.values
              .map(
                (preset) => ChoiceChip(
                  label: Text(
                    _toneCurveLabel(l10n, preset),
                    style: const TextStyle(fontSize: 9),
                  ),
                  selected: current.toneCurvePreset == preset,
                  onSelected: (selected) {
                    if (!selected) return;
                    service.updateFilterParams(
                      current.id,
                      toneCurvePreset: preset,
                    );
                    _updatePreview();
                  },
                ),
              )
              .toList(),
        );
      case FilterKind.levels:
        return Column(
          children: [
            _paramSlider(
              l10n.filterLevelsInputBlack,
              current.inputBlack.toDouble(),
              0,
              255,
              (v) =>
                  service.updateFilterParams(current.id, inputBlack: v.round()),
            ),
            _paramSlider(
              l10n.filterLevelsInputWhite,
              current.inputWhite.toDouble(),
              0,
              255,
              (v) =>
                  service.updateFilterParams(current.id, inputWhite: v.round()),
            ),
            _paramSlider(
              l10n.filterLevelsOutputBlack,
              current.outputBlack.toDouble(),
              0,
              255,
              (v) => service.updateFilterParams(
                current.id,
                outputBlack: v.round(),
              ),
            ),
            _paramSlider(
              l10n.filterLevelsOutputWhite,
              current.outputWhite.toDouble(),
              0,
              255,
              (v) => service.updateFilterParams(
                current.id,
                outputWhite: v.round(),
              ),
            ),
          ],
        );
      case FilterKind.sharpen:
        return _paramSlider(
          l10n.filterSharpenStrength,
          current.strength,
          0,
          100,
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.unsharpMask:
        return Column(
          children: [
            _paramSlider(
              l10n.filterStrengthBlurRadius,
              current.strength,
              1,
              20,
              (v) => service.updateFilterParams(current.id, strength: v),
            ),
            _paramSlider(
              l10n.filterUnsharpAmount,
              current.edgeStrength,
              0,
              3,
              (v) => service.updateFilterParams(current.id, edgeStrength: v),
              decimals: 2,
            ),
          ],
        );
      case FilterKind.vignette:
        return Column(
          children: [
            _colorControl(
              l10n.filterVignetteColor,
              current.vignetteColor,
              (c) => service.updateFilterParams(current.id, vignetteColor: c),
            ),
            _paramSlider(
              l10n.filterVignetteStrength,
              current.strength,
              0,
              100,
              (v) => service.updateFilterParams(current.id, strength: v),
            ),
          ],
        );
      case FilterKind.noise:
        return _paramSlider(
          l10n.filterNoiseStrength,
          current.strength,
          0,
          100,
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.retroAnime:
      case FilterKind.crt:
        return _paramSlider(
          l10n.filterRetroStrength,
          current.strength,
          0,
          100,
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.monochrome:
        return Column(
          children: [
            _paramSlider(
              l10n.filterMonochromeStrength,
              current.strength,
              0,
              100,
              (v) => service.updateFilterParams(current.id, strength: v),
            ),
            _colorControl(
              l10n.filterMonochromeColorLabel,
              current.monochromeColor,
              (c) => service.updateFilterParams(current.id, monochromeColor: c),
            ),
          ],
        );
      case FilterKind.colorAdjust:
        return Column(
          children: [
            _paramSlider(
              l10n.filterColorAdjustSaturationLabel,
              current.caSaturation,
              -100,
              100,
              (v) => service.updateFilterParams(current.id, caSaturation: v),
            ),
            _paramSlider(
              l10n.filterColorAdjustBrightnessLabel,
              current.caBrightness,
              -100,
              100,
              (v) => service.updateFilterParams(current.id, caBrightness: v),
            ),
            _paramSlider(
              l10n.filterColorAdjustContrastLabel,
              current.caContrast,
              -100,
              100,
              (v) => service.updateFilterParams(current.id, caContrast: v),
            ),
          ],
        );
      case FilterKind.threshold:
        return _paramSlider(
          l10n.filterThresholdLabel,
          current.thresholdValue,
          0,
          255,
          (v) => service.updateFilterParams(current.id, thresholdValue: v),
        );
      case FilterKind.fisheye:
        return _paramSlider(
          l10n.filterFisheyeStrength,
          current.strength,
          0,
          100,
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.chromaticAberration:
        return _paramSlider(
          l10n.filterChromaticAberrationStrength,
          current.strength,
          1,
          30,
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.lensDistortion:
        return Column(
          children: [
            if (_previewMask == null)
              Text(
                l10n.filterLensDistortionNoMaskHint,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            _paramSlider(
              l10n.filterLensDistortionStrength,
              current.strength,
              -100,
              100,
              (v) => service.updateFilterParams(current.id, strength: v),
            ),
            _paramSlider(
              l10n.filterLensDistortionOffsetX,
              current.lensCenterOffsetX,
              -100,
              100,
              (v) =>
                  service.updateFilterParams(current.id, lensCenterOffsetX: v),
            ),
            _paramSlider(
              l10n.filterLensDistortionOffsetY,
              current.lensCenterOffsetY,
              -100,
              100,
              (v) =>
                  service.updateFilterParams(current.id, lensCenterOffsetY: v),
            ),
          ],
        );
      case FilterKind.backgroundBlend:
        return Column(
          children: [
            _paramSlider(
              l10n.filterBackgroundBlendDirection,
              current.bgBlendDirection,
              0,
              360,
              (v) =>
                  service.updateFilterParams(current.id, bgBlendDirection: v),
            ),
            _paramSlider(
              l10n.filterBackgroundBlendLength,
              current.bgBlendLength,
              1,
              80,
              (v) => service.updateFilterParams(current.id, bgBlendLength: v),
            ),
            _paramSlider(
              l10n.filterBackgroundBlendBlur,
              current.bgBlendBlur,
              0,
              40,
              (v) => service.updateFilterParams(current.id, bgBlendBlur: v),
            ),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('光源方向を自動推定', style: TextStyle(fontSize: 11)),
              value: current.bgBlendAutoLight,
              onChanged: (v) {
                service.updateFilterParams(current.id, bgBlendAutoLight: v);
                _updatePreview();
              },
            ),
            _paramSlider(
              '馴染み強度',
              current.bgBlendStrength,
              0,
              100,
              (v) => service.updateFilterParams(current.id, bgBlendStrength: v),
            ),
            _paramSlider(
              '主光源の強さ',
              current.bgBlendLightStrength,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendLightStrength: v,
              ),
            ),
            _paramSlider(
              '影の強さ',
              current.bgBlendShadowStrength,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendShadowStrength: v,
              ),
            ),
            _paramSlider(
              '環境光',
              current.bgBlendAmbientStrength,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendAmbientStrength: v,
              ),
            ),
            _paramSlider(
              '下方反射光',
              current.bgBlendReflectionStrength,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendReflectionStrength: v,
              ),
            ),
            _paramSlider(
              '局所的な色移り',
              current.bgBlendColorBleed,
              0,
              100,
              (v) =>
                  service.updateFilterParams(current.id, bgBlendColorBleed: v),
            ),
            _paramSlider(
              '光の柔らかさ',
              current.bgBlendSoftness,
              0,
              100,
              (v) => service.updateFilterParams(current.id, bgBlendSoftness: v),
            ),
            _paramSlider(
              '副光源',
              current.bgBlendSecondaryStrength,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendSecondaryStrength: v,
              ),
            ),
            _paramSlider(
              '素材保護',
              current.bgBlendMaterialProtection,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendMaterialProtection: v,
              ),
            ),
            _paramSlider(
              '環境サンプリング帯',
              current.bgBlendSamplingBand,
              4,
              120,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendSamplingBand: v,
              ),
            ),
          ],
        );
    }
  }

  Widget _colorControl(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    FilterColorEyedropperTarget? eyedropperTarget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          InkWell(
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => Dialog(
                backgroundColor: Colors.transparent,
                child: ColorPickerPanel(
                  currentColor: Color(value),
                  onColorChanged: (color) {
                    onChanged(color.toARGB32());
                    _updatePreview();
                  },
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Color(value),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
          if (eyedropperTarget != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.colorize, size: 18),
              onPressed: () =>
                  widget.onStartCanvasEyedropper?.call(eyedropperTarget),
            ),
        ],
      ),
    );
  }

  Widget _paramSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int decimals = 0,
  }) {
    final safeValue = value.clamp(min, max).toDouble();
    final valueLabel = decimals > 0
        ? safeValue.toStringAsFixed(decimals)
        : safeValue.round().toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditableSliderValue(
            text: '$label: $valueLabel',
            style: const TextStyle(fontSize: 11),
            value: safeValue,
            min: min,
            max: max,
            isInt: decimals == 0,
            onChanged: (v) {
              onChanged(v.toDouble());
              _updatePreview();
            },
          ),
          SteppedSlider(
            value: safeValue,
            min: min,
            max: max,
            step: decimals > 0 ? 0.1 : 1,
            onChanged: (v) {
              onChanged(v);
              _updatePreview();
            },
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
    ValueChanged<int> onChanged, {
    String suffix = '',
    bool wrap = false,
  }) {
    int normalize(int next) {
      if (!wrap) return next.clamp(min, max);
      final span = max - min + 1;
      return ((next - min) % span + span) % span + min;
    }

    void change(int next) {
      onChanged(normalize(next));
      _updatePreview();
    }

    final shown = normalize(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $shown$suffix', style: const TextStyle(fontSize: 11)),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_rounded, size: 18),
                onPressed: wrap || shown > min ? () => change(shown - 1) : null,
              ),
              Expanded(
                child: SteppedSlider(
                  value: shown.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  step: 1,
                  onChanged: (v) => change(v.round()),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: wrap || shown < max ? () => change(shown + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _filterDisplayName(AppLocalizations l10n, FilterDef filter) {
    if (_isPrism(filter)) return 'プリズム';
    return switch (filter.kind) {
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
      FilterKind.autoLineart => l10n.filterNameAutoLineart,
    };
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

  String _auroraPresetLabel(
    AppLocalizations l10n,
    AuroraHologramPreset preset,
  ) => switch (preset) {
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

  IconData _iconForFilter(FilterDef filter) {
    if (_isPrism(filter)) return Icons.gradient;
    return switch (filter.kind) {
      FilterKind.gaussianBlur => Icons.blur_on,
      FilterKind.lensBlur => Icons.blur_circular,
      FilterKind.animeStyle => Icons.auto_awesome,
      FilterKind.outline => Icons.border_outer,
      FilterKind.toneCurve => Icons.show_chart,
      FilterKind.levels => Icons.bar_chart,
      FilterKind.sharpen => Icons.filter_center_focus,
      FilterKind.unsharpMask => Icons.blur_off,
      FilterKind.vignette => Icons.vignette,
      FilterKind.noise => Icons.grain,
      FilterKind.retroAnime => Icons.movie_filter,
      FilterKind.crt => Icons.tv,
      FilterKind.monochrome => Icons.filter_b_and_w,
      FilterKind.colorAdjust => Icons.tune,
      FilterKind.threshold => Icons.contrast,
      FilterKind.fisheye => Icons.panorama_fish_eye,
      FilterKind.chromaticAberration => Icons.color_lens,
      FilterKind.lensDistortion => Icons.remove_red_eye,
      FilterKind.pixelate => Icons.grid_view,
      FilterKind.auroraHologram => Icons.auto_awesome_mosaic,
      FilterKind.backgroundBlend => Icons.wb_twilight,
      FilterKind.inkPool => Icons.gesture_rounded,
      FilterKind.autoLineart => Icons.auto_fix_high,
    };
  }

  PremiumFeature? _premiumFeatureFor(FilterKind kind) {
    return switch (kind) {
      FilterKind.toneCurve => PremiumFeature.toneCurve,
      FilterKind.levels => PremiumFeature.levelAdjustment,
      _ => null,
    };
  }

  Uint8List _runFilter(
    FilterDef filter,
    Uint8List data,
    int width,
    int height,
  ) {
    if (_isPrism(filter)) {
      return _prismEngine.apply(
        data,
        width,
        height,
        blurPx: filter.prismBlurPx * _previewScale,
        gradientDirectionDegrees: filter.prismDirectionDegrees,
      );
    }
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
      case FilterKind.autoLineart:
        return AutoLineartEngine.render(
          AutoLineartEngine.analyze(
            data,
            width,
            height,
            roughWidthPx: filter.autoLineartRoughWidth * _previewScale,
          ),
          width,
          height,
          outputWidthPx: math.max(
            1.0,
            filter.autoLineartOutputWidth * _previewScale,
          ),
          taperLengthPx: filter.autoLineartTaperLength * _previewScale,
          smoothing: filter.autoLineartSmoothing,
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

  Future<void> _applyFilter() async {
    final layerId = widget.layerId;
    final filter = context.read<FilterService>().currentFilter;
    if (layerId == null || filter == null) return;
    setState(() => _applying = true);
    try {
      final ps = context.read<ProjectService>();
      final tm = ps.tileManagerOf(widget.projectId);
      final bulk = widget.bulkFrameIndices;
      if (bulk != null && bulk.length > 1) {
        await _applyBulk(ps, tm, layerId, filter, bulk);
      } else {
        await _applyToFrame(ps, tm, layerId, filter, widget.frameIndex);
      }
      if (mounted) widget.onClose();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<String?> _applyToFrame(
    ProjectService ps,
    TileManager tm,
    String layerId,
    FilterDef filter,
    int frameIndex, {
    String? generatedLayerId,
  }) async {
    final l10n =
        filter.kind == FilterKind.outline ||
            filter.kind == FilterKind.inkPool ||
            filter.kind == FilterKind.autoLineart
        ? AppLocalizations.of(context)!
        : null;
    final key = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      frameIndex,
      layerId,
    );
    final image = await tm.compositeLayerToImage(key);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) return null;
    final data = byteData.buffer.asUint8List();

    Uint8List result;
    final canUseManualAutoLineart =
        filter.kind == FilterKind.autoLineart &&
        _autoLineartManualEdited &&
        _autoLineartPreviewGraph != null &&
        frameIndex == widget.frameIndex &&
        (widget.bulkFrameIndices == null ||
            widget.bulkFrameIndices!.length <= 1);
    if (canUseManualAutoLineart) {
      result = AutoLineartEngine.render(
        _autoLineartPreviewGraph!,
        tm.canvasWidth,
        tm.canvasHeight,
        outputWidthPx: filter.autoLineartOutputWidth,
        taperLengthPx: filter.autoLineartTaperLength,
        smoothing: 0,
      );
    } else if (_isPrism(filter)) {
      // Full-resolution blur uses the exact user-facing px value. Clipping only
      // constrains the rainbow fill; the Gaussian stage is intentionally unclipped.
      result = await compute(applyPrismFilterInIsolate, (
        data,
        tm.canvasWidth,
        tm.canvasHeight,
        filter.prismBlurPx,
        filter.prismDirectionDegrees,
      ));
    } else {
      Uint8List? maskData;
      if (filter.kind == FilterKind.lensDistortion) {
        final selectionLayer = ps
            .layersOf(widget.projectId, widget.sceneId, frameIndex)
            .where((l) => l.type == model.LayerType.selection)
            .firstOrNull;
        if (selectionLayer != null) {
          final maskImage = await tm.compositeLayerToImage(
            ps.tileKeyFor(
              widget.projectId,
              widget.sceneId,
              frameIndex,
              selectionLayer.id,
            ),
          );
          final maskByteData = await maskImage.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          maskImage.dispose();
          maskData = maskByteData?.buffer.asUint8List();
        }
      }
      if (filter.kind == FilterKind.backgroundBlend) {
        final layers = ps.layersOf(
          widget.projectId,
          widget.sceneId,
          frameIndex,
        );
        final otherImage = await LayerCompositor.composite(
          tm,
          layers,
          (layer) => ps.tileKeyFor(
            widget.projectId,
            widget.sceneId,
            frameIndex,
            layer.id,
          ),
          tm.canvasWidth,
          tm.canvasHeight,
          shouldRender: (layer, _) => layer.id != layerId,
        );
        final otherData = await otherImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        otherImage.dispose();
        maskData = otherData?.buffer.asUint8List();
      }
      result = await compute(applyDrawFilterInIsolate, (
        data,
        tm.canvasWidth,
        tm.canvasHeight,
        filter,
        maskData,
      ));
    }

    if (!_isPrism(filter) && filter.kind == FilterKind.outline) {
      return _applyGeneratedLayer(
        ps,
        tm,
        layerId,
        frameIndex,
        result,
        generatedLayerId,
        l10n!.filterOutlineLayerNameSuffix,
      );
    }
    if (!_isPrism(filter) && filter.kind == FilterKind.inkPool) {
      return _applyGeneratedLayer(
        ps,
        tm,
        layerId,
        frameIndex,
        result,
        generatedLayerId,
        l10n!.filterInkPoolLayerNameSuffix,
      );
    }
    if (!_isPrism(filter) && filter.kind == FilterKind.autoLineart) {
      return _applyGeneratedLayer(
        ps,
        tm,
        layerId,
        frameIndex,
        result,
        generatedLayerId,
        l10n!.filterAutoLineartLayerNameSuffix,
      );
    }

    tm.replaceLayerPixels(key, result);
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

  Future<String> _applyGeneratedLayer(
    ProjectService ps,
    TileManager tm,
    String sourceLayerId,
    int frameIndex,
    Uint8List pixels,
    String? generatedLayerId,
    String Function(String) nameBuilder,
  ) async {
    final sourceLayer = ps
        .layersOf(widget.projectId, widget.sceneId, frameIndex)
        .where((l) => l.id == sourceLayerId)
        .firstOrNull;
    final sourceName = sourceLayer?.name ?? 'Layer';
    final created = ps.addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      type: model.LayerType.normal,
      name: nameBuilder(sourceName),
      id: generatedLayerId,
    );
    final layers = ps.layersOf(widget.projectId, widget.sceneId, frameIndex);
    final createdIndex = layers.indexWhere((l) => l.id == created.id);
    final sourceIndex = layers.indexWhere((l) => l.id == sourceLayerId);
    final targetIndex = sourceIndex < 0 ? createdIndex : sourceIndex + 1;
    if (createdIndex >= 0 && targetIndex >= 0 && createdIndex != targetIndex) {
      ps.reorderLayer(
        projectId: widget.projectId,
        sceneId: widget.sceneId,
        frameIndex: frameIndex,
        oldIndex: createdIndex,
        newIndex: targetIndex,
      );
    }
    final key = ps.tileKeyFor(
      widget.projectId,
      widget.sceneId,
      frameIndex,
      created.id,
    );
    tm.replaceLayerPixels(key, pixels);
    ps.updateLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      layer: created,
    );
    return created.id;
  }

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
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            setDialogState = setState;
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
    await Future.delayed(const Duration(milliseconds: 16));

    String? generatedLayerId;
    for (var i = 0; i < sorted.length; i++) {
      final created = await _applyToFrame(
        ps,
        tm,
        layerId,
        filter,
        sorted[i],
        generatedLayerId: generatedLayerId,
      );
      generatedLayerId ??= created;
      progress = (i + 1) / sorted.length;
      setDialogState?.call(() {});
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
