import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/advertising_service.dart';
import '../../services/autosave_service.dart';
import '../../services/project_service.dart';
import '../../services/brush_service.dart';
import '../../services/performance_service.dart';
import '../../widgets/ad_banner_widget.dart';
import '../../engine/undo_manager.dart';
import '../../models/onion_skin_settings.dart';
import '../../models/project.dart';
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
import '../../models/ruler.dart';

class CanvasScreen extends StatefulWidget {
  final String projectId;
  const CanvasScreen({super.key, required this.projectId});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  DrawingTool _currentTool = DrawingTool.pen;
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
  }

  @override
  void dispose() {
    _perf?.removeListener(_onPerfChanged);
    if (_autosaveAttached) context.read<AutosaveService>().detach();
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (adService.shouldShowAds) const AdBannerWidget(),
            _buildTopBar(),
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
                  ),
                  if (_showLayerPanel)
                    Positioned(
                      right: 0, top: 0, bottom: 0, width: 250,
                      child: LayerPanel(
                        onClose: () => setState(() => _showLayerPanel = false),
                        projectId: widget.projectId,
                        sceneId: _currentSceneId,
                        frameIndex: _currentFrame,
                      ),
                    ),
                  if (_showColorPicker)
                    Positioned(
                      left: 16, bottom: 16,
                      child: ColorPickerPanel(
                        currentColor: _currentColor,
                        onColorChanged: (color) {
                          setState(() => _currentColor = color);
                          context.read<BrushService>().setCurrentColor(color);
                        },
                        onClose: () => setState(() => _showColorPicker = false),
                      ),
                    ),
                  if (_showBrushPanel)
                    Positioned(
                      left: 16, top: 16,
                      child: BrushPanel(onClose: () => setState(() => _showBrushPanel = false)),
                    ),
                  // ペンサブツールパネル（ブラシ/トーン/スタンプ/投げ縄塗り）
                  if (_showPenSubToolPanel)
                    Positioned(
                      left: 16, top: 16,
                      child: PenSubToolPanel(
                        currentTool: _currentTool,
                        currentSubTool: _currentSubTool,
                        onSubToolSelected: (subTool) {
                          setState(() {
                            _currentSubTool = subTool;
                            if (subTool == PenSubTool.lassoFill) {
                              _currentTool = DrawingTool.lasso;
                            } else {
                              _currentTool = DrawingTool.pen;
                            }
                          });
                        },
                        onClose: () => setState(() => _showPenSubToolPanel = false),
                      ),
                    ),
                  // オニオンスキンパネル
                  if (_showOnionSkinPanel)
                    Positioned(
                      right: 16, top: 16,
                      child: OnionSkinPanel(
                        settings: _onionSkinSettings,
                        onChanged: (s) => setState(() => _onionSkinSettings = s),
                        onClose: () => setState(() => _showOnionSkinPanel = false),
                      ),
                    ),
                  // 定規パネル
                  if (_showRulerPanel)
                    Positioned(
                      left: 16, top: 16,
                      child: RulerPanel(
                        activeRuler: _activeRuler,
                        onRulerChanged: (r) => setState(() => _activeRuler = r),
                        onClose: () => setState(() => _showRulerPanel = false),
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
            ),
            FrameStripWidget(
              currentFrame: _currentFrame,
              projectId: widget.projectId,
              sceneId: _currentSceneId,
              onFrameSelected: (idx) => setState(() => _currentFrame = idx),
              onTimelineTap: () => context.go('/timeline/${widget.projectId}'),
            ),
          ],
        ),
      ),
    );
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('キャンバスをタップしてテキストを入力',
                  style: TextStyle(fontSize: 12, color: Colors.blue)),
            ),
          const Spacer(),
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

  void _showTextInputDialog(Offset position) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('テキスト入力'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'テキストを入力してください',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<ProjectService>().addTextLayer(
                  projectId: widget.projectId,
                  sceneId: _currentSceneId,
                  frameIndex: _currentFrame,
                  text: controller.text,
                  position: position,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}

enum DrawingTool {
  pen, eraser, bucket, lasso, eyedropper, finger,
  selectRect, selectLasso, selectMagicWand,
  move, transform,
  ruler, text, shape,
}

/// 図形ツールの種別（仕様書03：タップでポップアップ表示・OFF/線/四角形/円）
enum ShapeKind { off, line, rect, circle }
