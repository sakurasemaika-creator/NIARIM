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
  // ジェスチャー／ペンボタンでの消しゴム切替・ブラシ切替・手のひらツール
  // トグル用に、切替前のツールを一時的に覚えておく。
  DrawingTool? _toolBeforeGestureToggle;
  PenSubTool _currentSubTool = PenSubTool.brush;
  double _brushSize = 5;
  int _brushOpacity = 100;
  Color _currentColor = Colors.black;
  int _currentFrame = 0;
  bool _showLayerPanel = false;
  // ショートカット（Ctrl+A）からレイヤーパネルの全選択を起動するための
  // トークン。値を増やすたびにLayerPanel側で全選択が実行される。
  int _layerSelectAllToken = 0;
  // ショートカット（Ctrl+C/Ctrl+V）で現在アクティブなレイヤーを
  // コピー＆ペーストするための、セッション内のみのクリップボード。
  String? _copiedLayerId;
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
  _TextColorEyedropperTarget? _textColorEyedropperTarget;
  ValueChanged<Color>? _pendingTextColorEyedropper;

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
    // PC/DeXモード（広い画面）：レイヤーパネルをフローティング表示ではなく、
    // 常時表示のドッキングパネルとして右側に固定する（プロ向けレイアウト）。
    // サブツール系パネル（ブラシ・トーン・スタンプ等）もPC版では互いに
    // 排他にせず、開いているものをすべて縦に積んで同時表示する。
    final isDesktop = isWideScreen(context);
    final openToolPanels = isDesktop
        ? _openToolOptionPanels()
        : const <Widget>[];
    // 左利きモード：フローティング／ドッキングパネルを左右反転し、
    // 描画する手の側にパネルが重ならないようにする。
    final leftHanded = context.watch<SettingsService>().isLeftHanded;

    // DeXモード・マウス/キーボード入力・左手デバイス：設定画面
    // 「ショートカット設定」で割り当てたキーで、ツール切替やUndo/Redo
    // などの主要操作を行えるようにする。
    return CallbackShortcuts(
      bindings: _buildShortcutBindings(context),
      child: Focus(
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
            // ツールオプション系のフローティングパネル（ブラシ・トーン・
            // スタンプ・ペンサブツール・オニオンスキン・定規・フィルター・
            // 早替え設定）は、画面全体を覆うこの一番外側のStackへ配置する
            // ことで、太さ／不透明度スライダーやツールバーなど他のUI要素の
            // 手前に必ず表示されるようにしている。パネルの外側をタップすると
            // 閉じられる。
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: Row(
                        children: [
                          // デスクトップでは常設ツールバーを画面下部の横並びバーではなく、
                          // 左側（左利きモード時は右側）の縦レールとして常時表示する。
                          if (isDesktop && !leftHanded)
                            _buildToolbarWidget(vertical: true),
                          // PC/DeXモード：ツールオプション系パネルはフローティングではなく
                          // キャンバス左側（左利きモード時は右側）の常時ドッキング領域
                          // として表示する（複数同時に開いていれば縦に積んで並べる）。
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
                                      // 選択範囲を作り直した／解除したら、
                                      // 「変更キャンセル」で戻せる範囲も
                                      // そこで区切る。
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
                                // ツールオプション系フローティングパネル（ブラシ・トーン・
                                // スタンプ・ペンサブツール・オニオンスキン・定規・
                                // フィルター・早替え設定・レイヤー）は画面全体を覆う
                                // 一番外側のStackへ移した（build()末尾を参照）。
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
                          // PC/DeXモード：カラーピッカー・レイヤーパネル・キャンバス
                          // プレビューは、ツールオプション系ドッキング領域（上の
                          // openToolPanels）とは別に、右側（左利きモード時は左側）へ
                          // 縦に並べて同時表示する。単独でも複数同時でも表示可。
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
                                // 左利きモードでは領域が左側にあるため、ハンドルを
                                // 左へ引くほど広がる（右側配置とドラッグ方向を反転）。
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
                    // ブラシサイズ／不透明度スライダーは、サイズ・不透明度が実際に
                    // 意味を持つツール使用中のみ表示する。バケツ・スポイト・選択系・
                    // 変形・テキスト・図形ツールではブラシ設定が描画結果に影響しない
                    // ため非表示にし、縦スペースをキャンバスへ還元する。
                    // 選択範囲があるときは、変形量を数値で指定するスライダーを
                    // 画面下部へ出す（ハンドルのドラッグと同じ操作を、
                    // 細かく指定したいとき用）。ブラシ設定スライダーは
                    // 選択ツール中は出ないので場所は競合しない。
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
                    // メッシュ変形中は分割数のスライダーだけを画面下部へ出す
                    // （自由変形＝分割数1のときは何も出さない）。
                    if (_currentTool == DrawingTool.meshTransform &&
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
                    // デスクトップでは左側（左利きモードでは右側）の常設縦レールとして
                    // 表示するため、下部の横並びバーはモバイルレイアウトのみで表示する。
                    if (_showToolbar && !isDesktop && !_isSelectionToolActive)
                      _buildToolbarWidget(vertical: false),
                    if (_frameMultiSelectMode) _buildFrameMultiSelectBar(),
                    // フレーム一覧の折りたたみ用ハンドル（描画領域を
                    // できるだけ広げるため、任意のタイミングで開閉できるようにする）。
                    // 高さ16→28px・アイコン16→22pxへ拡大（ツールバー折りたたみ
                    // ハンドルと同様、タップしやすさ改善のため）。
                    //
                    // 選択ツール使用中は、キャンバス左下の操作バーへ集中できるよう
                    // ツールバー・フレーム一覧ごと畳む（開閉ハンドルも隠す）。
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
                            // 色固定をやめ、テーマの文字色と連動させる（CanvasIconButton・
                            // ToolbarWidgetの色連動と同じ方針）。
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
                // パネル表示中は、パネル外をタップすると閉じられるようにする
                // 透明バリア（パネル本体より下、Columnより上に敷く）。
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
                // トーン・スタンプの全機能管理パネル
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
                // ペンサブツールパネル（ブラシ/トーン/スタンプ）
                if (_showPenSubToolPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: true,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _penSubToolPanel(),
                  ),
                // オニオンスキンパネル
                if (_showOnionSkinPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: false,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _onionSkinPanel(),
                  ),
                // 定規パネル
                if (_showRulerPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: true,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _rulerPanel(),
                  ),
                // フィルターパネル（描画フィルター）
                if (_showFilterPanel && !isDesktop)
                  _sidedPanel(
                    anchorLeft: false,
                    leftHanded: leftHanded,
                    top: 56,
                    bottom: null,
                    child: _filterPanel(),
                  ),
                // 早替えツール設定パネル
                if (_showQuickToolPanel && !isDesktop)
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
                if (_showColorAdjustPanel && !isDesktop)
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
                    onClose: () => setState(() => _showReferenceWindow = false),
                  ),
              ],
            ),
          ),
        ),
      ),
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

  // PC/DeXモード（広い画面）：現在開いているツールオプション系パネルを
  // すべて返す（互いに排他にせず開いているものを全部縦積みする）。左側の
  // 常時ドッキング領域に使う。フローティング表示（スマホ）と同じパネル
  // インスタンスを流用する。カラーピッカー・レイヤーパネルはここには
  // 含めない（右側ドックで独立に扱うため。build()内を参照）。
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
      // 自由変形・メッシュ変形パネルは並べ替えの対象外として常に末尾に置く
      // （キャンバス上の格子点操作と直接絡むため、常に単独で開く前提のパネル）。
      // デスクトップの縦レール側だけに出す（スマホ幅では左下のキャンセル／適用と
      // 画面下部の分割数スライダーで操作する）。
      if (_showMeshTransformPanel) _meshTransformPanel(),
    ];
    return panels;
  }

  /// 常設ツールバー本体。[vertical]がtrueの場合は左側（左利きモードでは
  /// 右側）の縦レールとして、falseの場合は画面下部の横並びバーとして
  /// 表示する。
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

  /// カラーピッカー・レイヤーパネル・キャンバスプレビューを、設定された
  /// 積み重ね順で縦に並べる。開いているものだけを表示し、隣接する2枚の
  /// 間に区切り線を入れる。
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

  /// 複数のドッキングパネルを縦に積んで表示する。開いているパネル数が
  /// 多く画面高さに収まらない場合はスクロールできるようにする。各パネル
  /// 間には視認しやすいよう余白を入れる。
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
    // カラーピッカー内のスポイトボタン：スポイトツールへ切り替えて
    // キャンバス上の色を取得できるようにする
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
    // フル機能管理パネル（フォルダ・自作・検索・読み込み書き出し）
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

  /// 現在アクティブなレイヤーをコピー（Ctrl+C）。
  void _copyActiveLayer() {
    if (_currentLayerId == null) return;
    setState(() => _copiedLayerId = _currentLayerId);
  }

  /// コピー済みのレイヤーを複製して貼り付ける（Ctrl+V）。ピクセル内容も
  /// 含めて元レイヤーのすぐ上に複製し、複製後のレイヤーをアクティブにする。
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
  }) {
    return CanvasIconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: tooltip,
      selected: selected,
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
              style: const TextStyle(fontSize: 12),
            ),
            Switch(
              value: _lassoFillEnclosedMode,
              onChanged: (v) => setState(() => _lassoFillEnclosedMode = v),
            ),
          ],
          // 範囲選択中にのみ使える「選択範囲を反転」ボタン。
          if (_isSelectionToolActive && _hasActiveSelection) ...[
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
            onPressed: _confirmBackToProjectList,
            tooltip: l10n.timelineBackToProjectListTooltip,
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
      await context.push('/save-tree/${widget.projectId}');
      if (!mounted) return;
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

/// ドッキングパネルとキャンバスの境界に置く、横方向ドラッグ専用の
/// リサイズハンドル。ドラッグ中は
/// [onDeltaX]で移動量（デバイス非依存の論理px）を都度通知し、指を離した
/// 時点で[onDragEnd]を呼んで確定値の永続化を行わせる。
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

/// 選択ツールで選択範囲を掴んだときの操作モード（移動・拡大縮小・回転）。
///
/// かつては独立した「変形ツール」（DrawingTool.transform）がレイヤー全体の
/// 一体変形を担っていたが、選択範囲の変形と役割が重複していたため統合した。
/// レイヤー全体を変形したい場合は「全選択」してから各モードを使う。
/// モードはキャンバス左下のボタンで明示的に切り替える（掴んだ位置から
/// 推測する方式は、ハンドルがドラッグ中しか描かれず発見できなかった）。
enum SelectionTransformMode { move, scale, rotate }

/// 図形ツールの種別（タップでポップアップ表示・OFF/線/四角形/円）
enum ShapeKind { off, line, rect, circle }
