import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:niarim/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/save_tree_service.dart';
import '../../services/autosave_service.dart';
import '../../services/project_service.dart';
import '../../services/layer_clipboard_service.dart';
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
import '../../widgets/project_not_found_view.dart';
import '../../widgets/background_color_picker.dart';
import '../../widgets/dispose_on_unmount.dart';
import '../../widgets/editable_slider_value.dart';
import '../../widgets/labeled_slider.dart';
import '../../widgets/stepped_slider.dart';
import '../../utils/immersive_mode.dart';
import '../../utils/custom_automation_labels.dart';
import '../../utils/filter_display_name.dart';
import '../../engine/autofill_engine.dart' show AutofillCheckMode;
import '../../engine/text_render.dart';
import '../../engine/undo_manager.dart';
import '../../engine/custom_automation_executor.dart';
import '../../engine/filter_lens_mask.dart';
import '../../l10n/app_localizations.dart';
import '../../models/bundled_fonts.dart';
import '../../models/filter_canvas_gizmo.dart';
import '../../models/filter_def.dart';
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
import '../../widgets/typing_aware_shortcuts.dart';
import '../../widgets/pc_workspace.dart';
import '../../widgets/app_tutorial.dart';
import '../settings/pc_workspace_layout_settings_screen.dart';

class CanvasScreen extends StatefulWidget {
  final String projectId;
  const CanvasScreen({super.key, required this.projectId});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  // 画面全体のショートカット（取り消し・ツール切替等）を受けるフォーカス。
  // パネルの入力欄（レイヤー検索・色のコード等）に入力したままキャンバスへ
  // 描き始めたら、入力を終えてここへ戻す（戻さないとCtrl+Zが入力欄の
  // 文字の取り消しになる、またはどこにも届かない）。
  final FocusNode _screenFocus = FocusNode(debugLabel: 'Canvas');
  DrawingTool _currentTool = DrawingTool.pen;
  // ジェスチャー／ペンボタンでの消しゴム切替・ブラシ切替・手のひらツール
  // トグル用に、切替前のツールを一時的に覚えておく。
  DrawingTool? _toolBeforeGestureToggle;
  PenSubTool _currentSubTool = PenSubTool.brush;
  double _brushSize = 5;
  int _brushOpacity = 100;
  Color _currentColor = Colors.black;
  int _currentFrame = 0;
  AutofillCheckMode _autofillCheckMode = AutofillCheckMode.normal;
  bool _showLayerPanel = false;
  // ショートカット（Ctrl+A）からレイヤーパネルの全選択を起動するための
  // トークン。値を増やすたびにLayerPanel側で全選択が実行される。
  int _layerSelectAllToken = 0;
  // 資料ウィンドウ（三面図・参考画像を常に表示）。他のツールオプション系
  // パネルとは独立して開閉する（ツール切り替えやパネル外タップでは
  // 閉じない）ため、_closeAllOverlayPanels/_anyToolPanelOpenの対象には
  // あえて含めていない。
  bool _showReferenceWindow = false;
  // キャンバスプレビュー（ナビゲーター）：拡大表示中でも全体を縮小表示で
  // 確認できるPC/DeXモード専用のドッキングパネル。スマホ版では扱わない。
  bool _showCanvasPreviewPanel = false;
  bool _showColorPicker = false;
  bool _showBrushPanel = false;
  // トーン・スタンプの全機能管理パネル（フォルダ・自作・検索・
  // 読み込み書き出し）。ペンサブツールタブの「管理」ボタンから開く。
  bool _showTonePanel = false;
  bool _showStampPanel = false;
  bool _showPenSubToolPanel = false;
  bool _showOnionSkinPanel = false;
  bool _showRulerPanel = false;
  bool _showFilterPanel = false;
  bool _showQuickToolPanel = false;
  bool _showColorAdjustPanel = false;
  FilterColorEyedropperTarget? _filterColorEyedropperTarget;
  // The filter being adjusted, as the current layer would look with it
  // (shown on the canvas in the layer's place).
  ui.Image? _filterCanvasPreview;
  // The canvas selection (drawing filters apply only inside it) and the
  // glasses filter's lens area, painted on the canvas while it is adjusted.
  Uint8List? _canvasSelectionMask;
  final FilterLensMask _filterLensMask = FilterLensMask();
  _TextColorEyedropperTarget? _textColorEyedropperTarget;
  ValueChanged<Color>? _pendingTextColorEyedropper;
  Completer<int?>? _pendingBrushOutlineEyedropper;
  bool get _brushOutlineEyedropperActive =>
      _pendingBrushOutlineEyedropper != null;

  // ─── レイヤー全体の自由変形・メッシュ変形（新機能） ────────────────────
  // 実際の格子点ドラッグ・ワーププレビューはCanvasArea側で完結させ、
  // ここでは分割数・回転・拡大縮小の現在値と、確定／キャンセルの
  // トークン（増加するたびにCanvasArea側の対応する処理を1回起動する）
  // だけを持つ（RulerPanel等と同様、パネルの主導権はこの画面側）。
  bool _showMeshTransformPanel = false;
  int _meshDensity = 1;
  double _meshRotateDeg = 0.0;
  double _meshScaleValue = 1.0;
  int _meshCommitToken = 0;
  int _meshCancelToken = 0;

  // ─── 選択範囲の反転（範囲選択中にのみ使える機能） ────────────────
  // CanvasArea側が選択範囲の有無をonSelectionActiveChangedで通知し、
  // それに応じて上部バーの「選択範囲を反転」ボタンの表示を切り替える。
  // 反転自体はinvertSelectionTokenを増やすことでCanvasArea側へ指示する
  // （meshCommitToken等と同じトークン方式）。
  bool _hasActiveSelection = false;
  // 画面下部のスライダーで指定する変形量。いずれも「いまの状態が0」で、
  // 右へ動かすとプラス・左へ動かすとマイナス。指を離した時点で実画素へ
  // 確定し、ここを0（拡大縮小だけは1.0＝等倍）へ戻す。
  double _selectionMoveX = 0;
  double _selectionMoveY = 0;
  double _selectionScale = 1;
  double _selectionRotateDeg = 0;
  int _selectionTransformCommitToken = 0;
  // 「変更キャンセル」で戻す量。選択範囲を作った時点からこの選択範囲へ
  // 加えた変形の回数を数えておき、その回数ぶんUndoする。
  int _selectionTransformSteps = 0;
  int _invertSelectionToken = 0;
  int _selectAllSelectionToken = 0;
  int _clearSelectionToken = 0;

  bool get _isSelectionToolActive =>
      _currentTool == DrawingTool.selectRect ||
      _currentTool == DrawingTool.selectLasso ||
      _currentTool == DrawingTool.selectMagicWand;

  // 右側ドッキング領域（カラーピッカー・レイヤーパネル・キャンバス
  // プレビュー）の横幅。ドラッグ中はここへローカルに反映し、指を離した
  // 時点でSettingsServiceへ確定値を保存する。
  double? _panelWidthDragOverride;
  // 左側ツールオプション系ドッキング領域の横幅（ドラッグ中のローカル反映用）。
  double? _toolPanelWidthDragOverride;
  OverlayEntry? _customAutomationRecordingOverlay;

  // ─── PC/DeXモードの作業画面 ───────────────────────────────
  // ドックのタブを前に出す要求（PcPane.focusTab/focusSerial）。
  String? _pcFocusTab;
  int _pcFocusSerial = 0;
  // ドックの各ペインで前に出ているタブ（PcDockColumnが知らせる。描き直しは
  // 要らないのでsetStateしない）。
  final Map<String, String> _pcActiveTabs = {};
  // ツールプロパティのペインを出すか、ドックをすべて隠すか。
  bool _showPcToolProperty = true;
  bool _pcPanelsHidden = false;
  // キャンバスの表示の操作（拡大・縮小・回転）と、今の倍率・回転。
  CanvasViewRequest? _viewRequest;
  final ValueNotifier<CanvasViewInfo> _viewInfo = ValueNotifier(
    const CanvasViewInfo(zoom: 1, rotationDeg: 0),
  );
  // スマホ⇔PCの作業画面の切り替え・ドックの開閉でキャンバスの親が
  // 変わっても、描画の状態（表示の倍率・描きかけ）を引き継ぐ。
  final GlobalKey _canvasAreaKey = GlobalKey();

  /// モバイルレイアウトのオーバーレイパネル（レイヤー・色・ブラシ・トーン・
  /// スタンプ・ペンサブツール・オニオンスキン・定規・フィルター・早替え
  /// ツール設定・自由変形/メッシュ変形）は、右側/左側に重なって同時表示
  /// されると片方が下敷きになり閉じるボタンを押せなくなる不具合があった
  /// （「レイヤーパネルが一度表示すると非表示に戻せない」の原因）。
  /// いずれかを開く前に必ずこれを呼び、常に高々1枚のみが表示された状態を保つ。
  ///
  /// PC/DeXモード（広い画面）は複数パネルを同時ドッキング表示できるため
  /// 対象外にする（レイヤー・カラーピッカー・ブラシ・トーン・スタンプ等の
  /// サブツール系すべて。ドッキング表示のため重なって閉じられなくなる
  /// 心配がない）。自由変形/メッシュ変形パネルのみキャンバス上の格子点
  /// 操作と直接絡むため、画面サイズによらず引き続き排他のままにする。
  void _closeAllOverlayPanels() {
    // イベントハンドラ（onPressed経由）から呼ばれるため、build外での
    // watch()回避のためlisten:falseを渡す。
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
    // 他のパネルを開く操作で自由変形/メッシュ変形パネルが押し出される場合は、
    // 未確定のワーププレビューを残さないようキャンセル扱いにする。
    if (_showMeshTransformPanel) {
      _showMeshTransformPanel = false;
      _meshCancelToken++;
      if (_currentTool == DrawingTool.meshTransform) {
        _currentTool = DrawingTool.pen;
      }
    }
  }

  /// 自由変形・メッシュ変形パネルを開く（キャンバス上部バーの「設定/編集」
  /// メニューから、既存の変形ツールと異なり範囲選択なしで
  /// レイヤー全体を対象にする）。開くたびに分割数・回転・拡大縮小の
  /// スライダー値を初期状態へ戻す。
  /// [density]は格子の分割数。1（既定・4隅のみ）が「自由変形」、
  /// 2以上が「メッシュ変形」にあたる（同じ仕組みの分割数違い）。
  void _openMeshTransformPanel({int density = 1}) => setState(() {
    _closeAllOverlayPanels();
    _showMeshTransformPanel = true;
    _meshDensity = density;
    _meshRotateDeg = 0.0;
    _meshScaleValue = 1.0;
    _currentTool = DrawingTool.meshTransform;
  });

  /// 自由変形・メッシュ変形の確定（コントロールパネルの「適用」ボタン）。
  void _applyMeshTransform() => setState(() {
    _meshCommitToken++;
    _showMeshTransformPanel = false;
    _currentTool = DrawingTool.pen;
  });

  /// 自由変形・メッシュ変形のキャンセル（コントロールパネルの「キャンセル」
  /// ボタン・閉じるボタン）。ワーププレビューは破棄され、レイヤーへは
  /// 何も反映されない。
  void _cancelMeshTransform() => setState(() {
    _meshCancelToken++;
    _showMeshTransformPanel = false;
    _currentTool = DrawingTool.pen;
  });

  /// ブラシサイズ／不透明度が描画結果に影響するツールかどうか。
  /// ペン・消しゴム・投げ縄塗り・指（ワープ）・定規（定規ガイド沿いの
  /// 描画にペンと同じブラシ設定を使う）が対象。
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

  /// 定規ボタン（下部ツールバーからキャンバス上部
  /// バーの常設ボタンへ昇格）。定規パネルの開閉と定規ツールへの切替を
  /// 同時に行う（従来の下部ツールバー版と同じ挙動）。
  void _toggleRuler() => setState(() {
    final next = !_showRulerPanel;
    _closeAllOverlayPanels();
    _showRulerPanel = next;
    if (_currentTool != DrawingTool.ruler) {
      _currentTool = DrawingTool.ruler;
    }
  });

  /// オニオンスキンパネルの開閉（キャンバス上部
  /// バーの「設定/編集」メニューへ集約）。
  void _toggleOnionSkinPanel() => setState(() {
    final next = !_showOnionSkinPanel;
    _closeAllOverlayPanels();
    _showOnionSkinPanel = next;
  });

  /// フィルターパネルの開閉（キャンバス上部バーの
  /// 「設定/編集」メニューへ集約）。
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

  Future<int?> _startBrushOutlineEyedropper() {
    final previous = _pendingBrushOutlineEyedropper;
    if (previous != null && !previous.isCompleted) previous.complete(null);
    final completer = Completer<int?>();
    setState(() {
      _pendingBrushOutlineEyedropper = completer;
      // PC/DeXモードのドックはキャンバスを隠さないので開いたままにする。
      if (!isWideScreen(context, listen: false)) _showBrushPanel = false;
    });
    return completer.future;
  }

  void _handleCanvasEyedropper(Color color) {
    final pendingBrushOutline = _pendingBrushOutlineEyedropper;
    if (pendingBrushOutline != null) {
      setState(() => _pendingBrushOutlineEyedropper = null);
      if (!pendingBrushOutline.isCompleted) {
        pendingBrushOutline.complete(color.toARGB32());
      }
      return;
    }
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

  /// 背景切替（白/プロジェクト背景色 ⟷ 透過、
  /// キャンバス上部バーの「設定/編集」メニューへ集約）。
  void _toggleBackground() => setState(() {
    _canvasBackground = _canvasBackground == CanvasBackground.white
        ? CanvasBackground.transparent
        : CanvasBackground.white;
  });

  /// フレーム複数選択モードの切替（キャンバス上部
  /// バーの「設定/編集」メニューへ集約。大量処理実行時のフィルター
  /// 一括適用などに使用）。
  void _toggleFrameMultiSelect() => setState(() {
    _frameMultiSelectMode = !_frameMultiSelectMode;
    _selectedFrameIndices = {};
  });

  /// 画面端ダブルタップでのフレーム送り（フレーム一覧の開閉
  /// 状態と無関係に常時使える操作）。範囲外へは移動しない。
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
        frameCount: context.read<ProjectService>().frameCount(
          widget.projectId,
          _currentSceneId,
        ),
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

  bool _customAutomationRunning = false;

  Future<void> _executeCustomAutomation(
    CustomAutomation automation,
    CustomAutomationExecutionScope scope,
    List<int>? targetFrames,
  ) async {
    if (_customAutomationRunning) return;
    _customAutomationRunning = true;
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    final progress = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const ValueKey('custom-automation-progress'),
          title: Text(customAutomationDisplayName(l10n, automation.name)),
          content: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [CircularProgressIndicator()],
          ),
        ),
      ),
    );
    navigator.push(progress);
    try {
      await _executeSemanticAutomation(automation, scope, targetFrames);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.customAutomationExecutionFailed)),
        );
      }
    } finally {
      if (progress.isActive) navigator.removeRoute(progress);
      _customAutomationRunning = false;
    }
  }

  Future<void> _executeSemanticAutomation(
    CustomAutomation automation,
    CustomAutomationExecutionScope scope,
    List<int>? targetFrames,
  ) async {
    final activeLayerId = await CustomAutomationExecutor.executeCanvas(
      automation: automation,
      scope: scope,
      targetFrames: targetFrames,
      projectService: context.read<ProjectService>(),
      projectId: widget.projectId,
      sceneId: _currentSceneId,
      currentFrame: _currentFrame,
      currentLayerId: _currentLayerId,
      handleCanvasStateCommand: _executeSemanticCanvasStateCommand,
      layerName: _generatedLayerName,
    );
    if (activeLayerId != null && mounted) {
      setState(() => _currentLayerId = activeLayerId);
    }
  }

  /// The name of a layer a filter run by an automation adds, in the app's
  /// language (as the filter panel names it).
  String _generatedLayerName(String sourceName, FilterDef filter) =>
      generatedLayerName(AppLocalizations.of(context)!, sourceName, filter);

  Future<void> _executeSemanticCanvasStateCommand(
    String command,
    Map<String, Object?> args,
  ) {
    return _executeCanvasAutomationStep(
      CustomAutomationStep(
        id: 'semantic-runtime-$command',
        surface: CustomAutomationSurface.canvas,
        command: command,
        label: command,
        args: args,
        recordedFrame: _currentFrame,
      ),
      _currentFrame,
    );
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
      case 'canvas.filterApply':
        final rawSnapshot = step.args['filter'];
        if (rawSnapshot is! Map) throw StateError('Missing filter snapshot');
        final layerId = _currentLayerId;
        if (layerId == null) throw StateError('No active layer');
        final generatedLayerId = await RecordedFilterApplyService.apply(
          projectService: context.read<ProjectService>(),
          projectId: widget.projectId,
          sceneId: _currentSceneId,
          layerId: layerId,
          frameIndex: targetFrame,
          filterSnapshot: Map<String, Object?>.from(rawSnapshot),
          layerName: _generatedLayerName,
        );
        if (generatedLayerId != null && mounted) {
          setState(() => _currentLayerId = generatedLayerId);
        }
      case 'canvas.brightnessToAlpha':
        final layerId = _currentLayerId;
        if (layerId == null) throw StateError('No active layer');
        final projectService = context.read<ProjectService>();
        final layer = projectService
            .layersOf(widget.projectId, _currentSceneId, targetFrame)
            .where((value) => value.id == layerId)
            .firstOrNull;
        if (layer == null) throw StateError('No active layer');
        await projectService
            .tileManagerOf(widget.projectId)
            .applyBrightnessToAlpha(
              projectService.tileKeyFor(
                widget.projectId,
                _currentSceneId,
                targetFrame,
                layerId,
              ),
              grayMode: step.args['grayMode'] == true,
            );
        projectService.updateLayer(
          projectId: widget.projectId,
          sceneId: _currentSceneId,
          frameIndex: targetFrame,
          layer: layer,
        );
        if (mounted) setState(() {});
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

  /// キャンバス上部バーの「設定/編集」メニュー（
  /// 背景色・オニオンスキン・フィルター・フレーム範囲選択を集約）。
  void _showEditMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      // 項目数が多く、画面の低い端末では収まりきらないことがあるため
      // スクロール可能にする（以前はColumnを直置きしており、画面下端で
      // オーバーフローすることがあった）。
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 選んだ表示がその場で見えるよう、この行だけ作り直す（メニューは
              // キャンバスの画面とは別のルートなので、画面のsetStateでは
              // 作り直されず、選ぶ前の表示のままだった）。
              StatefulBuilder(
                builder: (ctx, setMenuState) {
                  final labels = {
                    AutofillCheckMode.normal: l10n.canvasAutofillCheckNormal,
                    AutofillCheckMode.partSeparation:
                        l10n.canvasAutofillCheckParts,
                    AutofillCheckMode.silhouette:
                        l10n.canvasAutofillCheckSilhouette,
                  };
                  Widget dropdown({required bool expanded}) =>
                      DropdownButton<AutofillCheckMode>(
                        value: _autofillCheckMode,
                        isExpanded: expanded,
                        underline: const SizedBox.shrink(),
                        items: [
                          for (final entry in labels.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: (mode) {
                          if (mode == null) return;
                          setState(() => _autofillCheckMode = mode);
                          setMenuState(() {});
                        },
                      );
                  return LayoutBuilder(
                    builder: (ctx, constraints) {
                      // 選択肢は、項目名の右に入るときだけ右に置き、入らない
                      // ときは項目名の下の行に置く（長い言語・大きな文字で
                      // 右に置くと、行の幅をすべて使って行が描けなかった）。
                      final style = Theme.of(ctx).textTheme.titleMedium;
                      final scaler = MediaQuery.textScalerOf(ctx);
                      var widest = 0.0;
                      for (final label in labels.values) {
                        final painter = TextPainter(
                          text: TextSpan(text: label, style: style),
                          textDirection: Directionality.of(ctx),
                          textScaler: scaler,
                        )..layout();
                        if (painter.width > widest) widest = painter.width;
                        painter.dispose();
                      }
                      // 選択肢の幅（▼を含む）＋先頭のアイコン・余白・項目名に
                      // 残したい最小の幅。
                      final fitsBeside =
                          widest + 32 + 56 + 32 + scaler.scale(96) <=
                          constraints.maxWidth;
                      return ListTile(
                        leading: Icon(
                          _autofillCheckMode == AutofillCheckMode.normal
                              ? Icons.visibility_outlined
                              : _autofillCheckMode ==
                                    AutofillCheckMode.partSeparation
                              ? Icons.palette_outlined
                              : Icons.contrast,
                        ),
                        title: Text(l10n.canvasAutofillCheckView),
                        subtitle: fitsBeside ? null : dropdown(expanded: true),
                        trailing: fitsBeside ? dropdown(expanded: false) : null,
                      );
                    },
                  );
                },
              ),
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
              // 背景色変更（プロジェクト作成時と同じ選択肢）
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
                subtitle: Text(l10n.canvasBackgroundColorChoices),
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
              // 筆圧カーブ設定画面（/settings/pen）を、設定画面だけでなくここ
              // からも開けるようにする（設定値自体はアプリ内共通の1箇所の
              // ため、どちらから開いても同じ値を編集することになる）。
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
              // レイヤー全体の自由変形・メッシュ変形。
              // 範囲選択の変形と異なり、選択範囲なしで現在レイヤー全体を
              // 自由に動かせる。
              ListTile(
                leading: const Icon(Icons.crop_free),
                title: Text(l10n.canvasEditMenuMeshTransform),
                subtitle: Text(l10n.canvasEditMenuMeshTransformSubtitle),
                onTap: () {
                  Navigator.pop(ctx);
                  _openMeshTransformPanel();
                },
              ),
              // 色調調整。彩度・明度・コントラストを
              // ライブプレビューで調整し、そのまま適用するか、描画/演出
              // フィルターへ新規フィルターとして追加できる。
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
              // 資料ウィンドウ（アニメ制作では三面図・キャラクター設定表などの
              // 資料を見ながら作業することが多いため、任意の参考画像を常に
              // フローティング表示できるようにした）。
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
              // キャンバスプレビュー（ナビゲーター）：PC/DeXモード専用。
              // ドッキング表示のためスマホ版では意味を持たない。
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

  // フレーム複数選択モード（大量処理実行時のフィルター一括適用）
  bool _frameMultiSelectMode = false;
  Set<int> _selectedFrameIndices = {};
  // nullなら現在フレームのみへ適用、非nullなら選択中の全フレームへ一括適用
  Set<int>? _filterBulkFrames;
  Ruler? _activeRuler;

  // キャンバス背景（白 / 透過）
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
  // dispose()内でcontext.read<T>()を呼ぶと、画面が他のウィジェットツリーの
  // 一括破棄に巻き込まれた際（例：GoRouterのgo()によるスタック置き換えで
  // 前の画面がまとめて破棄されるケース）に「破棄済みウィジェットの祖先を
  // 参照できない」例外になることがある。didChangeDependencies内（要素が
  // まだ確実にアクティブ）で取得して保持しておき、dispose()ではこちらを
  // 使う。
  AutosaveService? _autosaveService;
  ProjectService? _projectServiceForDispose;
  // フレーム一覧の折りたたみ状態（描画領域を広げるため
  // 任意のタイミングで開閉できるようにする）。
  bool _showFrameStrip = true;
  // ツールバーの折りたたみ状態（同上。スマホの小さな画面でも描画領域を
  // 最大限確保できるようにする）。
  bool _showToolbar = true;
  bool _workTrackingStarted = false;
  bool _missingMaterialChecked = false;
  // PC/DeXモードでブラシ・カラーピッカーのドッキングパネルを自動で開いた
  // かどうか（1セッション1回のみ。ユーザーが手動で閉じた後に毎回また
  // 開き直されると邪魔になるため）。
  bool _autoOpenedDesktopPanels = false;
  // 直前の表示がPC/DeXモードだったか（向きが変わって切り替わったかを見る）。
  bool? _lastLayoutWasWide;
  // スマホ表示へ移るときに閉じたドックのパネル（PC/DeXモードへ戻ったら開く）。
  Set<CanvasDockPanel>? _panelsBeforePhoneLayout;

  Set<CanvasDockPanel> _openDockPanels() => {
    if (_showBrushPanel) CanvasDockPanel.brush,
    if (_showColorPicker) CanvasDockPanel.colorPicker,
    if (_showLayerPanel) CanvasDockPanel.layer,
    if (_showTonePanel) CanvasDockPanel.tone,
    if (_showStampPanel) CanvasDockPanel.stamp,
    if (_showPenSubToolPanel) CanvasDockPanel.penSubTool,
    if (_showOnionSkinPanel) CanvasDockPanel.onionSkin,
    if (_showRulerPanel) CanvasDockPanel.ruler,
    if (_showFilterPanel) CanvasDockPanel.filter,
    if (_showQuickToolPanel) CanvasDockPanel.quickTool,
    if (_showColorAdjustPanel) CanvasDockPanel.colorAdjust,
    if (_showCanvasPreviewPanel) CanvasDockPanel.canvasPreview,
  };

  void _setDockPanels(Set<CanvasDockPanel> panels) {
    _showBrushPanel = panels.contains(CanvasDockPanel.brush);
    _showColorPicker = panels.contains(CanvasDockPanel.colorPicker);
    _showLayerPanel = panels.contains(CanvasDockPanel.layer);
    _showTonePanel = panels.contains(CanvasDockPanel.tone);
    _showStampPanel = panels.contains(CanvasDockPanel.stamp);
    _showPenSubToolPanel = panels.contains(CanvasDockPanel.penSubTool);
    _showOnionSkinPanel = panels.contains(CanvasDockPanel.onionSkin);
    _showRulerPanel = panels.contains(CanvasDockPanel.ruler);
    _showFilterPanel = panels.contains(CanvasDockPanel.filter);
    _showQuickToolPanel = panels.contains(CanvasDockPanel.quickTool);
    _showColorAdjustPanel = panels.contains(CanvasDockPanel.colorAdjust);
    _showCanvasPreviewPanel = panels.contains(CanvasDockPanel.canvasPreview);
  }

  @override
  void initState() {
    super.initState();
    // 描画に作業領域を広く使えるよう、既定でAndroid標準の
    // ナビゲーションバーを最小化する。
    ImmersiveMode.enterWorkspace();
  }

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
    // PC/DeXモード（広い画面）では、初回表示時にワークスペース設定
    // （設定＞ワークスペース＞PC版で既定で開くパネル）で選ばれている
    // パネルをまとめて自動でドッキング表示する。1セッション1回のみで、
    // 閉じた後にまた自動で開き直されると邪魔になるため、手動で閉じた後は
    // 再度自動では開かない。いずれも独立して閉じられる
    // （_closeAllOverlayPanelsもPC/DeXモードではこれらを対象外にしている）。
    final wide = isWideScreen(context);
    if (!_autoOpenedDesktopPanels && wide) {
      _autoOpenedDesktopPanels = true;
      _setDockPanels(context.read<SettingsService>().defaultDockedPanels);
    }
    // 自動判定で画面の向きが変わり、PC/DeXモードとスマホ表示が入れ替わった
    // とき：スマホ表示へ移るときはドックのパネルを閉じ（スマホは全パネルを
    // 閉じた状態が基本。開いたままだと浮かぶパネルが重なってキャンバスを
    // 覆った）、PC/DeXモードへ戻ったら同じパネルをまた開く。
    final wasWide = _lastLayoutWasWide;
    _lastLayoutWasWide = wide;
    if (wasWide == true && !wide) {
      _panelsBeforePhoneLayout = _openDockPanels();
      _setDockPanels(const {});
    } else if (wasWide == false && wide && _panelsBeforePhoneLayout != null) {
      _setDockPanels(_panelsBeforePhoneLayout!);
      _panelsBeforePhoneLayout = null;
    }
    _projectServiceForDispose = context.read<ProjectService>();
    // PerformanceServiceをlistenerで監視（依存差し替えに対応）
    final newPerf = context.read<PerformanceService>();
    if (newPerf != _perf) {
      _perf?.removeListener(_onPerfChanged);
      _perf = newPerf;
      _perf!.addListener(_onPerfChanged);
      _syncOnionFromPerf();
    }
    // 自動保存（クラッシュ復元専用）をこのプロジェクトへ接続する
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
    // 制作時間カウント（描画モードのみカウント）
    if (!_workTrackingStarted) {
      _workTrackingStarted = true;
      context.read<ProjectService>().beginWorkTracking(widget.projectId);
    }
    // 不足素材の検出（プロジェクトを開いた際に参照先の素材が
    // 見つからない場合は「不足素材があります」と表示。「再検索」で再確認）
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
    _screenFocus.dispose();
    _viewInfo.dispose();
    _filterCanvasPreview?.dispose();
    _filterLensMask.dispose();
    _customAutomationRecordingOverlay?.remove();
    _customAutomationRecordingOverlay = null;
    ImmersiveMode.exitWorkspace();
    _perf?.removeListener(_onPerfChanged);
    if (_autosaveAttached) _autosaveService?.detach();
    final projectService = _projectServiceForDispose;
    if (_workTrackingStarted) projectService?.endWorkTracking();
    // プロジェクトカードのサムネイルを編集終了時に更新する。
    // 非同期処理だがdispose()自体は同期のままfire-and-forgetで発火する
    // （ProjectService内部状態のみを参照するため、Widget破棄後も安全）。
    projectService?.generateAndSaveThumbnail(widget.projectId);
    super.dispose();
  }

  /// クラッシュ・ファイル破損時の復元用：プロジェクトの最終保存より新しい
  /// 自動保存があれば、確認ダイアログを出さずそのまま自動的に復元して
  /// 再開する（プロジェクトを開いた際、
  /// 自動保存データがあれば最後の自動保存から自動的に復元する）。
  /// 自動保存は常に「その時点までの最新の編集内容」を表すため、これへ
  /// 揃えることで作業を失うことはない（確認ダイアログを出して「無視」を
  /// 選ばれると、その分の編集内容が失われてしまう）。
  ///
  /// CanvasScreenはタイムラインモードとの往復（context.go）のたびにWidget
  /// ごと再生成されるため、Widget側の状態フラグだけでは「編集を再開した
  /// だけ」「タイムラインからキャンバスへ戻っただけ」でも毎回この処理が
  /// 走ってしまっていた（アプリセッション中に一度も明示保存していない限り
  /// 自動保存の方が新しいままになるため）。AutosaveService側にアプリ
  /// セッション単位で「確認済みか」を記録することで、1セッション中に
  /// 一度だけ行うようにしている。
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

  /// 不足素材の検出。プロジェクトを開いた際に参照先の素材ファイルが
  /// 見つからない場合、「不足素材があります」と「再検索」ボタンを表示する。
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
        // 操作ボタン付きのSnackBarは既定では時間で消えず、ホーム等の次の
        // 画面まで付いてきて、後から出す通知もその後ろで待ち続ける。
        persist: false,
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
    final project = context
        .watch<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    // 存在しないID・ゴミ箱へ移した作品：空のキャンバスを出さず、一覧へ戻す。
    if (project == null) {
      return const ProjectNotFoundView(
        homeButtonKey: Key('canvasNotFoundHome'),
      );
    }
    // PC/DeXモード（広い画面）では、スマホの浮かぶパネルを横に並べ直すのでは
    // なく、メニューバー・コマンドバー・ツールパレット・左右のドック・
    // フレーム一覧・ステータスバーで画面を区切った、PC専用の作業画面にする
    // （_buildPcWorkspace）。
    final isDesktop = isWideScreen(context);
    final filterAdjusting = _showFilterPanel && !isDesktop;
    final selectionEditingHidden = _selectionEditingGivesWay(isDesktop);
    // 左利きモード：パネル・ドックを左右反転し、描画する手の側に
    // パネルが重ならないようにする。
    final leftHanded = context.watch<SettingsService>().isLeftHanded;

    // DeXモード・マウス/キーボード入力・左手デバイス：設定画面
    // 「ショートカット設定」で割り当てたキーで、ツール切替やUndo/Redo
    // などの主要操作を行えるようにする。
    return TypingAwareShortcuts(
      bindings: _buildShortcutBindings(context),
      screenFocus: _screenFocus,
      child: Focus(
        focusNode: _screenFocus,
        autofocus: true,
        child: Scaffold(
          // キャンバスモードのバー類（上部バー・太さ/不透明度スライダー・
          // ツールバー・折りたたみハンドル）は、いずれも自前の背景を持たず
          // 「アイコンだけが浮かんでいる」意匠（canvas_icon_button.dart参照）。
          // ところがこれらはキャンバスのStackの外側＝Columnの別の行に置かれて
          // いるため、透過した先に見えるのはキャンバス外周ではなくScaffold
          // 本来の背景色だった。結果、バーの帯だけが明るい別パネルのように
          // 見えてしまう（Task#163で一度ツールバー側へ外周色を塗って
          // 誤魔化したが、その後の変更で透明に戻り再発した）。
          // Scaffoldの背景自体をキャンバス外周色に揃えることで、レイアウトも
          // ジェスチャー処理も変えずに「バーは透過、背後は一続きの
          // キャンバス外周」という本来の見た目にする。
          backgroundColor: kCanvasOutsideColor,
          body: SafeArea(
            child: isDesktop
                ? _buildPcWorkspace(
                    project,
                    selectionEditingHidden: selectionEditingHidden,
                    leftHanded: leftHanded,
                  )
                // ツールオプション系のフローティングパネル（ブラシ・トーン・
                // スタンプ・ペンサブツール・オニオンスキン・定規・フィルター・
                // 早替え設定）は、画面全体を覆うこの一番外側のStackへ配置する
                // ことで、太さ／不透明度スライダーやツールバーなど他のUI要素の
                // 手前に必ず表示されるようにしている。パネルの外側をタップすると
                // 閉じられる。
                : Stack(
                    children: [
                      Column(
                        children: [
                          // フィルターの調整中（スマホ）は、上部バー・ツールバー・
                          // フレーム一覧を畳み、調整パネルを画面下部へ横幅いっぱいに
                          // 出す（プレビューはキャンバスそのものに出る）。Undo/Redoも
                          // 調整パネル側だけにして、同じ役割のボタンを重ねて出さない。
                          if (!filterAdjusting) _buildTopBar(),
                          Expanded(
                            child: _buildCanvasStack(
                              project,
                              selectionEditingHidden: selectionEditingHidden,
                            ),
                          ),
                          // ブラシサイズ／不透明度スライダーは、サイズ・不透明度が実際に
                          // 意味を持つツール使用中のみ表示する。バケツ・スポイト・選択系・
                          // 変形・テキスト・図形ツールではブラシ設定が描画結果に影響しない
                          // ため非表示にし、縦スペースをキャンバスへ還元する。
                          // 選択範囲があるときは、変形量を数値で指定するスライダーを
                          // 画面下部へ出す（ハンドルのドラッグと同じ操作を、
                          // 細かく指定したいとき用）。ブラシ設定スライダーは
                          // 選択ツール中は出ないので場所は競合しない。
                          if (filterAdjusting)
                            _filterPanel(bottomBar: true)
                          else if (_isSelectionToolActive &&
                              _hasActiveSelection &&
                              !selectionEditingHidden)
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
                          if (!filterAdjusting && _usesBrushSize(_currentTool))
                            BrushSizeSlider(
                              brushSize: _brushSize,
                              opacity: _brushOpacity,
                              onSizeChanged: _setBrushSize,
                              onOpacityChanged: _setBrushOpacity,
                            ),
                          // メッシュ変形中は分割数のスライダーだけを画面下部へ出す
                          // （自由変形＝分割数1のときは何も出さない）。
                          if (!filterAdjusting &&
                              _currentTool == DrawingTool.meshTransform &&
                              _meshDensity > 1)
                            _meshDensitySlider(context),
                          // ツールバーの折りたたみ用ハンドル（フレーム一覧と
                          // 同様に、任意のタイミングで開閉できるようにし描画領域を広げる）。
                          // デスクトップでは常設の縦レール表示に切り替わるため対象外。
                          //
                          // 背景はツールバー本体と同じく持たせない（Scaffoldの
                          // 背景をキャンバス外周色に揃えてあるため、透過した先は
                          // キャンバス外周と地続きに見える）。
                          //
                          // 【タップしやすさ改善】高さ16→28pxへ拡大（アイコンも
                          // 16→22pxへ）。フルの48px（Material推奨タップ領域）まで
                          // 広げると常時表示のバーとして描画領域を圧迫しすぎるため、
                          // 誤タップしにくくなる範囲での妥協値としている。
                          if (!_isSelectionToolActive && !filterAdjusting)
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  shadows: CanvasIconButton.foregroundShadows(
                                    Theme.of(context).colorScheme.onSurface,
                                    Theme.of(context).colorScheme,
                                  ),
                                ),
                              ),
                            ),
                          // PC/DeXモードではツールパレット（縦）として作業画面の端に置く。
                          if (_showToolbar &&
                              !_isSelectionToolActive &&
                              !filterAdjusting)
                            _buildToolbarWidget(vertical: false),
                          if (_frameMultiSelectMode && !filterAdjusting)
                            _buildFrameMultiSelectBar(),
                          // フレーム一覧の折りたたみ用ハンドル（描画領域を
                          // できるだけ広げるため、任意のタイミングで開閉できるようにする）。
                          // 高さ16→28px・アイコン16→22pxへ拡大（ツールバー折りたたみ
                          // ハンドルと同様、タップしやすさ改善のため）。
                          //
                          // 選択ツール使用中は、キャンバス左下の操作バーへ集中できるよう
                          // ツールバー・フレーム一覧ごと畳む（開閉ハンドルも隠す）。
                          if (!_isSelectionToolActive && !filterAdjusting)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(
                                () => _showFrameStrip = !_showFrameStrip,
                              ),
                              child: Container(
                                height: 28,
                                alignment: Alignment.center,
                                color: Colors.transparent,
                                child: Icon(
                                  _showFrameStrip
                                      ? Icons.keyboard_arrow_down
                                      : Icons.keyboard_arrow_up,
                                  size: 22,
                                  // 色固定をやめ、テーマの文字色と連動させる（CanvasIconButton・
                                  // ToolbarWidgetの色連動と同じ方針）。
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  shadows: CanvasIconButton.foregroundShadows(
                                    Theme.of(context).colorScheme.onSurface,
                                    Theme.of(context).colorScheme,
                                  ),
                                ),
                              ),
                            ),
                          if (_showFrameStrip &&
                              !_isSelectionToolActive &&
                              !filterAdjusting)
                            _buildFrameStrip(),
                        ],
                      ),
                      // パネル表示中は、パネル外をタップすると閉じられるようにする
                      // 透明バリア（パネル本体より下、Columnより上に敷く）。
                      // フィルターパネルがキャンバスを使っている間（球体陰影の光・
                      // 魚眼の中心のドラッグ、キャンバスからの色取り）は、タッチを
                      // キャンバスへ通す。バリア自体は外さずIgnorePointerで素通し
                      // にすること（外すとStackの並びがずれ、パネルが作り直されて
                      // 編集中のフィルターが一覧へ戻ってしまう）。
                      if (_anyToolPanelOpen)
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: _filterPanelUsesCanvas(),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(_closeAllOverlayPanels),
                            ),
                          ),
                        ),
                      if (_showLayerPanel)
                        Positioned(
                          left: leftHanded ? 0 : null,
                          right: leftHanded ? null : 0,
                          top: 0,
                          bottom: 0,
                          width: 250,
                          child: LayerPanel(
                            onClose: () =>
                                setState(() => _showLayerPanel = false),
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
                      if (_showColorPicker)
                        _sidedPanel(
                          anchorLeft: true,
                          leftHanded: leftHanded,
                          top: null,
                          bottom: 16,
                          child: _colorPickerPanel(),
                        ),
                      if (_showBrushPanel)
                        _sidedPanel(
                          anchorLeft: true,
                          leftHanded: leftHanded,
                          top: 56,
                          bottom: null,
                          child: _brushPanel(),
                        ),
                      // トーン・スタンプの全機能管理パネル
                      if (_showTonePanel)
                        _sidedPanel(
                          anchorLeft: true,
                          leftHanded: leftHanded,
                          top: 56,
                          bottom: null,
                          child: _tonePanel(),
                        ),
                      if (_showStampPanel)
                        _sidedPanel(
                          anchorLeft: true,
                          leftHanded: leftHanded,
                          top: 56,
                          bottom: null,
                          child: _stampPanel(),
                        ),
                      // ペンサブツールパネル（ブラシ/トーン/スタンプ）
                      if (_showPenSubToolPanel)
                        _sidedPanel(
                          anchorLeft: true,
                          leftHanded: leftHanded,
                          top: 56,
                          bottom: null,
                          child: _penSubToolPanel(),
                        ),
                      // オニオンスキンパネル
                      if (_showOnionSkinPanel)
                        _sidedPanel(
                          anchorLeft: false,
                          leftHanded: leftHanded,
                          top: 56,
                          bottom: null,
                          child: _onionSkinPanel(),
                        ),
                      // 定規パネル
                      if (_showRulerPanel)
                        _sidedPanel(
                          anchorLeft: true,
                          leftHanded: leftHanded,
                          top: 56,
                          bottom: null,
                          child: _rulerPanel(),
                        ),
                      // 早替えツール設定パネル
                      if (_showQuickToolPanel)
                        _sidedPanel(
                          anchorLeft: false,
                          leftHanded: leftHanded,
                          top: null,
                          bottom: 16,
                          child: _quickToolPanel(),
                        ),
                      // レイヤー全体の自由変形・メッシュ変形パネル。
                      // 他パネルと異なり、格子点のドラッグ操作自体はこのパネルの外＝
                      // キャンバス側で行うため、あえて_anyToolPanelOpen（パネル外タップ
                      // で閉じる透明バリア）の対象には含めない（含めると、格子点を
                      // ドラッグしようとした最初のタップでバリアがパネルをキャンセル
                      // してしまい操作不能になる）。
                      //
                      // スマホ幅では専用パネルを出さない。自由変形・メッシュ変形中は
                      // 「キャンバス左下のキャンセル／適用」と「メッシュ変形のときだけ
                      // 画面下部の分割数スライダー」だけにして、格子点のドラッグに
                      // 画面を明け渡す（パネルがキャンバスを覆って掴めなくなるため）。
                      // デスクトップは横に並ぶので従来どおりパネルを出す。
                      // 色調調整パネル
                      if (_showColorAdjustPanel)
                        _sidedPanel(
                          anchorLeft: true,
                          leftHanded: leftHanded,
                          top: 56,
                          bottom: null,
                          child: _colorAdjustPanel(),
                        ),
                      // 資料ウィンドウ：PC/スマホ問わず常にフローティングで表示する
                      // （PC/DeXモードで右上に固定表示する案も試したが、右上は
                      // キャンバスプレビュー・ナビゲーターパネルの定位置と重なる
                      // ため、reference_window.dart側のコメントのとおり見送った）。
                      if (_showReferenceWindow)
                        ReferenceWindow(
                          onClose: () =>
                              setState(() => _showReferenceWindow = false),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// キャンバス本体（背景・CanvasArea・キャンバスの上に出す案内と操作バー）。
  /// スマホの画面とPC/DeXモードの作業画面の両方で使う。
  Widget _buildCanvasStack(
    Project project, {
    required bool selectionEditingHidden,
    bool isDesktop = false,
  }) {
    return Stack(
      children: [
        // 【重大バグ修正】背景は1枚だけ：CanvasArea自体は
        // 「枠外」を塗らず、実際の描画内容（drawingRect）
        // だけを描く透明なレイヤーになっており、この
        // Containerがキャンバス全域の唯一の背景として
        // 常に固定サイズ・固定色で存在する（=キャンバスは
        // この背景の中央に乗っているだけ、という単純な
        // 構成）。CanvasArea内部はTransformでピンチズーム・
        // パンを描画時に適用しているため、ズームアウトで
        // 描画内容だけが縮小されても、この背景自体は
        // 動かずに全域を覆い続ける（以前はCanvasArea側にも
        // 同じ色の「枠外」塗りを重ねて二重に背景を持たせて
        // いたため、縮小時に背景まで一緒に縮んで見た目が
        // ちぐはぐになる不具合があった）。
        Container(color: kCanvasOutsideColor),
        Listener(
          // 入力欄はマウス・ペンで外を押されると自分で
          // フォーカスを手放す（同じ押下の処理の中で、
          // ここより後に動く）。その後で戻す。
          onPointerDown: (_) => scheduleMicrotask(() {
            if (mounted && !_screenFocus.hasPrimaryFocus) {
              _screenFocus.requestFocus();
            }
          }),
          child: CanvasArea(
            key: _canvasAreaKey,
            onTapForText: _currentTool == DrawingTool.text
                ? onCanvasTapForText
                : null,
            onEyedropper: _handleCanvasEyedropper,
            autofillCheckMode: _autofillCheckMode,
            filterEyedropperActive:
                _filterColorEyedropperTarget != null ||
                _textColorEyedropperTarget != null ||
                _brushOutlineEyedropperActive,
            filterGizmo: _filterCanvasGizmo(project),
            currentLayerPreview: _filterCanvasPreviewShown(),
            currentLayerPreviewBlendMode: _filterCanvasPreviewBlendMode(),
            lockToolInput: selectionEditingHidden,
            onFilterGizmoChanged: (gizmo) => _moveFilterGizmo(project, gizmo),
            onFilterGizmoDragStart: () =>
                context.read<FilterService>().beginFilterEditGroup(),
            onFilterGizmoDragEnd: () =>
                context.read<FilterService>().endFilterEditGroup(),
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
            onGestureToolChange: (tool) => setState(() => _currentTool = tool),
            onGestureToggleTool: _handleGestureToggleTool,
            onNextQuickTool: _applyNextQuickTool,
            onToggleOnionSkin: () => setState(
              () => _onionSkinSettings = _onionSkinSettings.copyWith(
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
            selectAllSelectionToken: _selectAllSelectionToken,
            clearSelectionToken: _clearSelectionToken,
            selectionReferenceAllVisible: context
                .watch<SettingsService>()
                .selectionReferenceAllVisible,
            lassoSnapToLines: context.watch<SettingsService>().lassoSnapToLines,
            lassoGapTolerancePx: context
                .watch<SettingsService>()
                .lassoGapTolerancePx,
            onSelectionActiveChanged: (v) {
              if (_hasActiveSelection == v) return;
              setState(() {
                _hasActiveSelection = v;
                // 選択範囲を作り直した／解除したら、
                // 「変更キャンセル」で戻せる範囲も
                // そこで区切る。
                _selectionTransformSteps = 0;
                _resetSelectionSliders();
              });
            },
            onSelectionMaskChanged: (mask) {
              if (identical(_canvasSelectionMask, mask)) {
                return;
              }
              setState(() => _canvasSelectionMask = mask);
            },
            filterLensMask: _filterLensMaskShown(),
            onUndoGesture: _undo,
            onRedoGesture: _redo,
            onFilterLensMaskEdited: _editFilterLensMask,
            selectionMoveX: _selectionMoveX,
            selectionMoveY: _selectionMoveY,
            selectionScale: _selectionScale,
            selectionRotateDeg: _selectionRotateDeg,
            selectionTransformCommitToken: _selectionTransformCommitToken,
            viewRequest: _viewRequest,
            viewInfo: isDesktop ? _viewInfo : null,
          ),
        ),
        if (_filterColorEyedropperTarget != null ||
            _textColorEyedropperTarget != null ||
            _brushOutlineEyedropperActive)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: IgnorePointer(
              child: Center(
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.inverseSurface,
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
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _activeColorEyedropperHint(context),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onInverseSurface,
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
        if (_isSelectionToolActive || _currentTool == DrawingTool.meshTransform)
          Positioned(
            left: 12,
            bottom: 12,
            right: 12,
            // Out of the way while a filter is
            // adjusted: the selection stays as it is
            // (the filter keeps to it) and the
            // canvas shows the preview. Hidden, not
            // removed, so the Stack keeps its order.
            child: Visibility(
              visible: !selectionEditingHidden,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: _currentTool == DrawingTool.meshTransform
                      ? _meshCancelBar(context)
                      : _selectionToolBar(context),
                ),
              ),
            ),
          ),
        // ツールオプション系フローティングパネル（ブラシ・トーン・
        // スタンプ・ペンサブツール・オニオンスキン・定規・
        // フィルター・早替え設定・レイヤー）は画面全体を覆う
        // 一番外側のStackへ移した（build()末尾を参照）。
      ],
    );
  }

  /// いずれかのツールオプション系フローティングパネルが開いているか
  /// （パネル外タップでの一括クローズに使う）。
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

  // ─── PC/DeXモードの作業画面 ───────────────────────────────────────────

  /// PC/DeXモード専用の作業画面。上から、メニューバー・コマンドバー・
  /// ［ツールパレット｜ツールのドック｜キャンバス｜色・レイヤーのドック］・
  /// フレーム一覧・ステータスバー（左利きモードでは中段を左右反転）。
  /// スマホの「キャンバスの上に浮かぶパネル」は使わず、パネルはすべて
  /// ドックのペイン（タブ）に入るので、キャンバスを隠さない。
  Widget _buildPcWorkspace(
    Project project, {
    required bool selectionEditingHidden,
    required bool leftHanded,
  }) {
    final leftPanes = _pcPanelsHidden ? const <PcPane>[] : _pcLeftPanes();
    final rightPanes = _pcPanelsHidden ? const <PcPane>[] : _pcRightPanes();
    final leftOpen = leftPanes.any((p) => p.tabs.isNotEmpty);
    final rightOpen = rightPanes.any((p) => p.tabs.isNotEmpty);
    final widths = _fitDockWidths(
      context,
      isDesktop: true,
      toolDockOpen: leftOpen,
      rightDockOpen: rightOpen,
    );
    void onActiveTab(String pane, String tab) => _pcActiveTabs[pane] = tab;
    // つまみは、ドックの外側へ引くほどドックが広がる。
    final toolSplitter = PcDockSplitter(
      key: const ValueKey('pcToolDockSplitter'),
      onDrag: (dx) => setState(() {
        final current = _toolPanelWidthDragOverride ?? widths.tool;
        _toolPanelWidthDragOverride = (current + (leftHanded ? -dx : dx)).clamp(
          SettingsService.minDesktopToolPanelWidth,
          widths.toolMax,
        );
      }),
      onDragEnd: () {
        final w = _toolPanelWidthDragOverride;
        if (w != null) {
          context.read<SettingsService>().setDesktopToolPanelWidth(w);
        }
      },
    );
    final rightSplitter = PcDockSplitter(
      key: const ValueKey('pcRightDockSplitter'),
      onDrag: (dx) => setState(() {
        final current = _panelWidthDragOverride ?? widths.right;
        _panelWidthDragOverride = (current + (leftHanded ? dx : -dx)).clamp(
          SettingsService.minDesktopPanelWidth,
          widths.rightMax,
        );
      }),
      onDragEnd: () {
        final w = _panelWidthDragOverride;
        if (w != null) {
          context.read<SettingsService>().setDesktopPanelWidth(w);
        }
      },
    );
    final middle = <Widget>[
      _buildPcToolPalette(),
      if (leftOpen) ...[
        SizedBox(
          key: const ValueKey('pcToolDockBox'),
          width: widths.tool,
          child: PcDockColumn(
            key: const ValueKey('pcToolDock'),
            panes: leftPanes,
            onActiveTabChanged: onActiveTab,
          ),
        ),
        toolSplitter,
      ],
      Expanded(
        key: const ValueKey('pcCanvasColumn'),
        child: Column(
          children: [
            Expanded(
              child: _buildCanvasStack(
                project,
                selectionEditingHidden: selectionEditingHidden,
                isDesktop: true,
              ),
            ),
            if (_frameMultiSelectMode) _buildFrameMultiSelectBar(),
          ],
        ),
      ),
      if (rightOpen) ...[
        rightSplitter,
        SizedBox(
          key: const ValueKey('pcRightDockBox'),
          width: widths.right,
          child: PcDockColumn(
            key: const ValueKey('pcRightDock'),
            panes: rightPanes,
            onActiveTabChanged: onActiveTab,
          ),
        ),
      ],
    ];
    return Stack(
      children: [
        Column(
          children: [
            _buildPcMenuBar(project),
            _buildPcCommandBar(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: leftHanded ? middle.reversed.toList() : middle,
              ),
            ),
            if (_showFrameStrip) _buildPcFrameStrip(),
            _buildPcStatusBar(project),
          ],
        ),
        // 資料ウィンドウは、PCでも絵の横へ自由に置ける浮かぶ窓のまま。
        if (_showReferenceWindow)
          ReferenceWindow(
            onClose: () => setState(() => _showReferenceWindow = false),
          ),
      ],
    );
  }

  /// PC/DeXモード：ドックのタブを開いて前に出す。開いていて前に出ていれば閉じる。
  void _togglePcTab(CanvasDockPanel panel) => setState(() {
    final open = _openDockPanels().contains(panel);
    if (open && _pcActiveTabs.containsValue(panel.name)) {
      _setDockPanelOpen(panel, false);
    } else {
      _setDockPanelOpen(panel, true);
      _focusPcTab(panel.name);
    }
  });

  void _focusPcTab(String tabId) {
    _pcFocusTab = tabId;
    _pcFocusSerial++;
    _pcPanelsHidden = false;
  }

  void _setDockPanelOpen(CanvasDockPanel panel, bool open) {
    final panels = _openDockPanels();
    if (open) {
      panels.add(panel);
    } else {
      panels.remove(panel);
    }
    _setDockPanels(panels);
  }

  void _viewAction(CanvasViewAction action) => setState(
    () => _viewRequest = CanvasViewRequest(
      (_viewRequest?.serial ?? 0) + 1,
      action,
    ),
  );

  /// ツールのドック：ツールプロパティ／サブツール（ペンサブツール・ブラシ・
  /// トーン・スタンプ・早替え・定規）／調整（フィルター・色調調整・
  /// オニオンスキン・変形）。タブの並びは「PCレイアウト設定」の順。
  List<PcPane> _pcLeftPanes() {
    final l10n = AppLocalizations.of(context)!;
    const subTools = {
      CanvasDockPanel.penSubTool,
      CanvasDockPanel.brush,
      CanvasDockPanel.tone,
      CanvasDockPanel.stamp,
      CanvasDockPanel.quickTool,
      CanvasDockPanel.ruler,
    };
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
    final subToolTabs = <PcPaneTab>[];
    final adjustTabs = <PcPaneTab>[];
    for (final key in order) {
      final child = byPanel[key];
      if (child == null) continue;
      (subTools.contains(key) ? subToolTabs : adjustTabs).add(
        _pcDockTab(l10n, key, child),
      );
    }
    if (_showMeshTransformPanel) {
      adjustTabs.add(
        PcPaneTab(
          id: 'meshTransform',
          title: l10n.canvasEditMenuMeshTransform,
          icon: Icons.crop_free,
          child: _meshTransformPanel(),
          onClose: _cancelMeshTransform,
        ),
      );
    }
    return [
      PcPane(
        id: 'toolProperty',
        preferredHeight: 250,
        minLayoutHeight: 0,
        tabs: [
          if (_showPcToolProperty)
            PcPaneTab(
              id: 'toolProperty',
              title: l10n.pcPaneToolProperty,
              icon: Icons.tune,
              child: _pcToolProperty(),
              onClose: () => setState(() => _showPcToolProperty = false),
            ),
        ],
      ),
      PcPane(
        id: 'subTool',
        fill: true,
        tabs: subToolTabs,
        focusTab: _pcFocusTab,
        focusSerial: _pcFocusSerial,
      ),
      PcPane(
        id: 'adjust',
        fill: true,
        tabs: adjustTabs,
        focusTab: _pcFocusTab,
        focusSerial: _pcFocusSerial,
      ),
    ];
  }

  /// 色・レイヤーのドック：キャンバスプレビュー・カラー・レイヤーを
  /// 「PCレイアウト設定」の順に縦に並べる。
  List<PcPane> _pcRightPanes() {
    final l10n = AppLocalizations.of(context)!;
    final order = context.watch<SettingsService>().rightDockOrder;
    final panes = <PcPane>[];
    for (final key in order) {
      switch (key) {
        case CanvasDockPanel.canvasPreview:
          panes.add(
            PcPane(
              id: key.name,
              preferredHeight: 150,
              minLayoutHeight: 0,
              focusTab: _pcFocusTab,
              focusSerial: _pcFocusSerial,
              tabs: [
                if (_showCanvasPreviewPanel)
                  _pcDockTab(
                    l10n,
                    key,
                    CanvasPreviewNavigator(
                      projectId: widget.projectId,
                      sceneId: _currentSceneId,
                      frameIndex: _currentFrame,
                      onClose: () =>
                          setState(() => _showCanvasPreviewPanel = false),
                    ),
                  ),
              ],
            ),
          );
        case CanvasDockPanel.colorPicker:
          panes.add(
            PcPane(
              id: key.name,
              preferredHeight: 290,
              minLayoutHeight: 0,
              focusTab: _pcFocusTab,
              focusSerial: _pcFocusSerial,
              tabs: [
                if (_showColorPicker)
                  _pcDockTab(l10n, key, _colorPickerPanel()),
              ],
            ),
          );
        case CanvasDockPanel.layer:
          panes.add(
            PcPane(
              id: key.name,
              fill: true,
              focusTab: _pcFocusTab,
              focusSerial: _pcFocusSerial,
              tabs: [
                if (_showLayerPanel)
                  _pcDockTab(
                    l10n,
                    key,
                    LayerPanel(
                      onClose: () => setState(() => _showLayerPanel = false),
                      projectId: widget.projectId,
                      sceneId: _currentSceneId,
                      frameIndex: _currentFrame,
                      dockedMode: true,
                      onEditTextLayer: _onEditTextLayerTapped,
                      currentLayerId: _currentLayerId,
                      onLayerSelected: (id) =>
                          setState(() => _currentLayerId = id),
                      selectAllToken: _layerSelectAllToken,
                    ),
                  ),
              ],
            ),
          );
        default:
          break;
      }
    }
    return panes;
  }

  PcPaneTab _pcDockTab(
    AppLocalizations l10n,
    CanvasDockPanel panel,
    Widget child,
  ) => PcPaneTab(
    id: panel.name,
    title: _dockPanelTitle(l10n, panel),
    icon: _dockPanelIcon(panel),
    child: child,
    onClose: () => setState(() => _setDockPanelOpen(panel, false)),
  );

  static String _dockPanelTitle(AppLocalizations l10n, CanvasDockPanel p) =>
      switch (p) {
        CanvasDockPanel.brush => l10n.workspaceDockPanelBrush,
        CanvasDockPanel.colorPicker => l10n.workspaceDockPanelColorPicker,
        CanvasDockPanel.layer => l10n.workspaceDockPanelLayer,
        CanvasDockPanel.tone => l10n.workspaceDockPanelTone,
        CanvasDockPanel.stamp => l10n.workspaceDockPanelStamp,
        CanvasDockPanel.penSubTool => l10n.workspaceDockPanelPenSubTool,
        CanvasDockPanel.onionSkin => l10n.workspaceDockPanelOnionSkin,
        CanvasDockPanel.ruler => l10n.workspaceDockPanelRuler,
        CanvasDockPanel.filter => l10n.workspaceDockPanelFilter,
        CanvasDockPanel.quickTool => l10n.workspaceDockPanelQuickTool,
        CanvasDockPanel.colorAdjust => l10n.workspaceDockPanelColorAdjust,
        CanvasDockPanel.canvasPreview => l10n.workspaceDockPanelCanvasPreview,
      };

  static IconData _dockPanelIcon(CanvasDockPanel p) => switch (p) {
    CanvasDockPanel.brush => Icons.brush_outlined,
    CanvasDockPanel.colorPicker => Icons.palette_outlined,
    CanvasDockPanel.layer => Icons.layers_outlined,
    CanvasDockPanel.tone => Icons.grain,
    CanvasDockPanel.stamp => Icons.approval_outlined,
    CanvasDockPanel.penSubTool => Icons.edit_outlined,
    CanvasDockPanel.onionSkin => Icons.filter_none,
    CanvasDockPanel.ruler => Icons.straighten,
    CanvasDockPanel.filter => Icons.blur_on,
    CanvasDockPanel.quickTool => Icons.loop,
    CanvasDockPanel.colorAdjust => Icons.tune,
    CanvasDockPanel.canvasPreview => Icons.map_outlined,
  };

  /// ツールパレット（縦一列）。描くツールだけを並べ、パネルの開閉・保存・
  /// ヘルプはメニューバー・コマンドバーへ移してある。
  Widget _buildPcToolPalette() {
    final colors = PcWorkspaceColors.of(context);
    return DecoratedBox(
      key: const ValueKey('pcToolPalette'),
      decoration: BoxDecoration(
        color: colors.pane,
        border: Border.symmetric(vertical: BorderSide(color: colors.divider)),
      ),
      child: PcPaletteScope(
        child: _buildToolbarWidget(vertical: true, pcPalette: true),
      ),
    );
  }

  /// ツールプロパティ：いま選んでいるツールの設定（太さ・不透明度・
  /// 種類・選択範囲の変形など）を、ツールに合わせて出し分ける。
  Widget _pcToolProperty() {
    final l10n = AppLocalizations.of(context)!;
    final colors = PcWorkspaceColors.of(context);
    final brush = context.watch<BrushService>().currentBrush;
    final labelStyle = TextStyle(fontSize: 12, color: colors.onPane);
    final valueStyle = TextStyle(fontSize: 12, color: colors.mutedOnPane);
    Widget choices<T>(
      List<(T, String)> options,
      T selected,
      void Function(T) onSelect,
    ) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == selected,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => onSelect(value),
          ),
      ],
    );
    Widget action(IconData icon, String label, VoidCallback? onPressed) =>
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label, overflow: TextOverflow.ellipsis),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        );
    final children = <Widget>[
      Row(
        children: [
          Icon(_toolIcon(_currentTool), size: 18, color: colors.accentText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _toolStatusLabel(l10n, brush?.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Kuramubon',
                fontFamilyFallback: kHeadingFontFallback,
                fontSize: 13,
                color: colors.onPane,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
    ];
    if (_currentTool == DrawingTool.pen) {
      children.addAll([
        choices<PenSubTool>(
          [
            (PenSubTool.brush, l10n.penSubToolTabBrush),
            (PenSubTool.tone, l10n.workspaceDockPanelTone),
            (PenSubTool.stamp, l10n.workspaceDockPanelStamp),
          ],
          _currentSubTool,
          (v) => setState(() => _currentSubTool = v),
        ),
        const SizedBox(height: 6),
      ]);
    }
    if (_usesBrushSize(_currentTool)) {
      children.addAll([
        LabeledSlider(
          key: const ValueKey('pcBrushSize'),
          label: l10n.brushSettingsSizeLabel,
          value: _brushSize.clamp(1, 500).toDouble(),
          min: 1,
          max: 500,
          valueText: '${_brushSize.round()}px',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
          padding: const EdgeInsets.symmetric(vertical: 2),
          onChanged: _setBrushSize,
        ),
        LabeledSlider(
          key: const ValueKey('pcBrushOpacity'),
          label: l10n.brushSettingsOpacityLabel,
          value: _brushOpacity.clamp(1, 100).toDouble(),
          min: 1,
          max: 100,
          valueText: '$_brushOpacity%',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
          padding: const EdgeInsets.symmetric(vertical: 2),
          onChanged: (v) => _setBrushOpacity(v.round()),
        ),
      ]);
    }
    switch (_currentTool) {
      case DrawingTool.pen:
        children.add(
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              action(
                Icons.brush_outlined,
                l10n.toolbarBrushSettingsTooltip,
                () => _togglePcTab(CanvasDockPanel.brush),
              ),
              action(
                Icons.edit_outlined,
                l10n.workspaceDockPanelPenSubTool,
                () => _togglePcTab(CanvasDockPanel.penSubTool),
              ),
            ],
          ),
        );
      case DrawingTool.lasso:
        children.add(
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.canvasLassoEnclosedLabel, style: labelStyle),
            value: _lassoFillEnclosedMode,
            onChanged: (v) => setState(() => _lassoFillEnclosedMode = v),
          ),
        );
      case DrawingTool.finger || DrawingTool.blur || DrawingTool.mosaic:
        children.add(
          choices<DrawingTool>(
            [
              (DrawingTool.finger, l10n.toolbarFingerSubtoolWarp),
              (DrawingTool.blur, l10n.toolbarItemBlur),
              (DrawingTool.mosaic, l10n.toolbarItemMosaic),
            ],
            _currentTool,
            (v) => setState(() => _currentTool = v),
          ),
        );
      case DrawingTool.ruler:
        children.add(
          action(
            Icons.straighten,
            l10n.workspaceDockPanelRuler,
            () => _togglePcTab(CanvasDockPanel.ruler),
          ),
        );
      case DrawingTool.shape:
        children.add(
          choices<ShapeKind>(
            [
              (ShapeKind.line, l10n.canvasShapeLine),
              (ShapeKind.rect, l10n.canvasShapeRect),
              (ShapeKind.circle, l10n.canvasShapeCircle),
            ],
            _shapeKind,
            (v) => setState(() => _shapeKind = v),
          ),
        );
      case DrawingTool.selectRect ||
          DrawingTool.selectLasso ||
          DrawingTool.selectMagicWand:
        children.addAll([
          choices<DrawingTool>(
            [
              (DrawingTool.selectRect, l10n.toolbarSelectRect),
              (DrawingTool.selectLasso, l10n.toolbarSelectLasso),
              (DrawingTool.selectMagicWand, l10n.toolbarSelectMagicWand),
            ],
            _currentTool,
            (v) => setState(() => _currentTool = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              action(
                Icons.select_all,
                l10n.canvasSelectAllButton,
                () => setState(() => _selectAllSelectionToken++),
              ),
              action(
                Icons.deselect,
                l10n.canvasDeselectAllButton,
                _hasActiveSelection
                    ? () => setState(() => _clearSelectionToken++)
                    : null,
              ),
              action(
                Icons.invert_colors_outlined,
                l10n.canvasInvertSelectionTooltip,
                _hasActiveSelection
                    ? () => setState(() => _invertSelectionToken++)
                    : null,
              ),
            ],
          ),
          if (_hasActiveSelection) ...[
            const SizedBox(height: 4),
            SelectionTransformSliders(
              moveX: _selectionMoveX,
              moveY: _selectionMoveY,
              scale: _selectionScale,
              rotateDeg: _selectionRotateDeg,
              maxMove: _selectionSliderMaxMove(context),
              onChanged: ({moveX, moveY, scale, rotateDeg}) => setState(() {
                _selectionMoveX = moveX ?? _selectionMoveX;
                _selectionMoveY = moveY ?? _selectionMoveY;
                _selectionScale = scale ?? _selectionScale;
                _selectionRotateDeg = rotateDeg ?? _selectionRotateDeg;
              }),
              onCommit: () => setState(() {
                _selectionTransformCommitToken++;
                _selectionTransformSteps++;
                _resetSelectionSliders();
              }),
            ),
          ],
        ]);
      case DrawingTool.text:
        children.add(Text(l10n.canvasTapToEnterTextLabel, style: valueStyle));
      case DrawingTool.meshTransform:
        children.add(_meshDensitySlider(context));
      case DrawingTool.bucket:
        children.add(
          action(
            Icons.format_color_fill,
            l10n.bucketSettingsTitle,
            () => _runAutomationBlockedAction(
              () => context.push('/settings/bucket'),
            ),
          ),
        );
      case DrawingTool.eraser:
        break;
      case DrawingTool.eyedropper || DrawingTool.pan || DrawingTool.move:
        children.add(Text(l10n.pcToolPropertyEmpty, style: valueStyle));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      children: children,
    );
  }

  void _setBrushSize(double v) {
    setState(() => _brushSize = v);
    context.read<BrushService>().updateCurrentBrushSize(v);
    _recordCanvasAutomation(
      'canvas.brushSize',
      'Brush size',
      args: {'value': v},
    );
  }

  void _setBrushOpacity(int v) {
    setState(() => _brushOpacity = v);
    context.read<BrushService>().updateCurrentBrushOpacity(v);
    _recordCanvasAutomation(
      'canvas.brushOpacity',
      'Brush opacity',
      args: {'value': v},
    );
  }

  static IconData _toolIcon(DrawingTool tool) => switch (tool) {
    DrawingTool.pen => Icons.brush,
    DrawingTool.eraser => Icons.auto_fix_normal_outlined,
    DrawingTool.bucket => Icons.format_color_fill,
    DrawingTool.lasso => Icons.gesture,
    DrawingTool.eyedropper => Icons.colorize,
    DrawingTool.finger => Icons.pan_tool_alt,
    DrawingTool.blur => Icons.blur_on,
    DrawingTool.mosaic => Icons.grid_on,
    DrawingTool.selectRect => Icons.highlight_alt,
    DrawingTool.selectLasso => Icons.gesture,
    DrawingTool.selectMagicWand => Icons.auto_awesome,
    DrawingTool.move => Icons.open_with,
    DrawingTool.ruler => Icons.straighten,
    DrawingTool.text => Icons.text_fields,
    DrawingTool.shape => Icons.category,
    DrawingTool.pan => Icons.back_hand,
    DrawingTool.meshTransform => Icons.crop_free,
  };

  /// ステータスバー・ツールプロパティの見出しに出すツール名。ペンは
  /// 使っているブラシの名前を添える。
  String _toolStatusLabel(AppLocalizations l10n, String? brushName) {
    final name = switch (_currentTool) {
      DrawingTool.pen => switch (_currentSubTool) {
        PenSubTool.tone => l10n.workspaceDockPanelTone,
        PenSubTool.stamp => l10n.workspaceDockPanelStamp,
        _ => l10n.penSubToolTabBrush,
      },
      DrawingTool.eraser => l10n.toolbarItemEraser,
      DrawingTool.bucket => l10n.toolbarItemBucket,
      DrawingTool.lasso => l10n.penSubToolTabLassoFill,
      DrawingTool.eyedropper => l10n.toolbarItemEyedropper,
      DrawingTool.finger => l10n.toolbarFingerSubtoolWarp,
      DrawingTool.blur => l10n.toolbarItemBlur,
      DrawingTool.mosaic => l10n.toolbarItemMosaic,
      DrawingTool.selectRect => l10n.toolbarSelectRect,
      DrawingTool.selectLasso => l10n.toolbarSelectLasso,
      DrawingTool.selectMagicWand => l10n.toolbarSelectMagicWand,
      DrawingTool.move => l10n.commonMove,
      DrawingTool.ruler => l10n.canvasRulerTooltip,
      DrawingTool.text => l10n.toolbarItemText,
      DrawingTool.shape => l10n.toolbarItemShape,
      DrawingTool.pan => l10n.toolbarItemPan,
      DrawingTool.meshTransform => l10n.canvasEditMenuMeshTransform,
    };
    final brushInUse =
        _currentTool == DrawingTool.pen && _currentSubTool == PenSubTool.brush;
    return brushInUse && brushName != null && brushName.isNotEmpty
        ? brushName
        : name;
  }

  String? _shortcutLabel(ShortcutCommand command) {
    for (final b in context.read<ShortcutService>().bindings) {
      if (b.command == command) return b.comboLabel;
    }
    return null;
  }

  void _pcAddLayer(model.LayerType type) {
    final l10n = AppLocalizations.of(context)!;
    final projects = context.read<ProjectService>();
    final count = projects
        .layersOf(widget.projectId, _currentSceneId, _currentFrame)
        .length;
    final created = projects.addLayer(
      projectId: widget.projectId,
      sceneId: _currentSceneId,
      frameIndex: _currentFrame,
      type: type,
      name: type == model.LayerType.folder
          ? l10n.layerPanelDefaultFolderName(count + 1)
          : l10n.layerPanelDefaultLayerName(count + 1),
    );
    if (type != model.LayerType.folder) {
      setState(() => _currentLayerId = created.id);
    }
  }

  void _pcDuplicateLayer() {
    final layerId = _currentLayerId;
    if (layerId == null) return;
    final copy = context.read<ProjectService>().duplicateLayer(
      projectId: widget.projectId,
      sceneId: _currentSceneId,
      frameIndex: _currentFrame,
      layerId: layerId,
    );
    if (copy != null) setState(() => _currentLayerId = copy.id);
  }

  /// メニューバー。スマホの「設定/編集」メニュー・上部バー・ツールバーに
  /// 分かれていた操作を、PCのペイントソフトと同じ分類で並べる。
  Widget _buildPcMenuBar(Project project) {
    final l10n = AppLocalizations.of(context)!;
    final colors = PcWorkspaceColors.of(context);
    final undo = context.watch<UndoManager>();
    final open = _openDockPanels();
    void push(String route) =>
        _runAutomationBlockedAction(() => context.push(route));
    PcMenuItem windowItem(CanvasDockPanel panel) => PcMenuItem(
      key: ValueKey('pcMenuWindow.${panel.name}'),
      label: _dockPanelTitle(l10n, panel),
      checked: open.contains(panel),
      onPressed: () => _togglePcTab(panel),
    );
    PcMenuItem selectTool(DrawingTool tool, String label) => PcMenuItem(
      label: label,
      checked: _currentTool == tool,
      onPressed: () => setState(() => _currentTool = tool),
    );
    PcMenuItem checkMode(AutofillCheckMode mode, String label) => PcMenuItem(
      label: label,
      checked: _autofillCheckMode == mode,
      onPressed: () => setState(() => _autofillCheckMode = mode),
    );
    final menus = [
      PcMenu(
        key: const ValueKey('pcMenu.file'),
        label: l10n.pcMenuFile,
        entries: [
          PcMenuItem(
            key: const ValueKey('pcMenuSave'),
            label: l10n.toolbarSaveTooltip,
            icon: Icons.save_outlined,
            onPressed: () => push('/save-tree/${widget.projectId}'),
          ),
          const PcMenuDivider(),
          PcMenuItem(
            label: l10n.canvasTimelineModeTooltip,
            icon: Icons.movie_filter_outlined,
            onPressed: () => _runAutomationBlockedAction(
              () => context.go('/timeline/${widget.projectId}'),
            ),
          ),
          PcMenuItem(
            label: l10n.timelineBackToProjectListTooltip,
            icon: Icons.home_outlined,
            onPressed: _confirmBackToProjectList,
          ),
          const PcMenuDivider(),
          PcMenuItem(
            label: l10n.canvasEditMenuAutofillPresets,
            icon: Icons.auto_fix_high_outlined,
            onPressed: () => push('/autofill-presets'),
          ),
          PcMenuItem(
            label: l10n.customAutomationTitle,
            icon: Icons.playlist_play,
            onPressed: _showCustomAutomationManager,
          ),
          const PcMenuDivider(),
          PcMenuItem(
            label: l10n.settingsScreenTitle,
            icon: Icons.settings_outlined,
            onPressed: () => push('/settings'),
          ),
        ],
      ),
      PcMenu(
        key: const ValueKey('pcMenu.edit'),
        label: l10n.commonEdit,
        entries: [
          PcMenuItem(
            key: const ValueKey('pcMenuUndo'),
            label: l10n.shortcutCommandUndo,
            icon: Icons.undo,
            shortcut: _shortcutLabel(ShortcutCommand.undo),
            onPressed: undo.canUndo ? _undo : null,
          ),
          PcMenuItem(
            key: const ValueKey('pcMenuRedo'),
            label: l10n.shortcutCommandRedo,
            icon: Icons.redo,
            shortcut: _shortcutLabel(ShortcutCommand.redo),
            onPressed: undo.canRedo ? _redo : null,
          ),
          const PcMenuDivider(),
          PcMenuItem(
            label: l10n.commonCopy,
            icon: Icons.copy,
            shortcut: _shortcutLabel(ShortcutCommand.copy),
            onPressed: _currentLayerId == null ? null : _copyActiveLayer,
          ),
          PcMenuItem(
            label: l10n.commonPaste,
            icon: Icons.paste,
            shortcut: _shortcutLabel(ShortcutCommand.paste),
            onPressed: _currentLayerId == null ? null : _pasteCopiedLayer,
          ),
          const PcMenuDivider(),
          PcMenuItem(
            key: const ValueKey('pcMenuMeshTransform'),
            label: l10n.canvasEditMenuMeshTransform,
            icon: Icons.crop_free,
            onPressed: () => _openMeshTransformPanel(),
          ),
          PcMenuItem(
            label: l10n.canvasEditMenuPressureCurve,
            icon: Icons.gesture,
            onPressed: () => push('/settings/pen'),
          ),
          PcMenuItem(
            label: l10n.shortcutSettingsTitle,
            icon: Icons.keyboard_outlined,
            onPressed: () => push('/settings/shortcuts'),
          ),
        ],
      ),
      PcMenu(
        key: const ValueKey('pcMenu.selection'),
        label: l10n.pcMenuSelection,
        entries: [
          PcMenuItem(
            key: const ValueKey('pcMenuSelectAll'),
            label: l10n.canvasSelectAllButton,
            icon: Icons.select_all,
            onPressed: () => setState(() {
              if (!_isSelectionToolActive) {
                _currentTool = DrawingTool.selectRect;
              }
              _selectAllSelectionToken++;
            }),
          ),
          PcMenuItem(
            label: l10n.canvasDeselectAllButton,
            icon: Icons.deselect,
            onPressed: _hasActiveSelection
                ? () => setState(() => _clearSelectionToken++)
                : null,
          ),
          PcMenuItem(
            label: l10n.canvasInvertSelectionTooltip,
            icon: Icons.invert_colors_outlined,
            onPressed: _hasActiveSelection
                ? () => setState(() => _invertSelectionToken++)
                : null,
          ),
          const PcMenuDivider(),
          selectTool(DrawingTool.selectRect, l10n.toolbarSelectRect),
          selectTool(DrawingTool.selectLasso, l10n.toolbarSelectLasso),
          selectTool(DrawingTool.selectMagicWand, l10n.toolbarSelectMagicWand),
        ],
      ),
      PcMenu(
        key: const ValueKey('pcMenu.layer'),
        label: l10n.layerPanelTitle,
        entries: [
          PcMenuItem(
            key: const ValueKey('pcMenuNewLayer'),
            label: l10n.pcLayerNew,
            icon: Icons.add,
            onPressed: () => _pcAddLayer(model.LayerType.normal),
          ),
          PcMenuItem(
            label: l10n.layerPanelNewFolderButton,
            icon: Icons.create_new_folder_outlined,
            onPressed: () => _pcAddLayer(model.LayerType.folder),
          ),
          PcMenuItem(
            label: l10n.customAutomationStepDuplicateLayer,
            icon: Icons.control_point_duplicate,
            onPressed: _currentLayerId == null ? null : _pcDuplicateLayer,
          ),
          const PcMenuDivider(),
          windowItem(CanvasDockPanel.layer),
        ],
      ),
      PcMenu(
        key: const ValueKey('pcMenu.filter'),
        label: l10n.filterPanelTitle,
        entries: [
          PcMenuItem(
            key: const ValueKey('pcMenuFilter'),
            label: l10n.filterPanelTitle,
            icon: Icons.blur_on,
            checked: _showFilterPanel,
            onPressed: () => _togglePcTab(CanvasDockPanel.filter),
          ),
          PcMenuItem(
            label: l10n.canvasColorAdjustMenuTitle,
            icon: Icons.tune,
            checked: _showColorAdjustPanel,
            onPressed: () => _togglePcTab(CanvasDockPanel.colorAdjust),
          ),
          const PcMenuDivider(),
          PcMenuItem(
            label: l10n.canvasEditMenuFrameMultiSelect,
            checked: _frameMultiSelectMode,
            onPressed: _toggleFrameMultiSelect,
          ),
        ],
      ),
      PcMenu(
        key: const ValueKey('pcMenu.view'),
        label: l10n.pcMenuView,
        entries: [
          PcMenuItem(
            key: const ValueKey('pcMenuZoomIn'),
            label: l10n.pcViewZoomIn,
            icon: Icons.zoom_in,
            onPressed: () => _viewAction(CanvasViewAction.zoomIn),
          ),
          PcMenuItem(
            label: l10n.pcViewZoomOut,
            icon: Icons.zoom_out,
            onPressed: () => _viewAction(CanvasViewAction.zoomOut),
          ),
          PcMenuItem(
            label: l10n.pcViewFit,
            icon: Icons.fit_screen_outlined,
            onPressed: () => _viewAction(CanvasViewAction.fit),
          ),
          PcMenuItem(
            label: l10n.pcViewActualPixels,
            icon: Icons.crop_square,
            onPressed: () => _viewAction(CanvasViewAction.actualPixels),
          ),
          const PcMenuDivider(),
          PcMenuItem(
            label: l10n.pcViewRotateLeft,
            icon: Icons.rotate_left,
            onPressed: () => _viewAction(CanvasViewAction.rotateLeft),
          ),
          PcMenuItem(
            label: l10n.pcViewRotateRight,
            icon: Icons.rotate_right,
            onPressed: () => _viewAction(CanvasViewAction.rotateRight),
          ),
          PcMenuItem(
            label: l10n.pcViewResetRotation,
            icon: Icons.screen_rotation_alt_outlined,
            onPressed: () => _viewAction(CanvasViewAction.resetRotation),
          ),
          const PcMenuDivider(),
          PcMenuItem(
            label: l10n.canvasEditMenuBackgroundToggle,
            icon: Icons.grid_4x4,
            checked: _canvasBackground == CanvasBackground.transparent,
            onPressed: _toggleBackground,
          ),
          PcMenuItem(
            label: l10n.newProjectBackgroundColorLabel,
            icon: Icons.format_paint_outlined,
            onPressed: () => _showBackgroundColorPicker(context),
          ),
          PcMenuItem(
            key: const ValueKey('pcMenuOnionSkin'),
            label: l10n.onionSkinTitle,
            checked: _onionSkinSettings.enabled,
            onPressed: () => setState(
              () => _onionSkinSettings = _onionSkinSettings.copyWith(
                enabled: !_onionSkinSettings.enabled,
              ),
            ),
          ),
          PcSubmenu(
            label: l10n.canvasAutofillCheckView,
            icon: Icons.contrast,
            entries: [
              checkMode(
                AutofillCheckMode.normal,
                l10n.canvasAutofillCheckNormal,
              ),
              checkMode(
                AutofillCheckMode.partSeparation,
                l10n.canvasAutofillCheckParts,
              ),
              checkMode(
                AutofillCheckMode.silhouette,
                l10n.canvasAutofillCheckSilhouette,
              ),
            ],
          ),
          const PcMenuDivider(),
          PcMenuItem(
            label: l10n.canvasEditMenuReferenceWindow,
            checked: _showReferenceWindow,
            onPressed: () =>
                setState(() => _showReferenceWindow = !_showReferenceWindow),
          ),
          PcMenuItem(
            key: const ValueKey('pcMenuFrameStrip'),
            label: l10n.pcViewFrameStrip,
            checked: _showFrameStrip,
            onPressed: () => setState(() => _showFrameStrip = !_showFrameStrip),
          ),
          PcMenuItem(
            key: const ValueKey('pcMenuHidePanels'),
            label: l10n.pcViewHidePanels,
            checked: _pcPanelsHidden,
            onPressed: () => setState(() => _pcPanelsHidden = !_pcPanelsHidden),
          ),
        ],
      ),
      PcMenu(
        key: const ValueKey('pcMenu.window'),
        label: l10n.pcMenuWindow,
        entries: [
          PcMenuItem(
            key: const ValueKey('pcMenuWindow.toolProperty'),
            label: l10n.pcPaneToolProperty,
            checked: _showPcToolProperty,
            onPressed: () => setState(() {
              _showPcToolProperty = !_showPcToolProperty;
              if (_showPcToolProperty) _pcPanelsHidden = false;
            }),
          ),
          windowItem(CanvasDockPanel.penSubTool),
          windowItem(CanvasDockPanel.brush),
          windowItem(CanvasDockPanel.tone),
          windowItem(CanvasDockPanel.stamp),
          windowItem(CanvasDockPanel.quickTool),
          windowItem(CanvasDockPanel.ruler),
          const PcMenuDivider(),
          windowItem(CanvasDockPanel.filter),
          windowItem(CanvasDockPanel.colorAdjust),
          windowItem(CanvasDockPanel.onionSkin),
          const PcMenuDivider(),
          windowItem(CanvasDockPanel.canvasPreview),
          windowItem(CanvasDockPanel.colorPicker),
          windowItem(CanvasDockPanel.layer),
          const PcMenuDivider(),
          PcMenuItem(
            label: l10n.pcWorkspaceLayoutScreenTitle,
            icon: Icons.dashboard_outlined,
            onPressed: () => _runAutomationBlockedAction(
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PcWorkspaceLayoutSettingsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
      PcMenu(
        key: const ValueKey('pcMenu.help'),
        label: l10n.homeDrawerHelp,
        entries: [
          PcMenuItem(
            label: l10n.helpScreenTitle,
            icon: Icons.help_outline,
            onPressed: () => push('/help'),
          ),
          PcMenuItem(
            label: l10n.homeDrawerTutorial,
            icon: Icons.school_outlined,
            onPressed: () => AppTutorial.show(context),
          ),
          PcMenuItem(
            label: l10n.shortcutSettingsTitle,
            icon: Icons.keyboard_outlined,
            onPressed: () => push('/settings/shortcuts'),
          ),
        ],
      ),
    ];
    return PcMenuBar(
      menus: menus,
      trailing: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: colors.mutedOnChrome,
              ),
            ),
          ),
        ),
        PcModeSwitch(
          key: const ValueKey('pcModeSwitch'),
          labels: [l10n.pcModeCanvas, l10n.premiumFeatureTimeline],
          icons: const [Icons.brush_outlined, Icons.movie_filter_outlined],
          selectedIndex: 0,
          onSelected: (i) {
            if (i == 1) {
              _runAutomationBlockedAction(
                () => context.go('/timeline/${widget.projectId}'),
              );
            }
          },
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  /// コマンドバー：よく使う操作（取り消し・保存・選択範囲・表示の倍率と
  /// 回転・背景・オニオンスキン）をアイコンで並べる。
  Widget _buildPcCommandBar() {
    final l10n = AppLocalizations.of(context)!;
    final colors = PcWorkspaceColors.of(context);
    final undo = context.watch<UndoManager>();
    return PcCommandBar(
      leading: [
        PcToolButton(
          key: const ValueKey('pcCommandHome'),
          icon: Icons.home_outlined,
          tooltip: l10n.timelineBackToProjectListTooltip,
          onPressed: _confirmBackToProjectList,
        ),
        const PcCommandDivider(),
        PcToolButton(
          key: const ValueKey('pcCommandUndo'),
          icon: Icons.undo,
          tooltip: l10n.shortcutCommandUndo,
          onPressed: undo.canUndo ? _undo : null,
        ),
        PcToolButton(
          key: const ValueKey('pcCommandRedo'),
          icon: Icons.redo,
          tooltip: l10n.shortcutCommandRedo,
          onPressed: undo.canRedo ? _redo : null,
        ),
        PcToolButton(
          key: const ValueKey('pcCommandSave'),
          icon: Icons.save_outlined,
          tooltip: l10n.toolbarSaveTooltip,
          onPressed: () => _runAutomationBlockedAction(
            () => context.push('/save-tree/${widget.projectId}'),
          ),
        ),
        const PcCommandDivider(),
        PcToolButton(
          icon: Icons.select_all,
          tooltip: l10n.canvasSelectAllButton,
          onPressed: () => setState(() {
            if (!_isSelectionToolActive) _currentTool = DrawingTool.selectRect;
            _selectAllSelectionToken++;
          }),
        ),
        PcToolButton(
          icon: Icons.deselect,
          tooltip: l10n.canvasDeselectAllButton,
          onPressed: _hasActiveSelection
              ? () => setState(() => _clearSelectionToken++)
              : null,
        ),
        PcToolButton(
          icon: Icons.invert_colors_outlined,
          tooltip: l10n.canvasInvertSelectionTooltip,
          onPressed: _hasActiveSelection
              ? () => setState(() => _invertSelectionToken++)
              : null,
        ),
        const PcCommandDivider(),
        PcToolButton(
          key: const ValueKey('pcCommandZoomOut'),
          icon: Icons.zoom_out,
          tooltip: l10n.pcViewZoomOut,
          onPressed: () => _viewAction(CanvasViewAction.zoomOut),
        ),
        ValueListenableBuilder<CanvasViewInfo>(
          valueListenable: _viewInfo,
          builder: (context, info, _) => Tooltip(
            message: l10n.pcViewFit,
            child: InkWell(
              key: const ValueKey('pcCommandZoomValue'),
              borderRadius: BorderRadius.circular(5),
              onTap: () => _viewAction(CanvasViewAction.fit),
              child: Container(
                width: 56,
                height: 30,
                alignment: Alignment.center,
                child: Text(
                  '${(info.zoom * 100).round()}%',
                  style: TextStyle(fontSize: 12, color: colors.onChrome),
                ),
              ),
            ),
          ),
        ),
        PcToolButton(
          key: const ValueKey('pcCommandZoomIn'),
          icon: Icons.zoom_in,
          tooltip: l10n.pcViewZoomIn,
          onPressed: () => _viewAction(CanvasViewAction.zoomIn),
        ),
        PcToolButton(
          icon: Icons.fit_screen_outlined,
          tooltip: l10n.pcViewFit,
          onPressed: () => _viewAction(CanvasViewAction.fit),
        ),
        PcToolButton(
          icon: Icons.crop_square,
          tooltip: l10n.pcViewActualPixels,
          onPressed: () => _viewAction(CanvasViewAction.actualPixels),
        ),
        const PcCommandDivider(),
        PcToolButton(
          key: const ValueKey('pcCommandRotateLeft'),
          icon: Icons.rotate_left,
          tooltip: l10n.pcViewRotateLeft,
          onPressed: () => _viewAction(CanvasViewAction.rotateLeft),
        ),
        PcToolButton(
          icon: Icons.rotate_right,
          tooltip: l10n.pcViewRotateRight,
          onPressed: () => _viewAction(CanvasViewAction.rotateRight),
        ),
        ValueListenableBuilder<CanvasViewInfo>(
          valueListenable: _viewInfo,
          builder: (context, info, _) => PcToolButton(
            icon: Icons.screen_rotation_alt_outlined,
            tooltip: l10n.pcViewResetRotation,
            onPressed: info.rotationDeg.abs() > 0.05
                ? () => _viewAction(CanvasViewAction.resetRotation)
                : null,
          ),
        ),
        const PcCommandDivider(),
        PcToolButton(
          icon: Icons.grid_4x4,
          tooltip: l10n.canvasEditMenuBackgroundToggle,
          selected: _canvasBackground == CanvasBackground.transparent,
          onPressed: _toggleBackground,
        ),
        PcToolButton(
          key: const ValueKey('pcCommandOnionSkin'),
          icon: Icons.filter_none,
          tooltip: l10n.onionSkinTitle,
          selected: _onionSkinSettings.enabled,
          onPressed: () => setState(
            () => _onionSkinSettings = _onionSkinSettings.copyWith(
              enabled: !_onionSkinSettings.enabled,
            ),
          ),
        ),
        PcToolButton(
          icon: Icons.dashboard_customize_outlined,
          tooltip: l10n.canvasEditMenuReferenceWindow,
          selected: _showReferenceWindow,
          onPressed: () =>
              setState(() => _showReferenceWindow = !_showReferenceWindow),
        ),
        PcToolButton(
          icon: Icons.loop,
          tooltip: l10n.toolbarQuickToolTooltip,
          onPressed: _applyNextQuickTool,
        ),
      ],
      trailing: [
        PcToolButton(
          key: const ValueKey('pcCommandHidePanels'),
          icon: _pcPanelsHidden
              ? Icons.view_sidebar_outlined
              : Icons.fullscreen,
          tooltip: l10n.pcViewHidePanels,
          selected: _pcPanelsHidden,
          onPressed: () => setState(() => _pcPanelsHidden = !_pcPanelsHidden),
        ),
      ],
    );
  }

  /// フレーム一覧（スマホでは画面の下、PC/DeXモードではステータスバーの上）。
  Widget _buildFrameStrip() => FrameStripWidget(
    currentFrame: _currentFrame,
    projectId: widget.projectId,
    sceneId: _currentSceneId,
    showTransparency: _canvasBackground == CanvasBackground.transparent,
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
  );

  /// フレーム一覧（PC/DeXモード）。タイムラインの一覧と同じ部品を、
  /// 画面の下の段にパネルの面で置く。
  Widget _buildPcFrameStrip() {
    final colors = PcWorkspaceColors.of(context);
    return Material(
      key: const ValueKey('pcFrameStrip'),
      color: colors.pane,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.divider)),
        ),
        child: _buildFrameStrip(),
      ),
    );
  }

  /// ステータスバー：ツール・レイヤー・フレーム・キャンバスの大きさ・
  /// 表示の倍率と回転。
  Widget _buildPcStatusBar(Project project) {
    final l10n = AppLocalizations.of(context)!;
    final projects = context.watch<ProjectService>();
    final total = projects.frameCount(widget.projectId, _currentSceneId);
    final layer = projects
        .layersOf(widget.projectId, _currentSceneId, _currentFrame)
        .where((l) => l.id == _currentLayerId)
        .firstOrNull;
    final brush = context.watch<BrushService>().currentBrush;
    return PcStatusBar(
      key: const ValueKey('pcStatusBar'),
      items: [
        PcStatusItem(
          icon: _toolIcon(_currentTool),
          text: _toolStatusLabel(l10n, brush?.name),
        ),
        PcStatusItem(icon: Icons.layers_outlined, text: layer?.name ?? '-'),
        PcStatusItem(
          icon: Icons.movie_outlined,
          text: l10n.pcStatusFrame(_currentFrame + 1, total),
        ),
      ],
      trailing: [
        PcStatusItem(
          icon: Icons.aspect_ratio,
          text: '${project.drawingWidth}×${project.drawingHeight}px',
        ),
        ValueListenableBuilder<CanvasViewInfo>(
          valueListenable: _viewInfo,
          builder: (context, info, _) {
            final zoom = '${(info.zoom * 100).round()}%';
            final rotation = info.rotationDeg.round();
            return PcStatusItem(
              key: const ValueKey('pcStatusZoom'),
              icon: Icons.zoom_in,
              text: rotation == 0 ? zoom : '$zoom  $rotation°',
            );
          },
        ),
      ],
    );
  }

  /// PC/DeXモードの左右のドックの幅。保存した幅（ドラッグ中はその値）を
  /// 使うが、窓が狭くてキャンバスに[_minCanvasWidth]を残せないときは、
  /// 2つのドックを同じ割合で、パネルが崩れない下限
  /// （[SettingsService.minDesktopToolPanelWidth]・
  /// [SettingsService.minDesktopPanelWidth]）まで狭める
  /// （保存した幅のまま並べると、窓を狭めたときキャンバスが細い帯になり、
  /// さらに狭めると行がはみ出してキャンバスが消えた）。それでも入らない
  /// ほど狭い窓では、残りをキャンバスへ回す。`toolMax`・`rightMax`は
  /// ドラッグで広げられる上限。
  ({double tool, double right, double toolMax, double rightMax}) _fitDockWidths(
    BuildContext context, {
    required bool isDesktop,
    required bool toolDockOpen,
    required bool rightDockOpen,
  }) {
    final settings = context.watch<SettingsService>();
    const toolMin = SettingsService.minDesktopToolPanelWidth;
    const rightMin = SettingsService.minDesktopPanelWidth;
    const widest = SettingsService.maxDesktopPanelWidth;
    // 以前の版で下限より狭く保存した幅も、下限まで広げて使う。
    var tool = toolDockOpen
        ? (_toolPanelWidthDragOverride ?? settings.desktopToolPanelWidth).clamp(
            toolMin,
            widest,
          )
        : 0.0;
    var right = rightDockOpen
        ? (_panelWidthDragOverride ?? settings.desktopPanelWidth).clamp(
            rightMin,
            widest,
          )
        : 0.0;
    final rowWidth =
        MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal;
    // ツールパレット（ボタン1つ分＋左右の線）とドックのつまみ。
    final palette =
        40 *
            SettingsService.toolbarIconScaleForLevel(
              settings.toolbarSizeLevel,
            ) +
        2;
    final fixed =
        (isDesktop ? palette : 0.0) +
        (toolDockOpen ? PcDockSplitter.width : 0.0) +
        (rightDockOpen ? PcDockSplitter.width : 0.0);
    final budget = rowWidth - fixed - _minCanvasWidth;
    final wanted = tool + right;
    if (wanted > 0 && wanted > budget) {
      final scale = budget > 0 ? budget / wanted : 0.0;
      if (toolDockOpen) {
        tool = (tool * scale).clamp(toolMin, tool);
      }
      if (rightDockOpen) {
        // 片方が下限で止まった分は、もう片方を狭めて合わせる。
        right = (budget - tool).clamp(rightMin, right);
      }
      if (toolDockOpen) {
        tool = (budget - right).clamp(toolMin, tool);
      }
    }
    return (
      tool: tool,
      right: right,
      toolMax: (budget - right).clamp(toolMin, widest),
      rightMax: (budget - tool).clamp(rightMin, widest),
    );
  }

  /// PC/DeXモードでドックを開いても、キャンバスに残す幅。
  static const double _minCanvasWidth = 240;

  /// 常設ツールバー本体。[vertical]がtrueの場合は縦一列、falseの場合は
  /// 画面下部の横並びバーとして表示する。[pcPalette]はPC/DeXモードの
  /// ツールパレット（パネルの開閉はドックのタブで行う）。
  Widget _buildToolbarWidget({
    required bool vertical,
    bool pcPalette = false,
  }) => ToolbarWidget(
    vertical: vertical,
    pcPalette: pcPalette,
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
    onColorTap: pcPalette
        ? () => _togglePcTab(CanvasDockPanel.colorPicker)
        : () => setState(() {
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
    onPenLongPress: pcPalette
        ? () => _togglePcTab(CanvasDockPanel.penSubTool)
        : () => setState(() {
            final next = !_showPenSubToolPanel;
            _closeAllOverlayPanels();
            _showPenSubToolPanel = next;
          }),
    onFingerLongPress: () => _showFingerSubMenu(context),
    onTextTap: () => setState(() => _currentTool = DrawingTool.text),
    onShapeTap: () => _showShapeMenu(context),
    onQuickToolTap: _applyNextQuickTool,
    onQuickToolLongPress: pcPalette
        ? () => _togglePcTab(CanvasDockPanel.quickTool)
        : () => setState(() {
            final next = !_showQuickToolPanel;
            _closeAllOverlayPanels();
            _showQuickToolPanel = next;
          }),
    // 手動保存（セーブツリー）：「キャンバス → 保存 → キャンバスへ戻る」
    onSaveTap: () => _runAutomationBlockedAction(
      () => context.push('/save-tree/${widget.projectId}'),
    ),
    // 投げ縄塗り：ペンのサブツールではなくバケツ長押しメニューから
    // 選べるようにする（投げ縄で囲った範囲を塗る点でバケツ塗りに
    // 近いため）。
    onLassoFillSelected: () => setState(() {
      _currentSubTool = PenSubTool.lassoFill;
      _currentTool = DrawingTool.lasso;
    }),
    // 定規ボタン（キャンバス上部バーからツールバー内へ移設）。
    onRulerTap: _toggleRuler,
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
    // カラーピッカー内のスポイトボタン：スポイトツールへ切り替えて
    // キャンバス上の色を取得できるようにする
    onEyedropperTap: () => setState(() {
      _currentTool = DrawingTool.eyedropper;
      // PC/DeXモードのドックはキャンバスを隠さないので開いたままにする。
      if (!isWideScreen(context, listen: false)) _showColorPicker = false;
    }),
  );

  Widget _brushPanel() => BrushPanel(
    onClose: () => setState(() => _showBrushPanel = false),
    onEyedropOutlineColor: _startBrushOutlineEyedropper,
  );

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
    // フル機能管理パネル（フォルダ・自作・検索・読み込み書き出し）
    // PC/DeXモードではペンサブツールのタブを残したまま、管理パネルの
    // タブを隣に開いて前に出す。
    onManage: (subTool) => setState(() {
      final wide = isWideScreen(context, listen: false);
      if (!wide) _showPenSubToolPanel = false;
      final panel = switch (subTool) {
        PenSubTool.brush => CanvasDockPanel.brush,
        PenSubTool.tone => CanvasDockPanel.tone,
        PenSubTool.stamp => CanvasDockPanel.stamp,
        PenSubTool.lassoFill => null,
      };
      if (panel == null) return;
      _setDockPanelOpen(panel, true);
      if (wide) _focusPcTab(panel.name);
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

  /// CanvasArea側のハンドルドラッグによるライブ更新・Undo/Redoの巻き戻し反映用。
  /// ドラッグ確定時のUndo登録自体はcanvas_area.dart側（_handleRulerUp）が
  /// 1回だけ行うため、ここでは単純にstateを反映するのみでUndoは登録しない
  /// （毎フレーム登録するとUndoスタックが埋まってしまうため）。
  void _setActiveRulerLive(Ruler? r) {
    setState(() => _activeRuler = r);
  }

  /// 定規パネルからの選択・削除など、1回で完結する変更をUndoへ登録しつつ反映する
  /// （Undo通常対応）。
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

  /// Whether the filter panel is working on the canvas — always, while it is
  /// open: the canvas shows the filter's preview, and a touch there moves
  /// the filter's handles (sphere shading's light, the fisheye's centre) or
  /// picks a colour. Touches must reach the canvas, so the barrier that
  /// closes panels on a tap outside them is left out (on phones the panel
  /// is a bar under the canvas with its own close button).
  bool _filterPanelUsesCanvas() => _showFilterPanel;

  /// Undo from the keyboard or a two-finger tap: while a filter is being
  /// adjusted it takes back the filter's last edit (the canvas's own history
  /// is left alone until the filter is applied or closed).
  void _undo() {
    final filters = context.read<FilterService>();
    if (_showFilterPanel && filters.currentFilter != null) {
      filters.undoFilterEdit();
    } else {
      context.read<UndoManager>().undo();
    }
  }

  void _redo() {
    final filters = context.read<FilterService>();
    if (_showFilterPanel && filters.currentFilter != null) {
      filters.redoFilterEdit();
    } else {
      context.read<UndoManager>().redo();
    }
  }

  /// Whether the filter's UI has the screen, so the selection's own editing
  /// UI (its tool bar, transform sliders, handles on the canvas and the
  /// invert button) steps aside: on a phone while the filter panel is open
  /// (it runs along the bottom), on a wide screen while a filter is being
  /// adjusted in the docked panel. Both are never shown together; applying,
  /// cancelling or closing the filter brings the selection's UI back, with
  /// the selection as it was. Touches on the canvas then only reach the
  /// filter's handles.
  bool _selectionEditingGivesWay(bool isDesktop) =>
      _showFilterPanel &&
      (!isDesktop || context.watch<FilterService>().currentFilter != null);

  /// The filter's preview to show on the canvas in place of the current
  /// layer, while a filter is being adjusted.
  ui.Image? _filterCanvasPreviewShown() {
    final filter = context.watch<FilterService>().currentFilter;
    if (!_showFilterPanel || filter == null) return null;
    return _filterCanvasPreview;
  }

  /// Prism's result goes on in Linear Dodge (the layer is switched to it
  /// when applied), so its preview is drawn that way too.
  model.LayerBlendMode? _filterCanvasPreviewBlendMode() =>
      context.watch<FilterService>().currentFilter?.kind == FilterKind.prism
      ? model.LayerBlendMode.linearDodge
      : null;

  void _setFilterCanvasPreview(ui.Image? image) {
    if (!mounted) {
      image?.dispose();
      return;
    }
    setState(() {
      _filterCanvasPreview?.dispose();
      _filterCanvasPreview = image;
    });
  }

  /// What the filter being edited shows on the canvas to drag (sphere
  /// shading's light, the fisheye's centre), while the filter panel is open.
  FilterCanvasGizmo? _filterCanvasGizmo(Project? project) {
    final filter = context.watch<FilterService>().currentFilter;
    if (!_showFilterPanel || filter == null || project == null) return null;
    return filterCanvasGizmoFor(
      filter,
      project.drawingWidth,
      project.drawingHeight,
    );
  }

  /// The glasses filter's lens area, while that filter is adjusted.
  FilterLensMask? _filterLensMaskShown() {
    final filter = context.watch<FilterService>().currentFilter;
    if (!_showFilterPanel || filter?.kind != FilterKind.lensDistortion) {
      return null;
    }
    return _filterLensMask;
  }

  /// A stroke or fill on the canvas finished: the new lens area, one step
  /// of the filter's Undo.
  void _editFilterLensMask(Uint8List coverage) {
    final tm = context.read<ProjectService>().tileManagerOf(widget.projectId);
    _filterLensMask.edit(
      coverage,
      tm.canvasWidth,
      tm.canvasHeight,
      context.read<FilterService>().recordFilterEdit,
    );
  }

  void _moveFilterGizmo(Project? project, FilterCanvasGizmo gizmo) {
    final service = context.read<FilterService>();
    final filter = service.currentFilter;
    if (filter == null || project == null) return;
    service.moveCanvasGizmo(
      filter.id,
      gizmo,
      project.drawingWidth,
      project.drawingHeight,
    );
  }

  Widget _filterPanel({bool bottomBar = false}) => FilterPanel(
    projectId: widget.projectId,
    sceneId: _currentSceneId,
    layerId: _currentLayerId,
    frameIndex: _currentFrame,
    bulkFrameIndices: _filterBulkFrames,
    activeCanvasEyedropperTarget: _filterColorEyedropperTarget,
    onStartCanvasEyedropper: _toggleFilterColorEyedropper,
    bottomBar: bottomBar,
    onCanvasPreviewChanged: _setFilterCanvasPreview,
    selectionMask: _canvasSelectionMask,
    lensMask: _filterLensMask,
    onClose: () => setState(() {
      _filterLensMask.reset();
      _filterCanvasPreview?.dispose();
      _filterCanvasPreview = null;
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

  /// レイヤー全体の自由変形・メッシュ変形パネル。
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

  /// 色調調整パネル。
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

  /// フローティングパネルの左右配置ヘルパー。[anchorLeft]は通常（右利き）モードでの
  /// 配置側。左利きモード時は[leftHanded]により全パネルをまとめて左右反転する
  /// （描画する手の側にパネルが重ならないようにする）。
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

  /// プロジェクトの背景色（Project.backgroundColor。キャンバス表示だけで
  /// なく書き出し結果にも反映される）を、新規プロジェクト作成画面と
  /// まったく同じ選択肢から変更する。選択肢とスウォッチの見た目は
  /// [BackgroundColorSwatchPicker]（新規プロジェクト作成画面と共用）に
  /// 集約しており、片方だけ選択肢が増減する事故を防いでいる。
  ///
  /// なお「背景切替」（_toggleBackground）は表示専用の白⟷透過チェッカー
  /// 切替であり、こちらとは別物。
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

  /// ツール早替えボタンタップ時：登録順に次のツールへ切り替える。
  void _applyNextQuickTool() {
    final entry = context.read<QuickToolService>().next();
    if (entry == null) return;
    _activateToolSelection(
      toolKey: entry.toolKey,
      brushId: entry.brushId,
      sizeOverride: entry.sizeOverride,
    );
  }

  /// ツール＋ブラシ＋太さを一括で切り替える。早替えツール・ショートカット
  /// （キーボード・左手デバイス）のどちらから起動しても同じ挙動になるよう
  /// 共通化している。
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

  /// レイヤーパネルを開いた上でレイヤー全選択を起動する（Ctrl+A）。
  /// パネルが既に開いている場合はその場で全選択される。閉じていた場合は
  /// このタップで開くのみで、全選択はもう一度Ctrl+Aを押した時点で働く
  /// （LayerPanel初回表示時点ではdidUpdateWidgetが発火しないため）。
  void _selectAllLayers() => setState(() {
    _showLayerPanel = true;
    _layerSelectAllToken++;
  });

  /// 現在アクティブなレイヤーをコピー（Ctrl+C）。2本指上スワイプと
  /// 同じスナップショット式クリップボードを使うため、フレーム移動後も貼れる。
  void _copyActiveLayer() {
    final layerId = _currentLayerId;
    if (layerId == null) return;
    LayerClipboardService.instance.copy(
      projectService: context.read<ProjectService>(),
      projectId: widget.projectId,
      sceneId: _currentSceneId,
      frameIndex: _currentFrame,
      layerId: layerId,
    );
  }

  /// Ctrl+Vは現在アクティブなレイヤーの直前へ割り込み挿入する。
  /// 2本指下スワイプと同じく既存レイヤーを上書きしない。
  void _pasteCopiedLayer() {
    final targetId = _currentLayerId;
    if (targetId == null) return;
    final copy = LayerClipboardService.instance.pasteBefore(
      projectService: context.read<ProjectService>(),
      projectId: widget.projectId,
      targetSceneId: _currentSceneId,
      targetFrameIndex: _currentFrame,
      beforeLayerId: targetId,
    );
    if (copy == null) return;
    setState(() => _currentLayerId = copy.id);
  }

  void _toggleLayerPanel() => setState(() {
    final next = !_showLayerPanel;
    _closeAllOverlayPanels();
    _showLayerPanel = next;
  });

  /// 設定画面「ショートカット設定」の割り当て一覧から、キャンバスモードで
  /// 有効なキー割り当てのマップを組み立てる。ツール選択の割り当ては
  /// [_activateToolSelection]、主要操作は対応する処理へ振り分ける
  /// （タイムライン専用の操作はキャンバスモードでは無視する）。
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
          result[b.activator] = _undo;
        case ShortcutCommand.redo:
          result[b.activator] = _redo;
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
          // 切り取りは対応する貼り付け先（別フレーム等）の設計が
          // 未確定のため、キャンバスモードでは未割り当てのままにする。
          // タイムライン専用の操作、または未割り当ても同様。
          break;
      }
    }
    return result;
  }

  /// ジェスチャー／ペンボタンからのトグル切替（消しゴム切替・ブラシ切替・
  /// 手のひらツール）。既にそのツールならトグル前のツールへ戻す。
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

  /// 上部バー常設ボタン共通のスタイル（toolbar_widget.dartの
  /// _borderedIconButtonと同じ考え方）：背景なし・アイコンだけが浮かび、
  /// アイコンの形にぴったり沿う半透明の黒い縁取りを持つ（実装は
  /// CanvasIconButtonへ集約）。
  static Widget _topBarIconButton(
    BuildContext context,
    IconData icon, {
    required VoidCallback? onPressed,
    required String tooltip,
    bool selected = false,
    double iconSize = 20,
  }) {
    return CanvasIconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      selected: selected,
      iconSize: iconSize,
    );
  }

  /// 選択ツール使用中にキャンバス左下へ固定で出す操作バー。
  ///
  /// 1段目：自由変形／メッシュ変形／変更キャンセル
  /// 2段目：全選択／全解除
  ///
  /// 移動・拡大縮小・回転はここには**入れない**。選択範囲そのものに出る
  /// ハンドル（四隅＝拡大縮小、中央＝移動の十字矢印、右上＝回転のカーブ矢印）と、
  /// 画面下部のスライダーで行う。ボタンでモードを選ばせる方式をやめたのは、
  /// 「いま何のモードか」を覚えておく必要があり、掴む場所と一致しないため。
  ///
  /// このバーが出ている間はツールバーとフレーム一覧を畳むので、選択ツールから
  /// 抜ける導線としてバー自身に終了ボタン（×）を持たせている
  /// （これが無いとツールを切り替えられなくなる）。
  Widget _selectionToolBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsService>();
    final scheme = Theme.of(context).colorScheme;

    // 1段目・2段目とも同じ形・同じ大きさのボタンを3つずつ並べる。
    // 役割の違いは色で示す（既定＝地色、強調＝差し色、無効＝薄く）。
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
                // 自由変形とメッシュ変形は同じ仕組みの分割数違い
                // （4隅だけか、格子状に細かく分けるか）。
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
                // 変形を取り消して選択ツールごと抜ける。アイコンは、
                // 隣の「適用」がチェックなのと対になるよう×にしている。
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
                SegmentedButton<bool>(
                  key: const ValueKey('selection-reference-source'),
                  segments: [
                    ButtonSegment<bool>(
                      value: false,
                      icon: const Icon(Icons.layers_outlined, size: 14),
                      label: Text(
                        l10n.canvasSelectionReferenceWorkingLayer,
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: const Icon(Icons.layers, size: 14),
                      label: Text(
                        l10n.canvasSelectionReferenceVisibleLayers,
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                  selected: {settings.selectionReferenceAllVisible},
                  onSelectionChanged: (value) =>
                      settings.setSelectionReferenceAllVisible(value.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                if (_currentTool == DrawingTool.selectLasso)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        key: const ValueKey('lasso-snap-to-lines'),
                        onTap: () => settings.setLassoSnapToLines(
                          !settings.lassoSnapToLines,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: settings.lassoSnapToLines,
                                onChanged: (value) => settings
                                    .setLassoSnapToLines(value ?? false),
                                visualDensity: VisualDensity.compact,
                              ),
                              Text(
                                l10n.canvasLassoSnapToLines,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 1行目に項目名と値、2行目にスライダーだけを置き、
                      // スライダーを横幅いっぱいに広げる。幅の上限は「線に
                      // 吸着」を切っているときの2段目（参照レイヤーの切替＋
                      // チェックボックス）と同じくらいにし、バーがキャンバスへ
                      // 広がりすぎないようにする。
                      if (settings.lassoSnapToLines)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 288),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, right: 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          l10n.canvasLassoGapTolerance,
                                          style: const TextStyle(fontSize: 9),
                                        ),
                                      ),
                                      EditableSliderValue(
                                        text: '${settings.lassoGapTolerancePx}',
                                        style: const TextStyle(fontSize: 9),
                                        value: settings.lassoGapTolerancePx
                                            .toDouble(),
                                        min: 0,
                                        max: 12,
                                        title: l10n.canvasLassoGapTolerance,
                                        onChanged: (value) =>
                                            settings.setLassoGapTolerancePx(
                                              value.round(),
                                            ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'px',
                                        style: TextStyle(fontSize: 9),
                                      ),
                                    ],
                                  ),
                                ),
                                SteppedSlider(
                                  key: const ValueKey('lasso-gap-tolerance'),
                                  value: settings.lassoGapTolerancePx
                                      .toDouble(),
                                  min: 0,
                                  max: 12,
                                  divisions: 12,
                                  showSteppers: false,
                                  compact: true,
                                  onChanged: (value) => settings
                                      .setLassoGapTolerancePx(value.round()),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 4),
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
                // 変形をそのまま確定して選択ツールごと抜ける。
                // 変形は操作のたびに実画素へ焼かれているので、ここでは
                // 選択範囲を解除してツールを戻すだけでよい。
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

  /// 自由変形・メッシュ変形の実行中にキャンバス左下へ固定で出すキャンセル
  /// ボタン。仕様上、この2モードではこれ以外の変形用メニューは出さない
  /// （メッシュ変形のときだけ、画面下部に分割数のスライダーが付く）。
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
            // 適用の導線。この2モード中はツールバーを畳んでいるため、
            // 確定して抜ける手段をここに置かないと戻れなくなる。
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

  /// 「変形キャンセル（終了）」：いまの選択範囲へ加えた変形をまとめて
  /// 元へ戻したうえで、選択ツールごと抜ける。
  void _cancelSelectionTransformAndExit() {
    _revertSelectionTransforms();
    _exitSelectionTool();
  }

  /// いまの選択範囲へ加えた変形を、加えた回数ぶんまとめて元へ戻す
  /// （変形1回＝Undo履歴1件で積まれている）。
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

  /// 移動量スライダーの端の値。キャンバスの短辺の半分まで動かせるようにする。
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

  /// メッシュ変形中に画面下部へ出す分割数スライダー。
  Widget _meshDensitySlider(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return LabeledSlider(
      label: l10n.meshTransformDensityLabel,
      value: _meshDensity.toDouble(),
      min: 1,
      max: 10,
      divisions: 9,
      editable: false,
      valueText: '$_meshDensity×$_meshDensity',
      labelStyle: TextStyle(fontSize: 11, color: scheme.onSurface),
      valueStyle: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      onChanged: (v) => setState(() => _meshDensity = v.round()),
    );
  }

  void _resetSelectionSliders() {
    _selectionMoveX = 0;
    _selectionMoveY = 0;
    _selectionScale = 1;
    _selectionRotateDeg = 0;
  }

  /// 選択ツールを抜けてペンへ戻す（左下バーの終了ボタン）。
  /// 選択範囲は残したままだと他ツールの操作範囲を絞ったままになるため解除する。
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
          // プロジェクト一覧へ戻るボタンはタイムラインモード側へ移した。
          // キャンバスモードの画面左上（元は戻るボタンの
          // 位置）にはUndo/Redoを配置する。
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
          // 投げ縄塗り選択中：囲って塗るモードスイッチ
          if (_currentTool == DrawingTool.lasso &&
              _currentSubTool == PenSubTool.lassoFill) ...[
            const SizedBox(width: 8),
            Text(
              l10n.canvasLassoEnclosedLabel,
              style: TextStyle(
                fontSize: 12,
                shadows: CanvasIconButton.foregroundShadows(
                  Theme.of(context).colorScheme.onSurface,
                  Theme.of(context).colorScheme,
                ),
              ),
            ),
            Switch(
              value: _lassoFillEnclosedMode,
              onChanged: (v) => setState(() => _lassoFillEnclosedMode = v),
            ),
          ],
          // 範囲選択中にのみ使える「選択範囲を反転」ボタン。
          if (_isSelectionToolActive &&
              _hasActiveSelection &&
              !_selectionEditingGivesWay(isWideScreen(context))) ...[
            const SizedBox(width: 8),
            _topBarIconButton(
              context,
              Icons.invert_colors_outlined,
              onPressed: () => setState(() => _invertSelectionToken++),
              tooltip: l10n.canvasInvertSelectionTooltip,
            ),
          ],
          // テキストツール選択中：キャンバスタップでテキスト入力ダイアログを表示する旨を示すラベル
          if (_currentTool == DrawingTool.text)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                l10n.canvasTapToEnterTextLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  shadows: CanvasIconButton.foregroundShadows(
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme,
                  ),
                ),
              ),
            ),
          const Spacer(),
          // 設定/編集メニュー（背景色・オニオンスキン・
          // フィルター・フレーム範囲選択を集約）。
          _topBarIconButton(
            context,
            Icons.settings,
            onPressed: () => _showEditMenu(context),
            tooltip: l10n.canvasSettingsMenuTooltip,
          ),
          // 定規・ヘルプはツールバー内へ移設したため、この右上には
          // プロジェクト一覧へ戻るホームボタンを設置する
          // （タイムライン画面の同ボタンと同じ挙動：保存して戻る／
          // 保存せず戻るを選べる確認ダイアログを経由する）。
          _topBarIconButton(
            context,
            Icons.home_outlined,
            iconSize: 21,
            onPressed: _confirmBackToProjectList,
            tooltip: l10n.timelineBackToProjectListTooltip,
          ),
          // Direction cue beside the timeline symbol, sharing one hit target.
          // CanvasIconButton keeps both glyphs transparent and theme-colored.
          CanvasIconButton(
            key: const Key('canvasTimelineModeButton'),
            iconSize: 24,
            iconBuilder: (color) => FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.movie_filter_outlined, size: 19, color: color),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward, size: 14, color: color),
                ],
              ),
            ),
            onPressed: () => _runAutomationBlockedAction(
              () => context.go('/timeline/${widget.projectId}'),
            ),
            tooltip: l10n.canvasTimelineModeTooltip,
          ),
        ],
      ),
    );
  }

  /// プロジェクト一覧へ戻るボタン：タップ時に「保存して戻る」か
  /// 「保存せず戻る」かをポップアップで選べるようにする
  /// （timeline_screen.dartの同名メソッドと同じ挙動）。
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
      // 「保存して戻る」は、キャンバス画面の「保存」ボタンと同じ
      // セーブツリー画面（手動セーブ）を経由させる。
      final saves = context.read<SaveTreeService>();
      final before = saves.latestSaveOf(widget.projectId);
      await context.push('/save-tree/${widget.projectId}');
      if (!mounted) return;
      // 保存せずに戻った（取り消した・保存に失敗した）ときは一覧へ移らず、
      // キャンバスに残る。
      if (saves.latestSaveOf(widget.projectId) == before) return;
    }
    if (mounted) context.go('/home');
  }

  /// フレーム複数選択モード時のアクションバー（大量処理実行時の
  /// フィルター一括適用）。全選択・全解除・フィルター一括適用・キャンセルを提供する。
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

  /// 指ツール長押し時のサブツールメニュー（歪み／ガウスぼかし／モザイク）
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

  /// 図形ツールタップ時のポップアップ（OFF/線/四角形/円）
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

  /// テキストツール選択中にキャンバスタップで呼び出す。
  /// テキスト入力ダイアログを表示し、OK時にテキストレイヤーを自動生成する。
  void onCanvasTapForText(Offset position) {
    if (_currentTool != DrawingTool.text) return;
    _showTextInputDialog(position);
  }

  /// レイヤーパネルからテキストレイヤーをタップした時に呼び出す編集入口
  /// （既存テキストをタップすると編集開始。本実装ではレイヤー
  /// パネル経由とする。キャンバス上でのテキストボックス当たり判定による
  /// 直接タップ編集は対象外）。
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
            // スライダーを画面の横幅いっぱいに使えるよう、ダイアログを
            // 既定（左右40px空け、内容が狭ければ幅280）より広く取る。
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            title: Text(
              existingLayerId == null
                  ? l10n.canvasTextInputTitle
                  : l10n.canvasTextEditTitle,
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
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
                        // あらかじめ同梱しているフリーフォント（全てSIL Open Font
                        // License、Google Fonts配布分。ライセンス表記は設定画面
                        // 「利用規約・ライセンス」参照）
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
                    LabeledSlider(
                      label: l10n.brushSettingsSizeLabel,
                      value: fontSize,
                      min: 8,
                      max: 200,
                      sliderLabel: fontSize.round().toString(),
                      valueText: '${fontSize.round()}',
                      onChanged: (v) => setS(() => fontSize = v),
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
                        // 縦書き・横書きのワンタップ切替
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
                        // ルビ・縦中横・半角英数字回転の説明（ルビは縦書き・
                        // 横書きどちらでも使えるため、書字方向によらず常に表示する）
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
                    LabeledSlider(
                      label: l10n.canvasTextLineHeight,
                      value: lineHeight,
                      min: 0.8,
                      max: 3.0,
                      step: 0.1,
                      isInt: false,
                      sliderLabel: lineHeight.toStringAsFixed(1),
                      valueText: lineHeight.toStringAsFixed(1),
                      onChanged: (v) => setS(() => lineHeight = v),
                    ),
                    LabeledSlider(
                      label: l10n.canvasTextLetterSpacing,
                      value: letterSpacing,
                      min: -2,
                      max: 20,
                      sliderLabel: letterSpacing.toStringAsFixed(0),
                      valueText: letterSpacing.toStringAsFixed(0),
                      onChanged: (v) => setS(() => letterSpacing = v),
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
                      LabeledSlider(
                        label: l10n.canvasOutlineWidthLabel,
                        value: outlineWidth,
                        min: 0,
                        max: 20,
                        sliderLabel: outlineWidth.round().toString(),
                        valueText: '${outlineWidth.round()}',
                        onChanged: (v) => setS(() => outlineWidth = v),
                      ),
                    ],
                  ],
                ),
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

  /// 組版・ルビに関する説明（半角英数字の回転・縦中横・ルビ）。
  void _showVerticalTextHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // popup-standard-close: タイトル行の右端へ寄せた閉じるボタン。
        // AlertDialogの`icon:`スロットへ入れると、Flutterが
        // タイトルを強制的に中央寄せにするため（dialog.dartの
        // `textAlign: icon == null ? TextAlign.start : TextAlign.center`）、
        // 他のダイアログと不揃いになる。タイトル行へ直接置くこと。
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

enum _TextColorEyedropperTarget { body, outline }

enum DrawingTool {
  pen,
  eraser,
  bucket,
  lasso,
  eyedropper,
  finger,
  // 指ツールのサブツール：ガウスぼかし・モザイク。
  // 指ツールボタンの長押しメニューから切り替える。
  blur,
  mosaic,
  selectRect,
  selectLasso,
  selectMagicWand,
  move,
  ruler,
  text,
  shape,
  // 手のひらツール：ジェスチャー／ペンボタンからのみ到達する一時ツール。
  // ツールバーには表示せず、描画を行わずキャンバスの平行移動のみを行う。
  pan,
  // レイヤー全体の自由変形・メッシュ変形：範囲選択せずに現在レイヤー全体を
  // 変形できる（格子点を個別にドラッグする自由変形・メッシュ変形）。
  // 選択ツールの移動・拡大縮小・回転が一体変形なのに対し、こちらは各点を
  // 個別に動かせる点が異なる。キャンバス上部バーの「設定/編集」メニューと
  // 選択ツールの操作バーから到達する一時ツール。
  meshTransform,
}

/// 図形ツールの種別（タップでポップアップ表示・OFF/線/四角形/円）
enum ShapeKind { off, line, rect, circle }
