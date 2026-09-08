import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/autosave_service.dart';
import '../../services/project_service.dart';
import '../../services/brush_service.dart';
import '../../services/font_service.dart';
import '../../services/material_service.dart';
import '../../services/performance_service.dart';
import '../../services/filter_service.dart';
import '../../services/quick_tool_service.dart';
import '../../services/custom_automation_service.dart';
import '../../services/recorded_filter_apply_service.dart';
import '../../services/premium_service.dart';
import '../../services/settings_service.dart';
import '../../services/shortcut_service.dart';
import '../../models/shortcut_binding.dart';
import '../../models/custom_automation.dart';
import '../../widgets/background_color_picker.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/stepped_slider.dart';
import '../../utils/immersive_mode.dart';
import '../../engine/text_render.dart';
import '../../engine/undo_manager.dart';
import '../../l10n/app_localizations.dart';
import '../../models/bundled_fonts.dart';
import '../../models/layer.dart' as model;
import '../../models/onion_skin_settings.dart';
import '../../models/project.dart';
import '../../models/text_object.dart' as model;
import 'widgets/canvas_area.dart';
import 'widgets/canvas_icon_button.dart';
import 'widgets/toolbar_widget.dart';
import 'widgets/frame_strip_widget.dart';
import 'widgets/selection_transform_sliders.dart';
import 'widgets/brush_size_slider.dart';
import 'widgets/layer_panel.dart';
import 'widgets/color_adjust_sheet.dart';
import 'widgets/color_picker_panel.dart';
import 'widgets/brush_panel.dart';
import 'widgets/tone_panel.dart';
import 'widgets/stamp_panel.dart';
import 'widgets/pen_sub_tool_panel.dart';
import 'widgets/onion_skin_panel.dart';
import 'widgets/ruler_panel.dart';
import 'widgets/filter_panel.dart';
import 'widgets/quick_tool_panel.dart';
import 'widgets/mesh_transform_panel.dart';
import 'widgets/reference_window.dart';
import 'widgets/canvas_preview_navigator.dart';
import '../../models/canvas_dock_panel.dart';
import '../../models/ruler.dart';
import '../../widgets/responsive.dart';
import '../../config/font_fallback.dart';
import '../../widgets/scrollable_sheet_body.dart';
import '../../widgets/custom_automation_manager_sheet.dart';
import '../../widgets/custom_automation_draft_sheet.dart';
import '../../widgets/premium_lock_widget.dart';

class CanvasScreen extends StatefulWidget {
  final String projectId;
  const CanvasScreen({super.key, required this.projectId});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  DrawingTool _currentTool = DrawingTool.pen;
  DrawingTool? _toolBeforeGestureToggle;
  PenSubTool _currentSubTool = PenSubTool.brush;
  double _brushSize = 5;
  int _brushOpacity = 100;
  Color _currentColor = Colors.black;
  int _currentFrame = 0;
  bool _showLayerPanel = false;
  int _layerSelectAllToken = 0;
  String? _copiedLayerId;
  bool _showReferenceWindow = false;
  bool _showCanvasPreviewPanel = false;
  bool _showColorPicker = false;
  bool _showBrushPanel = false;
  bool _showTonePanel = false;
  bool _showStampPanel = false;
  bool _showPenSubToolPanel = false;
  bool _showOnionSkinPanel = false;
  bool _showRulerPanel = false;
  bool _showFilterPanel = false;
  bool _showQuickToolPanel = false;
  bool _showColorAdjustPanel = false;
  FilterColorEyedropperTarget? _filterColorEyedropperTarget;
  _TextColorEyedropperTarget? _textColorEyedropperTarget;
  ValueChanged<Color>? _pendingTextColorEyedropper;

  bool _showMeshTransformPanel = false;
  int _meshDensity = 1;
  double _meshRotateDeg = 0.0;
  double _meshScaleValue = 1.0;
  int _meshCommitToken = 0;
  int _meshCancelToken = 0;

  bool _hasActiveSelection = false;
  double _selectionMoveX = 0;
  double _selectionMoveY = 0;
  double _selectionScale = 1;
  double _selectionRotateDeg = 0;
  int _selectionTransformCommitToken = 0;
  int _selectionTransformSteps = 0;
  int _invertSelectionToken = 0;
  int _selectAllSelectionToken = 0;
  int _clearSelectionToken = 0;

  bool get _isSelectionToolActive =>
      _currentTool == DrawingTool.selectRect ||
      _currentTool == DrawingTool.selectLasso ||
      _currentTool == DrawingTool.selectMagicWand;

  double? _panelWidthDragOverride;
  double? _toolPanelWidthDragOverride;
  OverlayEntry? _customAutomationRecordingOverlay;

  void _closeAllOverlayPanels() {
    if (!isWideScreen(context, listen: false)) {
      _showLayerPanel = false;
      _showColorPicker = false;
      _showBrushPanel = false;
      _showTonePanel = false;
      _showStampPanel = false;
      _showPenSubToolPanel = false;
      _showOnionSkinPanel = false;
      _showRulerPanel = false;
      _showFilterPanel = false;
      _showQuickToolPanel = false;
      _showColorAdjustPanel = false;
    }
    if (_showMeshTransformPanel) {
      _showMeshTransformPanel = false;
      _meshCancelToken++;
      if (_currentTool == DrawingTool.meshTransform) {
        _currentTool = DrawingTool.pen;
      }
    }
  }

  void _openMeshTransformPanel({int density = 1}) => setState(() {
    _closeAllOverlayPanels();
    _showMeshTransformPanel = true;
    _meshDensity = density;
    _meshRotateDeg = 0.0;
    _meshScaleValue = 1.0;
    _currentTool = DrawingTool.meshTransform;
  });

  void _applyMeshTransform() => setState(() {
    _meshCommitToken++;
    _showMeshTransformPanel = false;
    _currentTool = DrawingTool.pen;
  });

  void _cancelMeshTransform() => setState(() {
    _meshCancelToken++;
    _showMeshTransformPanel = false;
    _currentTool = DrawingTool.pen;
  });

  bool _usesBrushSize(DrawingTool tool) => switch (tool) {
    DrawingTool.pen ||
    DrawingTool.eraser ||
    DrawingTool.lasso ||
    DrawingTool.finger ||
    DrawingTool.blur ||
    DrawingTool.mosaic ||
    DrawingTool.ruler => true,
    _ => false,
  };

  void _toggleRuler() => setState(() {
    final next = !_showRulerPanel;
    _closeAllOverlayPanels();
    _showRulerPanel = next;
    if (_currentTool != DrawingTool.ruler) {
      _currentTool = DrawingTool.ruler;
    }
  });

  void _toggleOnionSkinPanel() => setState(() {
    final next = !_showOnionSkinPanel;
    _closeAllOverlayPanels();
    _showOnionSkinPanel = next;
  });

  void _toggleFilterPanel() => setState(() {
    final next = !_showFilterPanel;
    _closeAllOverlayPanels();
    _showFilterPanel = next;
  });

  void _toggleFilterColorEyedropper(FilterColorEyedropperTarget target) {
    setState(() {
      _filterColorEyedropperTarget = _filterColorEyedropperTarget == target
          ? null
          : target;
    });
  }

  void _handleCanvasEyedropper(Color color) {
    final textTarget = _textColorEyedropperTarget;
    final pendingText = _pendingTextColorEyedropper;
    if (textTarget != null && pendingText != null) {
      setState(() {
        _textColorEyedropperTarget = null;
        _pendingTextColorEyedropper = null;
      });
      pendingText(color);
      return;
    }
    final target = _filterColorEyedropperTarget;
    if (target != null) {
      final filterService = context.read<FilterService>();
      final current = filterService.currentFilter;
      if (current != null) {
        switch (target) {
          case FilterColorEyedropperTarget.inkPool:
            filterService.updateFilterParams(
              current.id,
              inkPoolColor: color.toARGB32(),
            );
          case FilterColorEyedropperTarget.outline:
            filterService.updateFilterParams(
              current.id,
              outlineColor: color.toARGB32(),
            );
        }
      }
      setState(() => _filterColorEyedropperTarget = null);
      return;
    }
    setState(() => _currentColor = color);
    context.read<BrushService>().setCurrentColor(color);
  }

  String _activeColorEyedropperHint(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_textColorEyedropperTarget != null) {
      return l10n.filterCanvasEyedropperTooltip;
    }
    return _filterColorEyedropperTarget == FilterColorEyedropperTarget.inkPool
        ? l10n.filterInkPoolEyedropperHint
        : l10n.filterOutlineEyedropperHint;
  }

  void _toggleBackground() => setState(() {
    _canvasBackground = _canvasBackground == CanvasBackground.white
        ? CanvasBackground.transparent
        : CanvasBackground.white;
  });

  void _toggleFrameMultiSelect() => setState(() {
    _frameMultiSelectMode = !_frameMultiSelectMode;
    _selectedFrameIndices = {};
  });

  void _goToNextFrame() {
    final total = context.read<ProjectService>().frameCount(
      widget.projectId,
      _currentSceneId,
    );
    if (_currentFrame + 1 >= total) return;
    setState(() => _currentFrame += 1);
    _recordCanvasAutomation(
      'canvas.selectFrame',
      'Frame ${_currentFrame + 1}',
      args: {'frame': _currentFrame},
      changesFrame: true,
    );
  }

  void _goToPreviousFrame() {
    if (_currentFrame <= 0) return;
    setState(() => _currentFrame -= 1);
    _recordCanvasAutomation(
      'canvas.selectFrame',
      'Frame ${_currentFrame + 1}',
      args: {'frame': _currentFrame},
      changesFrame: true,
    );
  }

  void _showCustomAutomationManager() {
    final premium = context.read<PremiumService>();
    if (!premium.isFeatureAvailable(PremiumFeature.customAutomation)) {
      showPremiumBanner(context);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomAutomationManagerSheet(
        surface: CustomAutomationSurface.canvas,
        onExecute: _executeCustomAutomation,
        onRecordingStarted: _showCustomAutomationRecordingOverlay,
        recordingStartFrame: _currentFrame,
      ),
    );
  }

  void _showCustomAutomationRecordingOverlay() {
    _customAutomationRecordingOverlay?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          CustomAutomationRecordingStopButton(
            onStop: () {
              context.read<CustomAutomationService>().stopRecording();
              entry.remove();
              if (identical(_customAutomationRecordingOverlay, entry)) {
                _customAutomationRecordingOverlay = null;
              }
              _showCustomAutomationDraftReview();
            },
          ),
        ],
      ),
    );
    _customAutomationRecordingOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  void _showCustomAutomationDraftReview() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CustomAutomationDraftSheet(
        surface: CustomAutomationSurface.canvas,
        onResumeRecording: _showCustomAutomationRecordingOverlay,
      ),
    );
  }

  void _recordCanvasAutomation(
    String command,
    String label, {
    Map<String, Object?> args = const {},
    bool changesFrame = false,
  }) {
    context.read<CustomAutomationService>().recordStep(
      surface: CustomAutomationSurface.canvas,
      command: command,
      label: label,
      args: args,
      changesFrame: changesFrame,
      recordedFrame: _currentFrame,
    );
  }

  Future<void> _executeCustomAutomation(
    CustomAutomation automation,
    CustomAutomationExecutionScope scope,
  ) async {
    final total = context.read<ProjectService>().frameCount(
      widget.projectId,
      _currentSceneId,
    );
    final frames = scope == CustomAutomationExecutionScope.allFrames
        ? List<int>.generate(total, (index) => index)
        : <int>[_currentFrame];
    for (final frame in frames) {
      for (final step in automation.steps) {
        if (step.surface != CustomAutomationSurface.canvas) {
          throw StateError('Timeline command cannot run from Canvas mode');
        }
        await _executeCanvasAutomationStep(step, frame);
      }
    }
  }

  Future<void> _executeCanvasAutomationStep(
    CustomAutomationStep step,
    int targetFrame,
  ) async {
    switch (step.command) {
      case 'canvas.tool':
        final toolName = step.args['tool'] as String?;
        if (toolName == null) throw StateError('Missing tool');
        final tool = DrawingTool.values
            .where((value) => value.name == toolName)
            .firstOrNull;
        if (tool == null) throw StateError('Unknown tool: $toolName');
        setState(() => _currentTool = tool);
      case 'canvas.brushSize':
        final value = (step.args['value'] as num?)?.toDouble();
        if (value == null) throw StateError('Missing brush size');
        setState(() => _brushSize = value);
        context.read<BrushService>().updateCurrentBrushSize(value);
      case 'canvas.brushOpacity':
        final value = (step.args['value'] as num?)?.round();
        if (value == null) throw StateError('Missing brush opacity');
        setState(() => _brushOpacity = value.clamp(0, 100));
        context.read<BrushService>().updateCurrentBrushOpacity(_brushOpacity);
      case 'canvas.color':
        final argb = (step.args['argb'] as num?)?.toInt();
        if (argb == null) throw StateError('Missing color');
        final color = Color(argb);
        setState(() => _currentColor = color);
        context.read<BrushService>().setCurrentColor(color);
      case 'canvas.filter':
        final rawSnapshot = step.args['filter'];
        if (rawSnapshot is! Map) throw StateError('Missing filter snapshot');
        final layerId = _currentLayerId;
        if (layerId == null) throw StateError('No active layer');
        await RecordedFilterApplyService.apply(
          projectService: context.read<ProjectService>(),
          projectId: widget.projectId,
          sceneId: _currentSceneId,
          layerId: layerId,
          frameIndex: targetFrame,
          filterSnapshot: Map<String, Object?>.from(rawSnapshot),
        );
      case 'canvas.selectFrame':
        final frame = (step.args['frame'] as num?)?.round();
        if (frame == null) throw StateError('Missing frame');
        if (frame < 0 ||
            frame >=
                context.read<ProjectService>().frameCount(
                  widget.projectId,
                  _currentSceneId,
                )) {
          throw StateError('Frame is outside the current scene');
        }
        setState(() => _currentFrame = frame);
      default:
        throw StateError(
          'Unsupported Canvas automation command: ${step.command}',
        );
    }
  }

  Future<void> _runAutomationBlockedAction(VoidCallback action) async {
    final service = context.read<CustomAutomationService>();
    if (!service.isRecording) {
      action();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final stop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.customAutomationStopConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.customAutomationStopConfirmStop),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.customAutomationStopConfirmContinue),
          ),
        ],
      ),
    );
    if (stop != true || !mounted) return;
    service.cancelDraft();
    _customAutomationRecordingOverlay?.remove();
    _customAutomationRecordingOverlay = null;
    action();
  }

  void _showEditMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.auto_fix_high_outlined),
                title: Text(l10n.canvasEditMenuAutofillPresets),
                subtitle: Text(l10n.canvasEditMenuAutofillPresetsSubtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  _runAutomationBlockedAction(
                    () => context.push('/autofill-presets'),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  _canvasBackground == CanvasBackground.white
                      ? Icons.check_box_outline_blank
                      : Icons.grid_4x4,
                ),
                title: Text(l10n.canvasEditMenuBackgroundToggle),
                subtitle: Text(
                  _canvasBackground == CanvasBackground.white
                      ? l10n.canvasEditMenuBackgroundCurrentColor
                      : l10n.canvasEditMenuBackgroundCurrentTransparent,
                ),
                onTap: () {
                  _toggleBackground();
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(
                      context
                              .read<ProjectService>()
                              .projects
                              .where((p) => p.id == widget.projectId)
                              .firstOrNull
                              ?.backgroundColor ??
                          0xFFFFFFFF,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                title: Text(l10n.newProjectBackgroundColorLabel),
                subtitle: const Text('白 / 黒 / 透明 / ベージュ'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBackgroundColorPicker(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.layers_outlined),
                title: Text(l10n.onionSkinTitle),
                subtitle: Text(l10n.canvasEditMenuOnionSkinSubtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleOnionSkinPanel();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.playlist_play,
                  color:
                      context.read<PremiumService>().isFeatureAvailable(
                        PremiumFeature.customAutomation,
                      )
                      ? null
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(l10n.customAutomationTitle),
                trailing:
                    context.read<PremiumService>().isFeatureAvailable(
                      PremiumFeature.customAutomation,
                    )
                    ? null
                    : const Icon(Icons.lock_outline, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCustomAutomationManager();
                },
              ),
              ListTile(
                leading: const Icon(Icons.blur_on),
                title: Text(l10n.filterPanelTitle),
                subtitle: Text(l10n.canvasEditMenuFilterSubtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleFilterPanel();
                },
              ),
              ListTile(
                leading: Icon(
                  _frameMultiSelectMode ? Icons.checklist_rtl : Icons.checklist,
                ),
                title: Text(l10n.canvasEditMenuFrameMultiSelect),
                subtitle: Text(l10n.canvasEditMenuFrameMultiSelectSubtitle),
                onTap: () {
                  _toggleFrameMultiSelect();
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.gesture),
                title: Text(l10n.canvasEditMenuPressureCurve),
                subtitle: Text(l10n.canvasEditMenuPressureCurveSubtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  _runAutomationBlockedAction(
                    () => context.push('/settings/pen'),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.crop_free),
                title: Text(l10n.canvasEditMenuMeshTransform),
                subtitle: Text(l10n.canvasEditMenuMeshTransformSubtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  _openMeshTransformPanel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(l10n.canvasColorAdjustMenuTitle),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    final next = !_showColorAdjustPanel;
                    _closeAllOverlayPanels();
                    _showColorAdjustPanel = next;
                  });
                },
              ),
              ListTile(
                leading: Icon(
                  _showReferenceWindow
                      ? Icons.dashboard_customize
                      : Icons.dashboard_customize_outlined,
                ),
                title: Text(l10n.canvasEditMenuReferenceWindow),
                subtitle: Text(l10n.canvasEditMenuReferenceWindowSubtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _showReferenceWindow = !_showReferenceWindow);
                },
              ),
              if (isWideScreen(context))
                ListTile(
                  leading: Icon(
                    _showCanvasPreviewPanel ? Icons.map : Icons.map_outlined,
                  ),
                  title: Text(l10n.canvasEditMenuPreviewNavigator),
                  subtitle: Text(l10n.canvasEditMenuPreviewNavigatorSubtitle),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(
                      () => _showCanvasPreviewPanel = !_showCanvasPreviewPanel,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _frameMultiSelectMode = false;
  Set<int> _selectedFrameIndices = {};
  Set<int>? _filterBulkFrames;
  Ruler? _activeRuler;
  CanvasBackground _canvasBackground = CanvasBackground.white;
  bool _lassoFillEnclosedMode = false;
  ShapeKind _shapeKind = ShapeKind.off;
  OnionSkinSettings _onionSkinSettings = const OnionSkinSettings();
  QualityLevel? _lastQualityLevel;
  PerformanceService? _perf;
  String? _currentLayerId;
  bool _autosaveAttached = false;
  AutosaveService? _autosaveService;
  ProjectService? _projectServiceForDispose;
  bool _showFrameStrip = true;
  bool _showToolbar = true;
  bool _workTrackingStarted = false;
  bool _missingMaterialChecked = false;
  bool _autoOpenedDesktopPanels = false;

  @override
  void initState() {
    super.initState();
    ImmersiveMode.enterWorkspace();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brush = context.read<BrushService>().currentBrush;
    if (brush != null) {
      _brushSize = brush.size;
      _brushOpacity = brush.opacity;
    }
    if (_currentLayerId == null) {
      final scenes = context.read<ProjectService>().scenesOf(widget.projectId);
      if (scenes.isNotEmpty && scenes.first.frames.isNotEmpty) {
        final layers = scenes.first.frames.first.layers;
        if (layers.isNotEmpty) _currentLayerId = layers.first.id;
      }
    }
    if (!_autoOpenedDesktopPanels && isWideScreen(context)) {
      _autoOpenedDesktopPanels = true;
      final defaults = context.read<SettingsService>().defaultDockedPanels;
      _showBrushPanel = defaults.contains(CanvasDockPanel.brush);
      _showColorPicker = defaults.contains(CanvasDockPanel.colorPicker);
      _showLayerPanel = defaults.contains(CanvasDockPanel.layer);
      _showTonePanel = defaults.contains(CanvasDockPanel.tone);
      _showStampPanel = defaults.contains(CanvasDockPanel.stamp);
      _showPenSubToolPanel = defaults.contains(CanvasDockPanel.penSubTool);
      _showOnionSkinPanel = defaults.contains(CanvasDockPanel.onionSkin);
      _showRulerPanel = defaults.contains(CanvasDockPanel.ruler);
      _showFilterPanel = defaults.contains(CanvasDockPanel.filter);
      _showQuickToolPanel = defaults.contains(CanvasDockPanel.quickTool);
      _showColorAdjustPanel = defaults.contains(CanvasDockPanel.colorAdjust);
      _showCanvasPreviewPanel = defaults.contains(
        CanvasDockPanel.canvasPreview,
      );
    }
    _projectServiceForDispose = context.read<ProjectService>();
    final newPerf = context.read<PerformanceService>();
    if (newPerf != _perf) {
      _perf?.removeListener(_onPerfChanged);
      _perf = newPerf;
      _perf!.addListener(_onPerfChanged);
      _syncOnionFromPerf();
    }
    if (!_autosaveAttached) {
      _autosaveAttached = true;
      final autosave = context.read<AutosaveService>();
      _autosaveService = autosave;
      autosave.attach(
        context.read<ProjectService>(),
        widget.projectId,
        undoManager: context.read<UndoManager>(),
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkCrashRecovery(autosave),
      );
    }
    if (!_workTrackingStarted) {
      _workTrackingStarted = true;
      context.read<ProjectService>().beginWorkTracking(widget.projectId);
    }
    if (!_missingMaterialChecked) {
      _missingMaterialChecked = true;
      final materialService = context.read<MaterialService>();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkMissingMaterials(materialService),
      );
    }
  }

  @override
  void dispose() {
    _customAutomationRecordingOverlay?.remove();
    _customAutomationRecordingOverlay = null;
    ImmersiveMode.exitWorkspace();
    _perf?.removeListener(_onPerfChanged);
    if (_autosaveAttached) _autosaveService?.detach();
    final projectService = _projectServiceForDispose;
    if (_workTrackingStarted) projectService?.endWorkTracking();
    projectService?.generateAndSaveThumbnail(widget.projectId);
    super.dispose();
  }

  Future<void> _checkCrashRecovery(AutosaveService autosave) async {
    if (!mounted) return;
    if (autosave.hasPromptedThisSession(widget.projectId)) return;
    autosave.markPrompted(widget.projectId);
    final slot = autosave.latestSlotFor(widget.projectId);
    if (slot == null) return;
    final project = context
        .read<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (project == null || !slot.savedAt.isAfter(project.updatedAt)) return;
    final data = await autosave.restore(widget.projectId, slot.slotIndex);
    if (data == null || !mounted) return;
    context.read<ProjectService>().restoreFromAutosave(widget.projectId, data);
  }

  Future<void> _checkMissingMaterials(MaterialService materialService) async {
    final missing = await materialService.detectMissing(widget.projectId);
    if (!mounted || missing.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.canvasMissingMaterialsSnackbar),
        action: SnackBarAction(
          label: l10n.canvasResearchButton,
          onPressed: () => _checkMissingMaterials(materialService),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _onPerfChanged() => _syncOnionFromPerf();

  void _syncOnionFromPerf() {
    if (!mounted) return;
    final perf = _perf;
    if (perf == null) return;
    final level = perf.qualityLevel;
    final newPrev = perf.prevOnionSkinFrames;
    final newNext = perf.nextOnionSkinFrames;
    final newShowPrev = level != QualityLevel.custom
        ? true
        : perf.showPrevOnion;
    final newShowNext = level != QualityLevel.custom
        ? true
        : perf.showNextOnion;
    if (_lastQualityLevel == level &&
        _onionSkinSettings.prevFrames == newPrev &&
        _onionSkinSettings.nextFrames == newNext &&
        _onionSkinSettings.showPrev == newShowPrev &&
        _onionSkinSettings.showNext == newShowNext) {
      return;
    }
    _lastQualityLevel = level;
    setState(() {
      _onionSkinSettings = _onionSkinSettings.copyWith(
        showPrev: newShowPrev,
        showNext: newShowNext,
        prevFrames: newPrev,
        nextFrames: newNext,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final project = context
        .watch<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final isDesktop = isWideScreen(context);
    final openToolPanels = isDesktop
        ? _openToolOptionPanels()
        : const <Widget>[];
    final leftHanded = context.watch<SettingsService>().isLeftHanded;

    return CallbackShortcuts(
      bindings: _buildShortcutBindings(context),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: kCanvasOutsideColor,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: Row(
                        children: [
                          if (isDesktop && !leftHanded)
                            _buildToolbarWidget(vertical: true),
                          if (openToolPanels.isNotEmpty && !leftHanded) ...[
                            SizedBox(
                              width:
                                  _toolPanelWidthDragOverride ??
                                  context
                                      .watch<SettingsService>()
                                      .desktopToolPanelWidth,
                              child: _dockedPanelStack(openToolPanels),
                            ),
                            _ResizeHandle(
                              onDeltaX: (dx) => setState(() {
                                final settings = context
                                    .read<SettingsService>();
                                final current =
                                    _toolPanelWidthDragOverride ??
                                    settings.desktopToolPanelWidth;
                                _toolPanelWidthDragOverride = (current + dx)
                                    .clamp(200.0, 480.0);
                              }),
                              onDragEnd: () {
                                final w = _toolPanelWidthDragOverride;
                                if (w != null) {
                                  context
                                      .read<SettingsService>()
                                      .setDesktopToolPanelWidth(w);
                                }
                              },
                            ),
                          ],
                          Expanded(
                            child: Stack(
                              children: [
                                Container(color: kCanvasOutsideColor),
                                CanvasArea(
                                  onTapForText: _currentTool == DrawingTool.text
                                      ? onCanvasTapForText
                                      : null,
                                  onEyedropper: _handleCanvasEyedropper,
                                  filterEyedropperActive:
                                      _filterColorEyedropperTarget != null ||
                                      _textColorEyedropperTarget != null,
                                  project: project,
                                  background: _canvasBackground,
                                  currentLayerId: _currentLayerId,
                                  isEraser: _currentTool == DrawingTool.eraser,
                                  currentTool: _currentTool,
                                  currentSubTool: _currentSubTool,
                                  lassoFillEnclosedMode: _lassoFillEnclosedMode,
                                  onionSkinSettings: _onionSkinSettings,
                                  currentFrame: _currentFrame,
                                  sceneId: _currentSceneId,
                                  activeRuler: _activeRuler,
                                  onRulerChanged: _setActiveRulerLive,
                                  shapeKind: _shapeKind,
                                  onGestureToolChange: (tool) =>
                                      setState(() => _currentTool = tool),
                                  onGestureToggleTool: _handleGestureToggleTool,
                                  onNextQuickTool: _applyNextQuickTool,
                                  onToggleOnionSkin: () => setState(
                                    () => _onionSkinSettings =
                                        _onionSkinSettings.copyWith(
                                          enabled: !_onionSkinSettings.enabled,
                                        ),
                                  ),
                                  meshDensity: _meshDensity,
                                  meshRotateDeg: _meshRotateDeg,
                                  meshScaleValue: _meshScaleValue,
                                  meshCommitToken: _meshCommitToken,
                                  meshCancelToken: _meshCancelToken,
                                  onNextFrame: _goToNextFrame,
                                  onPreviousFrame: _goToPreviousFrame,
                                  invertSelectionToken: _invertSelectionToken,
                                  selectAllSelectionToken:
                                      _selectAllSelectionToken,
                                  clearSelectionToken: _clearSelectionToken,
                                  onSelectionActiveChanged: (v) {
                                    if (_hasActiveSelection == v) return;
                                    setState(() {
                                      _hasActiveSelection = v;
                                      _selectionTransformSteps = 0;
                                      _resetSelectionSliders();
                                    });
                                  },
                                  selectionMoveX: _selectionMoveX,
                                  selectionMoveY: _selectionMoveY,
                                  selectionScale: _selectionScale,
                                  selectionRotateDeg: _selectionRotateDeg,
                                  selectionTransformCommitToken:
                                      _selectionTransformCommitToken,
                                ),
                                if (_filterColorEyedropperTarget != null ||
                                    _textColorEyedropperTarget != null)
                                  Positioned(
                                    top: 12,
                                    left: 12,
                                    right: 12,
                                    child: IgnorePointer(
                                      child: Center(
                                        child: Material(
                                          elevation: 4,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .inverseSurface,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 9,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.colorize,
                                                  size: 18,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onInverseSurface,
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    _activeColorEyedropperHint(
                                                      context,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onInverseSurface,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_isSelectionToolActive ||
                                    _currentTool == DrawingTool.meshTransform)
                                  Positioned(
                                    left: 12,
                                    bottom: 12,
                                    right: 12,
                                    child: SafeArea(
                                      child: Align(
                                        alignment: Alignment.bottomLeft,
                                        child:
                                            _currentTool ==
                                                DrawingTool.meshTransform
                                            ? _meshCancelBar(context)
                                            : _selectionToolBar(context),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (openToolPanels.isNotEmpty && leftHanded) ...[
                            _ResizeHandle(
                              onDeltaX: (dx) => setState(() {
                                final settings = context
                                    .read<SettingsService>();
                                final current =
                                    _toolPanelWidthDragOverride ??
                                    settings.desktopToolPanelWidth;
                                _toolPanelWidthDragOverride = (current - dx)
                                    .clamp(200.0, 480.0);
                              }),
                              onDragEnd: () {
                                final w = _toolPanelWidthDragOverride;
                                if (w != null) {
                                  context
                                      .read<SettingsService>()
                                      .setDesktopToolPanelWidth(w);
                                }
                              },
                            ),
                            SizedBox(
                              width:
                                  _toolPanelWidthDragOverride ??
                                  context
                                      .watch<SettingsService>()
                                      .desktopToolPanelWidth,
                              child: _dockedPanelStack(openToolPanels),
                            ),
                          ],
                          if (isDesktop && leftHanded)
                            _buildToolbarWidget(vertical: true),
                          if (isDesktop &&
                              (_showColorPicker ||
                                  _showLayerPanel ||
                                  _showCanvasPreviewPanel))
                            _ResizeHandle(
                              onDeltaX: (dx) => setState(() {
                                final settings = context
                                    .read<SettingsService>();
                                final current =
                                    _panelWidthDragOverride ??
                                    settings.desktopPanelWidth;
                                _panelWidthDragOverride =
                                    (current + (leftHanded ? dx : -dx)).clamp(
                                      200.0,
                                      480.0,
                                    );
                              }),
                              onDragEnd: () {
                                final w = _panelWidthDragOverride;
                                if (w != null) {
                                  context
                                      .read<SettingsService>()
                                      .setDesktopPanelWidth(w);
                                }
                              },
                            ),
                          if (isDesktop &&
                              (_showColorPicker ||
                                  _showLayerPanel ||
                                  _showCanvasPreviewPanel))
                            SizedBox(
                              width:
                                  _panelWidthDragOverride ??
                                  context
                                      .watch<SettingsService>()
                                      .desktopPanelWidth,
                              child: _buildRightDockColumn(),
                            ),
                        ],
                      ),
                    ),
                    if (_isSelectionToolActive && _hasActiveSelection)
                      SelectionTransformSliders(
                        moveX: _selectionMoveX,
                        moveY: _selectionMoveY,
                        scale: _selectionScale,
                        rotateDeg: _selectionRotateDeg,
                        maxMove: _selectionSliderMaxMove(context),
                        onChanged: ({moveX, moveY, scale, rotateDeg}) =>
                            setState(() {
                              _selectionMoveX = moveX ?? _selectionMoveX;
                              _selectionMoveY = moveY ?? _selectionMoveY;
                              _selectionScale = scale ?? _selectionScale;
                              _selectionRotateDeg =
                                  rotateDeg ?? _selectionRotateDeg;
                            }),
                        onCommit: () => setState(() {
                          _selectionTransformCommitToken++;
                          _selectionTransformSteps++;
                          _resetSelectionSliders();
                        }),
                      ),
                    if (_usesBrushSize(_currentTool))
                      BrushSizeSlider(
                        brushSize: _brushSize,
                        opacity: _brushOpacity,
                        onSizeChanged: (v) {
                          setState(() => _brushSize = v);
                          context.read<BrushService>().updateCurrentBrushSize(
                            v,
                          );
                          _recordCanvasAutomation(
                            'canvas.brushSize',
                            'Brush size',
                            args: {'value': v},
                          );
                        },
                        onOpacityChanged: (v) {
                          setState(() => _brushOpacity = v);
                          context
                              .read<BrushService>()
                              .updateCurrentBrushOpacity(v);
                          _recordCanvasAutomation(
                            'canvas.brushOpacity',
                            'Brush opacity',
                            args: {'value': v},
                          );
                        },
                      ),
                    if (_currentTool == DrawingTool.meshTransform &&
                        _meshDensity > 1)
                      _meshDensitySlider(context),
                    if (!isDesktop && !_isSelectionToolActive)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            setState(() => _showToolbar = !_showToolbar),
                        child: Container(
                          height: 28,
                          alignment: Alignment.center,
                          color: Colors.transparent,
                          child: Icon(
                            _showToolbar
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            size: 22,
                            color: ThemeService.activeColorScheme.onSurface
                                .withValues(alpha: 0.70),
                          ),
                        ),
                      ),
                    if (_showToolbar && !isDesktop && !_isSelectionToolActive)
                      _buildToolbarWidget(vertical: false),
                    if (_frameMultiSelectMode) _buildFrameMultiSelectBar(),
                    if (!_isSelectionToolActive)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            setState(() => _showFrameStrip = !_showFrameStrip),
                        child: Container(
                          height: 28,
                          alignment: Alignment.center,
                          color: Colors.transparent,
                          child: Icon(
                            _showFrameStrip
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            size: 22,
                            color: Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    if (_showFrameStrip && !_isSelectionToolActive)
                      FrameStripWidget(
                        currentFrame: _currentFrame,
                        projectId: widget.projectId,
                        sceneId: _currentSceneId,
                        onFrameSelected: (idx) {
                          setState(() => _currentFrame = idx);
                          _recordCanvasAutomation(
                            'canvas.selectFrame',
                            'Frame ${idx + 1}',
                            args: {'frame': idx},
                            changesFrame: true,
                          );
                        },
                        onTimelineTap: () => _runAutomationBlockedAction(
                          () => context.go('/timeline/${widget.projectId}'),
                        ),
                        multiSelectMode: _frameMultiSelectMode,
                        selectedFrames: _selectedFrameIndices,
                        onFrameToggle: (idx) => setState(() {
                          if (_selectedFrameIndices.contains(idx)) {
                            _selectedFrameIndices.remove(idx);
                          } else {
                            _selectedFrameIndices.add(idx);
                          }
                        }),
                      ),
                  ],
                ),
                if (_anyToolPanelOpen && !isDesktop)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(_closeAllOverlayPanels),
                    ),
                  ),
                if (_showLayerPanel && !isDesktop)
                  Positioned(
                    left: leftHanded ? 0 : null,
                    right: leftHanded ? null : 0,
                    top: 0,
                    bottom: 0,
                    width: 250,
                    child: LayerPanel(
                      onClose: () => setState(() => _showLayerPanel = false),
                      projectId: widget.projectId,
                      sceneId: _currentSceneId,
                      frameIndex: _currentFrame,
                      onEditTextLayer: _onEditTextLayerTapped,
                      currentLayerId: _currentLayerId,
                      onLayerSelected: (id) =>
                          setState(() => _currentLayerId = id),
                      selectAllToken: _layerSelectAllToken,
                    ),
                  ),
                if (_showColorPicker && !isDesktop)
                  _sidedPanel(
                    anchorLeft: true,
                    leftHanded: leftHanded,
                    top: null,
                    bottom: 16,
                    child: _colorPickerPanel(),
                  ),
                if (_showBrushPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: true,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _brushPanel(),
                  ),
                if (_showTonePanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: true,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _tonePanel(),
                  ),
                if (_showStampPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: true,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _stampPanel(),
                  ),
                if (_showPenSubToolPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: true,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _penSubToolPanel(),
                  ),
                if (_showOnionSkinPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: false,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _onionSkinPanel(),
                  ),
                if (_showRulerPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: true,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _rulerPanel(),
                  ),
                if (_showFilterPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: false,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _filterPanel(),
                  ),
                if (_showQuickToolPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: false,
                    leftHanded: leftHanded,
                    top: null,
                    bottom: 16,
                    child: _quickToolPanel(),
                  ),
                if (_showColorAdjustPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: true,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _colorAdjustPanel(),
                  ),
                if (_showReferenceWindow)
                  ReferenceWindow(
                    onClose: () => setState(() => _showReferenceWindow = false),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _anyToolPanelOpen =>
      _showLayerPanel ||
      _showColorPicker ||
      _showBrushPanel ||
      _showTonePanel ||
      _showStampPanel ||
      _showPenSubToolPanel ||
      _showOnionSkinPanel ||
      _showRulerPanel ||
      _showFilterPanel ||
      _showQuickToolPanel ||
      _showColorAdjustPanel;

  List<Widget> _openToolOptionPanels() {
    final byPanel = <CanvasDockPanel, Widget>{
      if (_showPenSubToolPanel) CanvasDockPanel.penSubTool: _penSubToolPanel(),
      if (_showBrushPanel) CanvasDockPanel.brush: _brushPanel(),
      if (_showTonePanel) CanvasDockPanel.tone: _tonePanel(),
      if (_showStampPanel) CanvasDockPanel.stamp: _stampPanel(),
      if (_showOnionSkinPanel) CanvasDockPanel.onionSkin: _onionSkinPanel(),
      if (_showRulerPanel) CanvasDockPanel.ruler: _rulerPanel(),
      if (_showFilterPanel) CanvasDockPanel.filter: _filterPanel(),
      if (_showQuickToolPanel) CanvasDockPanel.quickTool: _quickToolPanel(),
      if (_showColorAdjustPanel)
        CanvasDockPanel.colorAdjust: _colorAdjustPanel(),
    };
    final order = context.read<SettingsService>().toolOptionDockOrder;
    final panels = [
      for (final key in order)
        if (byPanel[key] != null) byPanel[key]!,
      if (_showMeshTransformPanel) _meshTransformPanel(),
    ];
    return panels;
  }

  Widget _buildToolbarWidget({required bool vertical}) => ToolbarWidget(
    vertical: vertical,
    currentTool: _currentTool,
    currentColor: _currentColor,
    isStampSelected: _currentSubTool == PenSubTool.stamp,
    onToolSelected: (tool) {
      setState(() => _currentTool = tool);
      _recordCanvasAutomation(
        'canvas.tool',
        tool.name,
        args: {'tool': tool.name},
      );
    },
    onColorTap: () => setState(() {
      final next = !_showColorPicker;
      _closeAllOverlayPanels();
      _showColorPicker = next;
    }),
    onBrushTap: () => setState(() {
      final next = !_showBrushPanel;
      _closeAllOverlayPanels();
      _showBrushPanel = next;
    }),
    onLayerTap: () => setState(() {
      final next = !_showLayerPanel;
      _closeAllOverlayPanels();
      _showLayerPanel = next;
    }),
    onPenLongPress: () => setState(() {
      final next = !_showPenSubToolPanel;
      _closeAllOverlayPanels();
      _showPenSubToolPanel = next;
    }),
    onFingerLongPress: () => _showFingerSubMenu(context),
    onTextTap: () => setState(() => _currentTool = DrawingTool.text),
    onShapeTap: () => _showShapeMenu(context),
    onQuickToolTap: _applyNextQuickTool,
    onQuickToolLongPress: () => setState(() {
      final next = !_showQuickToolPanel;
      _closeAllOverlayPanels();
      _showQuickToolPanel = next;
    }),
    onSaveTap: () => _runAutomationBlockedAction(
      () => context.push('/save-tree/${widget.projectId}'),
    ),
    onLassoFillSelected: () => setState(() {
      _currentSubTool = PenSubTool.lassoFill;
      _currentTool = DrawingTool.lasso;
    }),
    onRulerTap: _toggleRuler,
  );

  Widget _buildRightDockColumn() {
    final byPanel = <CanvasDockPanel, Widget>{
      if (_showCanvasPreviewPanel)
        CanvasDockPanel.canvasPreview: CanvasPreviewNavigator(
          projectId: widget.projectId,
          sceneId: _currentSceneId,
          frameIndex: _currentFrame,
          onClose: () => setState(() => _showCanvasPreviewPanel = false),
        ),
      if (_showColorPicker)
        CanvasDockPanel.colorPicker: Flexible(
          child: SingleChildScrollView(
            child: ColorPickerPanel(
              currentColor: _currentColor,
              onColorChanged: (color) {
                setState(() => _currentColor = color);
                context.read<BrushService>().setCurrentColor(color);
                _recordCanvasAutomation(
                  'canvas.color',
                  'Color',
                  args: {'argb': color.toARGB32()},
                );
              },
              onClose: () => setState(() => _showColorPicker = false),
              onEyedropperTap: () => setState(() {
                _currentTool = DrawingTool.eyedropper;
                _showColorPicker = false;
              }),
            ),
          ),
        ),
      if (_showLayerPanel)
        CanvasDockPanel.layer: Expanded(
          child: LayerPanel(
            onClose: () => setState(() => _showLayerPanel = false),
            projectId: widget.projectId,
            sceneId: _currentSceneId,
            frameIndex: _currentFrame,
            dockedMode: true,
            onEditTextLayer: _onEditTextLayerTapped,
            currentLayerId: _currentLayerId,
            onLayerSelected: (id) => setState(() => _currentLayerId = id),
            selectAllToken: _layerSelectAllToken,
          ),
        ),
    };
    final order = context.watch<SettingsService>().rightDockOrder;
    final ordered = [
      for (final key in order)
        if (byPanel[key] != null) byPanel[key]!,
    ];
    final children = <Widget>[];
    for (var i = 0; i < ordered.length; i++) {
      if (i > 0) children.add(const Divider(height: 1));
      children.add(ordered[i]);
    }
    return Column(children: children);
  }

  Widget _dockedPanelStack(List<Widget> panels) => SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < panels.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          panels[i],
        ],
      ],
    ),
  );

  Widget _colorPickerPanel() => ColorPickerPanel(
    currentColor: _currentColor,
    onColorChanged: (color) {
      setState(() => _currentColor = color);
      context.read<BrushService>().setCurrentColor(color);
      _recordCanvasAutomation(
        'canvas.color',
        'Color',
        args: {'argb': color.toARGB32()},
      );
    },
    onClose: () => setState(() => _showColorPicker = false),
    onEyedropperTap: () => setState(() {
      _currentTool = DrawingTool.eyedropper;
      _showColorPicker = false;
    }),
  );

  Widget _brushPanel() =>
      BrushPanel(onClose: () => setState(() => _showBrushPanel = false));

  Widget _tonePanel() =>
      TonePanel(onClose: () => setState(() => _showTonePanel = false));

  Widget _stampPanel() =>
      StampPanel(onClose: () => setState(() => _showStampPanel = false));

  Widget _penSubToolPanel() => PenSubToolPanel(
    currentTool: _currentTool,
    currentSubTool: _currentSubTool,
    onSubToolSelected: (subTool) {
      setState(() {
        _currentSubTool = subTool;
        _currentTool = subTool == PenSubTool.lassoFill
            ? DrawingTool.lasso
            : DrawingTool.pen;
      });
    },
    onClose: () => setState(() => _showPenSubToolPanel = false),
    onManage: (subTool) => setState(() {
      _showPenSubToolPanel = false;
      switch (subTool) {
        case PenSubTool.brush:
          _showBrushPanel = true;
        case PenSubTool.tone:
          _showTonePanel = true;
        case PenSubTool.stamp:
          _showStampPanel = true;
        case PenSubTool.lassoFill:
          break;
      }
    }),
  );

  Widget _onionSkinPanel() => OnionSkinPanel(
    settings: _onionSkinSettings,
    onChanged: (s) => setState(() => _onionSkinSettings = s),
    onClose: () => setState(() => _showOnionSkinPanel = false),
  );

  Widget _rulerPanel() {
    final tileManager = context.read<ProjectService>().tileManagerOf(
      widget.projectId,
    );
    return RulerPanel(
      activeRuler: _activeRuler,
      onRulerChanged: _setActiveRulerWithUndo,
      onClose: () => setState(() => _showRulerPanel = false),
      canvasWidth: tileManager.canvasWidth,
      canvasHeight: tileManager.canvasHeight,
    );
  }

  void _setActiveRulerLive(Ruler? r) {
    setState(() => _activeRuler = r);
  }

  void _setActiveRulerWithUndo(Ruler? newRuler) {
    final old = _activeRuler;
    if (identical(old, newRuler)) return;
    setState(() => _activeRuler = newRuler);
    context.read<UndoManager>().push(
      RulerUndoAction(
        before: old,
        after: newRuler,
        onApply: _setActiveRulerLive,
      ),
    );
  }

  Widget _filterPanel() => FilterPanel(
    projectId: widget.projectId,
    sceneId: _currentSceneId,
    layerId: _currentLayerId,
    frameIndex: _currentFrame,
    bulkFrameIndices: _filterBulkFrames,
    activeCanvasEyedropperTarget: _filterColorEyedropperTarget,
    onStartCanvasEyedropper: _toggleFilterColorEyedropper,
    onClose: () => setState(() {
      _showFilterPanel = false;
      _filterBulkFrames = null;
      if (_frameMultiSelectMode) {
        _frameMultiSelectMode = false;
        _selectedFrameIndices = {};
      }
    }),
  );

  Widget _quickToolPanel() => QuickToolPanel(
    onClose: () => setState(() => _showQuickToolPanel = false),
    currentTool: _currentTool,
    currentBrushId: context.read<BrushService>().currentBrush?.id,
    currentBrushName: context.read<BrushService>().currentBrush?.name,
    currentSize: _brushSize,
  );

  Widget _meshTransformPanel() => MeshTransformPanel(
    density: _meshDensity,
    rotateDeg: _meshRotateDeg,
    scaleValue: _meshScaleValue,
    onDensityChanged: (v) => setState(() => _meshDensity = v),
    onRotateChanged: (v) => setState(() => _meshRotateDeg = v),
    onScaleChanged: (v) => setState(() => _meshScaleValue = v),
    onApply: _applyMeshTransform,
    onCancel: _cancelMeshTransform,
    onClose: _cancelMeshTransform,
  );

  Widget _colorAdjustPanel() => ColorAdjustSheet(
    projectId: widget.projectId,
    sceneId: _currentSceneId,
    layerId: _currentLayerId,
    frameIndex: _currentFrame,
    totalFrames: context.read<ProjectService>().frameCount(
      widget.projectId,
      _currentSceneId,
    ),
    onClose: () => setState(() => _showColorAdjustPanel = false),
  );

  Widget _sidedPanel({
    required bool anchorLeft,
    required bool leftHanded,
    required double? top,
    required double? bottom,
    required Widget child,
  }) {
    final onLeft = anchorLeft != leftHanded;
    return Positioned(
      left: onLeft ? 16 : null,
      right: onLeft ? null : 16,
      top: top,
      bottom: bottom,
      child: child,
    );
  }

  void _showBackgroundColorPicker(BuildContext context) {
    final ps = context.read<ProjectService>();
    final project = ps.projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (project == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ScrollableSheetBody(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.newProjectBackgroundColorLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              const SizedBox(height: 12),
              BackgroundColorSwatchPicker(
                selectedColor: Color(project.backgroundColor),
                onChanged: (color) {
                  ps.updateProjectBackgroundColor(
                    widget.projectId,
                    color.toARGB32(),
                  );
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyNextQuickTool() {
    final entry = context.read<QuickToolService>().next();
    if (entry == null) return;
    _activateToolSelection(
      toolKey: entry.toolKey,
      brushId: entry.brushId,
      sizeOverride: entry.sizeOverride,
    );
  }

  void _activateToolSelection({
    required String toolKey,
    String? brushId,
    double? sizeOverride,
  }) {
    setState(() => _currentTool = DrawingTool.values.byName(toolKey));
    if (brushId != null) {
      context.read<BrushService>().selectBrush(brushId);
    }
    if (sizeOverride != null) {
      context.read<BrushService>().updateCurrentBrushSize(sizeOverride);
      setState(() => _brushSize = sizeOverride);
    }
  }

  void _selectAllLayers() => setState(() {
    _showLayerPanel = true;
    _layerSelectAllToken++;
  });

  void _copyActiveLayer() {
    if (_currentLayerId == null) return;
    setState(() => _copiedLayerId = _currentLayerId);
  }

  void _pasteCopiedLayer() {
    final sourceId = _copiedLayerId;
    if (sourceId == null) return;
    final copy = context.read<ProjectService>().duplicateLayer(
      projectId: widget.projectId,
      sceneId: _currentSceneId,
      frameIndex: _currentFrame,
      layerId: sourceId,
      nameOverride: null,
    );
    if (copy == null) return;
    setState(() => _currentLayerId = copy.id);
  }

  void _toggleLayerPanel() => setState(() {
    final next = !_showLayerPanel;
    _closeAllOverlayPanels();
    _showLayerPanel = next;
  });

  Map<ShortcutActivator, VoidCallback> _buildShortcutBindings(
    BuildContext context,
  ) {
    final bindings = context.watch<ShortcutService>().bindings;
    final result = <ShortcutActivator, VoidCallback>{};
    for (final b in bindings) {
      if (b.isToolAction) {
        result[b.activator] = () => _activateToolSelection(
          toolKey: b.toolKey!,
          brushId: b.brushId,
          sizeOverride: b.sizeOverride,
        );
        continue;
      }
      switch (b.command) {
        case ShortcutCommand.undo:
          result[b.activator] = () => context.read<UndoManager>().undo();
        case ShortcutCommand.redo:
          result[b.activator] = () => context.read<UndoManager>().redo();
        case ShortcutCommand.toggleLayerPanel:
          result[b.activator] = _toggleLayerPanel;
        case ShortcutCommand.selectAll:
          result[b.activator] = _selectAllLayers;
        case ShortcutCommand.copy:
          result[b.activator] = _copyActiveLayer;
        case ShortcutCommand.paste:
          result[b.activator] = _pasteCopiedLayer;
        case ShortcutCommand.cut:
        case ShortcutCommand.playPause:
        case ShortcutCommand.previousFrame:
        case ShortcutCommand.nextFrame:
        case null:
          break;
      }
    }
    return result;
  }

  void _handleGestureToggleTool(DrawingTool tool) {
    setState(() {
      if (_currentTool == tool) {
        _currentTool = _toolBeforeGestureToggle ?? DrawingTool.pen;
        _toolBeforeGestureToggle = null;
      } else {
        _toolBeforeGestureToggle = _currentTool;
        _currentTool = tool;
      }
    });
  }

  static Widget _topBarIconButton(
    BuildContext context,
    IconData icon, {
    required VoidCallback? onPressed,
    required String tooltip,
    bool selected = false,
  }) {
    return CanvasIconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      selected: selected,
    );
  }

  Widget _selectionToolBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    Widget chip({
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
      String? tooltip,
      bool emphasized = false,
    }) {
      final enabled = onTap != null;
      final fg = emphasized
          ? scheme.onPrimary
          : scheme.onSurface.withValues(alpha: enabled ? 1.0 : 0.38);
      return Tooltip(
        message: tooltip ?? label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 72,
            height: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: emphasized
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: emphasized
                  ? null
                  : Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: fg),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                chip(
                  icon: Icons.crop_free,
                  label: l10n.canvasSelectionFreeTransform,
                  onTap: () => _openMeshTransformPanel(),
                ),
                chip(
                  icon: Icons.grid_on,
                  label: l10n.canvasSelectionMeshTransform,
                  onTap: () => _openMeshTransformPanel(density: 3),
                ),
                chip(
                  icon: Icons.close,
                  label: l10n.canvasSelectionRevertButton,
                  tooltip: l10n.canvasSelectionRevertTooltip,
                  onTap: _cancelSelectionTransformAndExit,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                chip(
                  icon: Icons.select_all,
                  label: l10n.canvasSelectAllButton,
                  onTap: () => setState(() => _selectAllSelectionToken++),
                ),
                chip(
                  icon: Icons.deselect,
                  label: l10n.canvasDeselectAllButton,
                  onTap: _hasActiveSelection
                      ? () => setState(() => _clearSelectionToken++)
                      : null,
                ),
                chip(
                  icon: Icons.check,
                  label: l10n.canvasSelectionApplyButton,
                  tooltip: l10n.canvasSelectionApplyTooltip,
                  emphasized: true,
                  onTap: _exitSelectionTool,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meshCancelBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonalIcon(
              onPressed: _cancelMeshTransform,
              icon: const Icon(Icons.close),
              label: Text(l10n.commonCancel),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: _applyMeshTransform,
              icon: const Icon(Icons.check),
              label: Text(l10n.meshTransformApplyButton),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelSelectionTransformAndExit() {
    _revertSelectionTransforms();
    _exitSelectionTool();
  }

  void _revertSelectionTransforms() {
    final undo = context.read<UndoManager>();
    for (var i = 0; i < _selectionTransformSteps; i++) {
      if (!undo.canUndo) break;
      undo.undo();
    }
    setState(() {
      _selectionTransformSteps = 0;
      _resetSelectionSliders();
    });
  }

  double _selectionSliderMaxMove(BuildContext context) {
    final project = context
        .read<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    final w = (project?.exportWidth ?? 1920).toDouble();
    final h = (project?.exportHeight ?? 1080).toDouble();
    return (w < h ? w : h) / 2;
  }

  Widget _meshDensitySlider(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              l10n.meshTransformDensityLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurface),
            ),
          ),
          Expanded(
            child: Slider(
              value: _meshDensity.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) => setState(() => _meshDensity = v.round()),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              '$_meshDensity×$_meshDensity',
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  void _resetSelectionSliders() {
    _selectionMoveX = 0;
    _selectionMoveY = 0;
    _selectionScale = 1;
    _selectionRotateDeg = 0;
  }

  void _exitSelectionTool() => setState(() {
    _clearSelectionToken++;
    _currentTool = DrawingTool.pen;
  });

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _topBarIconButton(
            context,
            Icons.undo,
            onPressed: () => context.read<UndoManager>().undo(),
            tooltip: l10n.commonUndo,
          ),
          _topBarIconButton(
            context,
            Icons.redo,
            onPressed: () => context.read<UndoManager>().redo(),
            tooltip: l10n.commonRedo,
          ),
          if (_currentTool == DrawingTool.lasso &&
              _currentSubTool == PenSubTool.lassoFill) ...[
            const SizedBox(width: 8),
            Text(
              l10n.canvasLassoEnclosedLabel,
              style: const TextStyle(fontSize: 12),
            ),
            Switch(
              value: _lassoFillEnclosedMode,
              onChanged: (v) => setState(() => _lassoFillEnclosedMode = v),
            ),
          ],
          if (_isSelectionToolActive && _hasActiveSelection) ...[
            const SizedBox(width: 8),
            _topBarIconButton(
              context,
              Icons.invert_colors_outlined,
              onPressed: () => setState(() => _invertSelectionToken++),
              tooltip: l10n.canvasInvertSelectionTooltip,
            ),
          ],
          if (_currentTool == DrawingTool.text)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                l10n.canvasTapToEnterTextLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          const Spacer(),
          _topBarIconButton(
            context,
            Icons.settings,
            onPressed: () => _showEditMenu(context),
            tooltip: l10n.canvasSettingsMenuTooltip,
          ),
          _topBarIconButton(
            context,
            Icons.home_outlined,
            onPressed: _confirmBackToProjectList,
            tooltip: l10n.timelineBackToProjectListTooltip,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBackToProjectList() async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.timelineBackToProjectListDialogTitle),
        content: Text(l10n.timelineBackToProjectListDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(l10n.timelineBackToProjectListDiscardButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(l10n.timelineBackToProjectListSaveButton),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'save') {
      await context.push('/save-tree/${widget.projectId}');
      if (!mounted) return;
    }
    if (mounted) context.go('/home');
  }

  Widget _buildFrameMultiSelectBar() {
    final l10n = AppLocalizations.of(context)!;
    final total = context.watch<ProjectService>().frameCount(
      widget.projectId,
      _currentSceneId,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          Text(
            l10n.canvasFrameSelectedCount(_selectedFrameIndices.length, total),
            style: const TextStyle(fontSize: 12),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(
              () => _selectedFrameIndices = {for (int i = 0; i < total; i++) i},
            ),
            child: Text(
              l10n.canvasSelectAllButton,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedFrameIndices = {}),
            child: Text(
              l10n.canvasDeselectAllButton,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          FilledButton.icon(
            onPressed: _selectedFrameIndices.isEmpty
                ? null
                : () => setState(() {
                    _filterBulkFrames = _selectedFrameIndices;
                    _showFilterPanel = true;
                  }),
            icon: const Icon(Icons.blur_on, size: 14),
            label: Text(
              l10n.canvasApplyFilterButton,
              style: const TextStyle(fontSize: 12),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.commonCancel,
            onPressed: () => setState(() {
              _frameMultiSelectMode = false;
              _selectedFrameIndices = {};
            }),
          ),
        ],
      ),
    );
  }

  void _showFingerSubMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pan_tool_alt),
              title: Text(l10n.toolbarFingerSubtoolWarp),
              selected: _currentTool == DrawingTool.finger,
              onTap: () {
                setState(() => _currentTool = DrawingTool.finger);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.blur_on),
              title: Text(l10n.toolbarItemBlur),
              selected: _currentTool == DrawingTool.blur,
              onTap: () {
                setState(() => _currentTool = DrawingTool.blur);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_4x4),
              title: Text(l10n.toolbarItemMosaic),
              selected: _currentTool == DrawingTool.mosaic,
              onTap: () {
                setState(() => _currentTool = DrawingTool.mosaic);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showShapeMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.not_interested),
              title: Text(l10n.canvasShapeOff),
              selected: _shapeKind == ShapeKind.off,
              onTap: () {
                setState(() {
                  _shapeKind = ShapeKind.off;
                  _currentTool = DrawingTool.pen;
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: Text(l10n.canvasShapeLine),
              selected: _shapeKind == ShapeKind.line,
              onTap: () {
                setState(() {
                  _shapeKind = ShapeKind.line;
                  _currentTool = DrawingTool.shape;
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.crop_square),
              title: Text(l10n.canvasShapeRect),
              selected: _shapeKind == ShapeKind.rect,
              onTap: () {
                setState(() {
                  _shapeKind = ShapeKind.rect;
                  _currentTool = DrawingTool.shape;
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: Text(l10n.canvasShapeCircle),
              selected: _shapeKind == ShapeKind.circle,
              onTap: () {
                setState(() {
                  _shapeKind = ShapeKind.circle;
                  _currentTool = DrawingTool.shape;
                });
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  String get _currentSceneId {
    final scenes = context.read<ProjectService>().scenesOf(widget.projectId);
    return scenes.isNotEmpty ? scenes.first.id : 'Scene0001';
  }

  void onCanvasTapForText(Offset position) {
    if (_currentTool != DrawingTool.text) return;
    _showTextInputDialog(position);
  }

  void editTextLayer(String layerId, model.TextObject text) {
    _showTextInputDialog(
      text.position,
      existingLayerId: layerId,
      existing: text,
    );
  }

  void _onEditTextLayerTapped(model.Layer layer) {
    final text = layer.textObject;
    if (text == null) return;
    editTextLayer(layer.id, text);
  }

  static const _textColorPalette = [
    0xFF000000,
    0xFFFFFFFF,
    0xFFFF0000,
    0xFF0066FF,
    0xFFFFCC00,
    0xFF00CC66,
    0xFFFF66CC,
    0xFF888888,
  ];

  void _showTextInputDialog(
    Offset position, {
    String? existingLayerId,
    model.TextObject? existing,
  }) {
    final controller = TextEditingController(text: existing?.text ?? '');
    double fontSize = existing?.fontSize ?? 24;
    int color = existing?.color.toARGB32() ?? 0xFF000000;
    bool isBold = existing?.isBold ?? false;
    bool isItalic = existing?.isItalic ?? false;
    String fontFamily = existing?.fontFamily ?? 'Roboto';
    double lineHeight = existing?.lineHeight ?? 1.2;
    double letterSpacing = existing?.letterSpacing ?? 0;
    TextAlign textAlign = existing?.align ?? TextAlign.left;
    bool outlineEnabled = existing?.outline?.enabled ?? false;
    int outlineColor = existing?.outline?.color.toARGB32() ?? 0xFF000000;
    double outlineWidth = existing?.outline?.width ?? 3;
    model.TextWritingDirection direction =
        existing?.direction ?? model.TextWritingDirection.horizontal;
    final fontService = context.read<FontService>();
    final l10n = AppLocalizations.of(context)!;

    model.TextObject textDraft() {
      final base =
          existing ??
          model.TextObject(
            id: '__text_color_draft__',
            text: controller.text,
            position: position,
          );
      return base.copyWith(
        text: controller.text,
        fontSize: fontSize,
        color: Color(color),
        isBold: isBold,
        isItalic: isItalic,
        fontFamily: fontFamily,
        lineHeight: lineHeight,
        letterSpacing: letterSpacing,
        align: textAlign,
        direction: direction,
        outline: model.TextOutline(
          enabled: outlineEnabled,
          color: Color(outlineColor),
          width: outlineWidth,
        ),
      );
    }

    void startTextCanvasEyedropper(
      _TextColorEyedropperTarget target,
      BuildContext dialogContext,
    ) {
      final draft = textDraft();
      Navigator.of(dialogContext).pop();
      setState(() {
        _textColorEyedropperTarget = target;
        _pendingTextColorEyedropper = (picked) {
          final next = target == _TextColorEyedropperTarget.body
              ? draft.copyWith(color: picked)
              : draft.copyWith(
                  outline: model.TextOutline(
                    enabled: true,
                    color: picked,
                    width: draft.outline?.width ?? outlineWidth,
                  ),
                );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showTextInputDialog(
              position,
              existingLayerId: existingLayerId,
              existing: next,
            );
          });
        };
      });
    }

    Future<void> pickTextColor(
      BuildContext dialogContext,
      int current,
      ValueChanged<int> onChanged,
    ) async {
      await showDialog<void>(
        context: dialogContext,
        builder: (pickerContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
            child: ColorPickerPanel(
              currentColor: Color(current),
              onColorChanged: (picked) {
                onChanged(picked.toARGB32());
                Navigator.of(pickerContext).pop();
              },
              onClose: () => Navigator.of(pickerContext).pop(),
            ),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => DisposeOnUnmount(
        controller: controller,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text(
              existingLayerId == null
                  ? l10n.canvasTextInputTitle
                  : l10n.canvasTextEditTitle,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: l10n.canvasTextInputHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: fontFamily,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.canvasTextFontLabel,
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'Roboto',
                        child: Text(l10n.canvasTextStandardFont),
                      ),
                      for (final f in kBundledFonts)
                        DropdownMenuItem(
                          value: f.family,
                          child: Text(
                            f.displayName,
                            style: TextStyle(fontFamily: f.family),
                          ),
                        ),
                      ...fontService.fonts.map(
                        (f) => DropdownMenuItem(
                          value: fontService.familyNameOf(f),
                          child: Text(
                            f.displayName,
                            style: TextStyle(
                              fontFamily: fontService.familyNameOf(f),
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setS(() => fontFamily = v ?? 'Roboto'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        l10n.brushSettingsSizeLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: SteppedSlider(
                          value: fontSize,
                          min: 8,
                          max: 200,
                          label: fontSize.round().toString(),
                          onChanged: (v) => setS(() => fontSize = v),
                        ),
                      ),
                      EditableSliderValue(
                        text: '${fontSize.round()}',
                        style: const TextStyle(fontSize: 12),
                        value: fontSize,
                        min: 8,
                        max: 200,
                        onChanged: (v) => setS(() => fontSize = v.toDouble()),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      FilterChip(
                        label: Text(l10n.canvasTextBold),
                        selected: isBold,
                        onSelected: (v) => setS(() => isBold = v),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(l10n.canvasTextItalic),
                        selected: isItalic,
                        onSelected: (v) => setS(() => isItalic = v),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: Icon(
                          direction == model.TextWritingDirection.vertical
                              ? Icons.text_rotate_vertical
                              : Icons.text_rotation_none,
                          size: 16,
                        ),
                        label: Text(
                          direction == model.TextWritingDirection.vertical
                              ? l10n.canvasTextVertical
                              : l10n.canvasTextHorizontal,
                        ),
                        onPressed: () => setS(() {
                          direction =
                              direction == model.TextWritingDirection.vertical
                              ? model.TextWritingDirection.horizontal
                              : model.TextWritingDirection.vertical;
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 18),
                        tooltip: l10n.canvasTypesettingHelpTooltip,
                        onPressed: () => _showVerticalTextHelp(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => pickTextColor(
                          ctx,
                          color,
                          (v) => setS(() => color = v),
                        ),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(ctx).colorScheme.outline,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.colorize),
                        tooltip: l10n.toolbarItemEyedropper,
                        onPressed: () => startTextCanvasEyedropper(
                          _TextColorEyedropperTarget.body,
                          ctx,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: _textColorPalette
                        .map(
                          (c) => GestureDetector(
                            onTap: () => setS(() => color = c),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Color(c),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color == c
                                      ? Theme.of(ctx).colorScheme.primary
                                      : ThemeService
                                            .activeColorScheme
                                            .onSurfaceVariant,
                                  width: color == c ? 2 : 1,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        l10n.canvasTextLineHeight,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: SteppedSlider(
                          value: lineHeight,
                          min: 0.8,
                          max: 3.0,
                          step: 0.1,
                          label: lineHeight.toStringAsFixed(1),
                          onChanged: (v) => setS(() => lineHeight = v),
                        ),
                      ),
                      EditableSliderValue(
                        text: lineHeight.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12),
                        value: lineHeight,
                        min: 0.8,
                        max: 3.0,
                        isInt: false,
                        onChanged: (v) => setS(() => lineHeight = v.toDouble()),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        l10n.canvasTextLetterSpacing,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: SteppedSlider(
                          value: letterSpacing,
                          min: -2,
                          max: 20,
                          label: letterSpacing.toStringAsFixed(0),
                          onChanged: (v) => setS(() => letterSpacing = v),
                        ),
                      ),
                      EditableSliderValue(
                        text: letterSpacing.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 12),
                        value: letterSpacing,
                        min: -2,
                        max: 20,
                        onChanged: (v) =>
                            setS(() => letterSpacing = v.toDouble()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        l10n.canvasTextAlign,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<TextAlign>(
                        segments: const [
                          ButtonSegment(
                            value: TextAlign.left,
                            icon: Icon(Icons.format_align_left, size: 16),
                          ),
                          ButtonSegment(
                            value: TextAlign.center,
                            icon: Icon(Icons.format_align_center, size: 16),
                          ),
                          ButtonSegment(
                            value: TextAlign.right,
                            icon: Icon(Icons.format_align_right, size: 16),
                          ),
                        ],
                        selected: {textAlign},
                        onSelectionChanged: (v) =>
                            setS(() => textAlign = v.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilterChip(
                    label: Text(l10n.canvasTextOutline),
                    selected: outlineEnabled,
                    onSelected: (v) => setS(() => outlineEnabled = v),
                  ),
                  if (outlineEnabled) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => pickTextColor(
                            ctx,
                            outlineColor,
                            (v) => setS(() => outlineColor = v),
                          ),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Color(outlineColor),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(ctx).colorScheme.outline,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.colorize),
                          tooltip: l10n.toolbarItemEyedropper,
                          onPressed: () => startTextCanvasEyedropper(
                            _TextColorEyedropperTarget.outline,
                            ctx,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: _textColorPalette
                          .map(
                            (c) => GestureDetector(
                              onTap: () => setS(() => outlineColor = c),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: outlineColor == c
                                        ? Theme.of(ctx).colorScheme.primary
                                        : ThemeService
                                              .activeColorScheme
                                              .onSurfaceVariant,
                                    width: outlineColor == c ? 2 : 1,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    Row(
                      children: [
                        Text(
                          l10n.canvasOutlineWidthLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Expanded(
                          child: SteppedSlider(
                            value: outlineWidth,
                            min: 0,
                            max: 20,
                            label: outlineWidth.round().toString(),
                            onChanged: (v) => setS(() => outlineWidth = v),
                          ),
                        ),
                        EditableSliderValue(
                          text: '${outlineWidth.round()}',
                          style: const TextStyle(fontSize: 12),
                          value: outlineWidth,
                          min: 0,
                          max: 20,
                          onChanged: (v) =>
                              setS(() => outlineWidth = v.toDouble()),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () async {
                  if (controller.text.isEmpty) {
                    Navigator.pop(ctx);
                    return;
                  }
                  final ps = context.read<ProjectService>();
                  final sceneId = _currentSceneId;
                  model.Layer layer;
                  model.TextObject textObject;
                  if (existingLayerId != null && existing != null) {
                    final current = ps
                        .layersOf(widget.projectId, sceneId, _currentFrame)
                        .where((l) => l.id == existingLayerId)
                        .firstOrNull;
                    if (current == null) {
                      Navigator.pop(ctx);
                      return;
                    }
                    layer = current;
                    textObject = existing.copyWith(
                      text: controller.text,
                      fontSize: fontSize,
                      color: Color(color),
                      isBold: isBold,
                      isItalic: isItalic,
                      fontFamily: fontFamily,
                      lineHeight: lineHeight,
                      letterSpacing: letterSpacing,
                      align: textAlign,
                      direction: direction,
                      outline: model.TextOutline(
                        enabled: outlineEnabled,
                        color: Color(outlineColor),
                        width: outlineWidth,
                      ),
                    );
                  } else {
                    layer = ps.addTextLayer(
                      projectId: widget.projectId,
                      sceneId: sceneId,
                      frameIndex: _currentFrame,
                      text: controller.text,
                      position: position,
                    );
                    textObject =
                        (layer.textObject ??
                                model.TextObject(
                                  id: layer.id,
                                  text: controller.text,
                                  position: position,
                                ))
                            .copyWith(
                              fontSize: fontSize,
                              color: Color(color),
                              isBold: isBold,
                              isItalic: isItalic,
                              fontFamily: fontFamily,
                              lineHeight: lineHeight,
                              letterSpacing: letterSpacing,
                              align: textAlign,
                              direction: direction,
                              outline: model.TextOutline(
                                enabled: outlineEnabled,
                                color: Color(outlineColor),
                                width: outlineWidth,
                              ),
                            );
                  }
                  final tileManager = ps.tileManagerOf(widget.projectId);
                  final bytes = await rasterizeTextObject(
                    textObject,
                    tileManager.canvasWidth,
                    tileManager.canvasHeight,
                    pixelMode: fontService.pixelModeForFamily(fontFamily),
                  );
                  if (bytes != null) {
                    tileManager.replaceLayerPixels(
                      ps.tileKeyFor(
                        widget.projectId,
                        sceneId,
                        _currentFrame,
                        layer.id,
                      ),
                      bytes,
                    );
                  }
                  ps.updateLayer(
                    projectId: widget.projectId,
                    sceneId: sceneId,
                    frameIndex: _currentFrame,
                    layer: layer.copyWith(textObject: textObject),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVerticalTextHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(l10n.canvasTypesettingHelpTooltip)),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.canvasHelpRotationTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              Text(l10n.canvasHelpRotationBody),
              const SizedBox(height: 8),
              Text(
                l10n.canvasHelpTatechuyokoTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              Text(l10n.canvasHelpTatechuyokoBody),
              const SizedBox(height: 8),
              Text(
                l10n.canvasHelpRubyTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Kuramubon',
                  fontFamilyFallback: kHeadingFontFallback,
                ),
              ),
              Text(l10n.canvasHelpRubyBody('{漢字|かんじ}')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final ValueChanged<double> onDeltaX;
  final VoidCallback onDragEnd;
  const _ResizeHandle({required this.onDeltaX, required this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDeltaX(d.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd(),
        child: Container(
          width: 8,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 2,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

enum _TextColorEyedropperTarget { body, outline }

enum DrawingTool {
  pen,
  eraser,
  bucket,
  lasso,
  eyedropper,
  finger,
  blur,
  mosaic,
  selectRect,
  selectLasso,
  selectMagicWand,
  move,
  ruler,
  text,
  shape,
  pan,
  meshTransform,
}

enum SelectionTransformMode { move, scale, rotate }

enum ShapeKind { off, line, rect, circle }
