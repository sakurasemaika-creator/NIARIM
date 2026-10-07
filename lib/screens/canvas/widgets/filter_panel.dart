import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/font_fallback.dart';
import '../../../engine/auto_lineart_engine.dart';
import '../../../engine/filter_engine.dart';
import '../../../engine/filter_lens_mask.dart';
import '../../../engine/filter_preview.dart';
import '../../../engine/filter_selection.dart';
import '../../../engine/layer_compositor.dart';
import '../../../engine/pixel_art_engine.dart';
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
import '../../../utils/blend_mode_label.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/grab_pan_gesture_recognizer.dart';
import '../../../widgets/pixel_color_mode_selector.dart';
import '../../../widgets/premium_lock_widget.dart';
import '../../../widgets/progress_dialog.dart';
import '../../../widgets/stepped_slider.dart';
import 'auto_lineart_control_overlay.dart';
import 'canvas_icon_button.dart';
import 'color_picker_panel.dart';
import 'panel_close_bar.dart';
import '../../../engine/premultiplied.dart';
import '../../../engine/tone_curve.dart';

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

  /// Laid out as a full-width bar along the bottom of the screen (phones,
  /// where the canvas chrome is hidden while a filter is adjusted) rather
  /// than as a narrow floating or docked panel.
  final bool bottomBar;

  /// Receives each new preview of the filter (the layer as it would look),
  /// to be shown on the canvas in place of the layer; the receiver owns the
  /// image. When set, the panel shows no preview of its own (auto line
  /// art's control-point editor aside).
  final ValueChanged<ui.Image>? onCanvasPreviewChanged;

  /// The canvas selection (one byte per canvas pixel, non-zero inside), or
  /// null: when set, the filter changes only what is inside it.
  final Uint8List? selectionMask;

  /// The glasses filter's lens area, painted on the canvas with the tools
  /// the panel offers while that filter is adjusted.
  final FilterLensMask? lensMask;

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
    this.bottomBar = false,
    this.onCanvasPreviewChanged,
    this.selectionMask,
    this.lensMask,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

/// The longest side of a filter's preview, in pixels. It is shown on the
/// canvas, so it is large enough to judge the result there; the filter runs
/// in a background isolate so the controls stay smooth.
const int kFilterPreviewMaxSide = 640;

/// The longest side auto line art analyses its rough lines at for the
/// preview (the analysis is the slow part; the lines render at any size).
const int _kLineartAnalysisMaxSide = 150;

/// The width of a setting's name (and value) in front of its slider when
/// the panel runs along the bottom of the screen.
const double _kBottomLabelWidth = 112;

class _FilterPanelState extends State<FilterPanel> {
  bool _showFavoritesOnly = false;
  bool _showSearch = false;
  bool _applying = false;
  int _toneCurveChannel = 0; // 0=RGB, 1=R, 2=G, 3=B
  int _levelsChannel = 0; // 0=RGB, 1=R, 2=G, 3=B
  // While editing, the controls can be folded away to leave only the name
  // and Undo / Redo / Apply over the canvas (to see it, and to reach what a
  // filter shows on it, such as sphere shading's light).
  bool _collapsed = false;

  Uint8List? _previewBase;
  // Auto line art's analysis copy of the layer (see _kLineartAnalysisMaxSide).
  Uint8List? _lineartBase;
  int _lineartW = 0;
  int _lineartH = 0;
  double _lineartScale = 1;
  // Only one preview runs in the background at a time; a change while it
  // runs asks for one more run with the latest settings.
  bool _previewRunning = false;
  bool _previewAgain = false;
  Uint8List? _previewMask;
  Uint8List? _previewBackgroundBytes;
  // The canvas selection and the glasses filter's lens area at the
  // preview's size (coverage, and the lens area as the RGBA mask the
  // filter reads), and the lens coverage that was scaled.
  Uint8List? _previewSelection;
  Uint8List? _previewLensMask;
  Uint8List? _previewLensMaskOf;
  // The glasses filter whose lens area has been started (from the
  // selection layer or the canvas selection), so it is started once.
  String? _lensMaskStartedFor;
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
  int _canvasW = 1;
  int _canvasH = 1;
  ui.Image? _previewImage;
  FilterDef? _previewRequestedFor;
  final Set<int> _editPointers = {};
  FilterService? _editGroupService;

  bool _isPrism(FilterDef filter) => filter.kind == FilterKind.prism;
  bool _isVhs(FilterDef filter) =>
      filter.kind == FilterKind.noise && filter.noiseStyle == NoiseStyle.vhs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FilterService>().clearCurrentFilter();
    });
    widget.lensMask?.addListener(_onLensMaskChanged);
    _loadPreviewBase();
  }

  @override
  void didUpdateWidget(FilterPanel old) {
    super.didUpdateWidget(old);
    if (old.lensMask != widget.lensMask) {
      old.lensMask?.removeListener(_onLensMaskChanged);
      widget.lensMask?.addListener(_onLensMaskChanged);
    }
    if (!identical(old.selectionMask, widget.selectionMask)) {
      _refreshPreviewSelection();
      _updatePreview();
    }
  }

  /// The canvas selection at the preview's size, or null when there is
  /// none (or it is not the canvas's size).
  void _refreshPreviewSelection() {
    final mask = widget.selectionMask;
    _previewSelection =
        mask == null || mask.length != _canvasW * _canvasH || _previewW == 0
        ? null
        : scaleSelectionCoverage(
            selectionCoverage(mask),
            _canvasW,
            _canvasH,
            _previewW,
            _previewH,
          );
  }

  /// The canvas selection at full size, as coverage, or null.
  Uint8List? _canvasSelectionCoverage(TileManager tm) {
    final mask = widget.selectionMask;
    if (mask == null || mask.length != tm.canvasWidth * tm.canvasHeight) {
      return null;
    }
    return selectionCoverage(mask);
  }

  void _onLensMaskChanged() {
    final mask = widget.lensMask;
    final coverage = mask?.coverage;
    if (!identical(coverage, _previewLensMaskOf)) {
      _previewLensMaskOf = coverage;
      _previewLensMask =
          coverage == null ||
              mask == null ||
              _previewW == 0 ||
              coverage.length != mask.width * mask.height
          ? null
          : coverageAsRgbaMask(
              scaleSelectionCoverage(
                coverage,
                mask.width,
                mask.height,
                _previewW,
                _previewH,
              ),
            );
      _updatePreview();
    }
    if (mounted) setState(() {});
  }

  /// Starts the glasses filter's lens area from what is already marked:
  /// the selection layer's paint, else the canvas selection, else nothing
  /// (with the pen ready, to paint it).
  Future<void> _startLensMask() async {
    final mask = widget.lensMask;
    if (mask == null) return;
    final ps = context.read<ProjectService>();
    final tm = ps.tileManagerOf(widget.projectId);
    final w = tm.canvasWidth, h = tm.canvasHeight;
    Uint8List? initial;
    final selectionLayer = ps
        .layersOf(widget.projectId, widget.sceneId, widget.frameIndex)
        .where((l) => l.type == model.LayerType.selection)
        .firstOrNull;
    if (selectionLayer != null) {
      final image = await tm.compositeLayerToImage(
        ps.tileKeyFor(
          widget.projectId,
          widget.sceneId,
          widget.frameIndex,
          selectionLayer.id,
        ),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (bytes != null) {
        final coverage = rgbaMaskCoverage(bytes.buffer.asUint8List());
        if (selectsAnything(coverage)) initial = coverage;
      }
    }
    initial ??= _canvasSelectionCoverage(tm);
    if (!mounted || widget.lensMask != mask) return;
    mask.replace(selectsAnything(initial) ? initial : null, w, h);
    mask.setTool(FilterLensMaskTool.pen);
  }

  @override
  void dispose() {
    widget.lensMask?.removeListener(_onLensMaskChanged);
    _previewImage?.dispose();
    _editGroupService?.endFilterEditGroup();
    super.dispose();
  }

  void _editPointerDown(int pointer) {
    if (_editPointers.add(pointer) && _editPointers.length == 1) {
      _editGroupService = context.read<FilterService>()..beginFilterEditGroup();
    }
  }

  void _editPointerUp(int pointer) {
    if (_editPointers.remove(pointer) && _editPointers.isEmpty) {
      _recordAutoLineartHandEdit();
      _editGroupService?.endFilterEditGroup();
      _editGroupService = null;
    }
  }

  // Auto line art's control points as they were before the touch (or the
  // confirmed delete) now editing them by hand; null when none is pending.
  ({AutoLineartGraph? graph, bool manual})? _autoLineartBeforeHandEdit;

  void _moveAutoLineartPoint(
    int pathIndex,
    int pointIndex,
    AutoLineartPoint point,
  ) {
    _autoLineartBeforeHandEdit ??= (
      graph: _autoLineartPreviewGraph,
      manual: _autoLineartManualEdited,
    );
    _autoLineartPreviewGraph = AutoLineartEngine.moveControlPoint(
      _autoLineartPreviewGraph!,
      pathIndex: pathIndex,
      pointIndex: pointIndex,
      point: point,
    );
    _autoLineartManualEdited = true;
    _scheduleAutoLineartPreviewUpdate();
  }

  void _replaceAutoLineartGraph(AutoLineartGraph graph) {
    _autoLineartBeforeHandEdit ??= (
      graph: _autoLineartPreviewGraph,
      manual: _autoLineartManualEdited,
    );
    _autoLineartPreviewGraph = graph;
    _autoLineartManualEdited = true;
    _scheduleAutoLineartPreviewUpdate();
    // A delete confirmed in a dialog comes after the touch has ended.
    if (_editPointers.isEmpty) _recordAutoLineartHandEdit();
  }

  /// Puts the control-point edit just finished into the filter's Undo
  /// history, in order with the settings' own steps: one drag, one tap or
  /// one confirmed delete is one step.
  void _recordAutoLineartHandEdit() {
    final before = _autoLineartBeforeHandEdit;
    _autoLineartBeforeHandEdit = null;
    if (before == null || identical(before.graph, _autoLineartPreviewGraph)) {
      return;
    }
    final after = (
      graph: _autoLineartPreviewGraph,
      manual: _autoLineartManualEdited,
    );
    void restore(({AutoLineartGraph? graph, bool manual}) state) {
      if (!mounted) return;
      setState(() {
        _autoLineartPreviewGraph = state.graph;
        _autoLineartManualEdited = state.manual;
      });
      _scheduleAutoLineartPreviewUpdate();
    }

    context.read<FilterService>().recordFilterEdit(
      undo: () => restore(before),
      redo: () => restore(after),
    );
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
    const maxSize = kFilterPreviewMaxSide;
    final scale = math.min(1.0, maxSize / math.max(width, height));
    final previewWidth = (width * scale).round().clamp(1, maxSize);
    final previewHeight = (height * scale).round().clamp(1, maxSize);
    final lineartScale = math.min(
      1.0,
      _kLineartAnalysisMaxSide / math.max(width, height),
    );
    final lineartWidth = (width * lineartScale).round().clamp(
      1,
      _kLineartAnalysisMaxSide,
    );
    final lineartHeight = (height * lineartScale).round().clamp(
      1,
      _kLineartAnalysisMaxSide,
    );
    final lineartBytes = await _downscaleToBytes(
      image.clone(),
      width,
      height,
      lineartWidth,
      lineartHeight,
    );
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
    _canvasW = width;
    _canvasH = height;
    _previewBase = bytes;
    _lineartBase = lineartBytes;
    _lineartW = lineartWidth;
    _lineartH = lineartHeight;
    _lineartScale = lineartScale;
    _previewMask = maskBytes;
    _previewBackgroundBytes = backgroundBytes;
    _previewW = previewWidth;
    _previewH = previewHeight;
    _refreshPreviewSelection();
    // The lens area may have been started before the preview's size was
    // known.
    _previewLensMaskOf = null;
    _onLensMaskChanged();
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
    _previewRequestedFor = filter;
    if (base == null || filter == null || !mounted) return;
    if (_previewRunning) {
      _previewAgain = true;
      return;
    }
    _previewRunning = true;
    try {
      await _runPreview(base, filter);
    } finally {
      _previewRunning = false;
    }
    if (_previewAgain && mounted) {
      _previewAgain = false;
      await _updatePreview();
    }
  }

  Future<void> _runPreview(Uint8List base, FilterDef filter) async {
    final previewRevision = ++_autoLineartPreviewRevision;
    final Uint8List filtered;
    final lineartBase = _lineartBase;
    if (filter.kind == FilterKind.autoLineart && lineartBase != null) {
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
          // Analysed on a small copy; the graph renders at any size.
          _autoLineartBaseGraph = AutoLineartEngine.analyze(
            lineartBase,
            _lineartW,
            _lineartH,
            roughWidthPx: math.max(
              2.0,
              filter.autoLineartRoughWidth * _lineartScale,
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
      final composed = AutoLineartEngine.composePreview(
        base,
        line,
        roughOpacity: 0.4,
      );
      final selection = _previewSelection;
      filtered = selection == null
          ? composed
          : restrictToSelection(base, composed, selection);
    } else {
      final selection = _previewSelection;
      // The glasses filter bends its own lens area (started from the
      // selection); sphere shading takes the selection as its area when no
      // selection layer is painted.
      final mask = switch (filter.kind) {
        FilterKind.lensDistortion when widget.lensMask != null =>
          _previewLensMask,
        FilterKind.sphereShading
            when _previewMask == null && selection != null =>
          coverageAsRgbaMask(selection),
        _ => _previewMask,
      };
      filtered = await compute(runFilterPreviewInSelection, (
        (
          filter: filter,
          data: base,
          width: _previewW,
          height: _previewH,
          scale: _previewScale,
          canvasWidth: _canvasW,
          canvasHeight: _canvasH,
          mask: mask,
          background: _previewBackgroundBytes,
        ),
        filter.kind == FilterKind.lensDistortion ? null : selection,
      ));
      if (!mounted) return;
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
    });
    widget.onCanvasPreviewChanged?.call(image.clone());
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

    // Also follows changes made outside the panel (dragging sphere
    // shading's light or the fisheye's centre on the canvas). Every change
    // replaces the filter, so identity says whether this one was previewed.
    if (current != null && !identical(current, _previewRequestedFor)) {
      _previewRequestedFor = current;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updatePreview();
      });
    }
    final lensFilterId = current?.kind == FilterKind.lensDistortion
        ? current!.id
        : null;
    if (lensFilterId != _lensMaskStartedFor && widget.lensMask != null) {
      _lensMaskStartedFor = lensFilterId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (lensFilterId == null) {
          widget.lensMask?.reset();
        } else {
          unawaited(_startLensMask());
        }
      });
    }

    if (widget.bottomBar) {
      return _buildBottomBar(context, l10n, service, filters, current);
    }

    // While a filter is edited the panel floats over the canvas with no
    // background, and touches on its empty parts go through to the canvas
    // (a Card would take them, as would the scroll view's own area).
    final shell = current == null
        ? (Widget child) => Card(
            elevation: 8,
            surfaceTintColor: Colors.transparent,
            child: child,
          )
        : (Widget child) =>
              Material(type: MaterialType.transparency, child: child);
    final collapsed = current != null && _collapsed;
    return shell(
      SizedBox(
        width: 300,
        height: collapsed ? null : 520,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _outlinedOverCanvas(
            context,
            enabled: current != null,
            child: Column(
              mainAxisSize: collapsed ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: current == null
                  ? [
                      PanelCenterCloseBar(onClose: widget.onClose),
                      _listTitleRow(l10n),
                      if (_showSearch) _searchField(l10n, service),
                      const Divider(),
                      _filterCards(l10n, service, filters, current),
                      const Divider(),
                      Expanded(
                        child: Center(
                          // "No filters" only when the search or favourites
                          // leave none; otherwise point at the list above.
                          child: Text(
                            filters.isEmpty
                                ? l10n.filterEmpty
                                : l10n.filterPickHint,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ]
                  : [
                      _editHeader(l10n, service, current, collapsed),
                      if (!collapsed)
                        Expanded(child: _editControls(l10n, service, current)),
                      const SizedBox(height: 8),
                      _actionRow(l10n, service, current),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  /// Phones: the panel runs along the bottom of the screen at full width,
  /// under the canvas (whose chrome is hidden meanwhile), so it never covers
  /// the picture, and the preview shows on the canvas itself.
  Widget _buildBottomBar(
    BuildContext context,
    AppLocalizations l10n,
    FilterService service,
    List<FilterDef> filters,
    FilterDef? current,
  ) {
    final collapsed = current != null && _collapsed;
    final maxControls = MediaQuery.sizeOf(context).height * 0.3;
    return Material(
      key: const ValueKey('filter-bottom-bar'),
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: _outlinedOverCanvas(
          context,
          enabled: current != null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: current == null
                ? [
                    _listTitleRow(l10n, withClose: true),
                    if (_showSearch) _searchField(l10n, service),
                    _filterCards(l10n, service, filters, current),
                    if (filters.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          l10n.filterEmpty,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ]
                : [
                    _editHeader(l10n, service, current, collapsed),
                    if (!collapsed)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxControls),
                        child: _editControls(l10n, service, current),
                      ),
                    const SizedBox(height: 4),
                    _actionRow(l10n, service, current),
                  ],
          ),
        ),
      ),
    );
  }

  /// The list's title, favourites-only and search toggles (and, in the
  /// bottom bar, the close button).
  Widget _listTitleRow(AppLocalizations l10n, {bool withClose = false}) {
    final bulk = widget.bulkFrameIndices;
    return Row(
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
          onPressed: () =>
              setState(() => _showFavoritesOnly = !_showFavoritesOnly),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.search, size: 18),
          onPressed: () => setState(() => _showSearch = !_showSearch),
        ),
        if (withClose) PanelCenterCloseBar(onClose: widget.onClose),
      ],
    );
  }

  Widget _searchField(AppLocalizations l10n, FilterService service) =>
      TextField(
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.filterSearchHint,
          prefixIcon: const Icon(Icons.search, size: 16),
        ),
        style: const TextStyle(fontSize: 12),
        onChanged: service.setSearchQuery,
      );

  /// The filters to choose from, as a row of cards.
  Widget _filterCards(
    AppLocalizations l10n,
    FilterService service,
    List<FilterDef> filters,
    FilterDef? current,
  ) {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final premium = _premiumFeatureFor(filter.kind);
          final locked =
              premium != null &&
              !context.watch<PremiumService>().isFeatureAvailable(premium);
          final selected = filter.id == current?.id;
          final child = GestureDetector(
            key: ValueKey('filter-card-${filter.id}'),
            onTap: locked ? null : () => service.selectFilter(filter.id),
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
                      filter.isFavorite ? Icons.star : Icons.star_outline,
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
    );
  }

  /// The edited filter's name, with the way back to the list, the button
  /// that folds the controls away and the close button.
  Widget _editHeader(
    AppLocalizations l10n,
    FilterService service,
    FilterDef current,
    bool collapsed,
  ) {
    return Row(
      children: [
        // While editing, the filter list stays hidden to keep the canvas
        // visible; this returns to it without closing.
        IconButton(
          key: const ValueKey('filter-back-to-list'),
          icon: const Icon(Icons.arrow_back, size: 18),
          tooltip: l10n.filterBackToList,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
        IconButton(
          key: const ValueKey('filter-collapse-button'),
          icon: Icon(
            collapsed ? Icons.expand_less : Icons.expand_more,
            size: 18,
          ),
          tooltip: collapsed
              ? l10n.filterPanelExpand
              : l10n.filterPanelCollapse,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: () => setState(() => _collapsed = !_collapsed),
        ),
        PanelCenterCloseBar(onClose: widget.onClose),
      ],
    );
  }

  /// The edited filter's controls, scrolling when they don't fit. When the
  /// canvas shows the preview there is no preview box here, except auto
  /// line art's control-point editor.
  Widget _editControls(
    AppLocalizations l10n,
    FilterService service,
    FilterDef current,
  ) {
    final bulk = widget.bulkFrameIndices;
    final lineartEditor =
        current.kind == FilterKind.autoLineart &&
        (bulk == null || bulk.length <= 1);
    final showPreviewBox =
        lineartEditor || widget.onCanvasPreviewChanged == null;
    final previewSide = current.kind == FilterKind.autoLineart ? 200.0 : 120.0;
    // One touch on the controls (a slider drag, a curve drag) is one step
    // for the filter's Undo.
    return Listener(
      onPointerDown: (e) => _editPointerDown(e.pointer),
      onPointerUp: (e) => _editPointerUp(e.pointer),
      onPointerCancel: (e) => _editPointerUp(e.pointer),
      // The app's scroll behaviour shows the scrollbar on the right; the
      // padding keeps the controls clear of it.
      child: SingleChildScrollView(
        hitTestBehavior: HitTestBehavior.deferToChild,
        padding: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showPreviewBox) ...[
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child:
                              lineartEditor && _autoLineartPreviewGraph != null
                              ? AutoLineartControlOverlay(
                                  image: _previewImage!,
                                  graph: _autoLineartPreviewGraph!,
                                  mode: _autoLineartControlMode,
                                  onPointMoved: _moveAutoLineartPoint,
                                  onGraphChanged: _replaceAutoLineartGraph,
                                )
                              : RawImage(
                                  image: _previewImage,
                                  fit: BoxFit.contain,
                                ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (widget.selectionMask != null &&
                current.kind != FilterKind.lensDistortion)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.highlight_alt,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        l10n.filterSelectionOnlyHint,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            _buildControls(l10n, service, current),
          ],
        ),
      ),
    );
  }

  /// Undo / Redo of the filter's settings, Apply, and auto line art's
  /// control-point modes.
  Widget _actionRow(
    AppLocalizations l10n,
    FilterService service,
    FilterDef current,
  ) {
    final bulk = widget.bulkFrameIndices;
    return Row(
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
          tooltip: l10n.commonUndo,
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
          tooltip: l10n.commonRedo,
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
        ),
        if (current.kind == FilterKind.autoLineart) ...[
          IconButton(
            key: const ValueKey('auto-lineart-add-point-button'),
            onPressed: () => setState(
              () => _autoLineartControlMode =
                  _autoLineartControlMode == AutoLineartControlMode.add
                  ? AutoLineartControlMode.move
                  : AutoLineartControlMode.add,
            ),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            tooltip: l10n.filterAutoLineartAddPointTooltip,
            isSelected: _autoLineartControlMode == AutoLineartControlMode.add,
          ),
          IconButton(
            key: const ValueKey('auto-lineart-delete-point-button'),
            onPressed: () => setState(
              () => _autoLineartControlMode =
                  _autoLineartControlMode == AutoLineartControlMode.delete
                  ? AutoLineartControlMode.move
                  : AutoLineartControlMode.delete,
            ),
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            tooltip: l10n.filterAutoLineartDeletePointTooltip,
            isSelected:
                _autoLineartControlMode == AutoLineartControlMode.delete,
          ),
        ],
      ],
    );
  }

  /// While a filter is being edited the panel has no background and floats
  /// over the canvas, like the canvas toolbar: give its text and icons the
  /// toolbar's outline so they read over any picture.
  Widget _outlinedOverCanvas(
    BuildContext context, {
    required bool enabled,
    required Widget child,
  }) {
    if (!enabled) return child;
    final shadows = CanvasIconButton.outlineShadows(
      context.watch<ThemeService>().current.menuBgColor,
    );
    return DefaultTextStyle.merge(
      style: TextStyle(shadows: shadows),
      child: IconTheme.merge(
        data: IconThemeData(shadows: shadows),
        child: child,
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
            decoration: _overCanvasDecoration(label: l10n.filterNoiseStyle),
            style: _overCanvasTextStyle(),
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
      case FilterKind.sphereShading:
        return _sphereShadingControls(l10n, service, current);
      case FilterKind.gaussianBlur:
      case FilterKind.lensBlur:
      case FilterKind.prism:
        return _paramSlider(
          l10n.filterStrengthBlurRadius,
          current.strength,
          1,
          60,
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.mosaic:
        return _paramSlider(
          l10n.filterPixelateBlockSize,
          current.strength,
          1,
          kPixelArtMaxBlockSize.toDouble(),
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.pixelate:
        // The block size and the dot counts are two views of one size (the
        // filter's strength): setting either moves the other, and the counts
        // are always the dots the result really has on this canvas.
        final canvas = context.read<ProjectService>().tileManagerOf(
          widget.projectId,
        );
        final canvasW = canvas.canvasWidth, canvasH = canvas.canvasHeight;
        final cell = current.pixelArtCellSize(canvasW, canvasH);
        int dotsAlong(int side, double size) =>
            PixelArtEngine.cellEdges(side, size).length - 1;
        final wide = dotsAlong(canvasW, cell);
        final high = dotsAlong(canvasH, cell);
        void setDots(int count, {required bool vertical}) {
          final side = vertical ? canvasH : canvasW;
          service.updateFilterParams(
            current.id,
            strength: side / count.clamp(1, side),
          );
        }

        return Column(
          children: [
            SegmentedButton<bool>(
              key: const ValueKey('pixel-art-size-mode'),
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l10n.filterPixelateModeBlock),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.filterPixelateModeDots),
                ),
              ],
              selected: {current.pixelArtByDots},
              showSelectedIcon: false,
              onSelectionChanged: (v) {
                service.updateFilterParams(current.id, pixelArtByDots: v.first);
                _updatePreview();
              },
            ),
            const SizedBox(height: 6),
            if (current.pixelArtByDots) ...[
              // Dots across and down, from 1 to the canvas's own size. Both
              // set the same square dot, so moving one moves the other and
              // the picture keeps its proportions.
              _integerStepperSlider(
                l10n.filterPixelateDotsWide,
                wide,
                1,
                canvasW,
                (n) => setDots(n, vertical: false),
                key: const ValueKey('pixel-art-dots-wide'),
              ),
              _integerStepperSlider(
                l10n.filterPixelateDotsHigh,
                high,
                1,
                canvasH,
                (n) => setDots(n, vertical: true),
                key: const ValueKey('pixel-art-dots-high'),
              ),
            ] else ...[
              _paramSlider(
                l10n.filterPixelateBlockSize,
                cell,
                1,
                kPixelArtMaxBlockSize.toDouble(),
                (v) => service.updateFilterParams(
                  current.id,
                  strength: v.roundToDouble(),
                ),
                shownValue: cell,
              ),
              Text(
                l10n.filterPixelateDotsSummary(wide, high),
                key: const ValueKey('pixel-art-dots-summary'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            PixelColorModeSelector(
              decoration: _overCanvasDecoration(),
              style: _overCanvasTextStyle(),
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
            _paramSlider(
              l10n.filterAnimeLineWidth,
              current.animeLineWidth,
              0,
              5,
              (v) => service.updateFilterParams(
                current.id,
                animeLineWidth: v.roundToDouble(),
              ),
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
            _paramSlider(
              l10n.filterOutlineErosion,
              current.outlineErosion,
              0,
              100,
              (v) => service.updateFilterParams(current.id, outlineErosion: v),
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
        // A channel's own levels apply on top of the RGB ones, so an
        // untouched channel starts at the defaults (no change).
        final values = channelValues.length >= 5
            ? channelValues
            : _levelsChannel == 0
            ? <double>[
                current.inputBlack.toDouble(),
                current.inputWhite.toDouble(),
                current.inputGamma,
                current.outputBlack.toDouble(),
                current.outputWhite.toDouble(),
              ]
            : const <double>[0, 255, 1, 0, 255];
        void updateLevel(int index, double rawValue) {
          // The input black stays below the input white.
          final value = switch (index) {
            0 => math.min(rawValue, values[1] - 1),
            1 => math.max(rawValue, values[0] + 1),
            _ => rawValue,
          };
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
        return _paramSlider(
          l10n.filterRetroStrength,
          current.strength,
          0,
          100,
          (v) => service.updateFilterParams(current.id, strength: v),
        );
      case FilterKind.crt:
        return Column(
          children: [
            _paramSlider(
              l10n.filterCrtScreenStrength,
              current.strength,
              0,
              100,
              (v) => service.updateFilterParams(current.id, strength: v),
            ),
            _paramSlider(
              l10n.filterCrtAberration,
              current.crtAberration,
              0,
              100,
              (v) => service.updateFilterParams(current.id, crtAberration: v),
            ),
            _paramSlider(
              l10n.filterCrtBleed,
              current.crtBleed,
              0,
              100,
              (v) => service.updateFilterParams(current.id, crtBleed: v),
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
        return Column(
          children: [
            // Above 0 the middle bulges (a fisheye), below 0 it pinches.
            _paramSlider(
              l10n.filterFisheyeStrength,
              current.strength,
              -100,
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
            // Moves the centre from the middle by a percentage of the
            // canvas: ±50 reaches the edges.
            _paramSlider(
              l10n.filterCenterX,
              current.fisheyeCenterX,
              -50,
              50,
              (v) => service.updateFilterParams(current.id, fisheyeCenterX: v),
            ),
            _paramSlider(
              l10n.filterCenterY,
              current.fisheyeCenterY,
              -50,
              50,
              (v) => service.updateFilterParams(current.id, fisheyeCenterY: v),
            ),
            _hint(l10n.filterFisheyeCanvasHint),
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
            // How much of the shift goes sideways (X, Y) and radially (Z).
            _paramSlider(
              l10n.filterAxisX,
              current.chromaticShiftX,
              -100,
              100,
              (v) => service.updateFilterParams(current.id, chromaticShiftX: v),
            ),
            _paramSlider(
              l10n.filterAxisY,
              current.chromaticShiftY,
              -100,
              100,
              (v) => service.updateFilterParams(current.id, chromaticShiftY: v),
            ),
            _paramSlider(
              l10n.filterAxisZ,
              current.chromaticShiftZ,
              -100,
              100,
              (v) => service.updateFilterParams(current.id, chromaticShiftZ: v),
            ),
          ],
        );
      case FilterKind.lensDistortion:
        return Column(
          children: [
            _lensMaskControls(l10n),
            if (widget.lensMask?.isEmpty ?? _previewMask == null)
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

  /// A dropdown over the canvas: no filled box behind it (the panel is
  /// see-through while a filter is edited), only a line under it.
  InputDecoration _overCanvasDecoration({String? label}) {
    final line = UnderlineInputBorder(
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: false,
      border: line,
      enabledBorder: line,
      labelStyle: _overCanvasTextStyle(),
    );
  }

  /// The panel's text over the canvas: outlined in the menu colour, as
  /// [_outlinedOverCanvas] gives the rest of the editing controls.
  TextStyle _overCanvasTextStyle() =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
        fontSize: 12,
        shadows: CanvasIconButton.outlineShadows(
          context.read<ThemeService>().current.menuBgColor,
        ),
      );

  /// A short note under a filter's controls.
  /// The glasses filter's lens area: the tool a touch on the canvas uses
  /// (pen, eraser, or the bucket, which adds the region tapped as the magic
  /// wand would select it), the pen's size, and clearing it. Each stroke,
  /// fill or clear is one step of the filter's Undo.
  Widget _lensMaskControls(AppLocalizations l10n) {
    final mask = widget.lensMask;
    if (mask == null) return const SizedBox.shrink();
    final tool = mask.tool;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.filterLensMaskTitle,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SegmentedButton<FilterLensMaskTool>(
                  key: const ValueKey('lens-mask-tool'),
                  segments: [
                    ButtonSegment(
                      value: FilterLensMaskTool.pen,
                      icon: const Icon(Icons.brush, size: 16),
                      label: Text(l10n.filterLensMaskPen),
                    ),
                    ButtonSegment(
                      value: FilterLensMaskTool.eraser,
                      icon: const Icon(Icons.auto_fix_normal, size: 16),
                      label: Text(l10n.filterLensMaskEraser),
                    ),
                    ButtonSegment(
                      value: FilterLensMaskTool.bucket,
                      icon: const Icon(Icons.format_color_fill, size: 16),
                      label: Text(l10n.filterLensMaskBucket),
                    ),
                  ],
                  selected: {?tool},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: (v) =>
                      mask.setTool(v.isEmpty ? null : v.first),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('lens-mask-clear'),
              tooltip: l10n.filterLensMaskClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: mask.isEmpty
                  ? null
                  : () => mask.edit(
                      null,
                      mask.width,
                      mask.height,
                      context.read<FilterService>().recordFilterEdit,
                    ),
            ),
          ],
        ),
        if (tool == FilterLensMaskTool.pen || tool == FilterLensMaskTool.eraser)
          _paramSlider(
            l10n.filterLensMaskBrushSize,
            mask.brushRadius,
            2,
            80,
            mask.setBrushRadius,
          ),
      ],
    );
  }

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  /// A blend mode picker (all of the layer blend modes).
  Widget _blendModeControl(
    String label,
    model.LayerBlendMode value,
    ValueChanged<model.LayerBlendMode> onChanged, {
    required String keyName,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: DropdownButtonFormField<model.LayerBlendMode>(
        // The value is part of the key so Undo, which changes it from
        // outside, shows the restored mode.
        key: ValueKey('$keyName-${value.name}'),
        decoration: _overCanvasDecoration(label: label),
        style: _overCanvasTextStyle(),
        initialValue: value,
        isExpanded: true,
        items: [
          for (final mode in model.LayerBlendMode.values)
            DropdownMenuItem(
              value: mode,
              child: Text(
                blendModeLabel(l10n, mode),
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
        onChanged: (mode) {
          if (mode == null) return;
          onChanged(mode);
          _updatePreview();
        },
      ),
    );
  }

  /// Sphere shading: the two colours and their blend modes (each its own,
  /// or both as one map in one mode), and the light ellipse, which can also
  /// be dragged on the canvas.
  Widget _sphereShadingControls(
    AppLocalizations l10n,
    FilterService service,
    FilterDef current,
  ) {
    final combined = current.sphereCombined;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          key: const ValueKey('sphere-shading-mode'),
          segments: [
            ButtonSegment(
              value: false,
              label: Text(l10n.filterSphereModeSeparate),
            ),
            ButtonSegment(
              value: true,
              label: Text(l10n.filterSphereModeCombined),
            ),
          ],
          selected: {combined},
          showSelectedIcon: false,
          onSelectionChanged: (v) {
            service.updateFilterParams(current.id, sphereCombined: v.first);
            _updatePreview();
          },
        ),
        if (combined) _hint(l10n.filterSphereCombinedHint),
        // Each colour with its blend mode on the same row.
        _colorControl(
          l10n.filterSphereShadowColor,
          current.sphereShadowColor,
          (c) => service.updateFilterParams(current.id, sphereShadowColor: c),
          trailing: combined
              ? null
              : _blendModeControl(
                  l10n.filterSphereShadowBlend,
                  current.sphereShadowBlend,
                  (m) => service.updateFilterParams(
                    current.id,
                    sphereShadowBlend: m,
                  ),
                  keyName: 'sphere-shadow-blend',
                ),
        ),
        _colorControl(
          l10n.filterSphereLightColor,
          current.sphereLightColor,
          (c) => service.updateFilterParams(current.id, sphereLightColor: c),
          trailing: combined
              ? null
              : _blendModeControl(
                  l10n.filterSphereLightBlend,
                  current.sphereLightBlend,
                  (m) => service.updateFilterParams(
                    current.id,
                    sphereLightBlend: m,
                  ),
                  keyName: 'sphere-light-blend',
                ),
        ),
        if (combined)
          _blendModeControl(
            l10n.filterSphereBlend,
            current.sphereCombinedBlend,
            (m) =>
                service.updateFilterParams(current.id, sphereCombinedBlend: m),
            keyName: 'sphere-combined-blend',
          ),
        _paramSlider(
          l10n.filterSphereLightX,
          current.sphereLightX,
          0,
          100,
          (v) => service.updateFilterParams(current.id, sphereLightX: v),
        ),
        _paramSlider(
          l10n.filterSphereLightY,
          current.sphereLightY,
          0,
          100,
          (v) => service.updateFilterParams(current.id, sphereLightY: v),
        ),
        _paramSlider(
          l10n.filterSphereLightWidth,
          current.sphereLightWidth,
          1,
          200,
          (v) => service.updateFilterParams(current.id, sphereLightWidth: v),
        ),
        _paramSlider(
          l10n.filterSphereLightHeight,
          current.sphereLightHeight,
          1,
          200,
          (v) => service.updateFilterParams(current.id, sphereLightHeight: v),
        ),
        _paramSlider(
          l10n.filterSphereLightBlur,
          current.sphereLightBlur,
          0,
          100,
          (v) => service.updateFilterParams(current.id, sphereLightBlur: v),
        ),
        _paramSlider(
          l10n.filterSphereShadowBlur,
          current.sphereShadowBlur,
          0,
          100,
          (v) => service.updateFilterParams(current.id, sphereShadowBlur: v),
        ),
        _hint(l10n.filterSphereCanvasHint),
      ],
    );
  }

  Widget _colorControl(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    FilterColorEyedropperTarget? eyedropperTarget,
    // Shown after the colour chip on the same row (a blend mode for it).
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (widget.bottomBar)
            SizedBox(
              width: _kBottomLabelWidth,
              child: Text(label, style: const TextStyle(fontSize: 11)),
            )
          else
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
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Expanded(child: trailing),
          ] else if (widget.bottomBar)
            const Spacer(),
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
    // The value to print when it differs from the slider's (one beyond the
    // slider's range, or a fractional size).
    double? shownValue,
  }) {
    final safeValue = value.clamp(min, max).toDouble();
    final shown = shownValue ?? safeValue;
    final valueLabel = decimals > 0
        ? shown.toStringAsFixed(decimals)
        : shownValue != null && shown != shown.roundToDouble()
        ? shown.toStringAsFixed(1)
        : shown.round().toString();
    if (widget.bottomBar) {
      // One row per setting along the bottom of the screen: the name and
      // value (tap to type it) beside the slider and its −/+ buttons.
      return Row(
        children: [
          SizedBox(
            width: _kBottomLabelWidth,
            // Room on the right for the value's pencil mark, which sits
            // just past the text.
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: EditableSliderValue(
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
            ),
          ),
          Expanded(
            child: SteppedSlider(
              value: safeValue,
              min: min,
              max: max,
              step: decimals > 0 ? 0.1 : 1,
              compact: true,
              onChanged: (v) {
                onChanged(v);
                _updatePreview();
              },
            ),
          ),
        ],
      );
    }
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
    Key? key,
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
    if (widget.bottomBar) {
      return Row(
        key: key,
        children: [
          SizedBox(
            width: _kBottomLabelWidth,
            child: Text(
              '$label: $shown$suffix',
              style: const TextStyle(fontSize: 11),
            ),
          ),
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
      );
    }
    return Padding(
      key: key,
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
      FilterKind.sphereShading => l10n.filterNameSphereShading,
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
      FilterKind.sphereShading => Icons.brightness_medium,
    };
  }

  PremiumFeature? _premiumFeatureFor(FilterKind kind) {
    return switch (kind) {
      FilterKind.toneCurve => PremiumFeature.toneCurve,
      FilterKind.levels => PremiumFeature.levelAdjustment,
      _ => null,
    };
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
    final selection = _canvasSelectionCoverage(tm);
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
      final lensMask = widget.lensMask;
      if (filter.kind == FilterKind.lensDistortion && lensMask != null) {
        // The lens area painted on the canvas (started from the selection
        // layer or the canvas selection).
        final coverage = lensMask.coverage;
        maskData = coverage == null || coverage.length != data.length ~/ 4
            ? null
            : coverageAsRgbaMask(coverage);
      } else if (filterUsesSelectionMask(filter.kind)) {
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
        if (maskData == null && selection != null) {
          maskData = coverageAsRgbaMask(selection);
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

    // A canvas selection keeps the filter inside it: a new layer is empty
    // outside it, a layer changed in place keeps its pixels there. The
    // glasses filter bends its own lens area instead.
    if (selection != null && filter.kind != FilterKind.lensDistortion) {
      result = filterGeneratesLayer(filter.kind)
          ? clearOutsideSelection(result, selection)
          : restrictToSelection(data, result, selection);
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
        FilterKind.outline,
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
        FilterKind.inkPool,
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
        FilterKind.autoLineart,
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
    FilterKind kind,
  ) async {
    final sourceLayer = ps
        .layersOf(widget.projectId, widget.sceneId, frameIndex)
        .where((l) => l.id == sourceLayerId)
        .firstOrNull;
    final sourceName = sourceLayer?.name ?? 'Layer';
    final before = ps.layersOf(widget.projectId, widget.sceneId, frameIndex);
    final sourceIndex = before.indexWhere((layer) => layer.id == sourceLayerId);
    final insertIndex = generatedLayerInsertIndex(kind, sourceIndex);
    final created = ps.addLayer(
      projectId: widget.projectId,
      sceneId: widget.sceneId,
      frameIndex: frameIndex,
      type: model.LayerType.normal,
      name: nameBuilder(sourceName),
      id: generatedLayerId,
      insertIndex: insertIndex,
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
      layer: sourceLayer == null
          ? created
          : generatedLayerFitted(created, sourceLayer, before, insertIndex),
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
          // A grabbed point takes the drag from the scrolling controls
          // around the editor, in any direction.
          return RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              GrabPanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    GrabPanGestureRecognizer
                  >(GrabPanGestureRecognizer.new, (recognizer) {
                    recognizer.dragStartBehavior = DragStartBehavior.down;
                    recognizer.grabs = (local) =>
                        _nearest(points, _normalize(local, size), max: .10) >=
                        0;
                    recognizer.onStart = (details) {
                      final n = _normalize(details.localPosition, size);
                      _dragIndex = _nearest(_points, n, max: .10);
                    };
                    recognizer.onUpdate = (details) {
                      final i = _dragIndex;
                      if (i == null || i < 0) return;
                      final next = [..._points];
                      if (i >= next.length) return;
                      var n = _normalize(details.localPosition, size);
                      if (i == 0) n = Offset(0, n.dy);
                      if (i == next.length - 1) n = Offset(1, n.dy);
                      if (i > 0 && i < next.length - 1) {
                        n = Offset(
                          n.dx.clamp(
                            next[i - 1].dx + .001,
                            next[i + 1].dx - .001,
                          ),
                          n.dy,
                        );
                      }
                      next[i] = n;
                      _emit(next);
                    };
                    recognizer.onEnd = (_) => _dragIndex = null;
                    recognizer.onCancel = () => _dragIndex = null;
                  }),
            },
            child: GestureDetector(
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
              child: CustomPaint(
                painter: _ToneCurvePainter(
                  points: points,
                  sourceRgba: widget.sourceRgba,
                  histogramChannel: widget.histogramChannel,
                  color: Theme.of(context).colorScheme.primary,
                  gridColor: Theme.of(context).colorScheme.outlineVariant,
                ),
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
        final a = rgba[i + 3];
        if (a == 0) continue;
        // The curve works on the straight colour, so the histogram counts it.
        final r = straightChannel(rgba[i], a);
        final g = straightChannel(rgba[i + 1], a);
        final b2 = straightChannel(rgba[i + 2], a);
        final value = switch (histogramChannel) {
          1 => r,
          2 => g,
          3 => b2,
          _ => ((r * 77 + g * 150 + b2 * 29) >> 8),
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
    // The same smooth curve the filter applies, sampled every 2 px.
    final tone = ToneCurve(points);
    final steps = math.max(2, size.width ~/ 2);
    final curve = Path()..moveTo(0, toCanvas(Offset(0, tone.valueAt(0))).dy);
    for (var i = 1; i <= steps; i++) {
      final x = i / steps;
      final p = toCanvas(Offset(x, tone.valueAt(x)));
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
