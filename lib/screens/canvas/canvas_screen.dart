import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/advertising_service.dart';
import '../../services/autosave_service.dart';
import '../../services/project_service.dart';
import '../../services/brush_service.dart';
import '../../services/font_service.dart';
import '../../services/material_service.dart';
import '../../services/performance_service.dart';
import '../../services/quick_tool_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../engine/text_render.dart';
import '../../engine/undo_manager.dart';
import '../../models/layer.dart' as model;
import '../../models/onion_skin_settings.dart';
import '../../models/project.dart';
import '../../models/text_object.dart' as model;
import 'widgets/canvas_area.dart';
import 'widgets/toolbar_widget.dart';
import 'widgets/frame_strip_widget.dart';
import 'widgets/brush_size_slider.dart';
import 'widgets/layer_panel.dart';
import 'widgets/color_picker_panel.dart';
import 'widgets/brush_panel.dart';
import 'widgets/pen_sub_tool_panel.dart';
import 'widgets/onion_skin_panel.dart';
import 'widgets/ruler_panel.dart';
import 'widgets/filter_panel.dart';
import 'widgets/quick_tool_panel.dart';
import '../../models/ruler.dart';
import '../../widgets/responsive.dart';

class CanvasScreen extends StatefulWidget {
  final String projectId;
  const CanvasScreen({super.key, required this.projectId});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  DrawingTool _currentTool = DrawingTool.pen;
  // ジェスチャー／ペンボタンでの消しゴム切替・ブラシ切替・手のひらツール
  // トグル用に、切替前のツールを一時的に覚えておく（仕様書08）。
  DrawingTool? _toolBeforeGestureToggle;
  PenSubTool _currentSubTool = PenSubTool.brush;
  double _brushSize = 5;
  int _brushOpacity = 100;
  Color _currentColor = Colors.black;
  int _currentFrame = 0;
  bool _showLayerPanel = false;
  bool _showColorPicker = false;
  bool _showBrushPanel = false;
  bool _showPenSubToolPanel = false;
  bool _showOnionSkinPanel = false;
  bool _showRulerPanel = false;
  bool _showFilterPanel = false;
  bool _showQuickToolPanel = false;
  // フレーム複数選択モード（仕様書18：大量処理実行時のフィルター一括適用）
  bool _frameMultiSelectMode = false;
  Set<int> _selectedFrameIndices = {};
  // nullなら現在フレームのみへ適用、非nullなら選択中の全フレームへ一括適用
  Set<int>? _filterBulkFrames;
  Ruler? _activeRuler;

  // キャンバス背景（仕様書27：白 / 透過）
  CanvasBackground _canvasBackground = CanvasBackground.white;

  // 投げ縄塗り：囲って塗るモード
  bool _lassoFillEnclosedMode = false;

  // 図形ツール：現在選択中の種別（OFF/線/四角形/円）
  ShapeKind _shapeKind = ShapeKind.off;

  OnionSkinSettings _onionSkinSettings = const OnionSkinSettings();
  QualityLevel? _lastQualityLevel;
  PerformanceService? _perf;

  String? _currentLayerId;
  bool _autosaveAttached = false;
  bool _workTrackingStarted = false;
  bool _missingMaterialChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // BrushServiceの現在ブラシ設定をローカル状態に同期（初回のみ有効）
    final brush = context.read<BrushService>().currentBrush;
    if (brush != null) {
      _brushSize = brush.size;
      _brushOpacity = brush.opacity;
    }
    // 現在レイヤーIDを初期化
    if (_currentLayerId == null) {
      final scenes = context.read<ProjectService>().scenesOf(widget.projectId);
      if (scenes.isNotEmpty && scenes.first.frames.isNotEmpty) {
        final layers = scenes.first.frames.first.layers;
        if (layers.isNotEmpty) _currentLayerId = layers.first.id;
      }
    }
    // PerformanceServiceをlistenerで監視（依存差し替えに対応）
    final newPerf = context.read<PerformanceService>();
    if (newPerf != _perf) {
      _perf?.removeListener(_onPerfChanged);
      _perf = newPerf;
      _perf!.addListener(_onPerfChanged);
      _syncOnionFromPerf();
    }
    // 自動保存（クラッシュ復元専用）をこのプロジェクトへ接続する（仕様書06・09）
    if (!_autosaveAttached) {
      _autosaveAttached = true;
      final autosave = context.read<AutosaveService>();
      autosave.attach(
        context.read<ProjectService>(),
        widget.projectId,
        undoManager: context.read<UndoManager>(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkCrashRecovery(autosave));
    }
    // 制作時間カウント（仕様書19：描画モードのみカウント）
    if (!_workTrackingStarted) {
      _workTrackingStarted = true;
      context.read<ProjectService>().beginWorkTracking(widget.projectId);
    }
    // 不足素材の検出（仕様書21：プロジェクトを開いた際に参照先の素材が
    // 見つからない場合は「不足素材があります」と表示。「再検索」で再確認）
    if (!_missingMaterialChecked) {
      _missingMaterialChecked = true;
      final materialService = context.read<MaterialService>();
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkMissingMaterials(materialService));
    }
  }

  @override
  void dispose() {
    _perf?.removeListener(_onPerfChanged);
    if (_autosaveAttached) context.read<AutosaveService>().detach();
    if (_workTrackingStarted) context.read<ProjectService>().endWorkTracking();
    super.dispose();
  }

  /// クラッシュ・ファイル破損時の復元用：プロジェクトの最終保存より新しい自動保存があれば復元を提案する。
  Future<void> _checkCrashRecovery(AutosaveService autosave) async {
    if (!mounted) return;
    final slot = autosave.latestSlotFor(widget.projectId);
    if (slot == null) return;
    final project = context.read<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (project == null || !slot.savedAt.isAfter(project.updatedAt)) return;
    if (!mounted) return;
    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自動保存データがあります'),
        content: const Text('前回の保存より新しい自動保存データが見つかりました。復元しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('無視')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('復元')),
        ],
      ),
    );
    if (restore != true || !mounted) return;
    final data = await autosave.restore(widget.projectId, slot.slotIndex);
    if (data == null || !mounted) return;
    context.read<ProjectService>().restoreFromAutosave(widget.projectId, data);
  }

  /// 不足素材の検出（仕様書21）。プロジェクトを開いた際に参照先の素材ファイルが
  /// 見つからない場合、「不足素材があります」と「再検索」ボタンを表示する。
  Future<void> _checkMissingMaterials(MaterialService materialService) async {
    final missing = await materialService.detectMissing(widget.projectId);
    if (!mounted || missing.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('不足素材があります'),
        action: SnackBarAction(
          label: '再検索',
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
    final newShowPrev = level != QualityLevel.custom ? true : perf.showPrevOnion;
    final newShowNext = level != QualityLevel.custom ? true : perf.showNextOnion;
    // qualityLevel・枚数・showPrev/showNextのいずれかが変化した場合のみ同期
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
    final adService = context.watch<AdvertisingService>();
    final project = context.watch<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    // PC/DeXモード（広い画面）：レイヤーパネルをフローティング表示ではなく、
    // 常時表示のドッキングパネルとして右側に固定する（プロ向けレイアウト）。
    final isDesktop = isWideScreen(context);
    final dockedToolPanel = isDesktop ? _activeToolPanel() : null;
    // 左利きモード（仕様書08）：フローティング／ドッキングパネルを左右反転し、
    // 描画する手の側にパネルが重ならないようにする。
    final leftHanded = context.watch<SettingsService>().isLeftHanded;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (adService.shouldShowAds)
              const AdBannerWidget(position: AdPosition.top),
            _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  // PC/DeXモード：ツールオプション系パネルはフローティングではなく
                  // キャンバス左側（左利きモード時は右側）の常時ドッキングパネル
                  // として表示する。
                  if (dockedToolPanel != null && !leftHanded)
                    SizedBox(width: 280, child: dockedToolPanel),
                  Expanded(
                    child: Stack(
                      children: [
                  CanvasArea(
                    onTapForText: _currentTool == DrawingTool.text
                        ? onCanvasTapForText
                        : null,
                    onEyedropper: (color) {
                      setState(() => _currentColor = color);
                      context.read<BrushService>().setCurrentColor(color);
                    },
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
                    shapeKind: _shapeKind,
                    onGestureToolChange: (tool) => setState(() => _currentTool = tool),
                    onGestureToggleTool: _handleGestureToggleTool,
                    onNextQuickTool: _applyNextQuickTool,
                    onToggleOnionSkin: () => setState(() =>
                        _onionSkinSettings = _onionSkinSettings.copyWith(enabled: !_onionSkinSettings.enabled)),
                  ),
                  if (_showLayerPanel && !isDesktop)
                    Positioned(
                      left: leftHanded ? 0 : null,
                      right: leftHanded ? null : 0,
                      top: 0, bottom: 0, width: 250,
                      child: LayerPanel(
                        onClose: () => setState(() => _showLayerPanel = false),
                        projectId: widget.projectId,
                        sceneId: _currentSceneId,
                        frameIndex: _currentFrame,
                        onEditTextLayer: _onEditTextLayerTapped,
                      ),
                    ),
                  if (_showColorPicker && !isDesktop)
                    _sidedPanel(anchorLeft: true, leftHanded: leftHanded, top: null, bottom: 16, child: _colorPickerPanel()),
                  if (_showBrushPanel && !isDesktop)
                    _sidedPanel(anchorLeft: true, leftHanded: leftHanded, top: 16, bottom: null, child: _brushPanel()),
                  // ペンサブツールパネル（ブラシ/トーン/スタンプ/投げ縄塗り）
                  if (_showPenSubToolPanel && !isDesktop)
                    _sidedPanel(anchorLeft: true, leftHanded: leftHanded, top: 16, bottom: null, child: _penSubToolPanel()),
                  // オニオンスキンパネル
                  if (_showOnionSkinPanel && !isDesktop)
                    _sidedPanel(anchorLeft: false, leftHanded: leftHanded, top: 16, bottom: null, child: _onionSkinPanel()),
                  // 定規パネル
                  if (_showRulerPanel && !isDesktop)
                    _sidedPanel(anchorLeft: true, leftHanded: leftHanded, top: 16, bottom: null, child: _rulerPanel()),
                  // フィルターパネル（仕様書18：描画フィルター）
                  if (_showFilterPanel && !isDesktop)
                    _sidedPanel(anchorLeft: false, leftHanded: leftHanded, top: 16, bottom: null, child: _filterPanel()),
                  // 早替えツール設定パネル（仕様書02・08）
                  if (_showQuickToolPanel && !isDesktop)
                    _sidedPanel(anchorLeft: false, leftHanded: leftHanded, top: null, bottom: 16, child: _quickToolPanel()),
                      ],
                    ),
                  ),
                  if (dockedToolPanel != null && leftHanded)
                    SizedBox(width: 280, child: dockedToolPanel),
                  if (isDesktop)
                    SizedBox(
                      width: 280,
                      child: LayerPanel(
                        onClose: () {},
                        projectId: widget.projectId,
                        sceneId: _currentSceneId,
                        frameIndex: _currentFrame,
                        dockedMode: true,
                        onEditTextLayer: _onEditTextLayerTapped,
                      ),
                    ),
                ],
              ),
            ),
            BrushSizeSlider(
              brushSize: _brushSize,
              opacity: _brushOpacity,
              onSizeChanged: (v) {
                setState(() => _brushSize = v);
                context.read<BrushService>().updateCurrentBrushSize(v);
              },
              onOpacityChanged: (v) {
                setState(() => _brushOpacity = v);
                context.read<BrushService>().updateCurrentBrushOpacity(v);
              },
            ),
            ToolbarWidget(
              currentTool: _currentTool,
              currentColor: _currentColor,
              isStampSelected: _currentSubTool == PenSubTool.stamp,
              onToolSelected: (tool) => setState(() => _currentTool = tool),
              onColorTap: () => setState(() => _showColorPicker = !_showColorPicker),
              onBrushTap: () => setState(() {
                _showBrushPanel = !_showBrushPanel;
                _showPenSubToolPanel = false;
              }),
              onLayerTap: () => setState(() => _showLayerPanel = !_showLayerPanel),
              onTimelineTap: () => context.go('/timeline/${widget.projectId}'),
              onPenLongPress: () => setState(() {
                _showPenSubToolPanel = !_showPenSubToolPanel;
                _showBrushPanel = false;
              }),
              onOnionSkinTap: () => setState(() => _showOnionSkinPanel = !_showOnionSkinPanel),
              onTextTap: () => setState(() => _currentTool = DrawingTool.text),
              onRulerTap: () => setState(() {
                _showRulerPanel = !_showRulerPanel;
                if (_currentTool != DrawingTool.ruler) {
                  _currentTool = DrawingTool.ruler;
                }
              }),
              onShapeTap: () => _showShapeMenu(context),
              onFilterTap: () => setState(() {
                _showFilterPanel = !_showFilterPanel;
                _showLayerPanel = false;
              }),
              onQuickToolTap: _applyNextQuickTool,
              onQuickToolLongPress: () => setState(() {
                _showQuickToolPanel = !_showQuickToolPanel;
                _showLayerPanel = false;
              }),
            ),
            if (_frameMultiSelectMode) _buildFrameMultiSelectBar(),
            FrameStripWidget(
              currentFrame: _currentFrame,
              projectId: widget.projectId,
              sceneId: _currentSceneId,
              onFrameSelected: (idx) => setState(() => _currentFrame = idx),
              onTimelineTap: () => context.go('/timeline/${widget.projectId}'),
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
      ),
    );
  }

  // PC/DeXモード（広い画面）：現在開いているツールオプション系パネルを1つ
  // 返す（複数同時に開いていた場合は優先度の高いものを返す）。左側の
  // 常時ドッキングパネルに使う。フローティング表示（スマホ）と同じ
  // パネルインスタンスを流用する。
  Widget? _activeToolPanel() {
    if (_showColorPicker) return _colorPickerPanel();
    if (_showPenSubToolPanel) return _penSubToolPanel();
    if (_showBrushPanel) return _brushPanel();
    if (_showOnionSkinPanel) return _onionSkinPanel();
    if (_showRulerPanel) return _rulerPanel();
    if (_showFilterPanel) return _filterPanel();
    if (_showQuickToolPanel) return _quickToolPanel();
    return null;
  }

  Widget _colorPickerPanel() => ColorPickerPanel(
        currentColor: _currentColor,
        onColorChanged: (color) {
          setState(() => _currentColor = color);
          context.read<BrushService>().setCurrentColor(color);
        },
        onClose: () => setState(() => _showColorPicker = false),
        // カラーピッカー内のスポイトボタン（仕様書20）：スポイトツールへ切り替えて
        // キャンバス上の色を取得できるようにする
        onEyedropperTap: () => setState(() {
          _currentTool = DrawingTool.eyedropper;
          _showColorPicker = false;
        }),
      );

  Widget _brushPanel() =>
      BrushPanel(onClose: () => setState(() => _showBrushPanel = false));

  Widget _penSubToolPanel() => PenSubToolPanel(
        currentTool: _currentTool,
        currentSubTool: _currentSubTool,
        onSubToolSelected: (subTool) {
          setState(() {
            _currentSubTool = subTool;
            _currentTool = subTool == PenSubTool.lassoFill ? DrawingTool.lasso : DrawingTool.pen;
          });
        },
        onClose: () => setState(() => _showPenSubToolPanel = false),
      );

  Widget _onionSkinPanel() => OnionSkinPanel(
        settings: _onionSkinSettings,
        onChanged: (s) => setState(() => _onionSkinSettings = s),
        onClose: () => setState(() => _showOnionSkinPanel = false),
      );

  Widget _rulerPanel() => RulerPanel(
        activeRuler: _activeRuler,
        onRulerChanged: (r) => setState(() => _activeRuler = r),
        onClose: () => setState(() => _showRulerPanel = false),
      );

  Widget _filterPanel() => FilterPanel(
        projectId: widget.projectId,
        sceneId: _currentSceneId,
        layerId: _currentLayerId,
        frameIndex: _currentFrame,
        bulkFrameIndices: _filterBulkFrames,
        onClose: () => setState(() {
          _showFilterPanel = false;
          _filterBulkFrames = null;
          if (_frameMultiSelectMode) {
            _frameMultiSelectMode = false;
            _selectedFrameIndices = {};
          }
        }),
      );

  Widget _quickToolPanel() =>
      QuickToolPanel(onClose: () => setState(() => _showQuickToolPanel = false));

  /// フローティングパネルの左右配置ヘルパー。[anchorLeft]は通常（右利き）モードでの
  /// 配置側。左利きモード時は[leftHanded]により全パネルをまとめて左右反転する
  /// （仕様書08：描画する手の側にパネルが重ならないようにする）。
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

  /// ツール早替えボタンタップ時：登録順に次のツールへ切り替える（仕様書02・08）。
  void _applyNextQuickTool() {
    final entry = context.read<QuickToolService>().next();
    if (entry == null) return;
    setState(() => _currentTool = DrawingTool.values.byName(entry.toolKey));
    final brushId = entry.brushId;
    if (brushId != null) {
      context.read<BrushService>().selectBrush(brushId);
    }
    final size = entry.sizeOverride;
    if (size != null) {
      context.read<BrushService>().updateCurrentBrushSize(size);
      setState(() => _brushSize = size);
    }
  }

  /// ジェスチャー／ペンボタンからのトグル切替（消しゴム切替・ブラシ切替・
  /// 手のひらツール）。既にそのツールならトグル前のツールへ戻す（仕様書08）。
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/'), tooltip: '戻る'),
          // 投げ縄塗り選択中：囲って塗るモードスイッチ
          if (_currentTool == DrawingTool.lasso && _currentSubTool == PenSubTool.lassoFill) ...[
            const SizedBox(width: 8),
            const Text('囲って塗る', style: TextStyle(fontSize: 12)),
            Switch(
              value: _lassoFillEnclosedMode,
              onChanged: (v) => setState(() => _lassoFillEnclosedMode = v),
            ),
          ],
          // テキストツール選択中：キャンバスタップでテキスト入力ダイアログを表示する旨を示すラベル
          if (_currentTool == DrawingTool.text)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('キャンバスをタップしてテキストを入力',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
            ),
          const Spacer(),
          // フレーム複数選択モード切替（仕様書18：フィルター一括適用など大量処理実行時）
          IconButton(
            icon: Icon(
              _frameMultiSelectMode ? Icons.checklist_rtl : Icons.checklist,
              size: 20,
              color: _frameMultiSelectMode ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: 'フレーム複数選択',
            onPressed: () => setState(() {
              _frameMultiSelectMode = !_frameMultiSelectMode;
              _selectedFrameIndices = {};
            }),
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () => context.read<UndoManager>().undo(),
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: () => context.read<UndoManager>().redo(),
            tooltip: 'Redo',
          ),
          // 背景切替ボタン（仕様書27：白 / 透過）
          IconButton(
            icon: Icon(
              _canvasBackground == CanvasBackground.white
                  ? Icons.check_box_outline_blank
                  : Icons.grid_4x4,
              size: 20,
            ),
            tooltip: _canvasBackground == CanvasBackground.white ? '背景：白' : '背景：透過',
            onPressed: () => setState(() {
              _canvasBackground = _canvasBackground == CanvasBackground.white
                  ? CanvasBackground.transparent
                  : CanvasBackground.white;
            }),
          ),
        ],
      ),
    );
  }

  /// フレーム複数選択モード時のアクションバー（仕様書18：大量処理実行時の
  /// フィルター一括適用）。全選択・全解除・フィルター一括適用・キャンセルを提供する。
  Widget _buildFrameMultiSelectBar() {
    final total = context.watch<ProjectService>().frameCount(widget.projectId, _currentSceneId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          Text('${_selectedFrameIndices.length} / $total フレーム選択中',
              style: const TextStyle(fontSize: 12)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(
                () => _selectedFrameIndices = {for (int i = 0; i < total; i++) i}),
            child: const Text('全選択', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedFrameIndices = {}),
            child: const Text('全解除', style: TextStyle(fontSize: 12)),
          ),
          FilledButton.icon(
            onPressed: _selectedFrameIndices.isEmpty
                ? null
                : () => setState(() {
                      _filterBulkFrames = _selectedFrameIndices;
                      _showFilterPanel = true;
                    }),
            icon: const Icon(Icons.blur_on, size: 14),
            label: const Text('フィルター適用', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'キャンセル',
            onPressed: () => setState(() {
              _frameMultiSelectMode = false;
              _selectedFrameIndices = {};
            }),
          ),
        ],
      ),
    );
  }

  /// 図形ツールタップ時のポップアップ（仕様書03：OFF/線/四角形/円）
  void _showShapeMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.not_interested),
              title: const Text('OFF（通常ブラシへ戻る）'),
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
              title: const Text('線'),
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
              title: const Text('四角形'),
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
              title: const Text('円'),
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

  /// テキストツール選択中にキャンバスタップで呼び出す。
  /// テキスト入力ダイアログを表示し、OK時にテキストレイヤーを自動生成する。
  void onCanvasTapForText(Offset position) {
    if (_currentTool != DrawingTool.text) return;
    _showTextInputDialog(position);
  }

  /// レイヤーパネルからテキストレイヤーをタップした時に呼び出す編集入口
  /// （仕様書15：既存テキストをタップすると編集開始。本実装ではレイヤー
  /// パネル経由とする。キャンバス上でのテキストボックス当たり判定による
  /// 直接タップ編集は今回のスコープ外）。
  void editTextLayer(String layerId, model.TextObject text) {
    _showTextInputDialog(text.position, existingLayerId: layerId, existing: text);
  }

  void _onEditTextLayerTapped(model.Layer layer) {
    final text = layer.textObject;
    if (text == null) return;
    editTextLayer(layer.id, text);
  }

  static const _textColorPalette = [
    0xFF000000, 0xFFFFFFFF, 0xFFFF0000, 0xFF0066FF,
    0xFFFFCC00, 0xFF00CC66, 0xFFFF66CC, 0xFF888888,
  ];

  void _showTextInputDialog(Offset position, {String? existingLayerId, model.TextObject? existing}) {
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
    model.TextWritingDirection direction = existing?.direction ?? model.TextWritingDirection.horizontal;
    final fontService = context.read<FontService>();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existingLayerId == null ? 'テキスト入力' : 'テキスト編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: null,
                  decoration: const InputDecoration(hintText: 'テキストを入力してください'),
                ),
                const SizedBox(height: 12),
                if (fontService.fonts.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: fontFamily,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'フォント', isDense: true),
                    items: [
                      const DropdownMenuItem(value: 'Roboto', child: Text('標準フォント')),
                      ...fontService.fonts.map((f) => DropdownMenuItem(
                            value: fontService.familyNameOf(f),
                            child: Text(f.displayName, style: TextStyle(fontFamily: fontService.familyNameOf(f))),
                          )),
                    ],
                    onChanged: (v) => setS(() => fontFamily = v ?? 'Roboto'),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('サイズ', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 8, max: 200,
                        label: fontSize.round().toString(),
                        onChanged: (v) => setS(() => fontSize = v),
                      ),
                    ),
                    Text('${fontSize.round()}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('太字'),
                      selected: isBold,
                      onSelected: (v) => setS(() => isBold = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('斜体'),
                      selected: isItalic,
                      onSelected: (v) => setS(() => isItalic = v),
                    ),
                    const SizedBox(width: 8),
                    // 縦書き・横書きのワンタップ切替（仕様書15）
                    ActionChip(
                      avatar: Icon(
                        direction == model.TextWritingDirection.vertical
                            ? Icons.text_rotate_vertical
                            : Icons.text_rotation_none,
                        size: 16,
                      ),
                      label: Text(direction == model.TextWritingDirection.vertical ? '縦書き' : '横書き'),
                      onPressed: () => setS(() {
                        direction = direction == model.TextWritingDirection.vertical
                            ? model.TextWritingDirection.horizontal
                            : model.TextWritingDirection.vertical;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _textColorPalette.map((c) => GestureDetector(
                    onTap: () => setS(() => color = c),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == c ? Theme.of(ctx).colorScheme.primary : Colors.grey,
                          width: color == c ? 2 : 1,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('行間', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: lineHeight, min: 0.8, max: 3.0,
                        label: lineHeight.toStringAsFixed(1),
                        onChanged: (v) => setS(() => lineHeight = v),
                      ),
                    ),
                    Text(lineHeight.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    const Text('文字間隔', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: letterSpacing, min: -2, max: 20,
                        label: letterSpacing.toStringAsFixed(0),
                        onChanged: (v) => setS(() => letterSpacing = v),
                      ),
                    ),
                    Text(letterSpacing.toStringAsFixed(0), style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('揃え', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    SegmentedButton<TextAlign>(
                      segments: const [
                        ButtonSegment(value: TextAlign.left, icon: Icon(Icons.format_align_left, size: 16)),
                        ButtonSegment(value: TextAlign.center, icon: Icon(Icons.format_align_center, size: 16)),
                        ButtonSegment(value: TextAlign.right, icon: Icon(Icons.format_align_right, size: 16)),
                      ],
                      selected: {textAlign},
                      onSelectionChanged: (v) => setS(() => textAlign = v.first),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilterChip(
                  label: const Text('アウトライン'),
                  selected: outlineEnabled,
                  onSelected: (v) => setS(() => outlineEnabled = v),
                ),
                if (outlineEnabled) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: _textColorPalette.map((c) => GestureDetector(
                      onTap: () => setS(() => outlineColor = c),
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: outlineColor == c ? Theme.of(ctx).colorScheme.primary : Colors.grey,
                            width: outlineColor == c ? 2 : 1,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  Row(
                    children: [
                      const Text('太さ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: outlineWidth, min: 0, max: 20,
                          label: outlineWidth.round().toString(),
                          onChanged: (v) => setS(() => outlineWidth = v),
                        ),
                      ),
                      Text('${outlineWidth.round()}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                if (controller.text.isEmpty) { Navigator.pop(ctx); return; }
                final ps = context.read<ProjectService>();
                final sceneId = _currentSceneId;
                model.Layer layer;
                model.TextObject textObject;
                if (existingLayerId != null && existing != null) {
                  final current = ps
                      .layersOf(widget.projectId, sceneId, _currentFrame)
                      .where((l) => l.id == existingLayerId)
                      .firstOrNull;
                  if (current == null) { Navigator.pop(ctx); return; }
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
                        enabled: outlineEnabled, color: Color(outlineColor), width: outlineWidth),
                  );
                } else {
                  layer = ps.addTextLayer(
                    projectId: widget.projectId,
                    sceneId: sceneId,
                    frameIndex: _currentFrame,
                    text: controller.text,
                    position: position,
                  );
                  textObject = (layer.textObject ?? model.TextObject(id: layer.id, text: controller.text, position: position))
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
                        enabled: outlineEnabled, color: Color(outlineColor), width: outlineWidth),
                  );
                }
                final tileManager = ps.tileManagerOf(widget.projectId);
                final bytes = await rasterizeTextObject(
                    textObject, tileManager.canvasWidth, tileManager.canvasHeight);
                if (bytes != null) {
                  tileManager.replaceLayerPixels(
                    ps.tileKeyFor(widget.projectId, sceneId, _currentFrame, layer.id),
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
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }
}

enum DrawingTool {
  pen, eraser, bucket, lasso, eyedropper, finger,
  selectRect, selectLasso, selectMagicWand,
  move, transform,
  ruler, text, shape,
  // 手のひらツール（仕様書08）：ジェスチャー／ペンボタンからのみ到達する一時ツール。
  // ツールバーには表示せず、描画を行わずキャンバスの平行移動のみを行う。
  pan,
}

/// 図形ツールの種別（仕様書03：タップでポップアップ表示・OFF/線/四角形/円）
enum ShapeKind { off, line, rect, circle }
