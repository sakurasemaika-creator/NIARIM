import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../engine/bucket_fill_engine.dart';
import '../../../engine/drawing_engine.dart';
import '../../../engine/input_handler.dart';
import '../../../engine/lasso_fill_engine.dart';
import '../../../engine/layer_compositor.dart';
import '../../../engine/onion_skin.dart';
import '../../../engine/procedural_texture.dart';
import '../../../engine/ruler_engine.dart';
import '../../../engine/stamp_engine.dart';
import '../../../engine/tile_manager.dart';
import '../../../engine/tone_engine.dart';
import '../../../engine/undo_manager.dart' as app_undo;
import '../../../models/layer.dart';
import '../../../models/onion_skin_settings.dart';
import '../../../models/project.dart';
import '../../../models/ruler.dart';
import '../../../services/brush_service.dart';
import '../../../services/performance_service.dart';
import '../../../services/project_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/stamp_service.dart';
import '../../../services/tone_service.dart';
import '../canvas_screen.dart';
import 'pen_sub_tool_panel.dart' show PenSubTool;

/// 変形ツールの操作モード（移動・拡大縮小・回転）
enum _TransformMode { translate, scale, rotate }

class CanvasArea extends StatefulWidget {
  final ValueChanged<Offset>? onTapForText;
  final ValueChanged<Color>? onEyedropper;
  final Project? project;
  final CanvasBackground background;
  final String? currentLayerId;
  final bool isEraser;
  final DrawingTool currentTool;
  final PenSubTool currentSubTool;
  final bool lassoFillEnclosedMode;
  final OnionSkinSettings onionSkinSettings;
  final int currentFrame;
  final String sceneId;
  final Ruler? activeRuler;
  // 定規のハンドルドラッグ（移動・回転・サイズ変更・消失点移動）による更新通知
  // （仕様書14）。ライブ更新・Undo確定の両方でこのコールバックを呼ぶ。
  final ValueChanged<Ruler?>? onRulerChanged;
  final ShapeKind shapeKind;
  // ジェスチャー／ペンボタンによるツール切替の通知先（仕様書08）。
  // onGestureToolChange：直接切り替え（スポイト等、押し続けの必要がないもの）
  // onGestureToggleTool：現在のツールとトグル切替（消しゴム切替・ブラシ切替・手のひらツール）
  final ValueChanged<DrawingTool>? onGestureToolChange;
  final ValueChanged<DrawingTool>? onGestureToggleTool;
  final VoidCallback? onNextQuickTool;
  // オニオンスキンON/OFF切替（仕様書22：ジェスチャーに割り当て可能）
  final VoidCallback? onToggleOnionSkin;

  const CanvasArea({
    super.key,
    this.onTapForText,
    this.onEyedropper,
    this.project,
    this.background = CanvasBackground.white,
    this.currentLayerId,
    this.isEraser = false,
    this.currentTool = DrawingTool.pen,
    this.currentSubTool = PenSubTool.brush,
    this.lassoFillEnclosedMode = false,
    this.onionSkinSettings = const OnionSkinSettings(),
    this.currentFrame = 0,
    this.sceneId = '',
    this.activeRuler,
    this.onRulerChanged,
    this.shapeKind = ShapeKind.off,
    this.onGestureToolChange,
    this.onGestureToggleTool,
    this.onNextQuickTool,
    this.onToggleOnionSkin,
  });

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> {
  final TransformationController _transformController = TransformationController();
  final InputHandler _inputHandler = InputHandler();
  final OnionSkinEngine _onionSkinEngine = OnionSkinEngine();
  final RulerEngine _rulerEngine = RulerEngine();
  // トーン・スタンプ・投げ縄塗りの本処理はisolate側で都度インスタンス化するため
  // （runToneStrokeInIsolate等を参照）、ここではエンジンインスタンスを保持しない。

  late TileManager _tileManager;
  late DrawingEngine _drawingEngine;

  ui.Image? _compositeImage;
  ui.Image? _belowImage;
  ui.Image? _aboveImage;
  final Map<int, ui.Image> _onionImages = {};
  bool _isCompositing = false;
  bool _isComposingSurroundings = false;

  // 現在フレームのレイヤー一覧（レイヤーパネル順・先頭が最前面）。
  // ProjectServiceの変更を検知して合成し直すために保持する。
  List<Layer> _layers = const [];

  Offset? _selectionStart;
  Offset? _selectionEnd;
  List<Offset> _lassoPoints = [];
  int _touchCount = 0;

  // ─── 選択範囲（矩形選択・投げ縄選択・自動選択で共通利用、仕様書03・16） ──
  // ドラッグ中は_selectionStart/_selectionEnd・_lassoPointsでプレビューのみ
  // 表示し、確定時に1px=1byteのマスクへ変換して保持する。投げ縄塗り・バケツ
  // 塗りはこのマスクを参照して選択範囲内のみ描画する。
  Uint8List? _selectionMask;
  ui.Image? _selectionOverlayImage;

  // ─── ペンサブツール：トーン自由描画・スタンプ ─────────────────────────
  // ライブ中は軌跡のプレビューのみ表示し、指を離した時点で一括してタイルへ
  // 書き戻す（毎ポインタ移動でキャンバス全体を読み書きすると低スペック端末で
  // 重くなるため）。
  List<Offset> _subToolStrokePoints = [];

  bool _engineInitialized = false;

  // ─── 図形ツール（線・四角形・円） ─────────────────────────────────────
  Offset? _shapeStart;
  Offset? _shapeEnd;

  // ─── 移動ツール ───────────────────────────────────────────────────────
  Offset? _moveStart;
  Offset _moveDelta = Offset.zero;

  // ─── 変形ツール ───────────────────────────────────────────────────────
  _TransformMode _transformMode = _TransformMode.translate;
  Offset? _transformStart;
  Offset? _transformCenter;
  Matrix4? _transformLive;

  // ─── バケツ連続塗り ───────────────────────────────────────────────────
  Uint8List? _bucketRefBuffer;
  Uint8List? _bucketVisitedMask;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_engineInitialized) {
      _initEngine();
      _engineInitialized = true;
    }
  }

  void _initEngine() {
    final project = widget.project;
    if (project != null) {
      _tileManager = context.read<ProjectService>().tileManagerOf(project.id);
    } else {
      _tileManager = TileManager(canvasWidth: 1920, canvasHeight: 1080);
    }
    _drawingEngine = DrawingEngine(tileManager: _tileManager);
    _scheduleComposite();
    _recomposeSurroundings(force: true);
  }

  @override
  void didUpdateWidget(CanvasArea old) {
    super.didUpdateWidget(old);
    if (old.project?.id != widget.project?.id) {
      _compositeImage?.dispose();
      _compositeImage = null;
      _belowImage?.dispose();
      _belowImage = null;
      _aboveImage?.dispose();
      _aboveImage = null;
      _layers = const [];
      _initEngine();
    }
    _drawingEngine.isEraser = widget.isEraser;
    if (old.activeRuler != widget.activeRuler) {
      _rulerEngine.setActiveRuler(widget.activeRuler);
    }
    if (old.onionSkinSettings != widget.onionSkinSettings ||
        old.currentFrame != widget.currentFrame) {
      _buildOnionImages();
    }
    // フレーム・シーン・現在レイヤーが変わった場合は現在レイヤー画像も
    // 合成し直す（他のレイヤー変更検知は_recomposeSurroundings内で行う）。
    final frameChanged = old.currentFrame != widget.currentFrame ||
        old.sceneId != widget.sceneId ||
        old.currentLayerId != widget.currentLayerId;
    if (frameChanged) {
      _scheduleComposite();
      // 選択範囲はフレームごとの一時状態のため、フレーム切替時にクリアする
      _clearSelectionMask();
    }
    _recomposeSurroundings(force: frameChanged);
  }

  @override
  void dispose() {
    _transformController.dispose();
    _compositeImage?.dispose();
    _belowImage?.dispose();
    _aboveImage?.dispose();
    _selectionOverlayImage?.dispose();
    for (final img in _onionImages.values) {
      img.dispose();
    }
    super.dispose();
  }

  // ─── 選択範囲マスク（矩形選択・投げ縄選択・自動選択で共通、仕様書03・16・25） ──

  void _clearSelectionMask() {
    if (_selectionMask == null && _selectionOverlayImage == null) return;
    _selectionOverlayImage?.dispose();
    _selectionOverlayImage = null;
    setState(() => _selectionMask = null);
  }

  Uint8List _rectSelectionMask(Offset a, Offset b, int w, int h) {
    final mask = Uint8List(w * h);
    final left = a.dx < b.dx ? a.dx : b.dx;
    final right = a.dx < b.dx ? b.dx : a.dx;
    final top = a.dy < b.dy ? a.dy : b.dy;
    final bottom = a.dy < b.dy ? b.dy : a.dy;
    final x0 = left.floor().clamp(0, w);
    final x1 = right.ceil().clamp(0, w);
    final y0 = top.floor().clamp(0, h);
    final y1 = bottom.ceil().clamp(0, h);
    for (int y = y0; y < y1; y++) {
      final rowBase = y * w;
      for (int x = x0; x < x1; x++) {
        mask[rowBase + x] = 1;
      }
    }
    return mask;
  }

  Uint8List _polygonSelectionMask(List<Offset> points, int w, int h) {
    final mask = Uint8List(w * h);
    if (points.length < 3) return mask;
    // 投げ縄塗り(LassoFillEngine)と同じRay Casting法。1回限りの確定処理
    // なので走査コストは許容範囲（毎フレーム再計算はしない）。
    bool inside(double px, double py) {
      int crossings = 0;
      final n = points.length;
      for (int i = 0; i < n; i++) {
        final pa = points[i];
        final pb = points[(i + 1) % n];
        if ((pa.dy <= py && pb.dy > py) || (pb.dy <= py && pa.dy > py)) {
          final t = (py - pa.dy) / (pb.dy - pa.dy);
          if (px < pa.dx + t * (pb.dx - pa.dx)) crossings++;
        }
      }
      return crossings % 2 != 0;
    }

    for (int y = 0; y < h; y++) {
      final rowBase = y * w;
      for (int x = 0; x < w; x++) {
        if (inside(x + 0.5, y + 0.5)) mask[rowBase + x] = 1;
      }
    }
    return mask;
  }

  /// 自動選択（マジックワンド）：タップ位置から表示中の全レイヤー合成色を基準に
  /// フラッドフィルし、選択範囲マスクを生成する（仕様書03：選択ツール）。
  Future<void> _magicWandSelectAt(Offset canvasPos) async {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final x = canvasPos.dx.round();
    final y = canvasPos.dy.round();
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    final buffer = await _flattenVisibleLayers();
    if (!mounted) return;
    final mask = _bucketEngine.selectionMask(
      canvasData: buffer,
      width: w,
      height: h,
      startX: x,
      startY: y,
    );
    _setSelectionMask(mask, w, h);
  }

  /// 選択範囲マスクを確定し、プレビュー用オーバーレイ画像を非同期で生成する。
  void _setSelectionMask(Uint8List mask, int w, int h) {
    _selectionOverlayImage?.dispose();
    _selectionOverlayImage = null;
    _selectionMask = mask;
    setState(() {});
    final rgba = Uint8List(w * h * 4);
    for (int i = 0; i < w * h; i++) {
      if (mask[i] == 0) continue;
      final idx = i * 4;
      // 選択範囲を半透明の水色でハイライト表示（キャンバス上のガイド表示、
      // 書き出しには含まれない）。
      rgba[idx] = 0x21;
      rgba[idx + 1] = 0x96;
      rgba[idx + 2] = 0xF3;
      rgba[idx + 3] = 0x55;
    }
    ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, (img) {
      if (!mounted || !identical(_selectionMask, mask)) {
        img.dispose();
        return;
      }
      setState(() => _selectionOverlayImage = img);
    });
  }

  // ─── 入力 ─────────────────────────────────────────────────────────────

  String get _layerId => widget.currentLayerId ?? 'Layer0001';

  /// レイヤーIDをTileManager用の合成キーへ変換する。通常レイヤーはフレームごとに
  /// 独立したキー（[frameLayerKey]）を使うが、共通・タイムライン素材・
  /// ウォーターマークなど表示範囲を持つレイヤーは、表示中のフレームに関わらず
  /// 常にホーム位置（実データのあるフレーム）のキーを指す（仕様書05・16：
  /// 複数フレームでの共有表示・共有編集のため）。
  String _tileKeyFor(String layerId, {int? frameIndex}) {
    final project = widget.project;
    if (project != null) {
      return context.read<ProjectService>().tileKeyFor(
            project.id, widget.sceneId, frameIndex ?? widget.currentFrame, layerId);
    }
    return frameLayerKey(widget.sceneId, frameIndex ?? widget.currentFrame, layerId);
  }

  void _syncBrushAndColor() {
    final bs = context.read<BrushService>();
    _drawingEngine.currentBrush = bs.currentBrush;
    final c = bs.currentColor;
    _drawingEngine.currentColor = ui.Color.fromARGB(
      (c.a * 255).round().clamp(0, 255),
      (c.r * 255).round().clamp(0, 255),
      (c.g * 255).round().clamp(0, 255),
      (c.b * 255).round().clamp(0, 255),
    );
  }

  /// 筆圧カーブ（仕様書08：アプリ全体に適用）と、品質設定の「傾き検知」ON/OFF
  /// （仕様書08：低品質・中品質はOFF固定）を反映したStrokePointを生成する。
  StrokePoint _rawToStrokePoint(PointerEvent event) {
    final settings = context.read<SettingsService>();
    final tiltEnabled = context.read<PerformanceService>().tiltEnabled;
    final raw = _inputHandler.toStrokePoint(event, pressureCurve: settings.applyPressureCurve);
    if (tiltEnabled) return raw;
    return StrokePoint(
      x: raw.x, y: raw.y, pressure: raw.pressure,
      tiltX: 0, tiltY: 0, inputType: raw.inputType,
    );
  }

  void _onPointerDown(PointerEvent event) {
    final type = _inputHandler.classifyInput(event);
    final canvasPos = _canvasPosition(event.localPosition);

    // 制作時間カウント（仕様書19）：キャンバスへの操作のたびに無操作タイマーをリセットする
    if (widget.project != null) {
      context.read<ProjectService>().pingWorkActivity();
    }

    // ペンボタン検出（仕様書08：対応端末のみ）。バレルボタン押下時は割り当てられた
    // アクションを実行し、描画は開始しない。
    if (type == InputType.stylus) {
      final settings = context.read<SettingsService>();
      if (event.buttons & kPrimaryStylusButton != 0) {
        _handleGesture(context, settings.penButton1);
        return;
      }
      if (event.buttons & kSecondaryStylusButton != 0) {
        _handleGesture(context, settings.penButton2);
        return;
      }
    }

    if (widget.currentTool == DrawingTool.pan) {
      // 手のひらツール：描画を行わずInteractiveViewerによる平行移動へ委ねる
      return;
    }

    if (widget.currentTool == DrawingTool.text && widget.onTapForText != null) {
      widget.onTapForText!(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.eyedropper) {
      _pickColor(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.selectRect) {
      _clearSelectionMask();
      setState(() {
        _selectionStart = canvasPos;
        _selectionEnd = canvasPos;
      });
      return;
    }
    if (widget.currentTool == DrawingTool.selectLasso) {
      _clearSelectionMask();
      setState(() { _lassoPoints = [canvasPos]; });
      return;
    }
    if (widget.currentTool == DrawingTool.selectMagicWand) {
      _clearSelectionMask();
      _magicWandSelectAt(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.shape && widget.shapeKind != ShapeKind.off) {
      setState(() {
        _shapeStart = canvasPos;
        _shapeEnd = canvasPos;
      });
      return;
    }
    if (widget.currentTool == DrawingTool.move) {
      setState(() {
        _moveStart = canvasPos;
        _moveDelta = Offset.zero;
      });
      return;
    }
    if (widget.currentTool == DrawingTool.transform) {
      _beginTransform(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.ruler) {
      _handleRulerDown(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.bucket) {
      if (type == InputType.touch) return;
      _syncBrushAndColor();
      _handleBucketDown(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.lasso) {
      if (type == InputType.touch) return;
      setState(() { _lassoPoints = [canvasPos]; });
      return;
    }
    if (widget.currentTool == DrawingTool.pen &&
        (widget.currentSubTool == PenSubTool.tone ||
            widget.currentSubTool == PenSubTool.stamp)) {
      if (type == InputType.touch) return;
      _syncBrushAndColor();
      setState(() { _subToolStrokePoints = [canvasPos]; });
      return;
    }

    if (type == InputType.touch) return;
    _syncBrushAndColor();
    // 透視定規：新しいストロークの開始点として、消失点スナップの基準をリセットする。
    _rulerEngine.beginStroke();
    final snapped = widget.currentTool == DrawingTool.ruler
        ? _toCanvasPoint(_rawToStrokePoint(event))
        : _applyRulerSnap(_toCanvasPoint(_rawToStrokePoint(event)));
    _beginTileUndo();
    _drawingEngine.beginStroke(snapped, _tileKeyFor(_layerId));
    _scheduleComposite();
  }

  void _onPointerMove(PointerEvent event) {
    final type = _inputHandler.classifyInput(event);
    final canvasPos = _canvasPosition(event.localPosition);

    if (widget.currentTool == DrawingTool.pan) return;
    if (widget.currentTool == DrawingTool.selectRect && _selectionStart != null) {
      setState(() => _selectionEnd = canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.selectLasso) {
      setState(() => _lassoPoints.add(canvasPos));
      return;
    }
    if (widget.currentTool == DrawingTool.shape && _shapeStart != null) {
      setState(() => _shapeEnd = _snapShapeEnd(_shapeStart!, canvasPos, widget.shapeKind));
      return;
    }
    if (widget.currentTool == DrawingTool.move && _moveStart != null) {
      setState(() => _moveDelta = canvasPos - _moveStart!);
      return;
    }
    if (widget.currentTool == DrawingTool.transform && _transformStart != null) {
      _updateTransform(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.ruler) {
      _handleRulerMove(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.bucket) {
      if (type == InputType.touch) return;
      _handleBucketMove(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.lasso) {
      if (type == InputType.touch) return;
      setState(() => _lassoPoints.add(canvasPos));
      return;
    }
    if (widget.currentTool == DrawingTool.pen &&
        (widget.currentSubTool == PenSubTool.tone ||
            widget.currentSubTool == PenSubTool.stamp)) {
      if (type == InputType.touch) return;
      setState(() => _subToolStrokePoints.add(canvasPos));
      return;
    }
    if (type == InputType.touch) return;
    if (widget.currentTool == DrawingTool.text ||
        widget.currentTool == DrawingTool.eyedropper) {
      return;
    }
    final snapped = _applyRulerSnap(_toCanvasPoint(_rawToStrokePoint(event)));
    _drawingEngine.continueStroke(snapped, _tileKeyFor(_layerId));
    _scheduleComposite();
  }

  void _onPointerUp(PointerEvent event) {
    final type = _inputHandler.classifyInput(event);

    if (widget.currentTool == DrawingTool.pan) return;
    if (widget.currentTool == DrawingTool.selectRect) {
      final start = _selectionStart;
      final end = _selectionEnd;
      setState(() {
        _selectionStart = null;
        _selectionEnd = null;
      });
      if (start != null && end != null && start != end) {
        final w = _tileManager.canvasWidth;
        final h = _tileManager.canvasHeight;
        _setSelectionMask(_rectSelectionMask(start, end, w, h), w, h);
      }
      return;
    }
    if (widget.currentTool == DrawingTool.selectLasso) {
      final points = List<Offset>.of(_lassoPoints);
      setState(() => _lassoPoints = []);
      if (points.length >= 3) {
        final w = _tileManager.canvasWidth;
        final h = _tileManager.canvasHeight;
        _setSelectionMask(_polygonSelectionMask(points, w, h), w, h);
      }
      return;
    }
    if (widget.currentTool == DrawingTool.shape) {
      _commitShape();
      return;
    }
    if (widget.currentTool == DrawingTool.move) {
      _commitMove();
      return;
    }
    if (widget.currentTool == DrawingTool.transform) {
      _commitTransform();
      return;
    }
    if (widget.currentTool == DrawingTool.ruler) {
      _handleRulerUp();
      return;
    }
    if (widget.currentTool == DrawingTool.bucket) {
      _handleBucketUp();
      if (type == InputType.touch) _inputHandler.onStylusUp();
      return;
    }
    if (widget.currentTool == DrawingTool.lasso) {
      _commitLassoFill();
      setState(() => _lassoPoints = []);
      if (type == InputType.touch) _inputHandler.onStylusUp();
      return;
    }
    if (widget.currentTool == DrawingTool.pen && widget.currentSubTool == PenSubTool.tone) {
      _commitToneStroke();
      setState(() => _subToolStrokePoints = []);
      if (type == InputType.touch) _inputHandler.onStylusUp();
      return;
    }
    if (widget.currentTool == DrawingTool.pen && widget.currentSubTool == PenSubTool.stamp) {
      _commitStampStroke();
      setState(() => _subToolStrokePoints = []);
      if (type == InputType.touch) _inputHandler.onStylusUp();
      return;
    }
    if (type == InputType.touch) {
      _inputHandler.onStylusUp();
      return;
    }
    if (widget.currentTool == DrawingTool.text ||
        widget.currentTool == DrawingTool.eyedropper) {
      return;
    }

    _drawingEngine.endStroke();
    _inputHandler.onStylusUp();
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
  }

  /// 自動塗り用線画レイヤーへ描画があった場合、直下の自動塗りレイヤーへ更新マークを立てる
  /// （仕様書16：needsAutofillUpdate自動セット）。
  void _markLineartDirtyIfNeeded() {
    final project = widget.project;
    if (project == null) return;
    context.read<ProjectService>().markLineartDirty(
        project.id, widget.sceneId, widget.currentFrame, _layerId);
  }

  // ─── Undo/Redo ─────────────────────────────────────────────────────────

  String? _undoRecordingLayerKey;

  /// 描画操作（ストローク・バケツ・投げ縄塗り・トーン・スタンプ・移動・
  /// 変形・図形）の直前に呼び、現在のレイヤーへのタイル変更差分の記録を開始する。
  void _beginTileUndo() {
    _undoRecordingLayerKey = _tileKeyFor(_layerId);
    _tileManager.beginUndoRecording(_undoRecordingLayerKey!);
  }

  /// 記録を終了し、実際に変更があった場合のみUndoManagerへ登録する。
  void _finishTileUndo() {
    final snapshot = _tileManager.endUndoRecording();
    final layerKey = _undoRecordingLayerKey;
    _undoRecordingLayerKey = null;
    if (snapshot.before.isEmpty || layerKey == null) return;
    context.read<app_undo.UndoManager>().push(app_undo.TileUndoAction(
      tileManager: _tileManager,
      layerId: layerKey,
      before: snapshot.before,
      after: snapshot.after,
      onApply: () {
        if (mounted) _scheduleComposite();
      },
    ));
  }

  // ─── 投げ縄塗り（ペンサブツール、仕様書25） ─────────────────────────────

  /// 投げ縄塗りを確定する。囲って塗るモードON/OFF・ベタ/トーン・透明色=消しゴム
  /// の判定は LassoFillEngine 側で行う。
  Future<void> _commitLassoFill() async {
    if (_lassoPoints.length < 3) return;
    _syncBrushAndColor();
    _beginTileUndo();
    final key = _tileKeyFor(_layerId);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final img = await _tileManager.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null || !mounted) return;
    final canvasData = byteData.buffer.asUint8List();
    final color = _drawingEngine.currentColor;

    Uint8List? toneTexture;
    const toneSize = 64;
    final toneService = context.read<ToneService>();
    if (toneService.lassoUseTone) {
      final tone = toneService.lastLassoTone ?? toneService.currentTone;
      if (tone != null) toneTexture = generateBuiltInToneTexture(tone, size: toneSize);
    }

    final points = _lassoPoints.map((p) => ui.Offset(p.dx, p.dy)).toList();
    // 低スペック端末でのUIスレッドブロックを避けるため、フルキャンバスの
    // 塗りつぶし処理はバックグラウンドisolateで実行する。
    final result = await compute(runLassoFillInIsolate, (
      enclosed: widget.lassoFillEnclosedMode,
      points: points,
      color: color,
      canvasData: canvasData,
      width: w,
      height: h,
      toneTexture: toneTexture,
      toneTextureWidth: toneSize,
      toneTextureHeight: toneSize,
      selectionMask: _selectionMask,
    ));
    if (!mounted) return;
    _tileManager.replaceLayerPixels(key, result);
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
  }

  // ─── ペンサブツール：トーン自由描画・スタンプ ─────────────────────────

  /// トーン自由描画を確定する（仕様書17：現在色で描画・サイズ一定・
  /// 回転なし・密度なし・散布なし）。ドラッグ中はプレビューのみで、
  /// 指を離した時点でまとめてタイルへ反映する。
  Future<void> _commitToneStroke() async {
    if (_subToolStrokePoints.isEmpty) return;
    final toneService = context.read<ToneService>();
    final tone = toneService.currentTone;
    if (tone == null) return;
    final bs = context.read<BrushService>();
    final brushSize = bs.currentBrush?.size ?? 20;
    _beginTileUndo();
    final key = _tileKeyFor(_layerId);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final img = await _tileManager.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null || !mounted) return;
    final canvasData = byteData.buffer.asUint8List();
    const toneSize = 64;
    final texture = generateBuiltInToneTexture(tone, size: toneSize);
    final c = bs.currentColor;
    final color = ui.Color.fromARGB(
      (c.a * 255).round().clamp(0, 255),
      (c.r * 255).round().clamp(0, 255),
      (c.g * 255).round().clamp(0, 255),
      (c.b * 255).round().clamp(0, 255),
    );
    final points = _subToolStrokePoints.map((p) => ui.Offset(p.dx, p.dy)).toList();
    // 低スペック端末でのUIスレッドブロックを避けるため、フルキャンバスの
    // 描画処理はバックグラウンドisolateで実行する。
    final result = await compute(runToneStrokeInIsolate, (
      erase: widget.isEraser,
      points: points,
      brushSize: brushSize,
      color: color,
      canvasData: canvasData,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: texture,
      toneWidth: toneSize,
      toneHeight: toneSize,
      opacity: bs.currentBrush?.opacity ?? 100,
    ));
    if (!mounted) return;
    _tileManager.replaceLayerPixels(key, result);
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
  }

  /// スタンプ描画を確定する（仕様書17：色情報はスタンプ自身が保持・
  /// ブラシサイズ連動・回転／密度／散布対応）。
  Future<void> _commitStampStroke() async {
    if (_subToolStrokePoints.isEmpty) return;
    final stampService = context.read<StampService>();
    final stamp = stampService.currentStamp;
    if (stamp == null) return;
    final bs = context.read<BrushService>();
    final stampSize = bs.currentBrush?.size ?? 40;
    _beginTileUndo();
    final key = _tileKeyFor(_layerId);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final img = await _tileManager.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null || !mounted) return;
    final canvasData = byteData.buffer.asUint8List();
    const texSize = 128;
    final texture = await generateBuiltInStampTexture(stamp, size: texSize);
    if (!mounted) return;

    // ストローク点をスタンプ間隔で間引く（密度が高すぎるとほぼ塗りつぶしになるため）
    final spacing = math.max(stampSize * 0.6, 4.0);
    final sampled = <ui.Offset>[];
    Offset? last;
    for (final p in _subToolStrokePoints) {
      if (last == null || (p - last).distance >= spacing) {
        sampled.add(ui.Offset(p.dx, p.dy));
        last = p;
      }
    }
    if (sampled.isEmpty) {
      sampled.add(ui.Offset(_subToolStrokePoints.first.dx, _subToolStrokePoints.first.dy));
    }

    // 低スペック端末でのUIスレッドブロックを避けるため、フルキャンバスの
    // スタンプ合成処理はバックグラウンドisolateで実行する。
    final result = await compute(runStampStrokeInIsolate, (
      canvasData: canvasData,
      width: w,
      height: h,
      texture: texture,
      texSize: texSize,
      points: sampled,
      stampSize: stampSize,
      rotation: stamp.rotation,
      scatter: stamp.scatter * stampSize,
      density: stamp.density,
    ));
    if (!mounted) return;
    _tileManager.replaceLayerPixels(key, result);
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
  }

  /// スポイトは表示中の全レイヤーを不透明度・ブレンドモード・クリッピングを
  /// 反映して合成した色をサンプリングする（仕様書16：表示されている見た目の色を拾う）。
  Future<void> _pickColor(Offset canvasPos) async {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final px = canvasPos.dx.round();
    final py = canvasPos.dy.round();
    if (px < 0 || py < 0 || px >= w || py >= h) return;
    final buffer = await _flattenVisibleLayers();
    if (!mounted) return;
    final idx = (py * w + px) * 4;
    if (idx + 3 >= buffer.length) return;
    widget.onEyedropper?.call(Color.fromARGB(
        buffer[idx + 3], buffer[idx], buffer[idx + 1], buffer[idx + 2]));
  }

  // ─── 図形ツール ───────────────────────────────────────────────────────

  /// 四角形・円のドラッグ終点を、縦横比1:1付近で正方形・真円へ自動スナップする。
  Offset _snapShapeEnd(Offset start, Offset end, ShapeKind kind) {
    if (kind != ShapeKind.rect && kind != ShapeKind.circle) return end;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dx == 0 || dy == 0) return end;
    final ratio = dx.abs() / dy.abs();
    if (ratio > 0.9 && ratio < 1.1) {
      final side = math.max(dx.abs(), dy.abs());
      return Offset(
        start.dx + side * (dx.isNegative ? -1 : 1),
        start.dy + side * (dy.isNegative ? -1 : 1),
      );
    }
    return end;
  }

  List<Offset> _ellipsePoints(Offset start, Offset end, {int segments = 48}) {
    final cx = (start.dx + end.dx) / 2;
    final cy = (start.dy + end.dy) / 2;
    final rx = (end.dx - start.dx).abs() / 2;
    final ry = (end.dy - start.dy).abs() / 2;
    return List.generate(segments, (i) {
      final t = (i / segments) * 2 * math.pi;
      return Offset(cx + rx * math.cos(t), cy + ry * math.sin(t));
    });
  }

  void _commitShape() {
    final start = _shapeStart;
    final end = _shapeEnd;
    setState(() {
      _shapeStart = null;
      _shapeEnd = null;
    });
    if (start == null || end == null || widget.shapeKind == ShapeKind.off) return;
    if (start == end) return;
    _syncBrushAndColor();
    _beginTileUndo();
    List<Offset> points;
    bool closeLoop;
    switch (widget.shapeKind) {
      case ShapeKind.line:
        points = [start, end];
        closeLoop = false;
      case ShapeKind.rect:
        points = [
          start,
          Offset(end.dx, start.dy),
          end,
          Offset(start.dx, end.dy),
        ];
        closeLoop = true;
      case ShapeKind.circle:
        points = _ellipsePoints(start, end);
        closeLoop = true;
      case ShapeKind.off:
        return;
    }
    // 図形はブラシ・トーンどちらでも描画可能（仕様書03）。ペンサブツールが
    // トーンの場合はトーンストロークエンジンで、それ以外はブラシで描画する。
    if (widget.currentSubTool == PenSubTool.tone) {
      _commitShapeWithTone(points, closeLoop);
    } else {
      _drawingEngine.commitShapePath(
        points.map((p) => StrokePoint(x: p.dx, y: p.dy)).toList(),
        _tileKeyFor(_layerId),
        closeLoop: closeLoop,
      );
      _scheduleComposite();
      _markLineartDirtyIfNeeded();
      _finishTileUndo();
    }
  }

  /// 図形をトーンで塗る（仕様書03：ブラシ・トーンどちらでも描画可能）。
  /// トーン自由描画（_commitToneStroke）と同じ仕組みで、図形の輪郭線上に
  /// 一定間隔で補間した密な点列をトーンストロークとして描画する。
  Future<void> _commitShapeWithTone(List<Offset> pathPoints, bool closeLoop) async {
    final toneService = context.read<ToneService>();
    final tone = toneService.currentTone;
    if (tone == null) {
      _finishTileUndo();
      return;
    }
    final bs = context.read<BrushService>();
    final brushSize = bs.currentBrush?.size ?? 20;
    final key = _tileKeyFor(_layerId);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final img = await _tileManager.compositeLayerToImage(key);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    if (byteData == null || !mounted) {
      _finishTileUndo();
      return;
    }
    final canvasData = byteData.buffer.asUint8List();
    const toneSize = 64;
    final texture = generateBuiltInToneTexture(tone, size: toneSize);
    final c = bs.currentColor;
    final color = ui.Color.fromARGB(
      (c.a * 255).round().clamp(0, 255),
      (c.r * 255).round().clamp(0, 255),
      (c.g * 255).round().clamp(0, 255),
      (c.b * 255).round().clamp(0, 255),
    );
    final densePoints = _densifyPath(pathPoints, closeLoop, math.max(1.0, brushSize / 3));
    // 低スペック端末でのUIスレッドブロックを避けるため、フルキャンバスの
    // 描画処理はバックグラウンドisolateで実行する。
    final result = await compute(runToneStrokeInIsolate, (
      erase: false,
      points: densePoints,
      brushSize: brushSize,
      color: color,
      canvasData: canvasData,
      canvasWidth: w,
      canvasHeight: h,
      toneTexture: texture,
      toneWidth: toneSize,
      toneHeight: toneSize,
      opacity: bs.currentBrush?.opacity ?? 100,
    ));
    if (!mounted) return;
    _tileManager.replaceLayerPixels(key, result);
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
    _finishTileUndo();
  }

  /// パス（[points]、[closeLoop]なら終点→始点も繋ぐ）を[spacing]間隔で
  /// 補間した密な点列に変換する（トーンストロークは点ごとにスタンプするため、
  /// 図形の頂点間を塗りつぶさずに済むよう補間が必要）。
  List<ui.Offset> _densifyPath(List<Offset> points, bool closeLoop, double spacing) {
    if (points.isEmpty) return const [];
    final segments = <Offset>[...points];
    if (closeLoop) segments.add(points.first);
    final result = <ui.Offset>[ui.Offset(points.first.dx, points.first.dy)];
    for (int i = 0; i < segments.length - 1; i++) {
      final from = segments[i];
      final to = segments[i + 1];
      final dist = (to - from).distance;
      final steps = math.max(1, (dist / spacing).ceil());
      for (int s = 1; s <= steps; s++) {
        final t = s / steps;
        result.add(ui.Offset(from.dx + (to.dx - from.dx) * t, from.dy + (to.dy - from.dy) * t));
      }
    }
    return result;
  }

  // ─── 移動ツール ───────────────────────────────────────────────────────

  void _commitMove() {
    final start = _moveStart;
    final delta = _moveDelta;
    setState(() {
      _moveStart = null;
      _moveDelta = Offset.zero;
    });
    if (start == null) return;
    if (delta.dx.abs() < 0.5 && delta.dy.abs() < 0.5) return;
    _beginTileUndo();
    _tileManager.translateLayer(_tileKeyFor(_layerId), delta.dx, delta.dy).then((_) {
      if (!mounted) return;
      _scheduleComposite();
      _markLineartDirtyIfNeeded();
      _finishTileUndo();
    });
  }

  // ─── 変形ツール ───────────────────────────────────────────────────────

  void _beginTransform(Offset canvasPos) {
    final w = _tileManager.canvasWidth.toDouble();
    final h = _tileManager.canvasHeight.toDouble();
    final center = Offset(w / 2, h / 2);
    final threshold = math.min(w, h) * 0.05;
    final scaleHandle = Offset(w, h);
    final rotateHandle = Offset(w / 2, -40);
    _TransformMode mode;
    if ((canvasPos - scaleHandle).distance < threshold) {
      mode = _TransformMode.scale;
    } else if ((canvasPos - rotateHandle).distance < threshold) {
      mode = _TransformMode.rotate;
    } else {
      mode = _TransformMode.translate;
    }
    setState(() {
      _transformMode = mode;
      _transformStart = canvasPos;
      _transformCenter = center;
      _transformLive = Matrix4.identity();
    });
  }

  void _updateTransform(Offset canvasPos) {
    final start = _transformStart;
    final center = _transformCenter;
    if (start == null || center == null) return;
    Matrix4 m;
    switch (_transformMode) {
      case _TransformMode.translate:
        final d = canvasPos - start;
        m = Matrix4.translationValues(d.dx, d.dy, 0);
      case _TransformMode.scale:
        final startDist = (start - center).distance;
        final curDist = (canvasPos - center).distance;
        final s = startDist > 1 ? (curDist / startDist).clamp(0.1, 10.0) : 1.0;
        m = Matrix4.translationValues(center.dx, center.dy, 0) *
            Matrix4.diagonal3Values(s, s, 1) *
            Matrix4.translationValues(-center.dx, -center.dy, 0);
      case _TransformMode.rotate:
        final a0 = math.atan2(start.dy - center.dy, start.dx - center.dx);
        final a1 = math.atan2(canvasPos.dy - center.dy, canvasPos.dx - center.dx);
        m = Matrix4.translationValues(center.dx, center.dy, 0) *
            Matrix4.rotationZ(a1 - a0) *
            Matrix4.translationValues(-center.dx, -center.dy, 0);
    }
    setState(() => _transformLive = m);
  }

  void _commitTransform() {
    final matrix = _transformLive;
    setState(() {
      _transformStart = null;
      _transformCenter = null;
      _transformLive = null;
    });
    if (matrix == null || matrix.isIdentity()) return;
    _beginTileUndo();
    _tileManager.transformLayer(_tileKeyFor(_layerId), matrix.storage).then((_) {
      if (!mounted) return;
      _scheduleComposite();
      _markLineartDirtyIfNeeded();
      _finishTileUndo();
    });
  }

  // ─── バケツ連続塗り ───────────────────────────────────────────────────

  /// バケツ塗りの参照用に、表示中の全レイヤーを不透明度・ブレンドモード・
  /// クリッピングを反映して合成する（仕様書04：バケツは表示中の全レイヤーの線を参照）。
  Future<Uint8List> _flattenVisibleLayers() async {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final project = widget.project;
    if (project == null) return Uint8List(w * h * 4);
    final layers = context
        .read<ProjectService>()
        .layersOf(project.id, widget.sceneId, widget.currentFrame);
    final image = await LayerCompositor.composite(
      _tileManager,
      layers,
      (l) => _tileKeyFor(l.id),
      w,
      h,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData?.buffer.asUint8List() ?? Uint8List(w * h * 4);
  }

  Future<void> _handleBucketDown(Offset canvasPos) async {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final buffer = await _flattenVisibleLayers();
    if (!mounted) return;
    _beginTileUndo();
    _bucketRefBuffer = buffer;
    _bucketVisitedMask = Uint8List(w * h);
    _bucketFillAt(canvasPos);
  }

  void _handleBucketMove(Offset canvasPos) {
    if (_bucketRefBuffer == null) return;
    _bucketFillAt(canvasPos);
  }

  void _handleBucketUp() {
    if (_bucketVisitedMask != null) _markLineartDirtyIfNeeded();
    _finishTileUndo();
    _bucketRefBuffer = null;
    _bucketVisitedMask = null;
  }

  final BucketFillEngine _bucketEngine = BucketFillEngine();

  /// 開始点からフラッドフィルし、変化したピクセルのみ現在レイヤーへ反映する。
  /// スワイプ中の連続塗り：既に塗った領域（訪問済みマスク）は再計算しない。
  void _bucketFillAt(Offset canvasPos) {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final x = canvasPos.dx.round();
    final y = canvasPos.dy.round();
    if (x < 0 || x >= w || y < 0 || y >= h) return;
    final mask = _bucketVisitedMask;
    final reference = _bucketRefBuffer;
    if (mask == null || reference == null) return;
    if (mask[y * w + x] != 0) return;

    final toneService = context.read<ToneService>();
    final tone = toneService.bucketUseTone
        ? (toneService.lastBucketTone ?? toneService.currentTone)
        : null;
    final Uint8List result;
    if (tone != null) {
      const toneSize = 64;
      final texture = generateBuiltInToneTexture(tone, size: toneSize);
      result = _bucketEngine.fillWithTone(
        canvasData: reference,
        width: w,
        height: h,
        startX: x,
        startY: y,
        toneColor: _drawingEngine.currentColor,
        toneTexture: texture,
        toneWidth: toneSize,
        toneHeight: toneSize,
        selectionMask: _selectionMask,
      );
    } else {
      result = _bucketEngine.fill(
        canvasData: reference,
        width: w,
        height: h,
        startX: x,
        startY: y,
        fillColor: _drawingEngine.currentColor,
        selectionMask: _selectionMask,
      );
    }

    bool changed = false;
    for (int py = 0; py < h; py++) {
      final rowBase = py * w;
      for (int px = 0; px < w; px++) {
        final idx = (rowBase + px) * 4;
        if (result[idx] != reference[idx] ||
            result[idx + 1] != reference[idx + 1] ||
            result[idx + 2] != reference[idx + 2] ||
            result[idx + 3] != reference[idx + 3]) {
          mask[rowBase + px] = 1;
          final tx = px ~/ TileManager.tileSize;
          final ty = py ~/ TileManager.tileSize;
          final key = _tileKeyFor(_layerId);
          final tile = _tileManager.getOrCreateTile(key, tx, ty);
          final lx = px % TileManager.tileSize;
          final ly = py % TileManager.tileSize;
          _tileManager.blendPixel(
              tile, lx, ly, result[idx], result[idx + 1], result[idx + 2], result[idx + 3]);
          _tileManager.markDirty(key, tx, ty);
          changed = true;
        }
      }
    }
    if (changed) _scheduleComposite();
  }

  StrokePoint _applyRulerSnap(StrokePoint sp) {
    if (widget.activeRuler == null) return sp;
    final snapped = _rulerEngine.snapToRuler(Offset(sp.x, sp.y));
    return StrokePoint(
      x: snapped.dx, y: snapped.dy,
      pressure: sp.pressure,
      tiltX: sp.tiltX, tiltY: sp.tiltY,
      inputType: sp.inputType,
    );
  }

  // ─── 定規の編集（移動・回転・サイズ変更・消失点移動、仕様書14） ───────────
  // 定規ツール選択中はキャンバスタップがハンドル操作として扱われる。
  // ハンドル座標は_paintRulerの描画と同じ座標系（ルーラーの position/
  // vanishingPoint と同じ、export解像度基準）で計算する。

  String? _rulerHandleId;
  Ruler? _rulerDragStartRuler;

  double get _rulerHitTolerance {
    final scale = _transformController.value.getMaxScaleOnAxis();
    return scale > 0 ? 28.0 / scale : 28.0;
  }

  Offset _rotatePoint(Offset v, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  /// 現在のルーラーのハンドル一覧（ハンドルID→キャンバス座標）を返す。
  /// _paintRulerが描画するハンドル位置と対応させている。
  Map<String, Offset> _rulerHandlePositions(Ruler r) {
    switch (r.type) {
      case RulerType.line:
        return {
          'move': r.position,
          'rotate': r.position + Offset.fromDirection(r.rotation, 220),
        };
      case RulerType.ellipse:
        final rx = r.settings.radiusX ?? 200;
        final ry = r.settings.radiusY ?? 120;
        return {
          'move': r.position,
          'resizeX': r.position + _rotatePoint(Offset(rx, 0), r.rotation),
          'resizeY': r.position + _rotatePoint(Offset(0, ry), r.rotation),
          'rotate': r.position + _rotatePoint(Offset(rx + 50, 0), r.rotation),
        };
      case RulerType.radial:
        return {
          'move': r.position,
          'rotate': r.position + Offset.fromDirection(r.rotation, 160),
        };
      case RulerType.onePointPerspective:
        return {'vp1': r.settings.vanishingPoint1 ?? r.position};
      case RulerType.twoPointPerspective:
        return {
          'vp1': r.settings.vanishingPoint1 ?? const Offset(200, 540),
          'vp2': r.settings.vanishingPoint2 ?? const Offset(1720, 540),
        };
      case RulerType.threePointPerspective:
        return {
          'vp1': r.settings.vanishingPoint1 ?? const Offset(200, 540),
          'vp2': r.settings.vanishingPoint2 ?? const Offset(1720, 540),
          'vp3': r.settings.vanishingPoint3 ?? const Offset(960, 100),
        };
      case RulerType.circle:
        return {'move': r.position};
    }
  }

  /// ハンドルをドラッグした結果の新しいRulerを計算する。
  Ruler _rulerWithHandleAt(Ruler r, String handleId, Offset canvasPos) {
    switch (handleId) {
      case 'move':
        return r.copyWith(position: canvasPos);
      case 'rotate':
        return r.copyWith(rotation: (canvasPos - r.position).direction);
      case 'resizeX':
      case 'resizeY':
        final local = _rotatePoint(canvasPos - r.position, -r.rotation);
        double newRx = r.settings.radiusX ?? 200;
        double newRy = r.settings.radiusY ?? 120;
        if (handleId == 'resizeX') {
          newRx = local.dx.abs().clamp(10.0, 4000.0);
        } else {
          newRy = local.dy.abs().clamp(10.0, 4000.0);
        }
        // 正円スナップ（仕様書14：横幅≒縦幅になると自動で正円に吸い付く）
        final maxR = math.max(newRx, newRy);
        if (maxR > 0 && (newRx - newRy).abs() / maxR < 0.08) {
          if (handleId == 'resizeX') {
            newRy = newRx;
          } else {
            newRx = newRy;
          }
        }
        return r.copyWith(settings: r.settings.copyWith(radiusX: newRx, radiusY: newRy));
      case 'vp1':
        return r.copyWith(settings: r.settings.copyWith(vanishingPoint1: canvasPos));
      case 'vp2':
        return r.copyWith(settings: r.settings.copyWith(vanishingPoint2: canvasPos));
      case 'vp3':
        return r.copyWith(settings: r.settings.copyWith(vanishingPoint3: canvasPos));
      default:
        return r;
    }
  }

  void _handleRulerDown(Offset canvasPos) {
    final ruler = widget.activeRuler;
    if (ruler == null) return;
    final handles = _rulerHandlePositions(ruler);
    String? bestId;
    double bestDist = _rulerHitTolerance;
    for (final entry in handles.entries) {
      final d = (entry.value - canvasPos).distance;
      if (d <= bestDist) {
        bestDist = d;
        bestId = entry.key;
      }
    }
    if (bestId == null) return;
    _rulerHandleId = bestId;
    _rulerDragStartRuler = ruler;
  }

  void _handleRulerMove(Offset canvasPos) {
    final handleId = _rulerHandleId;
    final ruler = widget.activeRuler;
    if (handleId == null || ruler == null) return;
    widget.onRulerChanged?.call(_rulerWithHandleAt(ruler, handleId, canvasPos));
  }

  void _handleRulerUp() {
    final handleId = _rulerHandleId;
    final before = _rulerDragStartRuler;
    _rulerHandleId = null;
    _rulerDragStartRuler = null;
    if (handleId == null || before == null) return;
    final after = widget.activeRuler;
    if (after == null || identical(before, after)) return;
    context.read<app_undo.UndoManager>().push(app_undo.RulerUndoAction(
      before: before,
      after: after,
      onApply: (ruler) => widget.onRulerChanged?.call(ruler),
    ));
  }

  // ─── 座標変換 ─────────────────────────────────────────────────────────

  StrokePoint _toCanvasPoint(StrokePoint screen) {
    final inv = Matrix4.inverted(_transformController.value);
    final local = MatrixUtils.transformPoint(inv, Offset(screen.x, screen.y));
    return StrokePoint(
      x: local.dx, y: local.dy,
      pressure: screen.pressure,
      tiltX: screen.tiltX, tiltY: screen.tiltY,
      inputType: screen.inputType,
    );
  }

  Offset _canvasPosition(Offset screenPos) {
    final inv = Matrix4.inverted(_transformController.value);
    return MatrixUtils.transformPoint(inv, screenPos);
  }

  // ─── 合成 ─────────────────────────────────────────────────────────────

  /// 現在レイヤーの画像を合成する。クリッピングONの場合はクリッピング元レイヤーの
  /// 形状でマスクした状態まで合成しておく（不透明度・ブレンドモードはpaint時に
  /// 適用するためここでは反映しない。仕様書16）。
  Future<ui.Image> _composeCurrentLayerImage() async {
    final key = _tileKeyFor(_layerId);
    final raw = await _tileManager.compositeLayerToImage(key);
    final idx = _layers.indexWhere((l) => l.id == _layerId);
    if (idx < 0 || !_layers[idx].hasClipping) return raw;
    final clipSourceId = findClipSourceLayerId(_layers, idx);
    if (clipSourceId == null) return raw;
    final clipImg = await _tileManager.compositeLayerToImage(_tileKeyFor(clipSourceId));
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    canvas.saveLayer(rect, ui.Paint());
    canvas.drawImage(clipImg, ui.Offset.zero, ui.Paint());
    canvas.drawImage(raw, ui.Offset.zero, ui.Paint()..blendMode = ui.BlendMode.srcIn);
    canvas.restore();
    clipImg.dispose();
    raw.dispose();
    final picture = recorder.endRecording();
    return picture.toImage(w, h);
  }

  void _scheduleComposite() {
    final project = widget.project;
    if (project == null) return;
    if (_isCompositing) {
      setState(() {});
      return;
    }
    _isCompositing = true;
    _composeCurrentLayerImage().then((img) {
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() {
        _compositeImage?.dispose();
        _compositeImage = img;
        _isCompositing = false;
      });
    });
  }

  /// 現在レイヤーより手前（above）／奥（below）にあるレイヤー群を、
  /// 不透明度・ブレンドモード・クリッピングを反映して合成しておく
  /// （仕様書16）。ドラッグ中の移動・変形プレビューでは現在レイヤーの画像
  /// （_compositeImage）だけを動かせば済むよう、あえて現在レイヤーを含めず
  /// 前後に分けてキャッシュする。
  ///
  /// レイヤーの追加・削除・並び替え・表示切替・不透明度・ブレンドモード変更は
  /// ProjectServiceを経由するため、[force]がfalseの場合は前回取得したレイヤー
  /// 一覧と参照が変わっていない限り再合成をスキップする（低スペック端末対策）。
  Future<void> _recomposeSurroundings({bool force = false}) async {
    final project = widget.project;
    if (project == null) return;
    if (_isComposingSurroundings) return;
    final ps = context.read<ProjectService>();
    final layers = ps.layersOf(project.id, widget.sceneId, widget.currentFrame);
    if (!force && _sameLayerList(_layers, layers)) return;
    _layers = layers;
    _isComposingSurroundings = true;

    final idx = layers.indexWhere((l) => l.id == _layerId);
    final above = idx < 0 ? const <Layer>[] : layers.sublist(0, idx);
    final below = idx < 0 ? layers : layers.sublist(idx + 1);
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;

    final belowImg =
        await LayerCompositor.composite(_tileManager, below, (l) => _tileKeyFor(l.id), w, h);
    if (!mounted) {
      belowImg.dispose();
      _isComposingSurroundings = false;
      return;
    }
    final aboveImg =
        await LayerCompositor.composite(_tileManager, above, (l) => _tileKeyFor(l.id), w, h);
    if (!mounted) {
      belowImg.dispose();
      aboveImg.dispose();
      _isComposingSurroundings = false;
      return;
    }
    setState(() {
      _belowImage?.dispose();
      _belowImage = belowImg;
      _aboveImage?.dispose();
      _aboveImage = aboveImg;
      _isComposingSurroundings = false;
    });
    // 合成中にさらに変更があった場合に備えて再チェック
    final latest = ps.layersOf(project.id, widget.sceneId, widget.currentFrame);
    if (!_sameLayerList(_layers, latest)) _recomposeSurroundings();
  }

  bool _sameLayerList(List<Layer> a, List<Layer> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// オニオンスキン用の前後フレーム画像を合成する。対象レイヤーは通常レイヤーと
  /// 自動塗り用線画レイヤーのみ（仕様書22：共通・テキスト・自動塗り・タイムライン
  /// 素材レイヤーは対象外）。
  Future<void> _buildOnionImages() async {
    if (!widget.onionSkinSettings.enabled) {
      if (_onionImages.isNotEmpty) {
        setState(() {
          for (final img in _onionImages.values) {
            img.dispose();
          }
          _onionImages.clear();
        });
      }
      return;
    }
    final project = widget.project;
    if (project == null) return;
    final offsets = _onionSkinEngine.getVisibleFrameOffsets(widget.onionSkinSettings);
    final ps = context.read<ProjectService>();
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final newImages = <int, ui.Image>{};
    for (final offset in offsets) {
      final frameIdx = widget.currentFrame + offset;
      if (frameIdx < 0) continue;
      final layers = ps.layersOf(project.id, widget.sceneId, frameIdx);
      if (layers.isEmpty) continue;
      newImages[offset] = await LayerCompositor.composite(
        _tileManager,
        layers,
        (l) => _tileKeyFor(l.id, frameIndex: frameIdx),
        w,
        h,
        shouldRender: (layer, _) =>
            layer.type == LayerType.normal || layer.type == LayerType.autoFillLineart,
      );
    }
    if (!mounted) {
      for (final img in newImages.values) {
        img.dispose();
      }
      return;
    }
    setState(() {
      for (final img in _onionImages.values) {
        img.dispose();
      }
      _onionImages
        ..clear()
        ..addAll(newImages);
    });
  }

  // ─── build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    return GestureDetector(
      // 2本指タップ
      onSecondaryTap: () => _handleGesture(context, settings.twoFingerTap),
      child: Listener(
        onPointerDown: (e) {
          if (e.kind == PointerDeviceKind.touch) {
            _touchCount++;
            if (_touchCount == 2) _handleGesture(context, settings.twoFingerTap);
            if (_touchCount == 3) _handleGesture(context, settings.threeFingerTap);
          }
          _onPointerDown(e);
        },
        onPointerMove: _onPointerMove,
        onPointerUp: (e) {
          if (e.kind == PointerDeviceKind.touch) {
            _touchCount = (_touchCount - 1).clamp(0, 10);
          }
          _onPointerUp(e);
        },
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.1,
          maxScale: 10.0,
          panEnabled: !_inputHandler.isStylusActive || widget.currentTool == DrawingTool.pan,
          scaleEnabled: !_inputHandler.isStylusActive || widget.currentTool == DrawingTool.pan,
          // 低スペック端末対策：キャンバスの再描画を他ウィジェットから分離し、
          // ストローク中の再描画コストを最小限に抑える。
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _CanvasPainter(
                project: widget.project,
                background: widget.background,
                transform: _transformController.value,
                compositeImage: _compositeImage,
                belowImage: _belowImage,
                aboveImage: _aboveImage,
                currentLayerOpacity:
                    _layers.where((l) => l.id == _layerId).firstOrNull?.opacity ?? 100,
                currentLayerBlendMode: _layers.where((l) => l.id == _layerId).firstOrNull?.blendMode ??
                    LayerBlendMode.normal,
                onionImages: Map.unmodifiable(_onionImages),
                onionSettings: widget.onionSkinSettings,
                onionEngine: _onionSkinEngine,
                selectionStart: _selectionStart,
                selectionEnd: _selectionEnd,
                selectionOverlayImage: _selectionOverlayImage,
                lassoPoints: _lassoPoints,
                subToolStrokePoints: _subToolStrokePoints,
                activeRuler: widget.activeRuler,
                shapeKind: widget.shapeKind,
                shapeStart: _shapeStart,
                shapeEnd: _shapeEnd,
                moveDelta: widget.currentTool == DrawingTool.move ? _moveDelta : null,
                transformLive: widget.currentTool == DrawingTool.transform ? _transformLive : null,
                showTransformHandles: widget.currentTool == DrawingTool.transform,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }

  void _handleGesture(BuildContext context, GestureAction action) {
    final undoManager = context.read<app_undo.UndoManager>();
    switch (action) {
      case GestureAction.undo:
        undoManager.undo();
      case GestureAction.redo:
        undoManager.redo();
      case GestureAction.eyedropper:
        // スポイトは次のタップ座標が必要なため、ツールをスポイトへ直接切り替える
        widget.onGestureToolChange?.call(DrawingTool.eyedropper);
      case GestureAction.eraserToggle:
        widget.onGestureToggleTool?.call(DrawingTool.eraser);
      case GestureAction.brushToggle:
        widget.onGestureToggleTool?.call(DrawingTool.pen);
      case GestureAction.panTool:
        widget.onGestureToggleTool?.call(DrawingTool.pan);
      case GestureAction.nextTool:
        widget.onNextQuickTool?.call();
      case GestureAction.onionSkinToggle:
        widget.onToggleOnionSkin?.call();
      case GestureAction.frameMove:
        // 2本指スワイプ専用の連続操作を想定した機能のため、単発ジェスチャー／
        // ペンボタンからの割り当ては未対応（仕様書08）
        break;
      case GestureAction.none:
        break;
    }
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────

class _CanvasPainter extends CustomPainter {
  final Project? project;
  final CanvasBackground background;
  final Matrix4 transform;
  final ui.Image? compositeImage;
  final ui.Image? belowImage;
  final ui.Image? aboveImage;
  final int currentLayerOpacity;
  final LayerBlendMode currentLayerBlendMode;
  final Map<int, ui.Image> onionImages;
  final OnionSkinSettings onionSettings;
  final OnionSkinEngine onionEngine;
  final Offset? selectionStart;
  final Offset? selectionEnd;
  final ui.Image? selectionOverlayImage;
  final List<Offset> lassoPoints;
  final List<Offset> subToolStrokePoints;
  final Ruler? activeRuler;
  final ShapeKind shapeKind;
  final Offset? shapeStart;
  final Offset? shapeEnd;
  final Offset? moveDelta;
  final Matrix4? transformLive;
  final bool showTransformHandles;

  static const Color _outsideColor = Color(0xFF3A3A3A);
  static const double _checkerSize = 16.0;

  const _CanvasPainter({
    required this.background,
    required this.transform,
    required this.onionImages,
    required this.onionSettings,
    required this.onionEngine,
    required this.lassoPoints,
    this.subToolStrokePoints = const [],
    this.project,
    this.compositeImage,
    this.belowImage,
    this.aboveImage,
    this.currentLayerOpacity = 100,
    this.currentLayerBlendMode = LayerBlendMode.normal,
    this.selectionStart,
    this.selectionEnd,
    this.selectionOverlayImage,
    this.activeRuler,
    this.shapeKind = ShapeKind.off,
    this.shapeStart,
    this.shapeEnd,
    this.moveDelta,
    this.transformLive,
    this.showTransformHandles = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hasExtended = project?.hasExtendedDrawingArea ?? false;
    final exportRect = _calcExportRect(size);
    final drawingRect = hasExtended
        ? Rect.fromLTWH(0, 0, size.width, size.height)
        : exportRect;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _outsideColor);
    _paintBackground(canvas, drawingRect);

    // 現在レイヤーより奥（背面）のレイヤー群
    _drawFrameImage(canvas, drawingRect, belowImage, Paint());

    // オニオンスキン（前フレーム）
    for (final entry in onionImages.entries) {
      if (entry.key >= 0) continue;
      _drawOnionFrame(canvas, drawingRect, entry.value, entry.key);
    }

    // 現在レイヤー（不透明度・ブレンドモードを反映）
    if (compositeImage != null) {
      final currentPaint = Paint()
        ..color = Color.fromARGB(
            (currentLayerOpacity.clamp(0, 100) * 255 / 100).round(), 255, 255, 255)
        ..blendMode = mapLayerBlendMode(currentLayerBlendMode);
      final sx = drawingRect.width / compositeImage!.width;
      final sy = drawingRect.height / compositeImage!.height;
      if (moveDelta != null || transformLive != null) {
        // 移動・変形ツール：ドラッグ中はコミット前のプレビューとして表示する
        canvas.save();
        canvas.translate(drawingRect.left, drawingRect.top);
        canvas.scale(sx, sy);
        if (moveDelta != null) {
          canvas.translate(moveDelta!.dx, moveDelta!.dy);
        }
        if (transformLive != null) {
          canvas.transform(transformLive!.storage);
        }
        canvas.drawImage(compositeImage!, Offset.zero, currentPaint);
        canvas.restore();
      } else {
        final src = Rect.fromLTWH(0, 0,
            compositeImage!.width.toDouble(), compositeImage!.height.toDouble());
        canvas.drawImageRect(compositeImage!, src, drawingRect, currentPaint);
      }
    }

    // オニオンスキン（後フレーム）
    for (final entry in onionImages.entries) {
      if (entry.key <= 0) continue;
      _drawOnionFrame(canvas, drawingRect, entry.value, entry.key);
    }

    // 現在レイヤーより手前（前面）のレイヤー群
    _drawFrameImage(canvas, drawingRect, aboveImage, Paint());

    // 確定済み選択範囲（矩形選択・投げ縄選択・自動選択で共通、仕様書03・16・25）
    if (selectionOverlayImage != null) {
      _drawFrameImage(canvas, drawingRect, selectionOverlayImage, Paint());
    }

    // 矩形選択プレビュー
    if (selectionStart != null && selectionEnd != null) {
      final sx = drawingRect.width / (project?.exportWidth ?? 1920);
      final sy = drawingRect.height / (project?.exportHeight ?? 1080);
      final r = Rect.fromPoints(
        drawingRect.topLeft +
            Offset(selectionStart!.dx * sx, selectionStart!.dy * sy),
        drawingRect.topLeft +
            Offset(selectionEnd!.dx * sx, selectionEnd!.dy * sy),
      );
      canvas.drawRect(r, Paint()..color = Colors.blue.withValues(alpha: 0.2));
      canvas.drawRect(r, Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);
    }

    // 投げ縄選択プレビュー
    if (lassoPoints.length > 1) {
      final sx = drawingRect.width / (project?.exportWidth ?? 1920);
      final sy = drawingRect.height / (project?.exportHeight ?? 1080);
      final path = Path();
      path.moveTo(
        drawingRect.left + lassoPoints.first.dx * sx,
        drawingRect.top + lassoPoints.first.dy * sy,
      );
      for (final p in lassoPoints.skip(1)) {
        path.lineTo(drawingRect.left + p.dx * sx, drawingRect.top + p.dy * sy);
      }
      canvas.drawPath(path, Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);
    }

    // トーン自由描画・スタンプのストロークプレビュー（確定は指を離した時点）
    if (subToolStrokePoints.length > 1) {
      final sx = drawingRect.width / (project?.exportWidth ?? 1920);
      final sy = drawingRect.height / (project?.exportHeight ?? 1080);
      final path = Path();
      path.moveTo(
        drawingRect.left + subToolStrokePoints.first.dx * sx,
        drawingRect.top + subToolStrokePoints.first.dy * sy,
      );
      for (final p in subToolStrokePoints.skip(1)) {
        path.lineTo(drawingRect.left + p.dx * sx, drawingRect.top + p.dy * sy);
      }
      canvas.drawPath(path, Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0);
    }

    // 図形ツール：ゴムバンドプレビュー（指を離すまで確定しない）
    if (shapeStart != null && shapeEnd != null && shapeKind != ShapeKind.off) {
      final sx = drawingRect.width / (project?.exportWidth ?? 1920);
      final sy = drawingRect.height / (project?.exportHeight ?? 1080);
      Offset ts(Offset p) =>
          drawingRect.topLeft + Offset(p.dx * sx, p.dy * sy);
      final shapePaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      switch (shapeKind) {
        case ShapeKind.line:
          canvas.drawLine(ts(shapeStart!), ts(shapeEnd!), shapePaint);
        case ShapeKind.rect:
          canvas.drawRect(Rect.fromPoints(ts(shapeStart!), ts(shapeEnd!)), shapePaint);
        case ShapeKind.circle:
          canvas.drawOval(Rect.fromPoints(ts(shapeStart!), ts(shapeEnd!)), shapePaint);
        case ShapeKind.off:
          break;
      }
    }

    // 変形ツール：バウンディングボックス・拡縮ハンドル・回転ハンドル
    if (showTransformHandles) {
      final sx = drawingRect.width / (project?.exportWidth ?? 1920);
      final sy = drawingRect.height / (project?.exportHeight ?? 1080);
      Offset ts(Offset p) =>
          drawingRect.topLeft + Offset(p.dx * sx, p.dy * sy);
      final w = (project?.exportWidth ?? 1920).toDouble();
      final h = (project?.exportHeight ?? 1080).toDouble();
      final boxPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(Rect.fromPoints(ts(Offset.zero), ts(Offset(w, h))), boxPaint);
      void handle(Offset p) {
        canvas.drawCircle(p, 8, Paint()..color = Colors.blue.withValues(alpha: 0.85));
        canvas.drawCircle(p, 8, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }
      handle(ts(Offset(w, h))); // 拡縮ハンドル
      handle(ts(Offset(w / 2, -40))); // 回転ハンドル
    }

    if (hasExtended) {
      canvas.drawRect(exportRect, Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }

    // 定規オーバーレイ
    _paintRuler(canvas, size, drawingRect);
  }

  void _paintRuler(Canvas canvas, Size size, Rect drawingRect) {
    final r = activeRuler;
    if (r == null || !r.isVisible) return;
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final cw = project?.exportWidth.toDouble() ?? 1920.0;
    final ch = project?.exportHeight.toDouble() ?? 1080.0;
    final sx = drawingRect.width / cw;
    final sy = drawingRect.height / ch;
    Offset ts(Offset p) => drawingRect.topLeft + Offset(p.dx * sx, p.dy * sy);
    void handle(Offset p) {
      canvas.drawCircle(p, 6, Paint()..color = Colors.blue.withValues(alpha: 0.8));
      canvas.drawCircle(p, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
    switch (r.type) {
      case RulerType.line:
        final c = ts(r.position);
        final len = size.longestSide;
        final dir = Offset.fromDirection(r.rotation, len);
        canvas.drawLine(c - dir, c + dir, paint);
        handle(c);
        handle(ts(r.position) + Offset.fromDirection(r.rotation, 220 * sx));
      case RulerType.ellipse:
        final rx = (r.settings.radiusX ?? 200) * sx;
        final ry = (r.settings.radiusY ?? 120) * sy;
        final c = ts(r.position);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(r.rotation);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), paint);
        canvas.restore();
        handle(c);
        handle(c + _rotateOffset(Offset(rx, 0), r.rotation));
        handle(c + _rotateOffset(Offset(0, ry), r.rotation));
        handle(c + _rotateOffset(Offset(rx + 50 * sx, 0), r.rotation));
      case RulerType.radial:
        final divs = r.settings.divisions ?? 12;
        final c = ts(r.position);
        final len = size.longestSide;
        for (int i = 0; i < divs; i++) {
          final a = (i / divs) * 3.14159265 * 2 + r.rotation;
          canvas.drawLine(c, c + Offset.fromDirection(a, len), paint);
        }
        handle(c);
        handle(c + Offset.fromDirection(r.rotation, 160 * sx));
      case RulerType.onePointPerspective:
        final vp = ts(r.settings.vanishingPoint1 ?? r.position);
        for (int i = 0; i <= 8; i++) {
          final t = i / 8.0;
          canvas.drawLine(vp, Offset(size.width * t, i.isEven ? 0 : size.height), paint);
        }
        handle(vp);
      case RulerType.twoPointPerspective:
        for (final vpp in [
          r.settings.vanishingPoint1 ?? const Offset(200, 540),
          r.settings.vanishingPoint2 ?? const Offset(1720, 540),
        ]) {
          final vp = ts(vpp);
          for (int i = 0; i <= 6; i++) {
            canvas.drawLine(vp, Offset(size.width * (i / 6.0), i.isEven ? 0 : size.height), paint);
          }
          handle(vp);
        }
      case RulerType.threePointPerspective:
        for (final vpp in [
          r.settings.vanishingPoint1 ?? const Offset(200, 540),
          r.settings.vanishingPoint2 ?? const Offset(1720, 540),
          r.settings.vanishingPoint3 ?? const Offset(960, 100),
        ]) {
          final vp = ts(vpp);
          for (int i = 0; i <= 4; i++) {
            canvas.drawLine(vp, Offset(size.width * (i / 4.0), i.isEven ? 0 : size.height), paint);
          }
          handle(vp);
        }
      case RulerType.circle:
        break;
    }
  }

  Offset _rotateOffset(Offset v, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  /// belowImage/aboveImage（フレーム全体サイズの合成済み画像）を描画領域へ
  /// スケールして描画する。不透明度・ブレンドモードは合成時に既に各レイヤーへ
  /// 適用済みのため、ここではスケーリングのみ行う。
  void _drawFrameImage(Canvas canvas, Rect drawingRect, ui.Image? image, Paint paint) {
    if (image == null) return;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, src, drawingRect, paint);
  }

  void _drawOnionFrame(
      Canvas canvas, Rect drawingRect, ui.Image img, int offset) {
    final opacity = onionEngine.getOpacityForFrame(onionSettings, offset);
    final color = onionEngine.getColorForFrame(onionSettings, offset);
    final src =
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(
        img,
        src,
        drawingRect,
        Paint()
          ..colorFilter = ui.ColorFilter.mode(
              color.withValues(alpha: opacity), BlendMode.srcATop));
  }

  Rect _calcExportRect(Size size) {
    final exportW = project?.exportWidth.toDouble() ?? 1920.0;
    final exportH = project?.exportHeight.toDouble() ?? 1080.0;
    final scale = project?.drawingAreaScale ?? 1.0;
    final availW = size.width / scale;
    final availH = size.height / scale;
    final aspectRatio = exportW / exportH;
    final double w, h;
    if (availW / availH > aspectRatio) {
      h = availH;
      w = h * aspectRatio;
    } else {
      w = availW;
      h = w / aspectRatio;
    }
    return Rect.fromLTWH(
        (size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  void _paintBackground(Canvas canvas, Rect rect) {
    if (background == CanvasBackground.white) {
      canvas.drawRect(rect, Paint()..color = Colors.white);
    } else {
      _paintChecker(canvas, rect);
    }
  }

  void _paintChecker(Canvas canvas, Rect rect) {
    final rawX = transform.getTranslation().x % _checkerSize;
    final rawY = transform.getTranslation().y % _checkerSize;
    final offsetX = rawX < 0 ? rawX + _checkerSize : rawX;
    final offsetY = rawY < 0 ? rawY + _checkerSize : rawY;
    final modX =
        ((rect.left - offsetX) % _checkerSize + _checkerSize) % _checkerSize;
    final modY =
        ((rect.top - offsetY) % _checkerSize + _checkerSize) % _checkerSize;
    final startX = rect.left - modX;
    final startY = rect.top - modY;
    final cols = ((rect.right - startX) / _checkerSize).ceil() + 1;
    final rows = ((rect.bottom - startY) / _checkerSize).ceil() + 1;
    final gridCol0 = ((startX - offsetX) / _checkerSize).round();
    final gridRow0 = ((startY - offsetY) / _checkerSize).round();
    canvas.save();
    canvas.clipRect(rect);
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        canvas.drawRect(
          Rect.fromLTWH(startX + col * _checkerSize,
              startY + row * _checkerSize, _checkerSize, _checkerSize),
          Paint()
            ..color = ((gridRow0 + row) + (gridCol0 + col)).isEven
                ? const Color.fromARGB(255, 242, 242, 242)
                : const Color.fromARGB(255, 167, 167, 167),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.compositeImage != compositeImage ||
      old.belowImage != belowImage ||
      old.aboveImage != aboveImage ||
      old.currentLayerOpacity != currentLayerOpacity ||
      old.currentLayerBlendMode != currentLayerBlendMode ||
      old.background != background ||
      old.transform != transform ||
      old.onionImages != onionImages ||
      old.selectionStart != selectionStart ||
      old.selectionEnd != selectionEnd ||
      old.selectionOverlayImage != selectionOverlayImage ||
      old.lassoPoints != lassoPoints ||
      old.subToolStrokePoints != subToolStrokePoints ||
      old.activeRuler != activeRuler ||
      old.shapeKind != shapeKind ||
      old.shapeStart != shapeStart ||
      old.shapeEnd != shapeEnd ||
      old.moveDelta != moveDelta ||
      old.transformLive != transformLive ||
      old.showTransformHandles != showTransformHandles ||
      old.project?.drawingAreaScale != project?.drawingAreaScale ||
      old.project?.exportWidth != project?.exportWidth ||
      old.project?.exportHeight != project?.exportHeight;
}
