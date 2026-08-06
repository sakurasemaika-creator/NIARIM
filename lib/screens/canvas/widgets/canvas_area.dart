import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../engine/bucket_fill_engine.dart';
import '../../../engine/drawing_engine.dart';
import '../../../engine/input_handler.dart';
import '../../../engine/onion_skin.dart';
import '../../../engine/ruler_engine.dart';
import '../../../engine/tile_manager.dart';
import '../../../engine/undo_manager.dart' as app_undo;
import '../../../models/onion_skin_settings.dart';
import '../../../models/project.dart';
import '../../../models/ruler.dart';
import '../../../services/brush_service.dart';
import '../../../services/project_service.dart';
import '../../../services/settings_service.dart';
import '../canvas_screen.dart';

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
  final OnionSkinSettings onionSkinSettings;
  final int currentFrame;
  final String sceneId;
  final Ruler? activeRuler;
  final ShapeKind shapeKind;

  const CanvasArea({
    super.key,
    this.onTapForText,
    this.onEyedropper,
    this.project,
    this.background = CanvasBackground.white,
    this.currentLayerId,
    this.isEraser = false,
    this.currentTool = DrawingTool.pen,
    this.onionSkinSettings = const OnionSkinSettings(),
    this.currentFrame = 0,
    this.sceneId = '',
    this.activeRuler,
    this.shapeKind = ShapeKind.off,
  });

  @override
  State<CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<CanvasArea> {
  final TransformationController _transformController = TransformationController();
  final InputHandler _inputHandler = InputHandler();
  final OnionSkinEngine _onionSkinEngine = OnionSkinEngine();
  final RulerEngine _rulerEngine = RulerEngine();

  late TileManager _tileManager;
  late DrawingEngine _drawingEngine;

  ui.Image? _compositeImage;
  final Map<int, ui.Image> _onionImages = {};
  bool _isCompositing = false;

  Offset? _selectionStart;
  Offset? _selectionEnd;
  List<Offset> _lassoPoints = [];
  int _touchCount = 0;

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
  }

  @override
  void didUpdateWidget(CanvasArea old) {
    super.didUpdateWidget(old);
    if (old.project?.id != widget.project?.id) {
      _compositeImage?.dispose();
      _compositeImage = null;
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
  }

  @override
  void dispose() {
    _transformController.dispose();
    _compositeImage?.dispose();
    for (final img in _onionImages.values) {
      img.dispose();
    }
    super.dispose();
  }

  // ─── 入力 ─────────────────────────────────────────────────────────────

  String get _layerId => widget.currentLayerId ?? 'Layer0001';

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

  void _onPointerDown(PointerEvent event) {
    final type = _inputHandler.classifyInput(event);
    final canvasPos = _canvasPosition(event.localPosition);

    if (widget.currentTool == DrawingTool.text && widget.onTapForText != null) {
      widget.onTapForText!(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.eyedropper) {
      _pickColor(canvasPos);
      return;
    }
    if (widget.currentTool == DrawingTool.selectRect) {
      setState(() {
        _selectionStart = canvasPos;
        _selectionEnd = canvasPos;
      });
      return;
    }
    if (widget.currentTool == DrawingTool.selectLasso) {
      setState(() { _lassoPoints = [canvasPos]; });
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
    if (widget.currentTool == DrawingTool.bucket) {
      if (type == InputType.touch) return;
      _syncBrushAndColor();
      _handleBucketDown(canvasPos);
      return;
    }

    if (type == InputType.touch) return;
    _syncBrushAndColor();
    final snapped = widget.currentTool == DrawingTool.ruler
        ? _toCanvasPoint(_inputHandler.toStrokePoint(event))
        : _applyRulerSnap(_toCanvasPoint(_inputHandler.toStrokePoint(event)));
    _drawingEngine.beginStroke(snapped, _layerId);
    _scheduleComposite();
  }

  void _onPointerMove(PointerEvent event) {
    final type = _inputHandler.classifyInput(event);
    final canvasPos = _canvasPosition(event.localPosition);

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
    if (widget.currentTool == DrawingTool.bucket) {
      if (type == InputType.touch) return;
      _handleBucketMove(canvasPos);
      return;
    }
    if (type == InputType.touch) return;
    if (widget.currentTool == DrawingTool.text ||
        widget.currentTool == DrawingTool.eyedropper) {
      return;
    }
    final snapped = _applyRulerSnap(_toCanvasPoint(_inputHandler.toStrokePoint(event)));
    _drawingEngine.continueStroke(snapped, _layerId);
    _scheduleComposite();
  }

  void _onPointerUp(PointerEvent event) {
    final type = _inputHandler.classifyInput(event);

    if (widget.currentTool == DrawingTool.selectRect) {
      setState(() {
        _selectionStart = null;
        _selectionEnd = null;
      });
      return;
    }
    if (widget.currentTool == DrawingTool.selectLasso) {
      setState(() => _lassoPoints = []);
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
    if (widget.currentTool == DrawingTool.bucket) {
      _handleBucketUp();
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
  }

  /// 自動塗り用線画レイヤーへ描画があった場合、直下の自動塗りレイヤーへ更新マークを立てる
  /// （仕様書16：needsAutofillUpdate自動セット）。
  void _markLineartDirtyIfNeeded() {
    final project = widget.project;
    if (project == null) return;
    context.read<ProjectService>().markLineartDirty(
        project.id, widget.sceneId, widget.currentFrame, _layerId);
  }

  void _pickColor(Offset canvasPos) {
    final (tx, ty) = _tileManager.getTileCoord(canvasPos.dx, canvasPos.dy);
    final tile = _tileManager.getTile(_layerId, tx, ty);
    if (tile == null) return;
    final px = canvasPos.dx.round() % TileManager.tileSize;
    final py = canvasPos.dy.round() % TileManager.tileSize;
    if (px < 0 || py < 0) return;
    final idx = (py * TileManager.tileSize + px) * 4;
    if (idx + 3 >= tile.length) return;
    widget.onEyedropper?.call(
        Color.fromARGB(tile[idx + 3], tile[idx], tile[idx + 1], tile[idx + 2]));
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
    _drawingEngine.commitShapePath(
      points.map((p) => StrokePoint(x: p.dx, y: p.dy)).toList(),
      _layerId,
      closeLoop: closeLoop,
    );
    _scheduleComposite();
    _markLineartDirtyIfNeeded();
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
    _tileManager.translateLayer(_layerId, delta.dx, delta.dy).then((_) {
      if (!mounted) return;
      _scheduleComposite();
      _markLineartDirtyIfNeeded();
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
    _tileManager.transformLayer(_layerId, matrix.storage).then((_) {
      if (!mounted) return;
      _scheduleComposite();
      _markLineartDirtyIfNeeded();
    });
  }

  // ─── バケツ連続塗り ───────────────────────────────────────────────────

  Future<Uint8List> _flattenVisibleLayers() async {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final project = widget.project;
    if (project == null) return Uint8List(w * h * 4);
    final layers = context
        .read<ProjectService>()
        .layersOf(project.id, widget.sceneId, widget.currentFrame);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (final layer in layers.reversed) {
      if (!layer.isVisible) continue;
      final img = await _tileManager.compositeLayerToImage(layer.id);
      canvas.drawImage(img, ui.Offset.zero, ui.Paint());
      img.dispose();
    }
    final pic = recorder.endRecording();
    final image = await pic.toImage(w, h);
    pic.dispose();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return byteData?.buffer.asUint8List() ?? Uint8List(w * h * 4);
  }

  Future<void> _handleBucketDown(Offset canvasPos) async {
    final w = _tileManager.canvasWidth;
    final h = _tileManager.canvasHeight;
    final buffer = await _flattenVisibleLayers();
    if (!mounted) return;
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

    final result = _bucketEngine.fill(
      canvasData: reference,
      width: w,
      height: h,
      startX: x,
      startY: y,
      fillColor: _drawingEngine.currentColor,
    );

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
          final tile = _tileManager.getOrCreateTile(_layerId, tx, ty);
          final lx = px % TileManager.tileSize;
          final ly = py % TileManager.tileSize;
          _tileManager.blendPixel(
              tile, lx, ly, result[idx], result[idx + 1], result[idx + 2], result[idx + 3]);
          _tileManager.markDirty(_layerId, tx, ty);
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

  void _scheduleComposite() {
    if (_isCompositing) {
      setState(() {});
      return;
    }
    _isCompositing = true;
    _tileManager.compositeLayerToImage(_layerId).then((img) {
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
    final offsets = _onionSkinEngine.getVisibleFrameOffsets(widget.onionSkinSettings);
    final ps = context.read<ProjectService>();
    final newImages = <int, ui.Image>{};
    for (final offset in offsets) {
      final frameIdx = widget.currentFrame + offset;
      if (frameIdx < 0) continue;
      final layers = ps.layersOf(widget.project?.id ?? '', widget.sceneId, frameIdx);
      if (layers.isEmpty) continue;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      for (final layer in layers.reversed) {
        if (!layer.isVisible) continue;
        final img = await _tileManager.compositeLayerToImage(layer.id);
        canvas.drawImage(img, ui.Offset.zero, ui.Paint());
        img.dispose();
      }
      final pic = recorder.endRecording();
      newImages[offset] =
          await pic.toImage(_tileManager.canvasWidth, _tileManager.canvasHeight);
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
          panEnabled: !_inputHandler.isStylusActive,
          scaleEnabled: !_inputHandler.isStylusActive,
          child: CustomPaint(
            painter: _CanvasPainter(
              project: widget.project,
              background: widget.background,
              transform: _transformController.value,
              compositeImage: _compositeImage,
              onionImages: Map.unmodifiable(_onionImages),
              onionSettings: widget.onionSkinSettings,
              onionEngine: _onionSkinEngine,
              selectionStart: _selectionStart,
              selectionEnd: _selectionEnd,
              lassoPoints: _lassoPoints,
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
        // スポイトは次のタップ座標が必要なため状態変更のみ
        break;
      case GestureAction.eraserToggle:
        // 親ウィジェットへの通知が必要なため現状はno-op
        break;
      default:
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
  final Map<int, ui.Image> onionImages;
  final OnionSkinSettings onionSettings;
  final OnionSkinEngine onionEngine;
  final Offset? selectionStart;
  final Offset? selectionEnd;
  final List<Offset> lassoPoints;
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
    this.project,
    this.compositeImage,
    this.selectionStart,
    this.selectionEnd,
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

    // オニオンスキン（前フレーム）
    for (final entry in onionImages.entries) {
      if (entry.key >= 0) continue;
      _drawOnionFrame(canvas, drawingRect, entry.value, entry.key);
    }

    // 描画内容
    if (compositeImage != null) {
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
        canvas.drawImage(compositeImage!, Offset.zero, Paint());
        canvas.restore();
      } else {
        final src = Rect.fromLTWH(0, 0,
            compositeImage!.width.toDouble(), compositeImage!.height.toDouble());
        canvas.drawImageRect(compositeImage!, src, drawingRect, Paint());
      }
    }

    // オニオンスキン（後フレーム）
    for (final entry in onionImages.entries) {
      if (entry.key <= 0) continue;
      _drawOnionFrame(canvas, drawingRect, entry.value, entry.key);
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
        canvas.drawLine(Offset(0, c.dy), Offset(size.width, c.dy), paint);
        handle(c);
      case RulerType.ellipse:
        final rx = (r.settings.radiusX ?? 200) * sx;
        final ry = (r.settings.radiusY ?? 120) * sy;
        final c = ts(r.position);
        canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), paint);
        handle(c);
      case RulerType.radial:
        final divs = r.settings.divisions ?? 12;
        final c = ts(r.position);
        final len = size.longestSide;
        for (int i = 0; i < divs; i++) {
          final a = (i / divs) * 3.14159265 * 2;
          canvas.drawLine(c, c + Offset.fromDirection(a, len), paint);
        }
        handle(c);
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
      old.background != background ||
      old.transform != transform ||
      old.onionImages != onionImages ||
      old.selectionStart != selectionStart ||
      old.selectionEnd != selectionEnd ||
      old.lassoPoints != lassoPoints ||
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
