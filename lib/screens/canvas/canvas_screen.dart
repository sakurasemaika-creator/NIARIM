import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
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
import '../../widgets/editable_slider_value.dart';
import '../../widgets/help_button.dart';
import '../../widgets/first_use_tooltip.dart';
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
import 'widgets/brush_size_slider.dart';
import 'widgets/layer_panel.dart';
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
  // トーン・スタンプの全機能管理パネル（仕様書17：フォルダ・自作・検索・
  // 読み込み書き出し）。ペンサブツールタブの「管理」ボタンから開く。
  bool _showTonePanel = false;
  bool _showStampPanel = false;
  bool _showPenSubToolPanel = false;
  bool _showOnionSkinPanel = false;
  bool _showRulerPanel = false;
  bool _showFilterPanel = false;
  bool _showQuickToolPanel = false;

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

  /// モバイルレイアウトのオーバーレイパネル（レイヤー・色・ブラシ・トーン・
  /// スタンプ・ペンサブツール・オニオンスキン・定規・フィルター・早替え
  /// ツール設定・自由変形/メッシュ変形）は、右側/左側に重なって同時表示
  /// されると片方が下敷きになり閉じるボタンを押せなくなる不具合があった
  /// （「レイヤーパネルが一度表示すると非表示に戻せない」の原因）。
  /// いずれかを開く前に必ずこれを呼び、常に高々1枚のみが表示された状態を保つ。
  void _closeAllOverlayPanels() {
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
    // 他のパネルを開く操作で自由変形/メッシュ変形パネルが押し出される場合は、
    // 未確定のワーププレビューを残さないようキャンセル扱いにする。
    if (_showMeshTransformPanel) {
      _showMeshTransformPanel = false;
      _meshCancelToken++;
      if (_currentTool == DrawingTool.meshTransform) _currentTool = DrawingTool.pen;
    }
  }

  /// 自由変形・メッシュ変形パネルを開く（キャンバス上部バーの「設定/編集」
  /// メニューから、仕様書28：既存の変形ツールと異なり範囲選択なしで
  /// レイヤー全体を対象にする）。開くたびに分割数・回転・拡大縮小の
  /// スライダー値を初期状態へ戻す。
  void _openMeshTransformPanel() => setState(() {
        _closeAllOverlayPanels();
        _showMeshTransformPanel = true;
        _meshDensity = 1;
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

  /// ブラシサイズ／不透明度が描画結果に影響するツールかどうか
  /// （仕様書02・タスク#96：描画エリア最大化のため、無関係なツール
  /// 使用中はブラシサイズスライダーを非表示にして縦スペースを還元する）。
  /// ペン・消しゴム・投げ縄塗り・指（ワープ）・定規（定規ガイド沿いの
  /// 描画にペンと同じブラシ設定を使う）が対象。
  bool _usesBrushSize(DrawingTool tool) => switch (tool) {
        DrawingTool.pen ||
        DrawingTool.eraser ||
        DrawingTool.lasso ||
        DrawingTool.finger ||
        DrawingTool.ruler =>
          true,
        _ => false,
      };

  /// 定規ボタン（仕様書08・タスク#95：下部ツールバーからキャンバス上部
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

  /// オニオンスキンパネルの開閉（仕様書08・タスク#95：キャンバス上部
  /// バーの「設定/編集」メニューへ集約）。
  void _toggleOnionSkinPanel() => setState(() {
        final next = !_showOnionSkinPanel;
        _closeAllOverlayPanels();
        _showOnionSkinPanel = next;
      });

  /// フィルターパネルの開閉（仕様書08・タスク#95：キャンバス上部バーの
  /// 「設定/編集」メニューへ集約）。
  void _toggleFilterPanel() => setState(() {
        final next = !_showFilterPanel;
        _closeAllOverlayPanels();
        _showFilterPanel = next;
      });

  /// 背景切替（白/プロジェクト背景色 ⟷ 透過、仕様書27・タスク#95：
  /// キャンバス上部バーの「設定/編集」メニューへ集約）。
  void _toggleBackground() => setState(() {
        _canvasBackground = _canvasBackground == CanvasBackground.white
            ? CanvasBackground.transparent
            : CanvasBackground.white;
      });

  /// フレーム複数選択モードの切替（仕様書18・タスク#95：キャンバス上部
  /// バーの「設定/編集」メニューへ集約。大量処理実行時のフィルター
  /// 一括適用などに使用）。
  void _toggleFrameMultiSelect() => setState(() {
        _frameMultiSelectMode = !_frameMultiSelectMode;
        _selectedFrameIndices = {};
      });

  /// 画面端ダブルタップでのフレーム送り（仕様書28：フレーム一覧の開閉
  /// 状態と無関係に常時使える操作）。範囲外へは移動しない。
  void _goToNextFrame() {
    final total = context.read<ProjectService>().frameCount(widget.projectId, _currentSceneId);
    if (_currentFrame + 1 >= total) return;
    setState(() => _currentFrame += 1);
  }

  void _goToPreviousFrame() {
    if (_currentFrame <= 0) return;
    setState(() => _currentFrame -= 1);
  }

  /// キャンバス上部バーの「設定/編集」メニュー（仕様書08・タスク#95：
  /// 背景色・オニオンスキン・フィルター・フレーム範囲選択を集約）。
  void _showEditMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_canvasBackground == CanvasBackground.white
                  ? Icons.check_box_outline_blank
                  : Icons.grid_4x4),
              title: Text(l10n.canvasEditMenuBackgroundToggle),
              subtitle: Text(_canvasBackground == CanvasBackground.white
                  ? l10n.canvasEditMenuBackgroundCurrentColor
                  : l10n.canvasEditMenuBackgroundCurrentTransparent),
              onTap: () {
                _toggleBackground();
                Navigator.pop(ctx);
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
              leading: const Icon(Icons.blur_on),
              title: Text(l10n.filterPanelTitle),
              subtitle: Text(l10n.canvasEditMenuFilterSubtitle),
              onTap: () {
                Navigator.pop(ctx);
                _toggleFilterPanel();
              },
            ),
            ListTile(
              leading: Icon(_frameMultiSelectMode ? Icons.checklist_rtl : Icons.checklist),
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
                context.push('/settings/pen');
              },
            ),
            // レイヤー全体の自由変形・メッシュ変形（仕様書28：新機能）。
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
          ],
        ),
      ),
    );
  }

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
  // フレーム一覧の折りたたみ状態（描画領域を広げるため
  // 任意のタイミングで開閉できるようにする）。
  bool _showFrameStrip = true;
  // ツールバーの折りたたみ状態（同上。スマホの小さな画面でも描画領域を
  // 最大限確保できるようにする）。
  bool _showToolbar = true;
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
    // 画面がごちゃごちゃしないよう、画面サイズによらずレイヤーパネルは
    // デフォルトで閉じた状態にする（以前はPC/DeXモードなど広い画面では
    // 自動的に開いていたが、ユーザーが開くボタンを押したときだけ表示する
    // 方針へ統一した）。
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
    // プロジェクトカードのサムネイルを編集終了時に更新する（仕様書19）。
    // 非同期処理だがdispose()自体は同期のままfire-and-forgetで発火する
    // （ProjectService内部状態のみを参照するため、Widget破棄後も安全）。
    context.read<ProjectService>().generateAndSaveThumbnail(widget.projectId);
    super.dispose();
  }

  /// クラッシュ・ファイル破損時の復元用：プロジェクトの最終保存より新しい
  /// 自動保存があれば、確認ダイアログを出さずそのまま自動的に復元して
  /// 再開する（仕様書「セーブ／自動保存の再設計」：プロジェクトを開いた際、
  /// 自動保存データがあれば最後の自動保存から自動的に復元する）。
  /// 自動保存は常に「その時点までの最新の編集内容」を表すため、これへ
  /// 揃えることでユーザーの作業を失うことはない（むしろ、以前のように
  /// ここで確認ダイアログを出して「無視」を選ばれてしまうと、その分の
  /// 編集内容が失われる方が問題だった）。
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
    final project = context.read<ProjectService>()
        .projects
        .where((p) => p.id == widget.projectId)
        .firstOrNull;
    if (project == null || !slot.savedAt.isAfter(project.updatedAt)) return;
    final data = await autosave.restore(widget.projectId, slot.slotIndex);
    if (data == null || !mounted) return;
    context.read<ProjectService>().restoreFromAutosave(widget.projectId, data);
  }

  /// 不足素材の検出（仕様書21）。プロジェクトを開いた際に参照先の素材ファイルが
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

    // DeXモード・マウス/キーボード入力（仕様書08）：Ctrl+Z/Ctrl+Y/Ctrl+Shift+Zで
    // Undo/Redoを行えるようにする。
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
            context.read<UndoManager>().undo(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
            context.read<UndoManager>().redo(),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): () =>
            context.read<UndoManager>().redo(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      body: SafeArea(
        // ツールオプション系のフローティングパネル（ブラシ・トーン・
        // スタンプ・ペンサブツール・オニオンスキン・定規・フィルター・
        // 早替え設定）は、画面全体を覆うこの一番外側のStackへ配置する
        // ことで、太さ／不透明度スライダーやツールバーなど他のUI要素の
        // 手前に必ず表示されるようにしている（以前はキャンバス領域内の
        // Stackに置いていたため、縦スペースが足りない場面で他の要素と
        // 重なって見えることがあった）。パネルの外側をタップすると
        // 閉じられる。
        child: Stack(
          children: [
            Column(
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
                    onRulerChanged: _setActiveRulerLive,
                    shapeKind: _shapeKind,
                    onGestureToolChange: (tool) => setState(() => _currentTool = tool),
                    onGestureToggleTool: _handleGestureToggleTool,
                    onNextQuickTool: _applyNextQuickTool,
                    onToggleOnionSkin: () => setState(() =>
                        _onionSkinSettings = _onionSkinSettings.copyWith(enabled: !_onionSkinSettings.enabled)),
                    meshDensity: _meshDensity,
                    meshRotateDeg: _meshRotateDeg,
                    meshScaleValue: _meshScaleValue,
                    meshCommitToken: _meshCommitToken,
                    meshCancelToken: _meshCancelToken,
                    onNextFrame: _goToNextFrame,
                    onPreviousFrame: _goToPreviousFrame,
                  ),
                  // ツールオプション系フローティングパネル（ブラシ・トーン・
                  // スタンプ・ペンサブツール・オニオンスキン・定規・
                  // フィルター・早替え設定・レイヤー）は画面全体を覆う
                  // 一番外側のStackへ移した（build()末尾を参照）。
                      ],
                    ),
                  ),
                  if (dockedToolPanel != null && leftHanded)
                    SizedBox(width: 280, child: dockedToolPanel),
                  if (isDesktop && _showLayerPanel)
                    SizedBox(
                      width: 280,
                      child: LayerPanel(
                        onClose: () => setState(() => _showLayerPanel = false),
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
            // ブラシサイズ／不透明度スライダーは、サイズ・不透明度が実際に
            // 意味を持つツール（仕様書02・タスク#96：描画エリア最大化）を
            // 使用中のみ表示する。バケツ・スポイト・選択系・変形・テキスト・
            // 図形ツールではブラシ設定が描画結果に影響しないため、常設表示
            // していた分の縦スペースをキャンバスへ還元する。
            if (_usesBrushSize(_currentTool))
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
            // ツールバーの折りたたみ用ハンドル（フレーム一覧と
            // 同様に、任意のタイミングで開閉できるようにし描画領域を広げる）。
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showToolbar = !_showToolbar),
              child: Container(
                height: 16,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: Icon(
                  _showToolbar ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ),
            if (_showToolbar)
              ToolbarWidget(
                currentTool: _currentTool,
                currentColor: _currentColor,
                isStampSelected: _currentSubTool == PenSubTool.stamp,
                onToolSelected: (tool) => setState(() => _currentTool = tool),
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
                onTextTap: () => setState(() => _currentTool = DrawingTool.text),
                onShapeTap: () => _showShapeMenu(context),
                onQuickToolTap: _applyNextQuickTool,
                onQuickToolLongPress: () => setState(() {
                  final next = !_showQuickToolPanel;
                  _closeAllOverlayPanels();
                  _showQuickToolPanel = next;
                }),
                // 手動保存（セーブツリー）：仕様書10「キャンバス → 保存 → キャンバスへ戻る」
                onSaveTap: () => context.push('/save-tree/${widget.projectId}'),
                // 投げ縄塗り：ペンのサブツールではなくバケツ長押しメニューから
                // 選べるようにする（投げ縄で囲った範囲を塗る点でバケツ塗りに
                // 近いため）。
                onLassoFillSelected: () => setState(() {
                  _currentSubTool = PenSubTool.lassoFill;
                  _currentTool = DrawingTool.lasso;
                }),
              ),
            if (_frameMultiSelectMode) _buildFrameMultiSelectBar(),
            // フレーム一覧の折りたたみ用ハンドル（描画領域を
            // できるだけ広げるため、任意のタイミングで開閉できるようにする）。
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showFrameStrip = !_showFrameStrip),
              child: Container(
                height: 16,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: Icon(
                  _showFrameStrip ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ),
            if (_showFrameStrip)
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
              _sidedPanel(anchorLeft: true, leftHanded: leftHanded, top: 56, bottom: null, child: _brushPanel()),
            // トーン・スタンプの全機能管理パネル（仕様書17）
            if (_showTonePanel && !isDesktop)
              _sidedPanel(anchorLeft: true, leftHanded: leftHanded, top: 56, bottom: null, child: _tonePanel()),
            if (_showStampPanel && !isDesktop)
              _sidedPanel(anchorLeft: true, leftHanded: leftHanded, top: 56, bottom: null, child: _stampPanel()),
            // ペンサブツールパネル（ブラシ/トーン/スタンプ）
            if (_showPenSubToolPanel && !isDesktop)
              _sidedPanel(anchorLeft: true, leftHanded: leftHanded, top: 56, bottom: null, child: _penSubToolPanel()),
            // オニオンスキンパネル
            if (_showOnionSkinPanel && !isDesktop)
              _sidedPanel(anchorLeft: false, leftHanded: leftHanded, top: 56, bottom: null, child: _onionSkinPanel()),
            // 定規パネル
            if (_showRulerPanel && !isDesktop)
              _sidedPanel(anchorLeft: true, leftHanded: leftHanded, top: 56, bottom: null, child: _rulerPanel()),
            // フィルターパネル（仕様書18：描画フィルター）
            if (_showFilterPanel && !isDesktop)
              _sidedPanel(anchorLeft: false, leftHanded: leftHanded, top: 56, bottom: null, child: _filterPanel()),
            // 早替えツール設定パネル（仕様書02・08）
            if (_showQuickToolPanel && !isDesktop)
              _sidedPanel(anchorLeft: false, leftHanded: leftHanded, top: null, bottom: 16, child: _quickToolPanel()),
            // レイヤー全体の自由変形・メッシュ変形パネル（仕様書28：新機能）。
            // 他パネルと異なり、格子点のドラッグ操作自体はこのパネルの外＝
            // キャンバス側で行うため、あえて_anyToolPanelOpen（パネル外タップ
            // で閉じる透明バリア）の対象には含めない（含めると、格子点を
            // ドラッグしようとした最初のタップでバリアがパネルをキャンセル
            // してしまい操作不能になる）。
            if (_showMeshTransformPanel && !isDesktop)
              _sidedPanel(anchorLeft: false, leftHanded: leftHanded, top: 56, bottom: null, child: _meshTransformPanel()),
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
      _showQuickToolPanel;

  // PC/DeXモード（広い画面）：現在開いているツールオプション系パネルを1つ
  // 返す（複数同時に開いていた場合は優先度の高いものを返す）。左側の
  // 常時ドッキングパネルに使う。フローティング表示（スマホ）と同じ
  // パネルインスタンスを流用する。
  Widget? _activeToolPanel() {
    if (_showColorPicker) return _colorPickerPanel();
    if (_showPenSubToolPanel) return _penSubToolPanel();
    if (_showBrushPanel) return _brushPanel();
    if (_showTonePanel) return _tonePanel();
    if (_showStampPanel) return _stampPanel();
    if (_showOnionSkinPanel) return _onionSkinPanel();
    if (_showRulerPanel) return _rulerPanel();
    if (_showFilterPanel) return _filterPanel();
    if (_showQuickToolPanel) return _quickToolPanel();
    if (_showMeshTransformPanel) return _meshTransformPanel();
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
            _currentTool = subTool == PenSubTool.lassoFill ? DrawingTool.lasso : DrawingTool.pen;
          });
        },
        onClose: () => setState(() => _showPenSubToolPanel = false),
        // フル機能管理パネル（フォルダ・自作・検索・読み込み書き出し、仕様書17）
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

  Widget _rulerPanel() => RulerPanel(
        activeRuler: _activeRuler,
        onRulerChanged: _setActiveRulerWithUndo,
        onClose: () => setState(() => _showRulerPanel = false),
      );

  /// CanvasArea側のハンドルドラッグによるライブ更新・Undo/Redoの巻き戻し反映用。
  /// ドラッグ確定時のUndo登録自体はcanvas_area.dart側（_handleRulerUp）が
  /// 1回だけ行うため、ここでは単純にstateを反映するのみでUndoは登録しない
  /// （毎フレーム登録するとUndoスタックが埋まってしまうため）。
  void _setActiveRulerLive(Ruler? r) {
    setState(() => _activeRuler = r);
  }

  /// 定規パネルからの選択・削除など、1回で完結する変更をUndoへ登録しつつ反映する
  /// （仕様書14：Undo通常対応）。
  void _setActiveRulerWithUndo(Ruler? newRuler) {
    final old = _activeRuler;
    if (identical(old, newRuler)) return;
    setState(() => _activeRuler = newRuler);
    context.read<UndoManager>().push(RulerUndoAction(
      before: old,
      after: newRuler,
      onApply: _setActiveRulerLive,
    ));
  }

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

  Widget _quickToolPanel() => QuickToolPanel(
        onClose: () => setState(() => _showQuickToolPanel = false),
        currentTool: _currentTool,
        currentBrushId: context.read<BrushService>().currentBrush?.id,
        currentBrushName: context.read<BrushService>().currentBrush?.name,
        currentSize: _brushSize,
      );

  /// レイヤー全体の自由変形・メッシュ変形パネル（仕様書28：新機能）。
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
    return CanvasIconButton(icon: icon, onPressed: onPressed, tooltip: tooltip, selected: selected);
  }

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // プロジェクト一覧へ戻るボタンはタイムラインモード側へ移した。
          // キャンバスモードの画面左上（元は戻るボタンの
          // 位置）にはUndo/Redoを配置する。
          _topBarIconButton(context, Icons.undo,
              onPressed: () => context.read<UndoManager>().undo(), tooltip: l10n.commonUndo),
          _topBarIconButton(context, Icons.redo,
              onPressed: () => context.read<UndoManager>().redo(), tooltip: l10n.commonRedo),
          // 投げ縄塗り選択中：囲って塗るモードスイッチ
          if (_currentTool == DrawingTool.lasso && _currentSubTool == PenSubTool.lassoFill) ...[
            const SizedBox(width: 8),
            Text(l10n.canvasLassoEnclosedLabel, style: const TextStyle(fontSize: 12)),
            Switch(
              value: _lassoFillEnclosedMode,
              onChanged: (v) => setState(() => _lassoFillEnclosedMode = v),
            ),
          ],
          // テキストツール選択中：キャンバスタップでテキスト入力ダイアログを表示する旨を示すラベル
          if (_currentTool == DrawingTool.text)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(l10n.canvasTapToEnterTextLabel,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
            ),
          const Spacer(),
          // 定規ボタン（仕様書08・タスク#95：下部ツールバーから昇格した常設ボタン）
          FirstUseTooltip(
            tooltipKey: 'ruler_tool',
            message: l10n.canvasRulerFirstUseTip,
            child: _topBarIconButton(context, Icons.straighten,
                onPressed: _toggleRuler,
                tooltip: l10n.canvasRulerTooltip,
                selected: _currentTool == DrawingTool.ruler),
          ),
          // 設定/編集メニュー（仕様書08・タスク#95：背景色・オニオンスキン・
          // フィルター・フレーム範囲選択を集約。旧・個別ボタンを整理統合した）。
          _topBarIconButton(context, Icons.settings,
              onPressed: () => _showEditMenu(context), tooltip: l10n.canvasSettingsMenuTooltip),
          const HelpButton(),
        ],
      ),
    );
  }

  /// フレーム複数選択モード時のアクションバー（仕様書18：大量処理実行時の
  /// フィルター一括適用）。全選択・全解除・フィルター一括適用・キャンセルを提供する。
  Widget _buildFrameMultiSelectBar() {
    final l10n = AppLocalizations.of(context)!;
    final total = context.watch<ProjectService>().frameCount(widget.projectId, _currentSceneId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          Text(l10n.canvasFrameSelectedCount(_selectedFrameIndices.length, total),
              style: const TextStyle(fontSize: 12)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(
                () => _selectedFrameIndices = {for (int i = 0; i < total; i++) i}),
            child: Text(l10n.canvasSelectAllButton, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => setState(() => _selectedFrameIndices = {}),
            child: Text(l10n.canvasDeselectAllButton, style: const TextStyle(fontSize: 12)),
          ),
          FilledButton.icon(
            onPressed: _selectedFrameIndices.isEmpty
                ? null
                : () => setState(() {
                      _filterBulkFrames = _selectedFrameIndices;
                      _showFilterPanel = true;
                    }),
            icon: const Icon(Icons.blur_on, size: 14),
            label: Text(l10n.canvasApplyFilterButton, style: const TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
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

  /// 図形ツールタップ時のポップアップ（仕様書03：OFF/線/四角形/円）
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(existingLayerId == null ? l10n.canvasTextInputTitle : l10n.canvasTextEditTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: null,
                  decoration: InputDecoration(hintText: l10n.canvasTextInputHint),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    initialValue: fontFamily,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.canvasTextFontLabel, isDense: true),
                    items: [
                      DropdownMenuItem(value: 'Roboto', child: Text(l10n.canvasTextStandardFont)),
                      // あらかじめ同梱しているフリーフォント（全てSIL Open Font
                      // License、Google Fonts配布分。ライセンス表記は設定画面
                      // 「利用規約・ライセンス」参照）
                      for (final f in kBundledFonts)
                        DropdownMenuItem(
                          value: f.family,
                          child: Text(f.displayName, style: TextStyle(fontFamily: f.family)),
                        ),
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
                    Text(l10n.brushSettingsSizeLabel, style: const TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 8, max: 200,
                        label: fontSize.round().toString(),
                        onChanged: (v) => setS(() => fontSize = v),
                      ),
                    ),
                    EditableSliderValue(
                      text: '${fontSize.round()}',
                      style: const TextStyle(fontSize: 12),
                      value: fontSize, min: 8, max: 200,
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
                    // 縦書き・横書きのワンタップ切替（仕様書15）
                    ActionChip(
                      avatar: Icon(
                        direction == model.TextWritingDirection.vertical
                            ? Icons.text_rotate_vertical
                            : Icons.text_rotation_none,
                        size: 16,
                      ),
                      label: Text(direction == model.TextWritingDirection.vertical ? l10n.canvasTextVertical : l10n.canvasTextHorizontal),
                      onPressed: () => setS(() {
                        direction = direction == model.TextWritingDirection.vertical
                            ? model.TextWritingDirection.horizontal
                            : model.TextWritingDirection.vertical;
                      }),
                    ),
                    // ルビ・縦中横・半角英数字回転の説明（仕様書15。ルビは縦書き・
                    // 横書きどちらでも使えるため、書字方向によらず常に表示する）
                    IconButton(
                      icon: const Icon(Icons.help_outline, size: 18),
                      tooltip: l10n.canvasTypesettingHelpTooltip,
                      onPressed: () => _showVerticalTextHelp(context),
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
                    Text(l10n.canvasTextLineHeight, style: const TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: lineHeight, min: 0.8, max: 3.0,
                        label: lineHeight.toStringAsFixed(1),
                        onChanged: (v) => setS(() => lineHeight = v),
                      ),
                    ),
                    EditableSliderValue(
                      text: lineHeight.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12),
                      value: lineHeight, min: 0.8, max: 3.0, isInt: false,
                      onChanged: (v) => setS(() => lineHeight = v.toDouble()),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(l10n.canvasTextLetterSpacing, style: const TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: letterSpacing, min: -2, max: 20,
                        label: letterSpacing.toStringAsFixed(0),
                        onChanged: (v) => setS(() => letterSpacing = v),
                      ),
                    ),
                    EditableSliderValue(
                      text: letterSpacing.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 12),
                      value: letterSpacing, min: -2, max: 20,
                      onChanged: (v) => setS(() => letterSpacing = v.toDouble()),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(l10n.canvasTextAlign, style: const TextStyle(fontSize: 12)),
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
                  label: Text(l10n.canvasTextOutline),
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
                      Text(l10n.canvasOutlineWidthLabel, style: const TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: outlineWidth, min: 0, max: 20,
                          label: outlineWidth.round().toString(),
                          onChanged: (v) => setS(() => outlineWidth = v),
                        ),
                      ),
                      EditableSliderValue(
                        text: '${outlineWidth.round()}',
                        style: const TextStyle(fontSize: 12),
                        value: outlineWidth, min: 0, max: 20,
                        onChanged: (v) => setS(() => outlineWidth = v.toDouble()),
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
                  textObject,
                  tileManager.canvasWidth,
                  tileManager.canvasHeight,
                  pixelMode: fontService.pixelModeForFamily(fontFamily),
                );
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
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  /// 組版・ルビに関する説明（仕様書15：半角英数字の回転・縦中横・ルビ）。
  void _showVerticalTextHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.canvasTypesettingHelpTooltip),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.canvasHelpRotationTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l10n.canvasHelpRotationBody),
              const SizedBox(height: 8),
              Text(l10n.canvasHelpTatechuyokoTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l10n.canvasHelpTatechuyokoBody),
              const SizedBox(height: 8),
              Text(l10n.canvasHelpRubyTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l10n.canvasHelpRubyBody('{漢字|かんじ}')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonClose)),
        ],
      ),
    );
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
  // レイヤー全体の自由変形・メッシュ変形：範囲選択せずに現在レイヤー全体を
  // 変形できる点がtransformと異なる（transformは4隅の一体スケール・回転の
  // みだが、こちらは格子点を個別にドラッグできる自由変形・メッシュ変形）。
  // ツールバーには表示せず、キャンバス上部バーの「設定/編集」メニューから
  // のみ到達する一時ツール。
  meshTransform,
}

/// 図形ツールの種別（仕様書03：タップでポップアップ表示・OFF/線/四角形/円）
enum ShapeKind { off, line, rect, circle }
