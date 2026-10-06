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
import '../../../models/custom_automation.dart';
import '../../../models/filter_def.dart';
import '../../../models/layer.dart' as model;
import '../../../services/custom_automation_service.dart';
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
  int _toneCurveChannel = 0; // 0=RGB, 1=R, 2=G, 3=B
  int _levelsChannel = 0; // 0=RGB, 1=R, 2=G, 3=B

  Uint8List? _previewBase;
  Uint8List? _previewMask;
  Uint8List? _previewBackgroundBytes;
  AutoLineartGraph? _autoLineartBaseGraph;
  AutoLineartGraph? _autoLineartPreviewGraph;
  AutoLineartGraph? _autoLineartEditBaselineGraph;
  double? _autoLineartPreviewRoughWidth;
  int? _autoLineartPreviewSmoothingLevel;
  bool _autoLineartManualEdited = false;
  bool _autoLineartPreviewUpdateScheduled = false;
  int _autoLineartPreviewRevision = 0;
  int _previewW = 0;
  int _previewH = 0;
  AutoLineartControlMode _autoLineartControlMode = AutoLineartControlMode.move;
  double _previewScale = 1;
  ui.Image? _previewImage;
  String? _previewFilterId;

  bool _isPrism(FilterDef filter) => filter.kind == FilterKind.prism;
  bool _isVhs(FilterDef filter) =>
      filter.kind == FilterKind.noise && filter.noiseStyle == NoiseStyle.vhs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FilterService>().clearCurrentFilter();
    });
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
      final smoothingLevel = filter.autoLineartSmoothing.round().clamp(0, 10);
      final roughChanged =
          _autoLineartBaseGraph == null ||
          _autoLineartPreviewRoughWidth != filter.autoLineartRoughWidth;
      final smoothingChanged =
          _autoLineartPreviewSmoothingLevel != smoothingLevel;
      if (roughChanged ||
          smoothingChanged ||
          _autoLineartPreviewGraph == null) {
        final previousBaseline = _autoLineartEditBaselineGraph;
        final previousEdited = _autoLineartPreviewGraph;
        final preserveManual =
            _autoLineartManualEdited &&
            previousBaseline != null &&
            previousEdited != null;
        if (roughChanged) {
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
        }
        final prepared = AutoLineartEngine.prepareEditableGraph(
          _autoLineartBaseGraph!,
          smoothingLevel: smoothingLevel,
        );
        _autoLineartPreviewGraph = preserveManual
            ? AutoLineartEngine.transferControlEdits(
                previousBaseline,
                previousEdited,
                prepared,
              )
            : prepared;
        _autoLineartEditBaselineGraph = prepared;
        _autoLineartPreviewSmoothingLevel = smoothingLevel;
        _autoLineartManualEdited = preserveManual;
      }
      final line = AutoLineartEngine.render(
        _autoLineartPreviewGraph!,
        _previewW,
        _previewH,
        outputWidthPx: math.max(
          1.0,
          filter.autoLineartOutputWidth * _previewScale,
        ),
        taperLengthPx: filter.autoLineartTaperLength * _previewScale,
        smoothing: 0,
        color: filter.autoLineartColor,
      );
      filtered = AutoLineartEngine.composePreview(
        base,
        line,
        roughOpacity: 0.4,
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
    final previewSide = current?.kind == FilterKind.autoLineart ? 200.0 : 120.0;

    if (current != null && current.id != _previewFilterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updatePreview());
    }

    return Card(
      elevation: current == null ? 8 : 0,
      color: current == null ? null : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: SizedBox(
        width: 300,
        height: 520,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (current == null)
                PanelCenterCloseBar(onClose: widget.onClose)
              else
                // While editing, the filter list stays hidden to keep the
                // canvas visible; this returns to it without closing.
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('filter-back-to-list'),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      tooltip: l10n.filterBackToList,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: service.clearCurrentFilter,
                    ),
                    Expanded(
                      child: Text(
                        _filterDisplayName(l10n, current),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                    ),
                    PanelCenterCloseBar(onClose: widget.onClose),
                  ],
                ),
              if (current == null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bulk != null
                            ? l10n.filterPanelTitleBulk(bulk.length)
                            : l10n.filterPanelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Kuramubon',
                          fontFamilyFallback: kHeadingFontFallback,
                        ),
                      ),
                    ),
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
                      onPressed: () =>
                          setState(() => _showSearch = !_showSearch),
                    ),
                  ],
                ),
              if (current == null && _showSearch)
                TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.filterSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 16),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: service.setSearchQuery,
                ),
              if (current == null) const Divider(),
              if (current == null)
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
                        key: ValueKey('filter-card-${filter.id}'),
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
                                  : ThemeService
                                        .activeColorScheme
                                        .outlineVariant,
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
              if (current == null) const Divider(),
              if (current == null)
                Expanded(
                  child: Center(
                    // "No filters" only when the search or favourites leave
                    // none; otherwise point at the list above.
                    child: Text(
                      filters.isEmpty ? l10n.filterEmpty : l10n.filterPickHint,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: previewSide,
                            height: previewSide,
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child:
                                        current.kind ==
                                                FilterKind.autoLineart &&
                                            _autoLineartPreviewGraph != null &&
                                            (bulk == null || bulk.length <= 1)
                                        ? AutoLineartControlOverlay(
                                            image: _previewImage!,
                                            graph: _autoLineartPreviewGraph!,
                                            mode: _autoLineartControlMode,
                                            onPointMoved: (pathIndex, pointIndex, point) {
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
                                            onGraphChanged: (graph) {
                                              _autoLineartPreviewGraph = graph;
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
                        _buildControls(l10n, service, current),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('filter-undo-button'),
                      onPressed: service.canUndoFilterEdit
                          ? () {
                              service.undoFilterEdit();
                              _updatePreview();
                            }
                          : null,
                      icon: const Icon(Icons.undo, size: 18),
                      tooltip: 'Undo',
                    ),
                    IconButton(
                      key: const ValueKey('filter-redo-button'),
                      onPressed: service.canRedoFilterEdit
                          ? () {
                              service.redoFilterEdit();
                              _updatePreview();
                            }
                          : null,
                      icon: const Icon(Icons.redo, size: 18),
                      tooltip: 'Redo',
                    ),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('filter-apply-button'),
                        onPressed: widget.layerId == null || _applying
                            ? null
                            : _applyFilter,
                        icon: _applying
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.check, size: 16),
                        label: Text(
                          bulk != null
                              ? l10n.filterApplyBulkButton(bulk.length)
                              : l10n.filterApplyButton,
                        ),
                      ),
                    ),
                    if (current.kind == FilterKind.autoLineart) ...[
                      IconButton(
                        key: const ValueKey('auto-lineart-add-point-button'),
                        onPressed: () => setState(
                          () => _autoLineartControlMode =
                              _autoLineartControlMode ==
                                  AutoLineartControlMode.add
                              ? AutoLineartControlMode.move
                              : AutoLineartControlMode.add,
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        tooltip: l10n.filterAutoLineartAddPointTooltip,
                        isSelected:
                            _autoLineartControlMode ==
                            AutoLineartControlMode.add,
                      ),
                      IconButton(
                        key: const ValueKey('auto-lineart-delete-point-button'),
                        onPressed: () => setState(
                          () => _autoLineartControlMode =
                              _autoLineartControlMode ==
                                  AutoLineartControlMode.delete
                              ? AutoLineartControlMode.move
                              : AutoLineartControlMode.delete,
                        ),
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        tooltip: l10n.filterAutoLineartDeletePointTooltip,
                        isSelected:
                            _autoLineartControlMode ==
                            AutoLineartControlMode.delete,
                      ),
                    ],
                  ],
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
          Text(
            l10n.filterPrismDescription,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 6),
          _integerStepperSlider(
            l10n.filterPrismBlurAmount,
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
            l10n.filterPrismColorDirection,
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

    if (current.kind == FilterKind.noise) {
      return Column(
        children: [
          DropdownButtonFormField<NoiseStyle>(
            key: ValueKey('noise-style-${current.noiseStyle.name}'),
            decoration: InputDecoration(labelText: l10n.filterNoiseStyle),
            initialValue: current.noiseStyle,
            items: [
              DropdownMenuItem(
                value: NoiseStyle.filmGrain,
                child: Text(l10n.filterNoiseFilmGrain),
              ),
              DropdownMenuItem(
                value: NoiseStyle.color,
                child: Text(l10n.filterNoiseColor),
              ),
              DropdownMenuItem(
                value: NoiseStyle.vhs,
                child: Text(l10n.filterNameVhsNoise),
              ),
            ],
            onChanged: (style) {
              if (style != null) {
                service.updateFilterParams(current.id, noiseStyle: style);
                _updatePreview();
              }
            },
          ),
          _paramSlider(
            l10n.filterNoiseStrength,
            current.strength,
            0,
            100,
            (v) => service.updateFilterParams(current.id, strength: v),
          ),
          if (_isVhs(current)) ...[
            _paramSlider(
              l10n.filterVhsScanlineStrength,
              current.caSaturation,
              0,
              100,
              (v) => service.updateFilterParams(current.id, caSaturation: v),
            ),
            _paramSlider(
              l10n.filterVhsColorBleed,
              current.caBrightness,
              0,
              100,
              (v) => service.updateFilterParams(current.id, caBrightness: v),
            ),
            _paramSlider(
              l10n.filterVhsTracking,
              current.caContrast,
              0,
              100,
              (v) => service.updateFilterParams(current.id, caContrast: v),
            ),
          ],
          _integerStepperSlider(
            l10n.filterNoiseSeed,
            current.noiseSeed,
            0,
            65535,
            (v) => service.updateFilterParams(current.id, noiseSeed: v),
          ),
        ],
      );
    }

    switch (current.kind) {
      case FilterKind.gaussianBlur:
      case FilterKind.lensBlur:
      case FilterKind.prism:
        return _paramSlider(
          l10n.filterStrengthBlurRadius,
          current.strength,
          1,
          20,
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.mosaic:
        return _paramSlider(
          l10n.filterPixelateBlockSize,
          current.strength,
          1,
          64,
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
                _updatePreview();
              },
              suffix: 'px',
            ),
            _colorControl(
              l10n.autofillPartLineColorLabel,
              current.autoLineartColor,
              (c) =>
                  service.updateFilterParams(current.id, autoLineartColor: c),
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
              current.autoLineartSmoothing.round().clamp(0, 10),
              0,
              10,
              (v) {
                service.updateFilterParams(
                  current.id,
                  autoLineartSmoothing: v.toDouble(),
                );
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
        return Column(
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: ToneCurvePreset.values
                  .map(
                    (preset) => ChoiceChip(
                      label: Text(
                        _toneCurveLabel(l10n, preset),
                        style: const TextStyle(fontSize: 9),
                      ),
                      selected:
                          current.toneCurvePoints.isEmpty &&
                          current.toneCurvePreset == preset,
                      onSelected: (selected) {
                        if (!selected) return;
                        service.updateFilterParams(
                          current.id,
                          toneCurvePreset: preset,
                          toneCurvePoints: const [],
                        );
                        _updatePreview();
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              key: const ValueKey('tone-curve-channel-selector'),
              segments: const [
                ButtonSegment(value: 0, label: Text('RGB')),
                ButtonSegment(value: 1, label: Text('R')),
                ButtonSegment(value: 2, label: Text('G')),
                ButtonSegment(value: 3, label: Text('B')),
              ],
              selected: {_toneCurveChannel},
              showSelectedIcon: false,
              onSelectionChanged: (v) =>
                  setState(() => _toneCurveChannel = v.first),
            ),
            const SizedBox(height: 8),
            _ToneCurveEditor(
              key: ValueKey('tone-curve-editor-$_toneCurveChannel'),
              points: (() {
                final stored = switch (_toneCurveChannel) {
                  1 => current.toneCurveRedPoints,
                  2 => current.toneCurveGreenPoints,
                  3 => current.toneCurveBluePoints,
                  _ => current.toneCurvePoints,
                };
                if (stored.isEmpty) {
                  return _toneCurveChannel == 0
                      ? toneCurvePoints(
                          current.toneCurvePreset,
                        ).map((p) => Offset(p.dx, p.dy)).toList()
                      : const [Offset(0, 0), Offset(1, 1)];
                }
                return [
                  for (var i = 0; i + 1 < stored.length; i += 2)
                    Offset(stored[i], stored[i + 1]),
                ];
              })(),
              sourceRgba: _previewBase,
              histogramChannel: _toneCurveChannel,
              onChanged: (points) {
                final values = [
                  for (final p in points) ...[p.dx, p.dy],
                ];
                service.updateFilterParams(
                  current.id,
                  toneCurvePoints: _toneCurveChannel == 0 ? values : null,
                  toneCurveRedPoints: _toneCurveChannel == 1 ? values : null,
                  toneCurveGreenPoints: _toneCurveChannel == 2 ? values : null,
                  toneCurveBluePoints: _toneCurveChannel == 3 ? values : null,
                );
                _updatePreview();
              },
            ),
          ],
        );
      case FilterKind.levels:
        final channelValues = switch (_levelsChannel) {
          1 => current.levelsRed,
          2 => current.levelsGreen,
          3 => current.levelsBlue,
          _ => const <double>[],
        };
        final values = channelValues.length >= 5
            ? channelValues
            : <double>[
                current.inputBlack.toDouble(),
                current.inputWhite.toDouble(),
                current.inputGamma,
                current.outputBlack.toDouble(),
                current.outputWhite.toDouble(),
              ];
        void updateLevel(int index, double value) {
          if (_levelsChannel == 0) {
            if (index == 0) {
              service.updateFilterParams(current.id, inputBlack: value.round());
            } else if (index == 1) {
              service.updateFilterParams(current.id, inputWhite: value.round());
            } else if (index == 2) {
              service.updateFilterParams(current.id, inputGamma: value);
            } else if (index == 3) {
              service.updateFilterParams(
                current.id,
                outputBlack: value.round(),
              );
            } else {
              service.updateFilterParams(
                current.id,
                outputWhite: value.round(),
              );
            }
          } else {
            final next = [...values]..[index] = value;
            service.updateFilterParams(
              current.id,
              levelsRed: _levelsChannel == 1 ? next : null,
              levelsGreen: _levelsChannel == 2 ? next : null,
              levelsBlue: _levelsChannel == 3 ? next : null,
            );
          }
        }
        return Column(
          children: [
            SegmentedButton<int>(
              key: const ValueKey('levels-channel-selector'),
              segments: const [
                ButtonSegment(value: 0, label: Text('RGB')),
                ButtonSegment(value: 1, label: Text('R')),
                ButtonSegment(value: 2, label: Text('G')),
                ButtonSegment(value: 3, label: Text('B')),
              ],
              selected: {_levelsChannel},
              showSelectedIcon: false,
              onSelectionChanged: (v) =>
                  setState(() => _levelsChannel = v.first),
            ),
            const SizedBox(height: 8),
            _paramSlider(
              l10n.filterLevelsInputBlack,
              values[0],
              0,
              255,
              (v) => updateLevel(0, v),
            ),
            _paramSlider(
              l10n.filterLevelsInputWhite,
              values[1],
              0,
              255,
              (v) => updateLevel(1, v),
            ),
            _paramSlider(
              l10n.filterLevelsGamma,
              values[2],
              0.1,
              10.0,
              (v) => updateLevel(2, v),
            ),
            _paramSlider(
              l10n.filterLevelsOutputBlack,
              values[3],
              0,
              255,
              (v) => updateLevel(3, v),
            ),
            _paramSlider(
              l10n.filterLevelsOutputWhite,
              values[4],
              0,
              255,
              (v) => updateLevel(4, v),
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
        return Column(
          children: [
            _paramSlider(
              l10n.filterFisheyeStrength,
              current.strength,
              0,
              100,
              (v) => service.updateFilterParams(current.id, strength: v),
            ),
            _paramSlider(
              l10n.filterFisheyeRadius,
              current.fisheyeRadius,
              1,
              100,
              (v) => service.updateFilterParams(current.id, fisheyeRadius: v),
            ),
            _paramSlider(
              l10n.filterCenterX,
              current.fisheyeCenterX,
              -100,
              100,
              (v) => service.updateFilterParams(current.id, fisheyeCenterX: v),
            ),
            _paramSlider(
              l10n.filterCenterY,
              current.fisheyeCenterY,
              -100,
              100,
              (v) => service.updateFilterParams(current.id, fisheyeCenterY: v),
            ),
          ],
        );
      case FilterKind.chromaticAberration:
        return Column(
          children: [
            _paramSlider(
              l10n.filterChromaticAberrationStrength,
              current.strength,
              0,
              30,
              (v) => service.updateFilterParams(current.id, strength: v),
            ),
            _paramSlider(
              l10n.filterAxisX,
              current.chromaticShiftX,
              -30,
              30,
              (v) => service.updateFilterParams(current.id, chromaticShiftX: v),
            ),
            _paramSlider(
              l10n.filterAxisY,
              current.chromaticShiftY,
              -30,
              30,
              (v) => service.updateFilterParams(current.id, chromaticShiftY: v),
            ),
            _paramSlider(
              l10n.filterAxisZ,
              current.chromaticShiftZ,
              -180,
              180,
              (v) => service.updateFilterParams(current.id, chromaticShiftZ: v),
            ),
          ],
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
              title: Text(
                l10n.filterBgBlendAutoLight,
                style: const TextStyle(fontSize: 11),
              ),
              value: current.bgBlendAutoLight,
              onChanged: (v) {
                service.updateFilterParams(current.id, bgBlendAutoLight: v);
                _updatePreview();
              },
            ),
            _paramSlider(
              l10n.filterBgBlendStrength,
              current.bgBlendStrength,
              0,
              100,
              (v) => service.updateFilterParams(current.id, bgBlendStrength: v),
            ),
            _paramSlider(
              l10n.filterBgBlendLightStrength,
              current.bgBlendLightStrength,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendLightStrength: v,
              ),
            ),
            _paramSlider(
              l10n.filterBgBlendShadowStrength,
              current.bgBlendShadowStrength,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendShadowStrength: v,
              ),
            ),
            _paramSlider(
              l10n.filterBgBlendAmbient,
              current.bgBlendAmbientStrength,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendAmbientStrength: v,
              ),
            ),
            _paramSlider(
              l10n.filterBgBlendBounce,
              current.bgBlendReflectionStrength,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendReflectionStrength: v,
              ),
            ),
            _paramSlider(
              l10n.filterBgBlendColorSpill,
              current.bgBlendColorBleed,
              0,
              100,
              (v) =>
                  service.updateFilterParams(current.id, bgBlendColorBleed: v),
            ),
            _paramSlider(
              l10n.filterBgBlendSoftness,
              current.bgBlendSoftness,
              0,
              100,
              (v) => service.updateFilterParams(current.id, bgBlendSoftness: v),
            ),
            _paramSlider(
              l10n.filterBgBlendSecondary,
              current.bgBlendSecondaryStrength,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendSecondaryStrength: v,
              ),
            ),
            _paramSlider(
              l10n.filterBgBlendMaterialProtection,
              current.bgBlendMaterialProtection,
              0,
              100,
              (v) => service.updateFilterParams(
                current.id,
                bgBlendMaterialProtection: v,
              ),
            ),
            _paramSlider(
              l10n.filterBgBlendSamplingBand,
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
    if (filter.id == 'Filter0025') return l10n.filterNameInvert;
    // Its noise style can be changed, so it is named by its preset rather
    // than by style; otherwise it shares Film Grain's name.
    if (filter.id == FilterService.genericNoiseFilterId) {
      return l10n.filterNameGenericNoise;
    }
    if (_isPrism(filter)) return l10n.filterNamePrism;
    if (_isVhs(filter)) return l10n.filterNameVhsNoise;
    return switch (filter.kind) {
      FilterKind.prism => l10n.filterNamePrism,
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
      FilterKind.colorAdjust => l10n.filterNameColorAdjust,
      FilterKind.threshold => l10n.filterNameThreshold,
      FilterKind.fisheye => l10n.filterNameFisheye,
      FilterKind.chromaticAberration => l10n.filterNameChromaticAberration,
      FilterKind.lensDistortion => l10n.filterNameLensDistortion,
      FilterKind.pixelate => l10n.filterNamePixelate,
      FilterKind.mosaic => l10n.filterNameMosaic,
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
    AuroraHologramPreset.silverHologram =>
      l10n.filterAuroraHologramPresetSilverHologram,
    AuroraHologramPreset.sampledGold =>
      l10n.filterAuroraHologramPresetSampledGold,
    AuroraHologramPreset.silverFoil =>
      l10n.filterAuroraHologramPresetSilverFoil,
    AuroraHologramPreset.luminousPearl =>
      l10n.filterAuroraHologramPresetLuminousPearl,
    AuroraHologramPreset.auroraPastel =>
      l10n.filterAuroraHologramPresetAuroraPastel,
    AuroraHologramPreset.darkRainbow =>
      l10n.filterAuroraHologramPresetDarkRainbow,
  };

  IconData _iconForFilter(FilterDef filter) {
    if (_isPrism(filter)) return Icons.gradient;
    if (_isVhs(filter)) return Icons.video_settings;
    return switch (filter.kind) {
      FilterKind.prism => Icons.gradient,
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
      FilterKind.colorAdjust => Icons.tune,
      FilterKind.threshold => Icons.contrast,
      FilterKind.fisheye => Icons.panorama_fish_eye,
      FilterKind.chromaticAberration => Icons.color_lens,
      FilterKind.lensDistortion => Icons.remove_red_eye,
      FilterKind.pixelate => Icons.grid_view,
      FilterKind.mosaic => Icons.grid_on,
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
      case FilterKind.prism:
        return _prismEngine.apply(
          data,
          width,
          height,
          blurPx: filter.prismBlurPx * _previewScale,
          gradientDirectionDegrees: filter.prismDirectionDegrees,
        );
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
          filter.toneCurvePoints.length >= 4
              ? [
                  for (var i = 0; i + 1 < filter.toneCurvePoints.length; i += 2)
                    Offset(
                      filter.toneCurvePoints[i],
                      filter.toneCurvePoints[i + 1],
                    ),
                ]
              : toneCurvePoints(filter.toneCurvePreset),
          redPoints: filter.toneCurveRedPoints.length >= 4
              ? [
                  for (
                    var i = 0;
                    i + 1 < filter.toneCurveRedPoints.length;
                    i += 2
                  )
                    Offset(
                      filter.toneCurveRedPoints[i],
                      filter.toneCurveRedPoints[i + 1],
                    ),
                ]
              : null,
          greenPoints: filter.toneCurveGreenPoints.length >= 4
              ? [
                  for (
                    var i = 0;
                    i + 1 < filter.toneCurveGreenPoints.length;
                    i += 2
                  )
                    Offset(
                      filter.toneCurveGreenPoints[i],
                      filter.toneCurveGreenPoints[i + 1],
                    ),
                ]
              : null,
          bluePoints: filter.toneCurveBluePoints.length >= 4
              ? [
                  for (
                    var i = 0;
                    i + 1 < filter.toneCurveBluePoints.length;
                    i += 2
                  )
                    Offset(
                      filter.toneCurveBluePoints[i],
                      filter.toneCurveBluePoints[i + 1],
                    ),
                ]
              : null,
        );
      case FilterKind.levels:
        return _engine.applyLevels(
          data,
          width,
          height,
          inputBlack: filter.inputBlack,
          inputWhite: filter.inputWhite,
          inputGamma: filter.inputGamma,
          outputBlack: filter.outputBlack,
          outputWhite: filter.outputWhite,
          redLevels: filter.levelsRed.length >= 5 ? filter.levelsRed : null,
          greenLevels: filter.levelsGreen.length >= 5
              ? filter.levelsGreen
              : null,
          blueLevels: filter.levelsBlue.length >= 5 ? filter.levelsBlue : null,
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
        return applyNoiseFilter(data, width, height, filter);
      case FilterKind.retroAnime:
        return _engine.applyRetroAnime(data, width, height, filter.strength);
      case FilterKind.crt:
        return _engine.applyCrt(data, width, height, filter.strength);
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
        return _engine.applyFisheye(
          data,
          width,
          height,
          filter.strength,
          radiusPercent: filter.fisheyeRadius,
          centerOffsetX: filter.fisheyeCenterX * _previewScale,
          centerOffsetY: filter.fisheyeCenterY * _previewScale,
        );
      case FilterKind.chromaticAberration:
        return _engine.applyChromaticAberration(
          data,
          width,
          height,
          math.max(
            filter.strength,
            math.sqrt(
              filter.chromaticShiftX * filter.chromaticShiftX +
                  filter.chromaticShiftY * filter.chromaticShiftY,
            ),
          ),
          math.atan2(filter.chromaticShiftY, filter.chromaticShiftX) +
              filter.chromaticShiftZ * math.pi / 180.0,
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
      case FilterKind.mosaic:
        return _engine.applyMosaic(
          data,
          width,
          height,
          filter.strength.round().clamp(1, 64),
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
          AutoLineartEngine.prepareEditableGraph(
            AutoLineartEngine.analyze(
              data,
              width,
              height,
              roughWidthPx: filter.autoLineartRoughWidth * _previewScale,
            ),
            smoothingLevel: filter.autoLineartSmoothing.round().clamp(0, 10),
          ),
          width,
          height,
          outputWidthPx: math.max(
            1.0,
            filter.autoLineartOutputWidth * _previewScale,
          ),
          taperLengthPx: filter.autoLineartTaperLength * _previewScale,
          smoothing: 0,
          color: filter.autoLineartColor,
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
        if (mounted) {
          context.read<CustomAutomationService>().recordStep(
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.filterApply',
            label: filter.name,
            args: {'filter': filter.toJson()},
            recordedFrame: widget.frameIndex,
          );
        }
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
        color: filter.autoLineartColor,
      );
    } else if (_isPrism(filter)) {
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

    final layer = ps
        .layersOf(widget.projectId, widget.sceneId, frameIndex)
        .where((l) => l.id == layerId)
        .firstOrNull;
    ps.replaceLayerPixels(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      layerId: layerId,
      pixels: result,
      updatedLayer: layer != null && _isPrism(filter)
          ? layer.copyWith(blendMode: model.LayerBlendMode.linearDodge)
          : null,
    );
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
    final sourceIndex = ps
        .layersOf(widget.projectId, widget.sceneId, frameIndex)
        .indexWhere((layer) => layer.id == sourceLayerId);
    final created = ps.addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      type: model.LayerType.normal,
      name: nameBuilder(sourceName),
      id: generatedLayerId,
      insertIndex: sourceIndex + 1,
    );
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
    try {
      // One Undo takes the filter off every frame it was applied to.
      await ps.runWithGroupedUndo(
        description: 'Filter on ${sorted.length} frames',
        operation: () async {
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
        },
      );
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

class _ToneCurveEditor extends StatefulWidget {
  final List<Offset> points;
  final Uint8List? sourceRgba;
  final int histogramChannel;
  final ValueChanged<List<Offset>> onChanged;

  const _ToneCurveEditor({
    super.key,
    required this.points,
    required this.sourceRgba,
    required this.histogramChannel,
    required this.onChanged,
  });

  @override
  State<_ToneCurveEditor> createState() => _ToneCurveEditorState();
}

class _ToneCurveEditorState extends State<_ToneCurveEditor> {
  int? _dragIndex;

  List<Offset> get _points {
    final p =
        widget.points
            .map((e) => Offset(e.dx.clamp(0.0, 1.0), e.dy.clamp(0.0, 1.0)))
            .toList()
          ..sort((a, b) => a.dx.compareTo(b.dx));
    return p.length >= 2 ? p : const [Offset(0, 0), Offset(1, 1)];
  }

  int _nearest(List<Offset> points, Offset normalized, {double max = .07}) {
    var best = -1;
    var distance = max;
    for (var i = 0; i < points.length; i++) {
      final d = (points[i] - normalized).distance;
      if (d < distance) {
        best = i;
        distance = d;
      }
    }
    return best;
  }

  Offset _normalize(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (1 - local.dy / size.height).clamp(0.0, 1.0),
  );

  void _emit(List<Offset> points) {
    points.sort((a, b) => a.dx.compareTo(b.dx));
    widget.onChanged(points);
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    return AspectRatio(
      aspectRatio: 1.65,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final n = _normalize(details.localPosition, size);
              if (_nearest(points, n) >= 0) return;
              _emit([...points, n]);
            },
            onLongPressStart: (details) {
              final n = _normalize(details.localPosition, size);
              final i = _nearest(points, n);
              if (i <= 0 || i >= points.length - 1) return;
              final next = [...points]..removeAt(i);
              _emit(next);
            },
            onPanStart: (details) {
              final n = _normalize(details.localPosition, size);
              _dragIndex = _nearest(points, n, max: .10);
            },
            onPanUpdate: (details) {
              final i = _dragIndex;
              if (i == null || i < 0) return;
              final next = [...points];
              var n = _normalize(details.localPosition, size);
              if (i == 0) n = Offset(0, n.dy);
              if (i == next.length - 1) n = Offset(1, n.dy);
              if (i > 0 && i < next.length - 1) {
                n = Offset(
                  n.dx.clamp(next[i - 1].dx + .001, next[i + 1].dx - .001),
                  n.dy,
                );
              }
              next[i] = n;
              _emit(next);
            },
            onPanEnd: (_) => _dragIndex = null,
            child: CustomPaint(
              painter: _ToneCurvePainter(
                points: points,
                sourceRgba: widget.sourceRgba,
                histogramChannel: widget.histogramChannel,
                color: Theme.of(context).colorScheme.primary,
                gridColor: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToneCurvePainter extends CustomPainter {
  final List<Offset> points;
  final Uint8List? sourceRgba;
  final int histogramChannel;
  final Color color;
  final Color gridColor;

  const _ToneCurvePainter({
    required this.points,
    required this.sourceRgba,
    required this.histogramChannel,
    required this.color,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final rgba = sourceRgba;
    if (rgba != null && rgba.length >= 4) {
      final bins = List<int>.filled(64, 0);
      var peak = 1;
      for (var i = 0; i + 3 < rgba.length; i += 4) {
        if (rgba[i + 3] == 0) continue;
        final value = switch (histogramChannel) {
          1 => rgba[i],
          2 => rgba[i + 1],
          3 => rgba[i + 2],
          _ => ((rgba[i] * 77 + rgba[i + 1] * 150 + rgba[i + 2] * 29) >> 8),
        };
        final b = (value * 63 ~/ 255).clamp(0, 63);
        bins[b]++;
        if (bins[b] > peak) peak = bins[b];
      }
      final hp = Paint()
        ..color = gridColor.withValues(alpha: .35)
        ..style = PaintingStyle.fill;
      final path = Path()..moveTo(0, size.height);
      for (var i = 0; i < bins.length; i++) {
        path.lineTo(
          size.width * i / (bins.length - 1),
          size.height * (1 - bins[i] / peak),
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(path, hp);
    }

    Offset toCanvas(Offset p) =>
        Offset(p.dx * size.width, (1 - p.dy) * size.height);
    final curve = Path()
      ..moveTo(toCanvas(points.first).dx, toCanvas(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final p = toCanvas(points[i]);
      curve.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final pointPaint = Paint()..color = color;
    for (final p in points) {
      canvas.drawCircle(toCanvas(p), 5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ToneCurvePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.sourceRgba != sourceRgba ||
      oldDelegate.histogramChannel != histogramChannel ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
