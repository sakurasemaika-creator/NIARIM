import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/brush.dart';
import '../models/brush_pressure_resolver.dart';
import 'brush_texture_cache.dart';
import 'texture_silhouette.dart';
import 'brush_texture_selector.dart';
import 'brush_render_plan.dart';
import 'brush_stroke_geometry.dart';
import 'hair_fold_raster.dart';
import 'oil_paint.dart';
import 'outline_accent.dart';
import 'perceptual_color_mixer.dart';
import 'pixel_line_path.dart';
import 'tile_manager.dart';
import 'watercolor_wash.dart';

final _jitterRng = math.Random();

class DrawingEngine {
  final TileManager tileManager;

  final List<StrokePoint> _currentStroke = [];

  // 1ストローク内の各画素の最大カバレッジを保持する。
  // ブラシ不透明度50%の線をspacing=1で引いた際、同じ画素へ多数のスタンプが
  // 重なって100%近くまで濃くなるのを防ぐ。別ストロークではリセットされるため、
  // 線同士を交差させた箇所は通常のsource-overどおり濃くなる。
  final _CoverageTiles _strokeCoverageByTile = _CoverageTiles();

  // 「重なりを維持する」をオフにした縁取りペンで、ストローク開始前の各画素の
  // 不透明度を保持する。縁取りはその下へ回り込み、既に描かれた所の上には
  // 描かれない（重なった所は縁取りせず、全体の周りだけを縁取る）。
  final Map<String, Uint8List> _strokeBaseAlpha = {};

  // ブラシの密度・散布を入力moveイベント数から独立させるため、ストロークを
  // またいで「直前のスタンプから進んだ距離」を保持する。各move区間の先頭で
  // spacingをリセットすると、同じ直線でもOSのイベント密度によって結果が
  // 変わるため、StampEngineと同じくパス長基準で再サンプリングする。
  double _distanceSinceLastBrushStamp = 0.0;
  bool _hasStampedCurrentStroke = false;
  String? _activeLayerId;
  math.Random _scatterRng = math.Random(0);
  HairFoldRaster? _foldRaster;
  final BrushTextureSelector _brushTextureSelector = BrushTextureSelector();
  double? _finalizedStrokeLengthOverride;

  /// How far along the stroke each cell ([_cellShift]) was reached while
  /// the stroke was drawn (the length at the furthest dab into it plus that
  /// dab's reach), keyed `cx << 24 | cy` in cells (for [redrawStrokeEnd]).
  final Map<int, double> _cellReach = {};

  /// A cell is 64 px square, 4 × 4 to a tile.
  static const _cellShift = 6;
  static const _cellsPerTile = TileManager.tileSize >> _cellShift;
  static const _allCells = (1 << _cellsPerTile * _cellsPerTile) - 1;

  /// While [redrawStrokeEnd] draws the stroke again: the only cells it draws
  /// into (keyed like [_cellReach]), and for each of their tiles (keyed
  /// `tx << 24 | ty`), those cells as bits (`row * 4 + column`).
  Set<int>? _redrawCells;
  Map<int, int>? _redrawMasks;

  /// The length along the stroke of the dab being drawn.
  double _stampLength = 0;

  /// Whether this stroke keeps [_cellReach] (its end may be drawn again).
  bool _recordsReach = false;
  bool _replayingFinalStroke = false;
  // 縁取りの強弱：ストローク全体の形から決まるので、ペンを離した後の
  // 描き直し（replayCurrentStrokeWithFinalFade）でだけ設定する。
  OutlineAccent? _outlineAccent;
  final List<ui.Offset> _strokeScreenPositions = [];
  // 油彩風の混色は絵の具の色ごとに、下の色ごとの混ざり方を覚えておく
  // （毛は下の色が変わったときだけ混ぜ直す）。近い色（各チャンネル4段）は
  // 同じものを使う。
  final Map<int, AnalogPaintMixer> _oilMixers = {};
  // 油彩風：このストロークで筆の毛が運んでいる絵の具と、塗る前のタイル。
  OilStroke? _oil;
  // 水彩風：このストロークの水彩の状態（ペンを離すと乾かす）。
  WatercolorStroke? _watercolor;
  // ピクセルモードの格子に置く線（_beginPixelStroke）。散布するブラシでは
  // 使わず、ドットを1つずつ格子へ寄せる。
  _PixelStroke? _pixelStroke;
  // ペン先の近くの、まだ変わりうる画素を描いている間、描く前の画素を覚える
  // （次に描き直す前に戻す）。
  _PixelLog? _pixelRecording;
  // 描いている点の形が、後の何点目の位置まで見たか（[_PixelLog.setSpan]）。
  int _pixelSpan = 0;
  // ピクセルモードの線を描き直している間に引いたタイル（[_writableTile]）。
  Map<int, Uint8List>? _updateTiles;
  String? _updateTilesLayer;
  // 描いている点に作った形（[_PixelLog.setShape]）。
  _PixelShapeCall? _pixelShapeCall;
  // 描き直しを決めるときに作った、[k]番目の点の形（描くときに使う）。
  ({int k, _PixelShapeCall call, int span})? _pixelShapeReady;

  String? get debugActiveBrushTexturePath => _brushTextureSelector.activePath;

  Brush? currentBrush;
  ui.Color currentColor = const ui.Color(0xFF000000);
  bool isEraser = false;
  bool pressureEnabled = true;

  // 定規など、手ブレ補正より後に必ず満たすべき最終座標制約。
  ui.Offset Function(ui.Offset)? pointConstraint;
  List<ui.Offset> Function(ui.Offset, ui.Offset)? curveBetween;
  double _strokeDistance = 0;

  // 手ブレ補正用：直近の平滑化済み座標（ON/OFF・強度調整）
  StrokePoint? _smoothed;

  DrawingEngine({required this.tileManager});

  void beginStroke(
    StrokePoint point,
    String layerId, {
    ui.Offset? screenPosition,
  }) {
    _currentStroke.clear();
    _strokeDistance = 0;
    _strokeScreenPositions.clear();
    _strokeCoverageByTile.clear();
    _strokeBaseAlpha.clear();
    if (!_replayingFinalStroke) {
      _cellReach.clear();
      final brush = currentBrush;
      _recordsReach =
          brush != null &&
          !brush.outlineEnabled &&
          !brush.pixelMode &&
          (brush.colourFadeMode != FadeMode.off ||
              brush.shapeTaperMode != FadeMode.off);
    }
    _foldRaster = null;
    _oil = null;
    _watercolor = null;
    _smoothed = point;
    final effective = _replayingFinalStroke
        ? point
        : _applyPointConstraint(point);
    _activeLayerId = layerId;
    _distanceSinceLastBrushStamp = 0.0;
    _hasStampedCurrentStroke = false;
    _scatterRng = math.Random(0);
    final brush = currentBrush;
    if (brush != null && !_replayingFinalStroke) {
      _brushTextureSelector.beginStroke(
        brushId: brush.id,
        paths: brush.resolvedCustomImagePaths,
        mode: brush.customImageSelectionMode,
      );
    } else if (brush == null) {
      _brushTextureSelector.endStroke();
    } else {
      _brushTextureSelector.rewindDabs();
    }
    _foldRaster =
        brush != null && brush.outlineEnabled && brush.foldEnabled && !isEraser
        ? HairFoldRaster(tileManager, layerId)
        : null;
    _currentStroke.add(effective);
    _strokeScreenPositions.add(
      screenPosition ?? ui.Offset(effective.x, effective.y),
    );
    if (_beginPixelStroke(effective, layerId)) return;
    final needsDirection =
        brush != null && (brush.rotation || brush.scatter > 0.0);
    if (!needsDirection) {
      _stampBrush(
        effective.x,
        effective.y,
        effective.pressure,
        effective.tiltX,
        effective.tiltY,
        layerId,
        strokeLengthOverride: 0.0,
      );
      _hasStampedCurrentStroke = true;
    }
  }

  void continueStroke(
    StrokePoint point,
    String layerId, {
    ui.Offset? screenPosition,
  }) {
    if (_currentStroke.isEmpty) {
      beginStroke(point, layerId, screenPosition: screenPosition);
      return;
    }
    final effective = _replayingFinalStroke
        ? point
        : _applyPointConstraint(_applyStabilization(point));
    _appendStrokePoint(effective, layerId, screenPosition);
  }

  /// Brings the smoothed line to the lift position before the final fade or
  /// outline is computed. The lift reuses the last contact's pressure and tilt.
  void finishStrokePath(
    StrokePoint lastContact,
    String layerId, {
    required ui.Offset canvasPosition,
    required ui.Offset screenPosition,
  }) {
    if (_currentStroke.isEmpty) return;
    final end = _applyPointConstraint(
      StrokePoint(
        x: canvasPosition.dx,
        y: canvasPosition.dy,
        pressure: lastContact.pressure,
        tiltX: lastContact.tiltX,
        tiltY: lastContact.tiltY,
        inputType: lastContact.inputType,
      ),
    );
    if (_distance(_currentStroke.last, end) <= 0.0001) return;
    _appendStrokePoint(end, layerId, screenPosition);
  }

  void _appendStrokePoint(
    StrokePoint effective,
    String layerId,
    ui.Offset? screenPosition,
  ) {
    final from = _currentStroke.last;
    final end = ui.Offset(effective.x, effective.y);
    final intermediate = _replayingFinalStroke
        ? const <ui.Offset>[]
        : curveBetween?.call(ui.Offset(from.x, from.y), end) ??
              const <ui.Offset>[];
    final screenFrom = _strokeScreenPositions.last;
    final screenTo = screenPosition ?? end;

    void add(StrokePoint point, ui.Offset screen) {
      final previous = _currentStroke.last;
      if (!(_foldRaster?.replacesStroke ?? false)) {
        _renderStrokeSegment(previous, point, layerId);
      }
      _strokeDistance += _distance(previous, point);
      _currentStroke.add(point);
      _strokeScreenPositions.add(screen);
    }

    for (var i = 0; i < intermediate.length; i++) {
      final offset = intermediate[i];
      final t = (i + 1) / (intermediate.length + 1);
      add(
        StrokePoint(
          x: offset.dx,
          y: offset.dy,
          pressure: from.pressure + (effective.pressure - from.pressure) * t,
          tiltX: from.tiltX + (effective.tiltX - from.tiltX) * t,
          tiltY: from.tiltY + (effective.tiltY - from.tiltY) * t,
          inputType: effective.inputType,
        ),
        ui.Offset.lerp(screenFrom, screenTo, t)!,
      );
    }
    add(effective, screenTo);
    _rebuildHairFold();
    if (_pixelStroke != null && !_replayingFinalStroke) {
      _updatePixelStroke(layerId);
    }
  }

  /// Whether the stroke is drawn again once it is complete: a フェード or
  /// 入り抜き needs its total length (for the ramp at the end), and an
  /// outline's 強弱 the whole stroke's curves. One that only changes the
  /// start of a stroke longer than its two distances was already drawn as it
  /// will be.
  bool get needsFinalFadeReplay {
    if (_currentStroke.isEmpty) return false;
    if (_accentsOutline) return true;
    final brush = currentBrush;
    if (brush == null) return false;
    if (brush.outlineEnabled) return brush.shapeTaperMode != FadeMode.off;
    final ramps = [
      if (brush.colourFadeMode != FadeMode.off) _fadeRamp(brush),
      if (brush.shapeTaperMode != FadeMode.off) _taperRamp(brush),
    ];
    if (ramps.isEmpty) return false;
    var total = 0.0;
    for (var i = 1; i < _currentStroke.length; i++) {
      total += _distance(_currentStroke[i - 1], _currentStroke[i]);
    }
    for (final ramp in ramps) {
      if (ramp.outRange > 0 && ramp.outValue < 1) return true;
      if (ramp.inRange + ramp.outRange > total) return true;
    }
    return false;
  }

  bool get _accentsOutline {
    final brush = currentBrush;
    return brush != null &&
        brush.outlineEnabled &&
        brush.outlineAccentEnabled &&
        !isEraser;
  }

  OutlineAccent _accentOf(Brush brush, List<StrokePoint> points) =>
      OutlineAccent.of(
        [for (final p in points) ui.Offset(p.x, p.y)],
        base: brush.outlineWidth,
        apex: brush.outlineAccentWidth,
        span: brush.size,
      );

  void replayCurrentStrokeWithFinalFade() {
    if (!needsFinalFadeReplay || _activeLayerId == null) return;
    final points = List<StrokePoint>.of(_currentStroke);
    final screen = List<ui.Offset>.of(_strokeScreenPositions);
    final layerId = _activeLayerId!;
    var totalLength = 0.0;
    for (var i = 1; i < points.length; i++) {
      totalLength += _distance(points[i - 1], points[i]);
    }
    _currentStroke.clear();
    _strokeDistance = 0;
    _strokeCoverageByTile.clear();
    _strokeBaseAlpha.clear();
    _distanceSinceLastBrushStamp = 0.0;
    _hasStampedCurrentStroke = false;
    _finalizedStrokeLengthOverride = totalLength;
    final brush = currentBrush;
    _outlineAccent = brush != null && _accentsOutline
        ? _accentOf(brush, points)
        : null;
    _replayingFinalStroke = true;
    try {
      beginStroke(points.first, layerId, screenPosition: screen.first);
      for (var i = 1; i < points.length; i++) {
        continueStroke(points[i], layerId, screenPosition: screen[i]);
      }
    } finally {
      _replayingFinalStroke = false;
    }
    _rebuildHairFold();
  }

  /// Draws again, with the stroke's final length, only where the end of the
  /// stroke changes (the tiles reached from within the end's フェード or
  /// 入り抜き), keeping what was drawn elsewhere: the same pixels as putting
  /// the tiles back as they were before the stroke and calling
  /// [replayCurrentStrokeWithFinalFade], for a fraction of the work. The tile
  /// manager must be recording the stroke's undo: the tiles drawn again are
  /// put back from that record, which stays as it is.
  ///
  /// Returns false, having done nothing, when the stroke has to be drawn
  /// again whole: a stroke shorter than its two distances (its start
  /// changes too), an outline pen (its fold and 強弱 take the whole stroke),
  /// the pixel grid, colour mixing (the bristles and the wash carry paint
  /// along the stroke).
  bool redrawStrokeEnd() {
    if (!needsFinalFadeReplay) return false;
    final brush = currentBrush;
    final layerId = _activeLayerId;
    if (brush == null ||
        layerId == null ||
        brush.outlineEnabled ||
        _accentsOutline ||
        _foldRaster != null ||
        _pixelStroke != null ||
        brush.pixelMode ||
        _oil != null ||
        _watercolor != null ||
        brush.pressureOn.mixing.enabled ||
        brush.pressureOff.mixing.enabled) {
      return false;
    }
    final recording = tileManager.recordingTouchedTiles;
    if (recording == null || recording.layerId != layerId) return false;
    var total = 0.0;
    for (var i = 1; i < _currentStroke.length; i++) {
      total += _distance(_currentStroke[i - 1], _currentStroke[i]);
    }
    var end = 0.0;
    for (final ramp in [
      if (brush.colourFadeMode != FadeMode.off)
        _fadeRamp(brush, totalLength: total),
      if (brush.shapeTaperMode != FadeMode.off)
        _taperRamp(brush, totalLength: total),
    ]) {
      if (ramp.shrunk) return false;
      if (ramp.outValue < 1 && ramp.outRange > end) end = ramp.outRange;
    }
    if (end <= 0) return false;
    // A dab changes when its length is within the end's distance (its
    // width) or its reach is (its colour, laid per pixel along the
    // stroke). Its dabs are where they were (the spacing does not depend
    // on the width), no wider than they were, and the same up to there.
    final from = total - end - 1;
    // The cells to draw again, and all the cells the stroke reached, by tile.
    final touched = <int, int>{};
    final masks = <int, int>{};
    for (final entry in _cellReach.entries) {
      final cx = entry.key >> 24;
      final cy = entry.key & 0xFFFFFF;
      final tileKey = (cx ~/ _cellsPerTile) << 24 | cy ~/ _cellsPerTile;
      final bit =
          1 << (cy % _cellsPerTile * _cellsPerTile + cx % _cellsPerTile);
      touched[tileKey] = (touched[tileKey] ?? 0) | bit;
      if (entry.value >= from) masks[tileKey] = (masks[tileKey] ?? 0) | bit;
    }
    // A tile whose every reached cell is drawn again is put back whole (as
    // drawing the stroke whole would, it is there afterwards only if a dab
    // reaches it); the rest keep their tile, reached by dabs that stay.
    final whole = <String>[];
    final cells = <int>{};
    for (final entry in masks.entries) {
      final tx = entry.key >> 24;
      final ty = entry.key & 0xFFFFFF;
      var mask = entry.value;
      if (mask == touched[entry.key]) {
        whole.add('$tx,$ty');
        mask = masks[entry.key] = _allCells;
      } else {
        tileManager.restoreRecordedCells(
          layerId,
          tx,
          ty,
          mask,
          1 << _cellShift,
        );
      }
      for (var bit = 0; bit < _cellsPerTile * _cellsPerTile; bit++) {
        if (mask & 1 << bit == 0) continue;
        cells.add(
          (tx * _cellsPerTile + bit % _cellsPerTile) << 24 |
              ty * _cellsPerTile + bit ~/ _cellsPerTile,
        );
      }
    }
    tileManager.restoreRecordedTiles(layerId, whole);
    _redrawCells = cells;
    _redrawMasks = masks;
    try {
      replayCurrentStrokeWithFinalFade();
    } finally {
      _redrawCells = null;
      _redrawMasks = null;
    }
    return true;
  }

  /// Whether a square [reach] px round ([x], [y]) touches any of [cells]
  /// (keyed like [_cellReach]).
  static bool _reachesAny(Set<int> cells, double x, double y, double reach) {
    final minX = math.max(0, (x - reach).floor()) >> _cellShift;
    final maxX = (x + reach).ceil() >> _cellShift;
    final minY = math.max(0, (y - reach).floor()) >> _cellShift;
    final maxY = (y + reach).ceil() >> _cellShift;
    for (var cy = minY; cy <= maxY; cy++) {
      for (var cx = minX; cx <= maxX; cx++) {
        if (cells.contains(cx << 24 | cy)) return true;
      }
    }
    return false;
  }

  void endStroke({bool cancel = false}) {
    if (!cancel) _rebuildHairFold(finalize: true);
    if (!cancel && _activeLayerId != null && _pixelStroke != null) {
      _updatePixelStroke(_activeLayerId!, finish: true);
    }
    _pixelStroke = null;
    _pixelRecording = null;
    // 回転/散布ONでPointerDown→Upだけのタップだった場合は進行方向が存在しない。
    // その場合だけ中心位置へ1回描画し、散布は行わない。
    if (!cancel &&
        !_hasStampedCurrentStroke &&
        _currentStroke.isNotEmpty &&
        _activeLayerId != null) {
      final point = _currentStroke.first;
      _stampBrush(
        point.x,
        point.y,
        point.pressure,
        point.tiltX,
        point.tiltY,
        _activeLayerId!,
        strokeLengthOverride: 0.0,
        applyScatter: false,
      );
    }
    if (!cancel) _watercolor?.finish(tileManager);
    _watercolor = null;
    _oil = null;
    _currentStroke.clear();
    _strokeDistance = 0;
    _strokeCoverageByTile.clear();
    _strokeBaseAlpha.clear();
    _smoothed = null;
    _activeLayerId = null;
    _distanceSinceLastBrushStamp = 0.0;
    _hasStampedCurrentStroke = false;
    _foldRaster = null;
    _strokeScreenPositions.clear();
    _brushTextureSelector.endStroke();
    _finalizedStrokeLengthOverride = null;
    _outlineAccent = null;
  }

  Brush? _foldViewSource;
  Brush? _foldView;

  /// [brush] as the fold's drawing reads it: that takes the shape of the
  /// ends from the fade fields, so they carry the brush's 入り抜き. The same
  /// brush gives the same object (the fold keeps its work while it does).
  Brush _foldViewOf(Brush brush) {
    if (brush.taperMode == FadeMode.off) return brush;
    if (!identical(brush, _foldViewSource)) {
      _foldViewSource = brush;
      _foldView = brush.copyWith(
        fadeMode: brush.taperMode,
        fadeIn: brush.taperIn,
        fadeOut: brush.taperOut,
      );
    }
    return _foldView!;
  }

  void _rebuildHairFold({bool finalize = false}) {
    // Final fade replay already knows the complete input: rasterize the fold
    // once after replay instead of rebuilding every intermediate prefix.
    if (_replayingFinalStroke) return;
    final brush = currentBrush;
    final raster = _foldRaster;
    if (brush == null || raster == null) return;
    final samples = <HairRibbonPoint>[];
    final taper = _taperRamp(
      brush,
      totalLength: _finalizedStrokeLengthOverride,
    );
    // 強弱 while drawing follows the curves drawn so far; once the stroke
    // is complete, its final curves.
    final accent =
        _outlineAccent ??
        (_accentsOutline ? _accentOf(brush, _currentStroke) : null);
    void add(ui.Offset position, double curvedPressure, double distance) {
      final pressure = resolveBrushPressure(
        brush: brush,
        pressureEnabled: pressureEnabled,
        curvedPressure: curvedPressure,
      );
      final scale = pressure.sizeScale * taper.at(distance);
      samples.add(
        HairRibbonPoint(
          position,
          (brush.size * scale).clamp(0, 2000).toDouble(),
          // Pressure and taper shape the strand, outline included
          // (outlinedStrokeRadii); they never fade it.
          (brush.opacity /
                  100 *
                  (brush.strokeDecay ? _calculateDecay(distance) : 1) *
                  currentColor.a)
              .clamp(0.0, 1.0)
              .toDouble(),
          scale,
          accent?.at(distance),
        ),
      );
    }

    // Within a custom taper the width follows a curve, while the strand
    // is drawn with widths straight between its points: a long segment
    // there (a fast flick) gets points every 2px, so the tail has the same
    // shape as the ordinary stamps give it.
    bool inTaper(double from, double to) =>
        brush.shapeTaperMode != FadeMode.off &&
        ((taper.inRange > 0 && from < taper.inRange) ||
            (taper.total != null &&
                taper.outRange > 0 &&
                to > taper.total! - taper.outRange));
    var distance = 0.0;
    for (var i = 0; i < _currentStroke.length; i++) {
      final point = _currentStroke[i];
      if (i > 0) {
        final previous = _currentStroke[i - 1];
        final length = _distance(previous, point);
        if (length > 4 && inTaper(distance, distance + length)) {
          final steps = (length / 2).ceil();
          for (var k = 1; k < steps; k++) {
            final t = k / steps;
            add(
              ui.Offset(
                previous.x + (point.x - previous.x) * t,
                previous.y + (point.y - previous.y) * t,
              ),
              previous.pressure + (point.pressure - previous.pressure) * t,
              distance + length * t,
            );
          }
        }
        distance += length;
      }
      add(ui.Offset(point.x, point.y), point.pressure, distance);
    }
    final texture = _brushTextureSelector.activePath;
    raster.render(
      points: samples,
      taperEnd: finalize,
      brush: _foldViewOf(brush),
      fillColor: currentColor,
      texture: texture == null
          ? null
          : getCachedBrushTexture(texture, mode: brush.imageInkMode),
    );
    // A waiting crescent leaves the ordinary stroke and its shared outline
    // coverage in place; clearing it would outline every stamp separately.
    if (raster.replacesStroke) _strokeCoverageByTile.clear();
  }

  StrokePoint _applyPointConstraint(StrokePoint point) {
    final constraint = pointConstraint;
    if (constraint == null) return point;
    final constrained = constraint(ui.Offset(point.x, point.y));
    return StrokePoint(
      x: constrained.dx,
      y: constrained.dy,
      pressure: point.pressure,
      tiltX: point.tiltX,
      tiltY: point.tiltY,
      inputType: point.inputType,
    );
  }

  /// 手ぶれ補正で、次の点を入力の方へ寄せる割合（強さ0で1＝そのまま、100で
  /// 0.15）。設定の試し書き欄も同じ式でならす。
  static double stabilizationFactor(int strength) =>
      (1.0 - strength.clamp(0, 100) / 100.0 * 0.85).clamp(0.05, 1.0);

  /// 手ぶれ補正の強さ（0〜100、0で補正しない）。アプリの設定の値で、どの
  /// ブラシにも同じ強さで効く（ブラシの`stabilization`は使わない）。
  int stabilizationStrength = 0;

  /// 手ブレ補正：入力座標を直近の平滑化済み座標へ指数移動平均で追従させる。
  /// strengthが高いほど追従を遅くし、線が滑らかになる（軽量・毎ピクセル計算なし）。
  StrokePoint _applyStabilization(StrokePoint raw) {
    if (currentBrush == null || stabilizationStrength <= 0) {
      _smoothed = raw;
      return raw;
    }
    final prev = _smoothed ?? raw;
    final factor = stabilizationFactor(stabilizationStrength);
    final smoothedPoint = StrokePoint(
      x: prev.x + (raw.x - prev.x) * factor,
      y: prev.y + (raw.y - prev.y) * factor,
      pressure: raw.pressure,
      tiltX: raw.tiltX,
      tiltY: raw.tiltY,
      inputType: raw.inputType,
    );
    _smoothed = smoothedPoint;
    return smoothedPoint;
  }

  /// 図形ツール確定描画（線・四角形・円）のブラシ版。現在のブラシ設定
  /// （サイズ・不透明度・フェード等を除く形状ラスタライズ）を使い、パス上を
  /// ブラシでなぞって描画する。トーンでの図形描画は本メソッドではなく
  /// 呼び出し側（canvas_area.dartの_commitShapeWithTone）がToneEngineへ
  /// 直接分岐する（ブラシ・トーンどちらでも描画可能）。
  ///
  /// [ellipse]を渡すと、ピクセルモードでは多角形の点ではなく、その四角に
  /// 内接する画素の楕円を描く。
  void commitShapePath(
    List<StrokePoint> pathPoints,
    String layerId, {
    bool closeLoop = false,
    bool removePixelCorners = true,
    ui.Rect? ellipse,
  }) {
    if (currentBrush == null || pathPoints.isEmpty) return;
    _currentStroke.clear();
    _strokeDistance = 0;
    _strokeCoverageByTile.clear();
    _strokeBaseAlpha.clear();
    _activeLayerId = layerId;
    _distanceSinceLastBrushStamp = 0.0;
    _hasStampedCurrentStroke = false;
    _scatterRng = math.Random(0);
    final brush = currentBrush!;
    _brushTextureSelector.beginStroke(
      brushId: brush.id,
      paths: brush.resolvedCustomImagePaths,
      mode: brush.customImageSelectionMode,
    );

    final first = pathPoints.first;
    _currentStroke.add(first);
    // 図形は手の震えが無いので、画素の境目でそのまま次の画素へ移り、ランも
    // 整えない。四角形の角は角の画素も描く。
    if (_beginPixelStroke(
      first,
      layerId,
      hysteresis: 0,
      reverseHysteresis: 0,
      removeCorners: removePixelCorners,
      window: 0,
      shape: true,
    )) {
      final stroke = _pixelStroke!;
      if (ellipse != null && stroke.traces.length == 1) {
        stroke.fixedChain = _pixelEllipseChain(ellipse, stroke.corners);
        stroke.closed = true;
      } else {
        for (int i = 1; i < pathPoints.length; i++) {
          final to = pathPoints[i];
          final previous = _currentStroke.last;
          _renderStrokeSegment(previous, to, layerId);
          _strokeDistance += _distance(previous, to);
          _currentStroke.add(to);
        }
        if (closeLoop && pathPoints.length > 1) {
          _renderStrokeSegment(_currentStroke.last, first, layerId);
          stroke.closed = true;
        }
      }
      endStroke();
      return;
    }
    final needsDirection = brush.rotation || brush.scatter > 0.0;
    if (!needsDirection) {
      _stampBrush(
        first.x,
        first.y,
        first.pressure,
        first.tiltX,
        first.tiltY,
        layerId,
        strokeLengthOverride: 0.0,
      );
      _hasStampedCurrentStroke = true;
    }
    for (int i = 1; i < pathPoints.length; i++) {
      final to = pathPoints[i];
      final previous = _currentStroke.last;
      _renderStrokeSegment(previous, to, layerId);
      _strokeDistance += _distance(previous, to);
      _currentStroke.add(to);
    }
    if (closeLoop && pathPoints.length > 1) {
      _renderStrokeSegment(_currentStroke.last, first, layerId);
    }
    endStroke();
  }

  void _renderStrokeSegment(StrokePoint from, StrokePoint to, String layerId) {
    if (currentBrush == null) return;
    final brush = currentBrush!;
    final distance = _distance(from, to);
    if (distance <= 1e-9) return;
    if (_pixelStroke != null) {
      _feedPixelStroke(from, to, distance);
      return;
    }

    final safeDensity = brush.density.clamp(0.1, 5.0).toDouble();
    final spacing = _brushStampSpacing(brush, safeDensity);
    final pathAngle = math.atan2(to.y - from.y, to.x - from.x);
    // この区間より前に実際に進んだ距離。各補間スタンプでは
    // base + consumed を使うため、1回の大きなmoveでも多数の小さなmoveでも
    // フェード/ストローク減衰が同じ距離位置で同じ値になる。
    final baseStrokeLength = _strokeDistance;

    // 回転/散布ではPointerDown時点で保留した初点を、最初の実移動から得た
    // 接線方向を使って描く。これで先頭だけ角度0・散布方向固定にならない。
    if (!_hasStampedCurrentStroke) {
      _stampBrush(
        from.x,
        from.y,
        from.pressure,
        from.tiltX,
        from.tiltY,
        layerId,
        strokeLengthOverride: baseStrokeLength,
        pathAngle: pathAngle,
        hasPathDirection: true,
      );
      _hasStampedCurrentStroke = true;
      _distanceSinceLastBrushStamp = 0.0;
    }

    var consumed = 0.0;
    while (_distanceSinceLastBrushStamp + (distance - consumed) >=
        spacing - 1e-9) {
      final needed = math.max(0.0, spacing - _distanceSinceLastBrushStamp);
      consumed += needed;
      final t = (consumed / distance).clamp(0.0, 1.0);
      final x = _stableDouble(from.x + (to.x - from.x) * t);
      final y = _stableDouble(from.y + (to.y - from.y) * t);
      final pressure = from.pressure + (to.pressure - from.pressure) * t;
      final tiltX = from.tiltX + (to.tiltX - from.tiltX) * t;
      final tiltY = from.tiltY + (to.tiltY - from.tiltY) * t;
      _stampBrush(
        x,
        y,
        pressure,
        tiltX,
        tiltY,
        layerId,
        strokeLengthOverride: baseStrokeLength + consumed,
        pathAngle: pathAngle,
        hasPathDirection: true,
      );
      _distanceSinceLastBrushStamp = 0.0;
    }
    _distanceSinceLastBrushStamp += distance - consumed;
    if (_distanceSinceLastBrushStamp.abs() < 1e-9) {
      _distanceSinceLastBrushStamp = 0.0;
    }
  }

  double _brushStampSpacing(Brush brush, double safeDensity) {
    // 装飾チェーンはブラシ径を変更したときもリンク同士の比率が崩れないよう、
    // 絶対pxのspacingではなくブラシサイズ比例で配置する。
    final factor = brush.tipSpacingFactor;
    if (factor > 0) {
      return math.max(1.0, brush.size * factor / safeDensity);
    }
    final pressureSize = brush.pressureOn.size;
    final minPressureScale = pressureEnabled && pressureSize.enabled
        ? math.min(pressureSize.weak, pressureSize.strong) / 100.0
        : 1.0;
    // A one-pixel gap between dab centers is still visible on the edge of a
    // fine or tapered stroke. Sample those continuous strokes at half-pixels.
    // Wider explicit gaps and shaped/texture tips keep their stamp rhythm.
    // 入り抜き narrows the width (the fade changes only the colour): a stroke
    // is fine where its ends are narrowest. Outline pens always take
    // half-pixels when they taper.
    final narrowest = brush.shapeTaperMode == FadeMode.off
        ? 1.0
        : brush.outlineEnabled
        ? 0.0
        : _narrowestTaper(brush);
    if (brush.spacing == 1 &&
        safeDensity >= 1 &&
        !brush.pixelMode &&
        brush.tipShape == BrushTipShape.round &&
        brush.scatter == 0 &&
        brush.size * minPressureScale * narrowest <= 2) {
      return 0.5;
    }
    return math.max(1.0, brush.spacing.toDouble() / safeDensity);
  }

  /// The narrowest 入り抜き makes a dab, as a share of its width.
  double _narrowestTaper(Brush brush) {
    final ramp = _endsRamp(
      brush.shapeTaperMode,
      brush.shapeTaperIn,
      brush.shapeTaperOut,
      fitsShortStroke: false,
    );
    var narrowest = 1.0;
    if (ramp.inRange > 0) narrowest = math.min(narrowest, ramp.inValue);
    if (ramp.outRange > 0) narrowest = math.min(narrowest, ramp.outValue);
    return narrowest;
  }

  double _stableDouble(double value) => (value * 1000000).round() / 1000000;

  /// ピクセルモードで、どのドットも画素の格子に置くブラシか（丸いペン先。
  /// 折り畳みの髪のブラシは、折り畳みの描画が線を描く）。
  bool _onPixelGrid(Brush brush) =>
      brush.pixelMode &&
      brush.tipShape == BrushTipShape.round &&
      !(brush.outlineEnabled && brush.foldEnabled);

  /// 格子に置くブラシの線の描き方。散布するブラシはnull（ドットを1つずつ
  /// 格子へ寄せる、[_stampBrush]）。
  _PixelKind? _pixelKindOf(Brush brush) {
    if (!_onPixelGrid(brush) || brush.scatter > 0) return null;
    if (brush.resolvedCustomImagePaths.isNotEmpty ||
        _brushStampSpacing(brush, brush.density.clamp(0.1, 5.0).toDouble()) >
            1) {
      return _PixelKind.stamps;
    }
    return brush.calligraphyAngle != null ? _PixelKind.nib : _PixelKind.line;
  }

  /// 太さを画素の数に丸めたもの。
  static int _pixelDiameter(double size) => math.max(1, size.round());

  /// 格子点：偶数の太さの線は画素の角（その角を中心にドットを置く）、
  /// 奇数は画素。
  static PixelPoint _pixelPointAt(double x, double y, bool corners) => corners
      ? (x: (x + 0.5).floor(), y: (y + 0.5).floor())
      : (x: x.floor(), y: y.floor());

  /// ピクセルモードの格子に置くブラシなら、ペン先の通る格子点をたどって
  /// 1点ずつ置く線を始める（最初の点もすぐ描く）。
  bool _beginPixelStroke(
    StrokePoint point,
    String layerId, {
    double hysteresis = kPixelLineHysteresis,
    double reverseHysteresis = kPixelLineReverseHysteresis,
    bool removeCorners = true,
    int window = kPixelRunWindow,
    bool shape = false,
  }) {
    _pixelStroke = null;
    _pixelRecording = null;
    final brush = currentBrush;
    final kind = brush == null ? null : _pixelKindOf(brush);
    if (brush == null || kind == null) return false;
    final corners = _pixelDiameter(brush.size).isEven;
    final start = ui.Offset(point.x, point.y);
    final stroke = _PixelStroke(
      kind: kind,
      corners: corners,
      squareCorners: shape && !removeCorners,
      spacing: _brushStampSpacing(
        brush,
        brush.density.clamp(0.1, 5.0).toDouble(),
      ),
      repeat: brush.lateralRepeatEnabled
          ? Brush.clampLateralRepeatCount(brush.lateralRepeatCount)
          : 1,
      start: start,
      startDab: _PixelDab(pressure: point.pressure, strokeLength: 0),
      newTracer: (at, dab) => PixelLineTracer<_PixelDab>(
        at,
        dab,
        corners: corners,
        hysteresis: hysteresis,
        reverseHysteresis: reverseHysteresis,
        removeCorners: removeCorners,
        window: window,
        trimLoop: !shape,
      ),
    );
    // 横方向の反復は、線の向きが分かってから（最初に動いたとき）始める。
    if (stroke.repeat == 1) stroke.addTrace(start, stroke.startDab);
    _pixelStroke = stroke;
    _hasStampedCurrentStroke = true;
    if (!_replayingFinalStroke && !shape) _updatePixelStroke(layerId);
    return true;
  }

  /// ペンが[from]から[to]（[distance]px）へ動いた：それぞれの線でたどる。
  void _feedPixelStroke(StrokePoint from, StrokePoint to, double distance) {
    final stroke = _pixelStroke!;
    final base = _strokeDistance;
    _PixelDab dabAt(double t) => _PixelDab(
      pressure: from.pressure + (to.pressure - from.pressure) * t,
      strokeLength: base + distance * t,
    );
    final end = ui.Offset(to.x, to.y);
    if (stroke.repeat == 1) {
      stroke.traces.first.walkTo(end, dabAt);
      return;
    }
    // 横方向の反復：それぞれの線は、ペンの道を直角にずらした道をたどる。
    stroke.path.add((end, base + distance));
    final normal = stroke.normal();
    if (normal == null) return;
    if (stroke.traces.isEmpty) _startRepeats(stroke, normal);
    final offsets = _repeatOffsets(dabAt(1));
    for (var i = 0; i < stroke.traces.length; i++) {
      stroke.traces[i].walkTo(end + normal * offsets[i], dabAt);
    }
  }

  void _startRepeats(_PixelStroke stroke, ui.Offset normal) {
    final offsets = _repeatOffsets(stroke.startDab);
    for (final offset in offsets) {
      stroke.addTrace(stroke.start + normal * offset, stroke.startDab);
    }
  }

  /// 横方向の反復のそれぞれの線の、ペンの道からのずれ（太さに比例）。
  List<double> _repeatOffsets(_PixelDab dab) {
    final brush = currentBrush!;
    return lateralOffsets(
      count: Brush.clampLateralRepeatCount(brush.lateralRepeatCount),
      spacing:
          _pixelDabSize(brush, dab) *
          brush.lateralRepeatSpacing.clamp(0.0, 4.0).toDouble(),
    );
  }

  /// [_stampBrush]が置くドットの太さ（筆圧・入り抜き込み）。
  double _pixelDabSize(Brush brush, _PixelDab dab) {
    final pressure = resolveBrushPressure(
      brush: brush,
      pressureEnabled: pressureEnabled,
      curvedPressure: dab.pressure,
    );
    var size = brush.size * pressure.sizeScale;
    // 入り抜き narrows the dot; the fade changes only its colour.
    if (brush.shapeTaperMode != FadeMode.off) {
      size *= _taperRamp(
        brush,
        totalLength: _finalizedStrokeLengthOverride,
      ).at(dab.strokeLength);
    }
    return size.clamp(0.5, 2000.0).toDouble();
  }

  // 確定した点のうち、描き方がまだ後の点で変わりうる点の数（中心線の
  // ならし・向き・角は前後4点まで見る）。
  static const int _pixelSettle = 5;

  /// ピクセルモードの線を描き直す：確定した点を描き、まだ変わりうる点
  /// （ペンの下の画素までの続き）を、前に描いたのと変わった点から描き直す
  /// （前に描いた画素は戻してから）。[finish]なら線を終える。
  void _updatePixelStroke(String layerId, {bool finish = false}) {
    _updateTiles = {};
    _updateTilesLayer = layerId;
    try {
      _updatePixelStrokeNow(layerId, finish: finish);
    } finally {
      _updateTiles = null;
      _updateTilesLayer = null;
    }
  }

  void _updatePixelStrokeNow(String layerId, {bool finish = false}) {
    final stroke = _pixelStroke!;
    if (finish && stroke.traces.isEmpty) {
      _startRepeats(stroke, const ui.Offset(0, 1));
    }
    if (!finish && stroke.traces.length == 1 && stroke.fixedChain == null) {
      _updatePixelTrace(stroke, stroke.traces.first, layerId);
      return;
    }
    // 線を終えるとき・横方向の反復：前に描いた画素をすべて戻して描き直す。
    _rollBackPixels(stroke, layerId, 0);
    final chains = <PixelChain<_PixelDab>>[];
    for (final trace in stroke.traces) {
      var chain =
          stroke.fixedChain ??
          (finish ? trace.tracer.finish() : trace.tracer.resolve());
      if (finish && stroke.closed && stroke.fixedChain == null) {
        // 閉じた図形は最初の点へ戻って終わる（同じ点を2度数えない）。
        if (chain.length > 2 && chain[chain.length - 1] == chain[0]) {
          chain = chain.prefix(chain.length - 1);
        } else {
          stroke.closed = false;
        }
      }
      chains.add(chain);
      final settled = finish
          ? chain.length
          : math.max(trace.rendered, trace.tracer.frozen - _pixelSettle);
      trace.state = _drawPixelRange(
        stroke,
        chain,
        trace.rendered,
        settled,
        trace.state,
        layerId,
        reuse: finish ? null : _shapeCacheOf(stroke, trace),
      );
      trace.rendered = settled;
    }
    if (finish) return;
    final log = stroke.log;
    for (var i = 0; i < stroke.traces.length; i++) {
      final trace = stroke.traces[i];
      _drawPixelRange(
        stroke,
        chains[i],
        trace.rendered,
        chains[i].length,
        trace.state,
        layerId,
        log: log,
        reuse: _shapeCacheOf(stroke, trace),
      );
      _forgetSettledShapes(trace);
    }
  }

  /// 前に作った形を使い回してよい線（間隔を空けて置くドットは、何番目の
  /// ドットかでペン先の画像が変わるので使わない）。
  static _PixelTrace? _shapeCacheOf(_PixelStroke stroke, _PixelTrace trace) =>
      stroke.kind == _PixelKind.stamps ? null : trace;

  /// 確定した点の形は、もう描き直さないので忘れる。
  static void _forgetSettledShapes(_PixelTrace trace) =>
      trace.shapes.forgetBefore(trace.rendered);

  /// 1本の線の描き直し：前に描いた続きの点のうち、形が変わらない点は
  /// そのまま残し、変わった点から先だけを戻して描き直す。
  void _updatePixelTrace(
    _PixelStroke stroke,
    _PixelTrace trace,
    String layerId,
  ) {
    final chain = trace.tracer.resolve();
    final log = stroke.log;
    final from = trace.rendered;
    final exact = _pixelRedrawsAllAffected;
    final unchanged = _unchangedPixelPoints(trace, chain, log, exact: exact);
    final same = exact
        ? unchanged
        : _unchangedPixelShapes(stroke, trace, chain, log, unchanged);
    trace.drawn = chain;
    _rollBackPixels(stroke, layerId, same);
    final settled = math.max(from, trace.tracer.frozen - _pixelSettle);
    // 描いてあり、もう変わらない点は、描き直さずに確定する。
    final kept = math.min(same, settled - from);
    trace.state = _drawPixelRange(
      stroke,
      chain,
      from,
      from + kept,
      trace.state,
      layerId,
      draw: false,
    );
    log.dropFront(kept);
    trace.rendered = from + kept;
    if (settled > from + same) {
      trace.state = _drawPixelRange(
        stroke,
        chain,
        trace.rendered,
        settled,
        trace.state,
        layerId,
        reuse: _shapeCacheOf(stroke, trace),
      );
      trace.rendered = settled;
    }
    // 残った（描いてある）続きの点のあとから、続きを描く。
    final drawnUpTo = math.max(trace.rendered, from + same);
    final state = _drawPixelRange(
      stroke,
      chain,
      trace.rendered,
      drawnUpTo,
      trace.state,
      layerId,
      draw: false,
    );
    _drawPixelRange(
      stroke,
      chain,
      drawnUpTo,
      chain.length,
      state,
      layerId,
      log: log,
      reuse: _shapeCacheOf(stroke, trace),
    );
    _pixelShapeReady = null;
    _forgetSettledShapes(trace);
  }

  /// 前に描いた続きの点（[log]）のうち、先頭から何点が、新しい並び[chain]で
  /// も同じ画素を描くか。
  ///
  /// 点の描く画素は、その点の値（[_samePixelDab]）と、その点のまわりの
  /// 決まった範囲の点の位置（描いたときに[_PixelLog]が覚えた範囲。範囲に
  /// 点があるかで線の端かも分かる）だけで決まる。最初に位置の変わった点より
  /// 前で、範囲がそこへ届かない点は変わらない。前の点の描いた画素や線の
  /// 長さに左右される分（混色・間隔を空けて置くドット）は、変わった点から
  /// 先をすべて描き直すので同じになる。
  ///
  /// [exact]なら、見る範囲を前後どの点も同じ広さ（前4点・後5点）にし、値は
  /// 筆圧・線の長さをそのまま比べる（[_pixelRedrawsAllAffected]）。
  int _unchangedPixelPoints(
    _PixelTrace trace,
    PixelChain<_PixelDab> chain,
    _PixelLog log, {
    bool exact = false,
  }) {
    final drawn = trace.drawn;
    final from = trace.rendered;
    final count = math.min(log.points, chain.length - from);
    if (drawn == null || count <= 0) return 0;
    // 位置（とその点があるか）が最初に変わった点。
    final shorter = math.min(drawn.length, chain.length);
    var changed = math.max(0, from - _PixelLog.maxSpan);
    while (changed < shorter && drawn[changed] == chain[changed]) {
      changed++;
    }
    if (changed == shorter && drawn.length == chain.length) {
      changed = chain.length + _PixelLog.maxSpan + 1;
    }
    for (var i = 0; i < count; i++) {
      final k = from + i;
      if (exact) {
        final a = drawn.dataAt(k), b = chain.dataAt(k);
        if (k + _exactSpan >= changed ||
            a.pressure != b.pressure ||
            a.strokeLength != b.strokeLength) {
          return i;
        }
        continue;
      }
      if (k + log.spanAt(i) >= changed) return i;
      if (!_samePixelDab(drawn.dataAt(k), chain.dataAt(k))) return i;
    }
    return count;
  }

  // [_pixelRedrawsAllAffected]のときに見る、後の点の数。
  static const int _exactSpan = 5;

  /// 描き方に効くかどうかに関係なく、前後の点・値が変わった点をすべて描き
  /// 直すか。水彩風は、乾かすときに最後に塗った画素の混色度合い・不透明度を
  /// 筆の外のにじみに使う（[WatercolorStroke.finish]）ので、それが点ごとに
  /// 変わりうるとき（筆圧・入り抜き・減衰）は、描き直す点も最後に塗る画素も
  /// 変えない。
  bool get _pixelRedrawsAllAffected {
    final brush = currentBrush!;
    if (isEraser) return false;
    final pressure = _resolvePressure(brush, 1.0);
    if (pressure.mixingMode != BrushMixingMode.watercolor) return false;
    if (brush.fadeMode != FadeMode.off ||
        brush.shapeTaperMode != FadeMode.off ||
        brush.strokeDecay ||
        _outlineAccent != null) {
      return true;
    }
    if (!pressureEnabled) return false;
    final on = brush.pressureOn;
    return on.opacity.enabled ||
        (on.mixing.enabled && on.mixing.weakRate != on.mixing.strongRate);
  }

  /// 2つの点の値で、[_stampBrush]が同じ画素を描くか（線の長さは入り抜き・
  /// ストローク減衰・縁取りの強弱だけが、筆圧は[resolveBrushPressure]の
  /// 結果だけが描き方に効く）。
  bool _samePixelDab(_PixelDab a, _PixelDab b) {
    if (identical(a, b)) return true;
    final brush = currentBrush!;
    if ((brush.fadeMode != FadeMode.off ||
            brush.shapeTaperMode != FadeMode.off ||
            brush.strokeDecay ||
            _outlineAccent != null) &&
        a.strokeLength != b.strokeLength) {
      return false;
    }
    if (a.pressure == b.pressure) return true;
    return _resolvePressure(brush, a.pressure) ==
        _resolvePressure(brush, b.pressure);
  }

  /// まだ変わりうる点として描いた画素を、[keep]番目の点の分から先だけ
  /// 描く前に戻す。
  void _rollBackPixels(_PixelStroke stroke, String layerId, int keep) {
    final log = stroke.log;
    if (keep >= log.points) return;
    final oil = log.rollBack(keep, tileManager);
    for (final (tx, ty) in log.takeTouched()) {
      tileManager.invalidateTile(layerId, tx, ty);
    }
    final current = _oil;
    if (current != null) current.bristles = oil ?? current.bristles.empty();
  }

  /// [chain]の[from]から[to]の手前までの点を描く（[draw]が偽なら描かずに
  /// 線の長さ・ドットの番号だけ進める）。[state]は[from]番目の点での線の
  /// 長さと次に置くドットの番号で、[to]番目の点での値を返す。[log]を
  /// 渡すと、まだ変わりうる点として描く前の画素を覚える。
  ({double length, int next}) _drawPixelRange(
    _PixelStroke stroke,
    PixelChain<_PixelDab> chain,
    int from,
    int to,
    ({double length, int next}) state,
    String layerId, {
    bool draw = true,
    _PixelLog? log,
    _PixelTrace? reuse,
  }) {
    var length = state.length;
    var next = state.next;
    final centre = stroke.corners ? 0.0 : 0.5;
    for (var k = from; k < to; k++) {
      if (k > from) length += _chainStep(chain, k);
      // 描かずに進めるだけなら、線の長さと置くドットの番号だけ数える。
      if (!draw && stroke.kind != _PixelKind.stamps) continue;
      final _PixelShape? shape;
      if (stroke.kind != _PixelKind.stamps) {
        shape = _pixelShapeOf(stroke, chain, k, null);
      } else if (length + 1e-9 < next * stroke.spacing) {
        shape = null;
      } else {
        final texture = stroke.textureAt(next, _brushTextureSelector);
        next = (length / stroke.spacing + 1e-9).floor() + 1;
        shape = _pixelShapeOf(stroke, chain, k, texture);
      }
      if (!draw) continue;
      log?.beginPoint(_oil?.bristles.copy());
      if (shape == null) {
        // 置かないドットは、その点までの線の長さだけで決まる。
        log?.setSpan(0);
        continue;
      }
      final made = shape;
      final p = chain[k];
      final dab = chain.dataAt(k);
      _pixelRecording = log;
      _pixelSpan = _pixelBaseSpan(stroke);
      _pixelShapeCall = null;
      _stampBrush(
        p.x + centre,
        p.y + centre,
        dab.pressure,
        0,
        0,
        layerId,
        strokeLengthOverride: dab.strokeLength,
        pixelShape: (fill, outer) {
          // 描き直しを決めるときに作った形、前に同じ点に作った形（見る範囲の
          // 点が同じとき）があれば、それを使う。
          final ready = _pixelShapeReady;
          final cached = reuse?.shapes[k];
          final ({PixelMask? fill, PixelMask? outline}) masks;
          if (ready != null &&
              ready.k == k &&
              ready.call.fill == fill &&
              ready.call.outer == outer) {
            masks = (fill: ready.call.fillMask, outline: ready.call.outline);
            _pixelSpan = ready.span;
          } else if (cached != null &&
              cached.call.fill == fill &&
              cached.call.outer == outer &&
              _samePixelWindow(cached.chain, chain, k, cached.span)) {
            masks = (fill: cached.call.fillMask, outline: cached.call.outline);
            _pixelSpan = cached.span;
          } else {
            masks = made(fill, outer);
          }
          _pixelShapeCall = _PixelShapeCall(
            fill,
            outer,
            masks.fill,
            masks.outline,
          );
          return masks;
        },
      );
      log?.setSpan(_pixelSpan);
      log?.setShape(_pixelShapeCall);
      final call = _pixelShapeCall;
      if (reuse != null && call != null) {
        reuse.shapes[k] = _PixelShapeEntry(chain, call, _pixelSpan);
      }
      _pixelRecording = null;
    }
    if (to > from && to < chain.length) length += _chainStep(chain, to);
    return (length: length, next: next);
  }

  /// [chain]の[k]番目の点に置く形（塗りの太さと縁取りの外径から）。
  _PixelShape _pixelShapeOf(
    _PixelStroke stroke,
    PixelChain<_PixelDab> chain,
    int k,
    String? texture,
  ) {
    if (stroke.kind == _PixelKind.line) {
      return (fill, outer) => _pixelOutlined(fill, outer, (d) {
        // 太さ2以上の帯は、中心線のならしで前後の点まで見る。
        if (d >= 2) _pixelSpan = _PixelLog.maxSpan;
        return pixelLineMask(
          chain,
          k,
          d,
          corners: stroke.corners,
          closed: stroke.closed,
          squareCorners: stroke.squareCorners,
        );
      });
    }
    final p = chain[k];
    final angle = _pixelTipAngle(currentBrush!, chain, k, stroke.closed);
    return (fill, outer) => _pixelOutlined(
      fill,
      outer,
      (d) => _pixelTip(p, d, stroke.corners, angle, texture),
    );
  }

  /// 点の形が、形を作る前から後の何点目の位置まで見ると分かっているか
  /// （回転するペン先の向きは前後2点の位置から）。
  int _pixelBaseSpan(_PixelStroke stroke) =>
      stroke.kind != _PixelKind.line && currentBrush!.rotation ? 2 : 0;

  /// [_unchangedPixelPoints]の後の点のうち、位置と値が同じで、作り直した形も
  /// 前に描いた形と同じ点を、描き直さずに残す（線の帯は、後の点が増えて
  /// 中心線のならしが変わっても、画素は変わらないことが多い）。形の違った点は、
  /// 作った形を描くときに使う（[_pixelShapeReady]）。
  ///
  /// 間隔を空けて置くドットは、置くかどうかが線の長さで決まるので残さない。
  int _unchangedPixelShapes(
    _PixelStroke stroke,
    _PixelTrace trace,
    PixelChain<_PixelDab> chain,
    _PixelLog log,
    int same,
  ) {
    final drawn = trace.drawn;
    if (drawn == null || stroke.kind == _PixelKind.stamps) return same;
    final from = trace.rendered;
    final count = math.min(log.points, chain.length - from);
    while (same < count) {
      final k = from + same;
      if (drawn[k] != chain[k] ||
          !_samePixelDab(drawn.dataAt(k), chain.dataAt(k))) {
        break;
      }
      // 形を作らなかった点（塗らない点）は、値が同じなら今も塗らない。
      final call = log.shapeAt(same);
      if (call != null) {
        _pixelSpan = _pixelBaseSpan(stroke);
        final masks = _pixelShapeOf(stroke, chain, k, null)(
          call.fill,
          call.outer,
        );
        if (!_samePixelMask(masks.fill, call.fillMask) ||
            !_samePixelMask(masks.outline, call.outline)) {
          _pixelShapeReady = (
            k: k,
            call: _PixelShapeCall(
              call.fill,
              call.outer,
              masks.fill,
              masks.outline,
            ),
            span: _pixelSpan,
          );
          break;
        }
      }
      same++;
    }
    return same;
  }

  /// [a]と[b]で、[k]番目の点の前後[span]点の位置（とその点があるか）が
  /// 同じか。
  static bool _samePixelWindow(
    PixelChain<_PixelDab> a,
    PixelChain<_PixelDab> b,
    int k,
    int span,
  ) {
    for (var i = k - span; i <= k + span; i++) {
      final inA = i >= 0 && i < a.length;
      final inB = i >= 0 && i < b.length;
      if (inA != inB) return false;
      if (inA && a[i] != b[i]) return false;
    }
    return true;
  }

  /// 2つの形が同じ画素を塗り、同じ範囲を持つか。
  static bool _samePixelMask(PixelMask? a, PixelMask? b) {
    if (a == null || b == null) return a == b;
    return a.sameAs(b);
  }

  static double _chainStep(PixelChain<Object?> chain, int k) {
    final a = chain[k - 1], b = chain[k];
    return a.x != b.x && a.y != b.y ? math.sqrt2 : 1.0;
  }

  /// 太さ[fill]（縁取りの外径[outer]、縁取りが無ければ0）の形：[shapeOf]が
  /// 太さごとの形を返す。縁取りは塗りの形を縁取りの幅だけ広げたもの。
  ({PixelMask? fill, PixelMask? outline}) _pixelOutlined(
    double fill,
    double outer,
    PixelMask Function(int diameter) shapeOf,
  ) {
    final fillMask = fill >= 0.5 ? shapeOf(_pixelDiameter(fill)) : null;
    if (outer <= 0) return (fill: fillMask, outline: null);
    final width = ((outer - fill) / 2).round();
    final outline = fillMask == null
        ? shapeOf(_pixelDiameter(outer))
        : width > 0
        ? fillMask.dilate(width)
        : null;
    return (fill: fillMask, outline: outline);
  }

  /// ペン先の向き：カリグラフィーの角度に、回転するブラシは線の向きを足す
  /// （64段に丸める）。
  double _pixelTipAngle(
    Brush brush,
    PixelChain<Object?> chain,
    int k,
    bool closed,
  ) {
    var angle = (brush.calligraphyAngle ?? 0) * math.pi / 180;
    if (brush.rotation && chain.length > 1) {
      final n = chain.length;
      PixelPoint at(int i) =>
          closed ? chain[((i % n) + n) % n] : chain[i.clamp(0, n - 1)];
      final a = at(k - 2), b = at(k + 2);
      if (a != b) {
        angle += math.atan2((b.y - a.y).toDouble(), (b.x - a.x).toDouble());
      }
    }
    const steps = 64;
    return (angle / (2 * math.pi) * steps).round() * 2 * math.pi / steps;
  }

  /// 格子点[p]に置く太さ[d]のペン先：ペン先の画像[texture]・カリグラフィーの
  /// 平たいペン先・丸いドットのどれか。
  PixelMask _pixelTip(
    PixelPoint p,
    int d,
    bool corners,
    double angle,
    String? texture,
  ) {
    final brush = currentBrush!;
    final alpha = texture == null
        ? null
        : getCachedBrushTexture(texture, mode: brush.imageInkMode);
    final nib = brush.calligraphyAngle;
    if (alpha == null && nib == null) return PixelMask.dot(p, d);
    return pixelTipMask(
      p,
      d,
      corners: corners,
      ratio: nib == null ? 1 : Brush.clampNibWidthRatio(brush.nibWidthRatio),
      angle: angle,
      alpha: alpha,
      alphaSize: brushTextureSize,
    );
  }

  /// 図形の楕円の画素の並び（[bounds]に内接）。
  PixelChain<_PixelDab> _pixelEllipseChain(ui.Rect bounds, bool corners) {
    final a = _pixelPointAt(bounds.left, bounds.top, corners);
    final b = _pixelPointAt(bounds.right, bounds.bottom, corners);
    final points = pixelEllipse(a.x, a.y, b.x, b.y);
    final dabs = <_PixelDab>[];
    var length = 0.0;
    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        final p = points[i - 1], q = points[i];
        length += p.x != q.x && p.y != q.y ? math.sqrt2 : 1.0;
      }
      dabs.add(_PixelDab(pressure: 1, strokeLength: length));
    }
    return PixelChain.of(points, dabs);
  }

  void _stampBrush(
    double x,
    double y,
    double pressure,
    double tiltX,
    double tiltY,
    String layerId, {
    double? strokeLengthOverride,
    double pathAngle = 0.0,
    bool hasPathDirection = false,
    bool applyScatter = true,
    // ピクセルモードの格子に置く形（塗りの太さと縁取りの外径から）。
    ({PixelMask? fill, PixelMask? outline}) Function(double, double)?
    pixelShape,
  }) {
    if (currentBrush == null) return;
    final brush = currentBrush!;

    final resolvedPressure = _resolvePressure(brush, pressure);
    var size = brush.size * resolvedPressure.sizeScale;
    // 縁取りペンの筆圧は全体の形だけを変え、不透明度には効かせない。
    var opacity =
        (brush.opacity / 100.0) *
        (brush.outlineEnabled ? 1.0 : resolvedPressure.opacityScale);

    final strokeLength = strokeLengthOverride ?? _strokeDistance;
    _stampLength = strokeLength;

    // 入り抜きは線の始点と終点に向かって太さだけを細くする（色・不透明度は
    // 変えない）。縁取りペンでは、入り抜き・筆圧は縁取りを含む全体の形だけを
    // 変え、縁取り線の太さと透明度は変えない（outlinedStrokeRadii）。0%では
    // 何も描かない。
    if (brush.shapeTaperMode != FadeMode.off) {
      final taper = _taperRamp(
        brush,
        totalLength: _finalizedStrokeLengthOverride,
      ).at(strokeLength);
      size *= taper;
      if (taper <= 0) return;
    }
    // Drawing only the end again: a dab that reaches none of those tiles
    // draws nothing in them and changes nothing a later dab uses (no
    // scattering, random flakes or changing tip images).
    final redrawCells = _redrawCells;
    if (redrawCells != null &&
        brush.scatter <= 0 &&
        brush.tipShape != BrushTipShape.hexagon &&
        brush.resolvedCustomImagePaths.length <= 1) {
      var reach = size * 3 + resolvedPressure.blur * 1.5 + 16;
      if (brush.lateralRepeatEnabled) {
        reach +=
            size *
            Brush.clampLateralRepeatCount(brush.lateralRepeatCount) *
            (brush.lateralRepeatSpacing.abs() + 1) *
            2;
      }
      if (!_reachesAny(redrawCells, x, y, reach)) return;
    }
    // フェードは線の始点と終点に向かって透けていき、その間はブラシの
    // 不透明度のまま（太さは変えない。縁取りペンは透けない）。透け方は
    // 画素ごとに、その画素が線に沿ってどこにあるかで決める（スタンプごとに
    // 決めると、重なったスタンプのうち先のものが線の真ん中ほど遠くまで
    // 届き、真ん中だけ先に濃く・遅く薄くなる）。
    _FadeAlong? fadeAlong;
    if (brush.colourFadeMode != FadeMode.off) {
      final ramp = _fadeRamp(
        brush,
        totalLength: _finalizedStrokeLengthOverride,
      );
      if (hasPathDirection && pixelShape == null) {
        // (Dots on the pixel grid take the fade of their own dot.)
        final reach = size / 2 + resolvedPressure.blur + 2;
        if (ramp.changesWithin(strokeLength - reach, strokeLength + reach)) {
          fadeAlong = _FadeAlong(
            ramp,
            strokeLength,
            math.cos(pathAngle),
            math.sin(pathAngle),
          );
        }
      } else {
        opacity *= ramp.at(strokeLength);
      }
    }
    // ストローク減衰はインク切れ表現なので、不透明度だけを減らして太さは維持する。
    if (brush.strokeDecay) {
      opacity *= _calculateDecay(strokeLength);
    }

    // Apply the selected color's alpha to brush opacity.
    if (!isEraser) opacity *= currentColor.a;
    opacity = opacity.clamp(0.0, 1.0);
    final outlinedRadii = brush.outlineEnabled
        ? outlinedStrokeRadii(
            width: size,
            scale: brush.size > 0 ? size / brush.size : 1.0,
            outlineWidth:
                _outlineAccent?.at(strokeLength) ?? brush.outlineWidth,
          )
        : null;
    size = size.clamp(0.5, 2000.0);

    var stampX = x;
    var stampY = y;
    if (applyScatter && brush.scatter > 0.0) {
      final maxOffset = brush.scatter.clamp(0.0, 1.0) * size;
      final offset = (_scatterRng.nextDouble() * 2.0 - 1.0) * maxOffset;
      final normal = pathAngle + math.pi / 2.0;
      stampX += math.cos(normal) * offset;
      stampY += math.sin(normal) * offset;
    }

    final alphaInt = (opacity * 255).round().clamp(0, 255);
    if (alphaInt == 0) return;

    // 油彩風：このスタンプを置く前に、筆の毛が下の絵の具を拾う。
    if (resolvedPressure.mixingMode == BrushMixingMode.oil && !isEraser) {
      (_oil ??= OilStroke(
        layerId: layerId,
        bristles: brush.size.ceil().clamp(2, 128).toInt(),
        seed: (stampX * 7919 + stampY * 104729).round(),
      )).advance(
        tileManager,
        stampX,
        stampY,
        size / 2,
        direction: hasPathDirection ? pathAngle : null,
        stretch: resolvedPressure.mixingStretch,
        paint: _rgb24(currentColor),
        rate: resolvedPressure.mixingRate / 100,
        mixer: _oilMixerFor(
          _rgb24(currentColor),
          resolvedPressure.mixingBrightnessCorrection,
        ),
      );
    }
    if (resolvedPressure.mixingMode == BrushMixingMode.watercolor &&
        !isEraser &&
        _watercolor == null) {
      _watercolor = WatercolorStroke(
        layerId: layerId,
        paint: _rgb24(currentColor),
        brushSize: brush.size.toDouble(),
        water: resolvedPressure.mixingWater,
        pigment: resolvedPressure.mixingPigment,
        bleed: resolvedPressure.mixingBleed,
        texture: resolvedPressure.mixingTexture,
        softEdge: resolvedPressure.mixingSoftEdge,
        brightnessCorrection: resolvedPressure.mixingBrightnessCorrection,
        seed: (stampX * 7919 + stampY * 104729).round(),
      );
    }

    // ピクセルモードの散布するドットも、1つずつ格子に寄せた同じ形で置く。
    if (pixelShape == null && _onPixelGrid(brush)) {
      final texture = _brushTextureSelector.nextDabPath();
      final corners = _pixelDiameter(brush.size).isEven;
      final angle =
          (brush.calligraphyAngle ?? 0) * math.pi / 180 +
          (brush.rotation ? pathAngle : 0);
      final centers = brush.lateralRepeatEnabled
          ? lateralCenters(
              center: ui.Offset(stampX, stampY),
              tangent: ui.Offset(math.cos(pathAngle), math.sin(pathAngle)),
              count: Brush.clampLateralRepeatCount(brush.lateralRepeatCount),
              spacing:
                  size * brush.lateralRepeatSpacing.clamp(0.0, 4.0).toDouble(),
            )
          : [ui.Offset(stampX, stampY)];
      pixelShape = (fill, outer) {
        final shapes = [
          for (final c in centers)
            _pixelOutlined(
              fill,
              outer,
              (d) => _pixelTip(
                _pixelPointAt(c.dx, c.dy, corners),
                d,
                corners,
                angle,
                texture,
              ),
            ),
        ];
        PixelMask? merge(Iterable<PixelMask?> masks) {
          final list = masks.whereType<PixelMask>().toList();
          return list.isEmpty ? null : PixelMask.union(list);
        }

        return (
          fill: merge(shapes.map((s) => s.fill)),
          outline: merge(shapes.map((s) => s.outline)),
        );
      };
    }
    if (pixelShape != null) {
      // 格子に置く形：縁取り（外径）を先に、塗りを上に。
      final fill = outlinedRadii == null ? size : outlinedRadii.fill * 2;
      final outer = outlinedRadii == null || brush.outlineWidth <= 0
          ? 0.0
          : outlinedRadii.outer * 2;
      final masks = pixelShape(fill, outer);
      final outline = masks.outline;
      if (outline != null) {
        _renderCircleStamp(
          stampX,
          stampY,
          outer / 2,
          alphaInt,
          (scaleX: 1.0, scaleY: 1.0, angle: 0.0),
          layerId,
          true,
          0,
          null,
          grainStrength: brush.grainStrength,
          mixingMode: resolvedPressure.mixingMode,
          mixingRate: resolvedPressure.mixingRate,
          mixingBrightnessCorrection:
              resolvedPressure.mixingBrightnessCorrection,
          colorOverride: ui.Color(brush.outlineColor),
          coverageNamespace: 'outline',
          behindExisting: !brush.outlineKeepOverlap,
          pixelMask: outline,
        );
      }
      final fillMask = masks.fill;
      if (fillMask != null) {
        _renderCircleStamp(
          stampX,
          stampY,
          fill / 2,
          alphaInt,
          (scaleX: 1.0, scaleY: 1.0, angle: 0.0),
          layerId,
          true,
          0,
          null,
          grainStrength: brush.grainStrength,
          mixingMode: resolvedPressure.mixingMode,
          mixingRate: resolvedPressure.mixingRate,
          mixingBrightnessCorrection:
              resolvedPressure.mixingBrightnessCorrection,
          coverageNamespace: outline != null ? 'fill' : 'legacy',
          pixelMask: fillMask,
          fadeAlong: fadeAlong,
        );
      }
      return;
    }

    // グリッターペンは大きな六角形フレークとして描画する。粒ごとに向きを
    // ランダム化し、同じ向きの六角形が機械的に並ぶ見た目を避ける。
    // ラメペンを含む他ブラシは従来どおり円形スタンプのまま。
    final isGlitterHexagon = brush.tipShape == BrushTipShape.hexagon;
    final isChainLink = brush.tipShape == BrushTipShape.chainLink;
    final isBallChain = brush.tipShape == BrushTipShape.ballChain;
    final chainStep = isChainLink
        ? (strokeLength / math.max(1.0, _brushStampSpacing(brush, 1.0))).round()
        : 0;
    final particleRotation = isGlitterHexagon
        ? _scatterRng.nextDouble() * math.pi * 2.0
        : isChainLink
        // 実鎖の「交互に別平面を向く」印象を2Dで読めるよう、隣接リンクを
        // 接線に対して左右へ交互に傾ける。完全な90度交互より連結が自然。
        ? (chainStep.isEven ? -0.48 : 0.48)
        : 0.0;
    final chainAspect = brush.chainAspect.clamp(.1, 1.0);
    final chainThickness = brush.chainThickness.clamp(.05, .9);

    // 傾き変形：カリグラフィーブラシ（ペン先角度固定）の場合は、実際の
    // スタイラス傾きに関わらず常に固定角度へ扁平化したペン先を使う。
    final nibAngle = brush.calligraphyAngle;
    var tilt = nibAngle != null
        ? (
            scaleX: Brush.clampNibWidthRatio(brush.nibWidthRatio),
            scaleY: 1.0,
            angle: nibAngle * math.pi / 180,
          )
        : calcTiltTransform(tiltX, tiltY);
    // 回転ONではブラシ先端をパス接線方向へ追従させる。固定角度ブラシは
    // その角度を接線方向へのオフセットとして保持する。
    if (brush.rotation) {
      final angleOffset = (nibAngle ?? 0) * math.pi / 180;
      tilt = (
        scaleX: tilt.scaleX,
        scaleY: tilt.scaleY,
        angle: pathAngle + angleOffset,
      );
    }
    final stylusTiltMagnitude = nibAngle == null && !brush.rotation
        ? math.sqrt(tiltX * tiltX + tiltY * tiltY).clamp(0.0, 1.0)
        : 0.0;

    // 自作ブラシ（ブラシ画像からのブラシ作成）が選択され、
    // 事前読み込み済みの場合はその形状を、それ以外は円形（またはピクセル
    // モード）でスタンプする。
    final texturePath = _brushTextureSelector.nextDabPath();
    final customTexture = texturePath != null
        ? getCachedBrushTexture(texturePath, mode: brush.imageInkMode)
        : null;
    final silhouetteDistanceMap =
        texturePath != null &&
            brush.imageInkMode == BrushImageInkMode.silhouette
        ? getCachedSilhouetteDistance(texturePath)
        : null;
    final extensionPlan = buildBrushStampPlan(
      brush: brush,
      center: ui.Offset(stampX, stampY),
      pathAngle: pathAngle,
      effectiveSize: size,
      outlinedRadii: outlinedRadii,
    );
    final usesExtensionRaster =
        brush.lateralRepeatEnabled ||
        brush.outlineEnabled ||
        extensionPlan.hollowSquare;
    final centers = usesExtensionRaster
        ? extensionPlan.centers
        : <ui.Offset>[ui.Offset(stampX, stampY)];
    for (final center in centers) {
      final outlineRadius = extensionPlan.outlineRadius;
      if (usesExtensionRaster && outlineRadius != null) {
        _renderCircleStamp(
          center.dx,
          center.dy,
          outlineRadius,
          alphaInt,
          tilt,
          layerId,
          brush.pixelMode,
          resolvedPressure.blur,
          customTexture,
          stylusTiltMagnitude: stylusTiltMagnitude,
          grainStrength: brush.grainStrength,
          edgeJitter: resolvedPressure.edgeJitterEnabled,
          edgeJitterStrength: resolvedPressure.edgeJitterStrength,
          mixingMode: resolvedPressure.mixingMode,
          mixingRate: resolvedPressure.mixingRate,
          mixingBrightnessCorrection:
              resolvedPressure.mixingBrightnessCorrection,
          hexagon: isGlitterHexagon,
          particleRotation: particleRotation,
          chainLink: isChainLink,
          chainAspect: chainAspect,
          chainThickness: chainThickness,
          ballChain: isBallChain,
          hollowSquare: extensionPlan.hollowSquare,
          hollowSquareInnerRatio: extensionPlan.hollowSquareInnerRatio,
          colorOverride: ui.Color(brush.outlineColor),
          coverageNamespace: 'outline',
          behindExisting: !brush.outlineKeepOverlap,
          silhouetteDistanceMap: !isEraser && extensionPlan.fillRadius > 0
              ? silhouetteDistanceMap
              : null,
          silhouetteOutlineWidth: outlineRadius - extensionPlan.fillRadius,
          // A tip finer than a pixel covers only its own width of it.
          coverageCap: brush.pixelMode ? 1.0 : math.min(1.0, outlineRadius * 2),
        );
      }
      // A tapered outline-pen tip thinner than its outline has no fill left.
      if (extensionPlan.fillRadius > 0) {
        _renderCircleStamp(
          center.dx,
          center.dy,
          extensionPlan.fillRadius,
          alphaInt,
          tilt,
          layerId,
          brush.pixelMode,
          resolvedPressure.blur,
          customTexture,
          stylusTiltMagnitude: stylusTiltMagnitude,
          grainStrength: brush.grainStrength,
          edgeJitter: resolvedPressure.edgeJitterEnabled,
          edgeJitterStrength: resolvedPressure.edgeJitterStrength,
          mixingMode: resolvedPressure.mixingMode,
          mixingRate: resolvedPressure.mixingRate,
          mixingBrightnessCorrection:
              resolvedPressure.mixingBrightnessCorrection,
          hexagon: isGlitterHexagon,
          particleRotation: particleRotation,
          chainLink: isChainLink,
          chainAspect: chainAspect,
          chainThickness: chainThickness,
          ballChain: isBallChain,
          hollowSquare: usesExtensionRaster && extensionPlan.hollowSquare,
          hollowSquareInnerRatio: extensionPlan.hollowSquareInnerRatio,
          coverageNamespace: usesExtensionRaster ? 'fill' : 'legacy',
          fadeAlong: fadeAlong,
        );
      }
    }
  }

  double _sampleTipAlpha(
    Uint8List texture,
    double x,
    double y,
    bool pixelMode,
  ) {
    if (x.abs() > 1 || y.abs() > 1) return 0;
    const last = brushTextureSize - 1;
    final tx = ((x + 1) * brushTextureSize / 2 - 0.5).clamp(
      0.0,
      last.toDouble(),
    );
    final ty = ((y + 1) * brushTextureSize / 2 - 0.5).clamp(
      0.0,
      last.toDouble(),
    );
    if (pixelMode) {
      final alpha =
          texture[(ty.round() * brushTextureSize + tx.round()) * 4 + 3];
      return alpha >= 128 ? 1.0 : 0.0;
    }
    final left = tx.floor(), top = ty.floor();
    final right = math.min(left + 1, last), bottom = math.min(top + 1, last);
    final fx = tx - left, fy = ty - top;
    final topLeft = texture[(top * brushTextureSize + left) * 4 + 3];
    final topRight = texture[(top * brushTextureSize + right) * 4 + 3];
    final bottomLeft = texture[(bottom * brushTextureSize + left) * 4 + 3];
    final bottomRight = texture[(bottom * brushTextureSize + right) * 4 + 3];
    final upper = topLeft + (topRight - topLeft) * fx;
    final lower = bottomLeft + (bottomRight - bottomLeft) * fx;
    return (upper + (lower - upper) * fy) / 255;
  }

  /// [resolveBrushPressure]（同じブラシ・同じ筆圧が続くことが多いので、
  /// 直前の結果を使い回す）。
  ResolvedBrushPressure _resolvePressure(Brush brush, double pressure) {
    final last = _lastResolvedPressure;
    if (last != null &&
        identical(last.brush, brush) &&
        last.enabled == pressureEnabled &&
        last.pressure == pressure) {
      return last.resolved;
    }
    final resolved = resolveBrushPressure(
      brush: brush,
      pressureEnabled: pressureEnabled,
      curvedPressure: pressure,
    );
    _lastResolvedPressure = (
      brush: brush,
      enabled: pressureEnabled,
      pressure: pressure,
      resolved: resolved,
    );
    return resolved;
  }

  ({
    Brush brush,
    bool enabled,
    double pressure,
    ResolvedBrushPressure resolved,
  })?
  _lastResolvedPressure;

  void _renderCircleStamp(
    double cx,
    double cy,
    double radius,
    int alpha,
    ({double scaleX, double scaleY, double angle}) tilt,
    String layerId,
    bool pixelMode,
    int blurRadius,
    Uint8List? customTexture, {
    double stylusTiltMagnitude = 0.0,
    int grainStrength = 0,
    bool edgeJitter = false,
    int edgeJitterStrength = 50,
    BrushMixingMode mixingMode = BrushMixingMode.off,
    int mixingRate = 0,
    int mixingBrightnessCorrection = 3,
    bool hexagon = false,
    double particleRotation = 0.0,
    bool chainLink = false,
    double chainAspect = 1.0,
    double chainThickness = 0.0,
    bool ballChain = false,
    bool hollowSquare = false,
    double hollowSquareInnerRatio = 0.5,
    ui.Color? colorOverride,
    String coverageNamespace = 'legacy',
    double coverageCap = 1.0,
    bool behindExisting = false,
    Uint8List? silhouetteDistanceMap,
    double silhouetteOutlineWidth = 0,
    PixelMask? pixelMask,
    _FadeAlong? fadeAlong,
  }) {
    final paintColor = colorOverride ?? currentColor;
    final r = paintColor.r;
    final g = paintColor.g;
    final b = paintColor.b;
    final ri = (r * 255).round();
    final gi = (g * 255).round();
    final bi = (b * 255).round();

    // 影響範囲のタイルを特定
    final effectiveRadius = radius * math.max(tilt.scaleX, tilt.scaleY);
    final blur = blurRadius.toDouble();
    // The image's square can extend past the circular fallback once rotated.
    final textureReach = customTexture == null ? 1.0 : math.sqrt2;
    final totalRadius =
        (effectiveRadius + blur) * textureReach +
        (edgeJitter ? edgeJitterStrength / 40.0 : 0.0);
    final cosA = math.cos(-tilt.angle);
    final sinA = math.sin(-tilt.angle);
    final cosParticle = math.cos(-particleRotation);
    final sinParticle = math.sin(-particleRotation);
    // Precompute falloff constants once per tip, not for every raster pixel.
    final softSigma = math.max(0.5, (radius + blur) / 3.3);
    // A pixel center can be half a pixel from the dab center on each axis.
    // Keep the innermost sample fully opaque while the Gaussian falls off.
    final falloffScale = -0.5 / (softSigma * softSigma);
    final softnessMix = blur > 0
        ? (blur / (blur + radius)).clamp(0.0, 1.0)
        : 0.0;
    final hardShare = 1.0 - softnessMix;
    final blurReach = radius + blur;

    // ピクセルモードの格子に置く形（[pixelMask]の画素だけを塗る）。
    final minTx = pixelMask != null
        ? (pixelMask.left / TileManager.tileSize).floor()
        : ((cx - totalRadius) / TileManager.tileSize).floor();
    final maxTx = pixelMask != null
        ? ((pixelMask.right - 1) / TileManager.tileSize).floor()
        : ((cx + totalRadius) / TileManager.tileSize).floor();
    final minTy = pixelMask != null
        ? (pixelMask.top / TileManager.tileSize).floor()
        : ((cy - totalRadius) / TileManager.tileSize).floor();
    final maxTy = pixelMask != null
        ? ((pixelMask.bottom - 1) / TileManager.tileSize).floor()
        : ((cy + totalRadius) / TileManager.tileSize).floor();
    final recording = _pixelRecording;
    // 油彩風：線は毛が置く絵の具（選択色に拾った絵の具を混ぜた色）で下を
    // 覆う。縁取りは縁取りの色で覆う。
    final paintRgb = ri << 16 | gi << 8 | bi;
    final oilMixer = mixingMode == BrushMixingMode.oil && !isEraser
        ? _oilMixerFor(paintRgb, mixingBrightnessCorrection)
        : null;
    // 縁取りは選択色の毛が運ぶ絵の具を使わない。
    final carries = colorOverride == null;
    // 格子に置く形で、ざらつき・傾きの濃淡・覆いの上限が効かないときは、
    // 形のどの画素も同じ不透明度で塗る。
    final uniformAlpha =
        pixelMask != null &&
            grainStrength <= 0 &&
            coverageCap >= 1.0 &&
            !(stylusTiltMagnitude > 0.0001 && radius > 0)
        ? _byte((alpha * 1.0).round())
        : -1;

    if (pixelMask == null && !_replayingFinalStroke && _recordsReach) {
      final reach = _stampLength + totalRadius;
      final minX = math.max(0, (cx - totalRadius).floor()) >> _cellShift;
      final maxX = (cx + totalRadius).ceil() >> _cellShift;
      final minY = math.max(0, (cy - totalRadius).floor()) >> _cellShift;
      final maxY = (cy + totalRadius).ceil() >> _cellShift;
      for (var gy = minY; gy <= maxY; gy++) {
        for (var gx = minX; gx <= maxX; gx++) {
          final key = gx << 24 | gy;
          final reached = _cellReach[key];
          if (reached == null || reached < reach) _cellReach[key] = reach;
        }
      }
    }
    final redrawMasks = _redrawMasks;
    for (int ty = minTy; ty <= maxTy; ty++) {
      for (int tx = minTx; tx <= maxTx; tx++) {
        if (tx < 0 || ty < 0) continue;
        // Drawing only the end again: only in its cells.
        var cellMask = _allCells;
        if (redrawMasks != null) {
          final mask = redrawMasks[tx << 24 | ty];
          if (mask == null) continue;
          cellMask = mask;
        }
        final clip = cellMask != _allCells;
        _foldRaster?.rememberTile(tx, ty);
        final tile = _writableTile(layerId, tx, ty);
        // 水彩風は塗る前のタイルを覚え、そこへ透明な絵の具を重ねて描く。
        final watercolor =
            mixingMode == BrushMixingMode.watercolor &&
                colorOverride == null &&
                !isEraser
            ? _watercolor
            : null;
        watercolor?.touchTile(tx, ty, tile);
        final tileOriginX = tx * TileManager.tileSize;
        final tileOriginY = ty * TileManager.tileSize;
        final coverage = _strokeCoverageByTile.of(
          coverageNamespace,
          layerId,
          tx,
          ty,
        );
        // The outline is the first stamp of a stroke to reach a tile, so this
        // keeps the tile as it was before the stroke.
        final base = behindExisting
            ? _strokeBaseAlpha.putIfAbsent('$layerId:$tx:$ty', () {
                final alpha = Uint8List(
                  TileManager.tileSize * TileManager.tileSize,
                );
                for (var i = 0; i < alpha.length; i++) {
                  alpha[i] = tile[i * 4 + 3];
                }
                return alpha;
              })
            : null;
        final previousFill = base == null
            ? null
            : _strokeCoverageByTile.existing('fill', layerId, tx, ty);
        // 油彩風は塗る前のタイルへ置く（縁取りを下へ回すときを除く）。
        final oil = oilMixer != null && base == null
            ? (_oil ??= OilStroke(layerId: layerId, bristles: 0, seed: 0))
            : null;
        oil?.touchTile(tx, ty, tile);

        // タイル内の影響ピクセル範囲
        final localMinX = pixelMask != null
            ? math.max(0, pixelMask.left - tileOriginX)
            : math.max(0, (cx - totalRadius - tileOriginX).floor());
        final localMaxX = pixelMask != null
            ? math.min(
                TileManager.tileSize - 1,
                pixelMask.right - 1 - tileOriginX,
              )
            : math.min(
                TileManager.tileSize - 1,
                (cx + totalRadius - tileOriginX).ceil(),
              );
        final localMinY = pixelMask != null
            ? math.max(0, pixelMask.top - tileOriginY)
            : math.max(0, (cy - totalRadius - tileOriginY).floor());
        final localMaxY = pixelMask != null
            ? math.min(
                TileManager.tileSize - 1,
                pixelMask.bottom - 1 - tileOriginY,
              )
            : math.min(
                TileManager.tileSize - 1,
                (cy + totalRadius - tileOriginY).ceil(),
              );

        for (int py = localMinY; py <= localMaxY; py++) {
          var rowCells = _allCells;
          if (clip) {
            rowCells =
                cellMask >> (py >> _cellShift) * _cellsPerTile &
                (1 << _cellsPerTile) - 1;
            if (rowCells == 0) {
              py |= (1 << _cellShift) - 1;
              continue;
            }
          }
          for (int px = localMinX; px <= localMaxX; px++) {
            if (clip && rowCells & 1 << (px >> _cellShift) == 0) {
              px |= (1 << _cellShift) - 1;
              continue;
            }
            // 格子に置く形は、その形の画素だけを塗る（外の画素は何もしない）。
            if (pixelMask != null &&
                !pixelMask.contains(tileOriginX + px, tileOriginY + py)) {
              continue;
            }
            // 格子に置く形で、どの画素も同じ不透明度のとき（[uniformAlpha]）は、
            // 1画素ごとの距離の計算は要らない。
            final worldX = tileOriginX + px + 0.5;
            final worldY = tileOriginY + py + 0.5;
            var desiredAlpha = uniformAlpha;
            if (desiredAlpha < 0) {
              final dx = worldX - cx;
              final dy = worldY - cy;

              // 傾き変形を適用した楕円距離
              final rdx = dx * cosA - dy * sinA;
              final rdy = dx * sinA + dy * cosA;
              final ux = rdx / tilt.scaleX;
              final uy = rdy / tilt.scaleY;
              final dist = math.sqrt(ux * ux + uy * uy);

              double pixelAlpha;
              if (pixelMask != null) {
                pixelAlpha = 1.0;
              } else if (silhouetteDistanceMap != null) {
                final imageRadius = radius - silhouetteOutlineWidth;
                final texelScale = brushTextureSize / (2 * imageRadius);
                final texelCenter = (brushTextureSize - 1) / 2;
                final maskX = ux * cosParticle - uy * sinParticle;
                final maskY = ux * sinParticle + uy * cosParticle;
                final distance =
                    sampleSilhouetteDistance(
                      silhouetteDistanceMap,
                      brushTextureSize,
                      maskX * texelScale + texelCenter,
                      maskY * texelScale + texelCenter,
                    ) /
                    texelScale;
                pixelAlpha = (silhouetteOutlineWidth + .5 - distance).clamp(
                  0.0,
                  1.0,
                );
              } else if (customTexture != null) {
                final imageRadius = radius + (pixelMode ? 0 : blur);
                var maskX = ux * cosParticle - uy * sinParticle;
                var maskY = ux * sinParticle + uy * cosParticle;
                if (!pixelMode &&
                    blur == 0 &&
                    edgeJitter &&
                    dist > radius - 1.5 &&
                    dist > 0) {
                  final maxJitter = edgeJitterStrength / 100.0 * 2.5;
                  final jitter =
                      (_jitterRng.nextDouble() - 0.5) * maxJitter * 2;
                  final scale = math.max(0.0, (dist - jitter) / dist);
                  maskX *= scale;
                  maskY *= scale;
                }
                final nx = maskX / imageRadius;
                final ny = maskY / imageRadius;
                pixelAlpha = _sampleTipAlpha(customTexture, nx, ny, pixelMode);
                // Small dabs cover fractions of a canvas pixel even when the
                // source PNG edge spans less than a texel at canvas scale.
                if (!pixelMode && imageRadius < brushTextureSize / 2) {
                  final offset = 0.35 / imageRadius;
                  pixelAlpha =
                      (_sampleTipAlpha(customTexture, nx - offset, ny, false) +
                          _sampleTipAlpha(
                            customTexture,
                            nx + offset,
                            ny,
                            false,
                          ) +
                          _sampleTipAlpha(
                            customTexture,
                            nx,
                            ny - offset,
                            false,
                          ) +
                          _sampleTipAlpha(
                            customTexture,
                            nx,
                            ny + offset,
                            false,
                          )) /
                      4;
                }
                if (!pixelMode && blur > 0 && pixelAlpha > 0) {
                  // The rim eases out (smoothstep): level where it meets the
                  // tip and where it meets nothing, so a soft stroke falls
                  // off as a bell, not a cone with a crease at its edge.
                  var classic = 1.0;
                  if (dist > radius) {
                    final t = math.min(1.0, (dist - radius) / blur);
                    classic = 1.0 - t * t * (3.0 - 2.0 * t);
                  }
                  final soft = math.exp(
                    falloffScale * math.max(0.0, dist * dist - 0.5),
                  );
                  pixelAlpha *= classic * hardShare + soft * softnessMix;
                }
              } else if (hollowSquare) {
                final outerDistance = math.max(ux.abs(), uy.abs());
                final innerRadius =
                    radius * hollowSquareInnerRatio.clamp(0.0, 0.95).toDouble();
                final outerAa = (radius + 0.5 - outerDistance).clamp(0.0, 1.0);
                final innerAa = (outerDistance - innerRadius + 0.5).clamp(
                  0.0,
                  1.0,
                );
                pixelAlpha = math.min(outerAa, innerAa);
              } else if (chainLink) {
                // 中抜き楕円リンク。接線座標へ揃えたあと、リンク固有の交互角度
                // だけ回す。outer/innerの楕円距離差で肉厚を作るため、拡縮しても
                // リングの穴が潰れずチェーンとして読める。
                final lx = ux * cosParticle - uy * sinParticle;
                final ly = ux * sinParticle + uy * cosParticle;
                final outerX = radius;
                final outerY = radius * chainAspect;
                final wall = radius * chainThickness;
                final innerX = math.max(0.5, outerX - wall);
                final innerY = math.max(0.5, outerY - wall);
                final outerD = math.sqrt(
                  (lx * lx) / (outerX * outerX) + (ly * ly) / (outerY * outerY),
                );
                final innerD = math.sqrt(
                  (lx * lx) / (innerX * innerX) + (ly * ly) / (innerY * innerY),
                );
                final outerAa = ((1.0 - outerD) * radius + 0.7).clamp(0.0, 1.0);
                final innerAa = ((innerD - 1.0) * radius + 0.7).clamp(0.0, 1.0);
                pixelAlpha = math.min(outerAa, innerAa);
              } else if (hexagon) {
                // グリッターフレーク：正六角形。傾き変形後のローカル座標を
                // 粒固有の角度だけ回転し、六角形の符号付き近似距離でAAする。
                final hx = ux * cosParticle - uy * sinParticle;
                final hy = ux * sinParticle + uy * cosParticle;
                final ax = hx.abs();
                final ay = hy.abs();
                const sqrt3 = 1.7320508075688772;
                final hexDist = math.max(
                  ay / (sqrt3 / 2.0),
                  (sqrt3 * ax + ay) / sqrt3,
                );
                pixelAlpha = (radius + 0.5 - hexDist).clamp(0.0, 1.0);
              } else if (pixelMode) {
                // ピクセルモード：エッジをシャープに（アンチエイリアス無し）
                pixelAlpha = dist <= radius ? 1.0 : 0.0;
              } else if (blur > 0) {
                // A blurred tip must soften *inside* its nominal radius too.
                // A fully opaque disc with a faded rim made the airbrush look
                // like a thick marker. Blend the original coverage with a
                // smooth, center-weighted Gaussian as blur grows; tiny blur
                // values retain the crisp underlying brush character.
                if (dist <= blurReach) {
                  var classic = 1.0;
                  if (dist > radius) {
                    final t = (dist - radius) / blur;
                    classic = 1.0 - t * t * (3.0 - 2.0 * t);
                  }
                  final soft = math.exp(
                    falloffScale * math.max(0.0, dist * dist - 0.5),
                  );
                  pixelAlpha = classic * hardShare + soft * softnessMix;
                } else {
                  pixelAlpha = 0.0;
                }
              } else {
                // 通常ブラシ／ボールチェーン：アンチエイリアス。ボールチェーンは
                // 円形そのものを保ち、専用spacingで粒がつながり過ぎないようにする。
                if (edgeJitter && dist > radius - 1.5) {
                  final maxJitter = edgeJitterStrength / 100.0 * 2.5;
                  final jitter =
                      (_jitterRng.nextDouble() - 0.5) * maxJitter * 2;
                  pixelAlpha = (radius + 0.5 - dist + jitter).clamp(0.0, 1.0);
                } else {
                  pixelAlpha = (radius + 0.5 - dist).clamp(0.0, 1.0);
                }
              }

              // Reproducible paper tooth for graphite, charcoal, gouache and
              // pastel. World-coordinate hash keeps the same grain across
              // overlapping dabs, zoom levels, and exported raster frames.
              // Built-in smooth brushes and legacy files pass zero and retain
              // exactly the previous pixels.
              if (grainStrength > 0 && pixelAlpha > 0) {
                var grain =
                    ((tileOriginX + px) * 73856093) ^
                    ((tileOriginY + py) * 19349663);
                grain = (grain ^ (grain >> 13)) * 1274126177;
                final noise = (grain & 255) / 255.0;
                final grit = grainStrength / 100.0;
                pixelAlpha *= 1.0 - grit * (0.15 + 0.82 * noise);
              }

              if (pixelAlpha > coverageCap) pixelAlpha = coverageCap;
              if (pixelAlpha <= 0) continue;

              // スタイラスを寝かせた場合は、傾き方向（+rdx）をペン先側として濃く、
              // 反対側を薄くする。形状の引き伸ばしだけで一様濃度にならないよう、
              // 元の円座標ux/radiusに沿って緩やかな線形濃度勾配を掛ける。
              // カリグラフィー固定角度ではスタイラス傾きではないため適用しない。
              if (stylusTiltMagnitude > 0.0001 && radius > 0) {
                final alongTilt = (ux / radius).clamp(-1.0, 1.0);
                final shadeStrength = 0.40 * stylusTiltMagnitude;
                final shade = (1.0 + alongTilt * shadeStrength).clamp(
                  0.45,
                  1.0,
                );
                pixelAlpha *= shade;
              }

              desiredAlpha = _byte((alpha * pixelAlpha).round());
            }
            if (fadeAlong != null && desiredAlpha > 0) {
              desiredAlpha = _byte(
                (desiredAlpha * fadeAlong.at(worldX, worldY, cx, cy)).round(),
              );
            }
            if (desiredAlpha <= 0) continue;

            // 同一ストローク内では、同じ画素へのスタンプ重複を加算せず
            // 「そのストロークがこの画素をどこまで覆ったか」の最大値だけを採用する。
            final coveragePos = py * TileManager.tileSize + px;
            final oldCoverage = coverage[coveragePos];
            if (oil != null) {
              // 油彩風：塗る前の画素の上へ、毛が置く絵の具を置き直す。筆の
              // 中心が通り過ぎる時にもう一度置くので、色の移り変わりは線に
              // 直角になる（前の縁で決めたままだと、スタンプの弧の形が残る）。
              final passing = carries && oil.passes(worldX, worldY, cx, cy);
              if (desiredAlpha <= oldCoverage && !passing) continue;
              recording?.remember(
                tileManager,
                tile,
                tx,
                ty,
                coveragePos,
                coverage,
                null,
              );
              final covered = math.max(desiredAlpha, oldCoverage);
              coverage[coveragePos] = covered;
              if (pixelMode) tileManager.markPaintedPixel(tile, coveragePos);
              oil.lay(
                tile,
                tx,
                ty,
                px,
                py,
                covered,
                paintRgb,
                carry: carries,
                cx: cx,
                cy: cy,
                radius: radius,
              );
              continue;
            }
            if (desiredAlpha <= oldCoverage) continue;
            recording?.remember(
              tileManager,
              tile,
              tx,
              ty,
              coveragePos,
              coverage,
              watercolor,
            );
            var incrementalAlpha = oldCoverage >= 255
                ? 0
                : _byte(
                    (((desiredAlpha - oldCoverage) * 255) / (255 - oldCoverage))
                        .round(),
                  );
            coverage[coveragePos] = desiredAlpha;
            if (watercolor != null) {
              if (pixelMode) tileManager.markPaintedPixel(tile, coveragePos);
              watercolor.cover(
                tile,
                tx,
                ty,
                px,
                py,
                desiredAlpha,
                mixingRate,
                opacity: alpha,
              );
              continue;
            }
            if (base != null && !isEraser) {
              // Keep this outline behind the existing layer and this stroke's fill.
              incrementalAlpha =
                  incrementalAlpha * (255 - base[coveragePos]) ~/ 255;
              if (previousFill != null) {
                incrementalAlpha =
                    incrementalAlpha * (255 - previousFill[coveragePos]) ~/ 255;
              }
            }
            if (incrementalAlpha <= 0) continue;
            if (pixelMode && !isEraser) {
              tileManager.markPaintedPixel(tile, coveragePos);
            }

            if (isEraser) {
              tileManager.erasePixel(tile, px, py, incrementalAlpha);
            } else if (oilMixer != null) {
              final paint = paintRgb;
              final idx = (py * TileManager.tileSize + px) * 4;
              final belowAlpha = tile[idx + 3];
              // A faint edge holds less paint to pick up than a solid area.
              // The tile is premultiplied: the colour under the brush is
              // its RGB divided back by its alpha.
              int under(int c) => (c * 255 ~/ belowAlpha).clamp(0, 255);
              final mixed = belowAlpha > 0
                  ? oilMixer.mixNear(
                      under(tile[idx]) << 16 |
                          under(tile[idx + 1]) << 8 |
                          under(tile[idx + 2]),
                      mixingRate / 100.0 * belowAlpha / 255.0,
                      paint,
                    )
                  : paint;
              tileManager.blendPixel(
                tile,
                px,
                py,
                mixed >> 16 & 0xFF,
                mixed >> 8 & 0xFF,
                mixed & 0xFF,
                incrementalAlpha,
              );
            } else {
              tileManager.blendPixel(
                tile,
                px,
                py,
                ri,
                gi,
                bi,
                incrementalAlpha,
              );
            }
          }
        }
        // 描き直しの中で引いたタイルは、引いたときに変わったと記録してある。
        if (_updateTiles == null || layerId != _updateTilesLayer) {
          tileManager.markDirty(layerId, tx, ty);
        }
      }
    }
  }

  /// 書き込むタイル（[TileManager.getOrCreateTile]）。ピクセルモードの線を
  /// 描き直している間（[_updateTiles]）は、同じタイルは最初の1回だけ引く：
  /// その間は同じバッファが返り、変わったこと・取り消しの記録は最初に引いた
  /// ときに記録される（描き直しの途中で、その記録を読む処理は無い）。
  Uint8List _writableTile(String layerId, int tx, int ty) {
    final tiles = _updateTiles;
    if (tiles == null || layerId != _updateTilesLayer) {
      return tileManager.getOrCreateTile(layerId, tx, ty);
    }
    return tiles[tx << 24 | ty] ??= tileManager.getOrCreateTile(
      layerId,
      tx,
      ty,
    );
  }

  // ─── ユーティリティ ───────────────────────────────────────────────────

  /// `value.clamp(0, 255)`（整数どうしなので比べるだけ）。
  static int _byte(int value) => value < 0 ? 0 : (value > 255 ? 255 : value);

  double _distance(StrokePoint a, StrokePoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// [brush]'s fade (フェード) as a ramp at each end of the stroke: from its
  /// start value up to full over its start distance, and from full down to
  /// its end value over its end distance; full in between. 弱・中・強 are set
  /// ramps; カスタム takes the brush's own. The end ramp needs [totalLength],
  /// known once the stroke is complete (the stroke is then drawn again).
  /// When the two ramps would overlap on an ordinary brush's short stroke,
  /// they are shortened in proportion so that they meet at full, not dip
  /// below either end.
  _FadeRamp _fadeRamp(Brush brush, {double? totalLength}) => _endsRamp(
    brush.colourFadeMode,
    brush.fadeIn,
    brush.fadeOut,
    fitsShortStroke: true,
    totalLength: totalLength,
  );

  /// The stroke's 入り抜き: how much of the width is left along it, with the
  /// same ramps as the fade. An outline pen's ends shape the whole pen and
  /// keep their distances on a short stroke.
  _FadeRamp _taperRamp(Brush brush, {double? totalLength}) => _endsRamp(
    brush.shapeTaperMode,
    brush.shapeTaperIn,
    brush.shapeTaperOut,
    fitsShortStroke: !brush.outlineEnabled,
    totalLength: totalLength,
  );

  _FadeRamp _endsRamp(
    FadeMode mode,
    FadeEndpointSettings fadeIn,
    FadeEndpointSettings fadeOut, {
    required bool fitsShortStroke,
    double? totalLength,
  }) {
    final (inValue, inRange, outValue, outRange) = switch (mode) {
      FadeMode.off => (1.0, 0.0, 1.0, 0.0),
      FadeMode.weak => (0.5, 40.0, 0.5, 40.0),
      FadeMode.medium => (0.2, 80.0, 0.2, 80.0),
      FadeMode.strong => (0.0, 150.0, 0.0, 150.0),
      FadeMode.custom => (
        fadeIn.value / 100,
        fadeIn.rangePx,
        fadeOut.value / 100,
        fadeOut.rangePx,
      ),
    };
    var start = math.max(0.0, inRange);
    var end = math.max(0.0, outRange);
    var shrunk = false;
    if (fitsShortStroke) {
      // An end left at 100% does not change, so its distance takes no share
      // of a short stroke (the custom setting's untouched end is 100% over
      // 500px).
      if (inValue >= 1) start = 0;
      if (outValue >= 1) end = 0;
      if (totalLength != null && start + end > totalLength) {
        final share = totalLength / (start + end);
        start *= share;
        end *= share;
        shrunk = true;
      }
    }
    return _FadeRamp(
      inValue: inValue.clamp(0.0, 1.0).toDouble(),
      inRange: start,
      outValue: outValue.clamp(0.0, 1.0).toDouble(),
      outRange: end,
      total: totalLength,
      shrunk: shrunk,
    );
  }

  /// How far a custom taper has grown at [progress] (0 at the tip, 1 where
  /// it meets the full stroke): as steep at the tip as a straight ramp (just
  /// as sharp a point), and level where it meets the full width, so the
  /// outline does not turn a corner where the taper begins (a straight ramp
  /// does). Still [rangePx] long.
  static double _taperShoulder(double progress) =>
      progress + progress * progress * (1 - progress);

  double _calculateDecay(double strokeLength) =>
      (1.0 - strokeLength / 2000).clamp(0.05, 1.0);

  /// The cached mixer for paint near [paint] (each channel to 4 levels).
  AnalogPaintMixer _oilMixerFor(int paint, int brightnessCorrection) {
    final near = paint & 0xFCFCFC;
    final correction = brightnessCorrection.clamp(1, 5).toInt();
    final key = near << 3 | correction;
    final cached = _oilMixers.remove(key);
    if (cached != null) return _oilMixers[key] = cached;
    if (_oilMixers.length >= 24) _oilMixers.remove(_oilMixers.keys.first);
    return _oilMixers[key] = AnalogPaintMixer(
      selected: near,
      brightnessCorrection: correction,
    );
  }

  static int _rgb24(ui.Color color) =>
      (color.r * 255).round() << 16 |
      (color.g * 255).round() << 8 |
      (color.b * 255).round();

  /// 油彩風 brush mixing of [selected] into [below] like paint, keeping the
  /// colours vivid (see [AnalogPaintMixer]). [rate] is the contribution of
  /// the colour below.
  ui.Color mixColor(
    ui.Color below,
    ui.Color selected,
    double rate, {
    int brightnessCorrection = 3,
  }) => mixPerceptualColor(
    below,
    selected,
    rate,
    brightnessCorrection: brightnessCorrection,
  );

  ({double scaleX, double scaleY, double angle}) calcTiltTransform(
    double tiltX,
    double tiltY,
  ) {
    final tiltMag = math.sqrt(tiltX * tiltX + tiltY * tiltY);
    final stretch = 1.0 + tiltMag * 2.0;
    final angle = (tiltX != 0 || tiltY != 0) ? math.atan2(tiltY, tiltX) : 0.0;
    return (scaleX: stretch, scaleY: 1.0, angle: angle);
  }
}

class StrokePoint {
  final double x;
  final double y;
  final double pressure;
  final double tiltX;
  final double tiltY;
  final InputType inputType;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    this.tiltX = 0.0,
    this.tiltY = 0.0,
    this.inputType = InputType.touch,
  });
}

enum InputType { touch, stylus, mouse }

/// ピクセルモードの格子に置く形を、塗りの太さと縁取りの外径から作るもの。
typedef _PixelShape =
    ({PixelMask? fill, PixelMask? outline}) Function(double fill, double outer);

/// 点に作った形（作ったときの塗りの太さ・縁取りの外径と、その形）。
///
/// 入れ物に入れるので、レコードではなくクラスにする（レコードの型を確かめる
/// のは、入れ物へ入れるたびだと重い）。
final class _PixelShapeCall {
  const _PixelShapeCall(this.fill, this.outer, this.fillMask, this.outline);

  final double fill;
  final double outer;
  final PixelMask? fillMask;
  final PixelMask? outline;
}

/// 1ストローク内の、タイルごとの各画素の最大カバレッジ（覆いの種類
/// ・レイヤー・タイルごと）。続けて同じタイルを引くことが多いので、最近
/// 引いたものは文字列のキーを作らずに返す。
class _CoverageTiles {
  final Map<String, Uint8List> _tiles = {};
  // 最近引いた4つ（種類・レイヤー・タイルの位置・記録）。
  static const int _slots = 4;
  final List<String?> _namespaces = List.filled(_slots, null);
  final List<String?> _layers = List.filled(_slots, null);
  final Int32List _xs = Int32List(_slots);
  final Int32List _ys = Int32List(_slots);
  final List<Uint8List?> _recent = List.filled(_slots, null);
  int _next = 0;

  /// [namespace]の覆いの記録（無ければ空で作る）。
  Uint8List of(String namespace, String layerId, int tx, int ty) =>
      existing(namespace, layerId, tx, ty) ??
      _remember(
        namespace,
        layerId,
        tx,
        ty,
        _tiles.putIfAbsent(
          '$namespace:$layerId:$tx:$ty',
          () => Uint8List(TileManager.tileSize * TileManager.tileSize),
        ),
      );

  /// [namespace]の覆いの記録（無ければnull）。
  Uint8List? existing(String namespace, String layerId, int tx, int ty) {
    for (var i = 0; i < _slots; i++) {
      final tile = _recent[i];
      if (tile != null &&
          _xs[i] == tx &&
          _ys[i] == ty &&
          _namespaces[i] == namespace &&
          _layers[i] == layerId) {
        return tile;
      }
    }
    final tile = _tiles['$namespace:$layerId:$tx:$ty'];
    return tile == null ? null : _remember(namespace, layerId, tx, ty, tile);
  }

  Uint8List _remember(
    String namespace,
    String layerId,
    int tx,
    int ty,
    Uint8List tile,
  ) {
    final i = _next;
    _next = (_next + 1) % _slots;
    _namespaces[i] = namespace;
    _layers[i] = layerId;
    _xs[i] = tx;
    _ys[i] = ty;
    _recent[i] = tile;
    return tile;
  }

  void clear() {
    _tiles.clear();
    _recent.fillRange(0, _slots, null);
  }
}

/// ピクセルモードの線の点の、ドットを置くときの値。
class _PixelDab {
  final double pressure;
  final double strokeLength;

  const _PixelDab({required this.pressure, required this.strokeLength});
}

/// ピクセルモードの格子に置くブラシの描き方：丸いペン先の線（太さが一定の
/// 帯）・カリグラフィーの平たいペン先を点ごとに置く線・間隔を空けて置く
/// ドット／ペン先の画像。
enum _PixelKind { line, nib, stamps }

/// ピクセルモードの格子に置く1本のストローク（横方向の反復なら線ごとの
/// [_PixelTrace]）。
class _PixelStroke {
  _PixelStroke({
    required this.kind,
    required this.corners,
    required this.squareCorners,
    required this.spacing,
    required this.repeat,
    required this.start,
    required this.startDab,
    required this.newTracer,
  });

  final _PixelKind kind;

  /// 画素の角を格子点にするか（偶数の太さ）。
  final bool corners;
  final bool squareCorners;

  /// 間隔を空けて置くドットの間隔（px）。
  final double spacing;
  final int repeat;
  final ui.Offset start;
  final _PixelDab startDab;
  final PixelLineTracer<_PixelDab> Function(ui.Offset, _PixelDab) newTracer;
  final List<_PixelTrace> traces = [];

  /// 閉じた図形（最後の点の次が最初の点）。
  bool closed = false;

  /// 楕円のように、たどらずに決まった点の並び。
  PixelChain<_PixelDab>? fixedChain;

  /// まだ変わりうる点として描いた画素（描き直す前に戻す）。
  final _PixelLog log = _PixelLog();

  /// 間隔を空けて置くペン先の画像（何番目のドットか、の順に選ぶ）。
  final List<String?> _textures = [];

  /// 横方向の反復の向きを測る、ペンの道（位置と、そこまでの長さ）。
  final List<(ui.Offset, double)> path = [];

  void addTrace(ui.Offset at, _PixelDab dab) =>
      traces.add(_PixelTrace(newTracer(at, dab), at));

  String? textureAt(int index, BrushTextureSelector selector) {
    while (_textures.length <= index) {
      _textures.add(selector.nextDabPath());
    }
    return _textures[index];
  }

  /// 今のペンの道の向きに直角な向き（1px動くまではnull）。向きは最後の
  /// 2pxほどで測る。
  ui.Offset? normal() {
    if (path.isEmpty) return null;
    final (end, length) = path.last;
    if (length < 1) return null;
    var from = start;
    for (var i = path.length - 2; i >= 0; i--) {
      if (length - path[i].$2 >= 2) {
        from = path[i].$1;
        break;
      }
    }
    final d = end - from;
    if (d.distance < 1e-6) return null;
    final unit = d / d.distance;
    return ui.Offset(-unit.dy, unit.dx);
  }
}

/// [_PixelStroke]の中の1本の線。
class _PixelTrace {
  _PixelTrace(this.tracer, this.last);

  final PixelLineTracer<_PixelDab> tracer;

  /// 最後にたどったペンの位置（反復ではずらした位置）。
  ui.Offset last;

  /// 描いた（確定した）点の数。
  int rendered = 0;

  /// [rendered]番目の点までの線の長さと、次に置くドットの番号（間隔を空けて
  /// 置くドット）。
  ({double length, int next}) state = (length: 0, next: 0);

  /// 前に描いた点の並び（[DrawingEngine._updatePixelTrace]が、変わった点を
  /// 見つけるのに使う）。
  PixelChain<_PixelDab>? drawn;

  /// まだ変わりうる点に前に作った形（点の番号ごと）と、そのときの点の並び。
  /// 形の見る範囲の点が同じなら、描き直すときにそのまま使う。
  final _PixelShapes shapes = _PixelShapes();

  void walkTo(ui.Offset to, _PixelDab Function(double t) dabAt) {
    tracer.walk(last, to, dabAt);
    last = to;
  }
}

/// [_PixelTrace]の点に前に作った形（点の番号ごと、[forgetBefore]より後の点）。
class _PixelShapes {
  int _base = 0;
  final List<_PixelShapeEntry?> _entries = [];

  _PixelShapeEntry? operator [](int k) {
    final i = k - _base;
    return i >= 0 && i < _entries.length ? _entries[i] : null;
  }

  void operator []=(int k, _PixelShapeEntry entry) {
    final i = k - _base;
    if (i < 0) return;
    while (_entries.length <= i) {
      _entries.add(null);
    }
    _entries[i] = entry;
  }

  /// [k]番目より前の点の形を忘れる。
  void forgetBefore(int k) {
    final count = k - _base;
    if (count <= 0) return;
    if (count >= _entries.length) {
      _entries.clear();
    } else {
      _entries.removeRange(0, count);
    }
    _base = k;
  }
}

/// 点に前に作った形と、そのときの点の並び・形が前後の何点目まで見たか。
final class _PixelShapeEntry {
  const _PixelShapeEntry(this.chain, this.call, this.span);

  final PixelChain<_PixelDab> chain;
  final _PixelShapeCall call;
  final int span;
}

/// まだ変わりうる点として描いた画素の、描く前の状態（点ごと）。
///
/// ペンが動くたびに覚えては戻すので、入れ物は縮めずに使い回す（数で
/// 使っている所までを表し、後ろは次に覚えるときに上書きする）。
class _PixelLog {
  // 画素ごと（[_pixelCount]個）：タイル・その線の覆いの記録・水彩の状態と、
  // [_stride]個の数（位置・覆い・塗った印・水彩の状態・タイルの位置）・RGBA。
  static const int _stride = 6;
  final List<Uint8List> _tiles = [];
  final List<Uint8List> _coverages = [];
  final List<WatercolorStroke?> _washes = [];
  Int32List _values = Int32List(64 * _stride);
  Uint32List _rgba = Uint32List(64);
  int _pixelCount = 0;
  // 点ごと（[_first]から[_pointCount]の手前まで）：その点の最初の画素の
  // 番号・形が後の何点目まで見たか・作った形・描く前の油彩の筆の毛。
  Int32List _starts = Int32List(64);
  Int32List _spans = Int32List(64);
  final List<_PixelShapeCall?> _shapes = [];
  final List<OilBristles?> _oilBristles = [];
  int _first = 0;
  int _pointCount = 0;
  // 戻した画素のタイル（左に24ビットずらしたx・y）。
  final Set<int> _touched = {};

  /// 覚えている点の数。
  int get points => _pointCount - _first;

  /// 点の形が、後の何点目の位置まで見たかの最大。
  static const int maxSpan = 4;

  /// [i]番目の点の形が、後の何点目の位置まで見たか。
  int spanAt(int i) => _spans[_first + i];

  /// [i]番目の点に作った形（形を作らなかった点はnull）。
  _PixelShapeCall? shapeAt(int i) => _shapes[_first + i];

  static void _put<E>(List<E> list, int index, E value) {
    if (index < list.length) {
      list[index] = value;
    } else {
      list.add(value);
    }
  }

  static Int32List _grownInts(Int32List list, int length) {
    if (length <= list.length) return list;
    return Int32List(math.max(length, 2 * list.length))..setAll(0, list);
  }

  void beginPoint(OilBristles? oil) {
    final point = _pointCount++;
    _starts = _grownInts(_starts, _pointCount);
    _spans = _grownInts(_spans, _pointCount);
    _starts[point] = _pixelCount;
    _spans[point] = maxSpan;
    _put(_shapes, point, null);
    _put(_oilBristles, point, oil);
  }

  /// 最後に始めた点の形が、後の[span]点目の位置まで見た。
  void setSpan(int span) => _spans[_pointCount - 1] = span;

  /// 最後に始めた点に作った形。
  void setShape(_PixelShapeCall? shape) => _shapes[_pointCount - 1] = shape;

  void remember(
    TileManager tileManager,
    Uint8List tile,
    int tx,
    int ty,
    int pos,
    Uint8List coverage,
    WatercolorStroke? wash,
  ) {
    final i = pos * 4;
    final p = _pixelCount++;
    _put(_tiles, p, tile);
    _put(_coverages, p, coverage);
    _put(_washes, p, wash);
    _values = _grownInts(_values, _pixelCount * _stride);
    if (_rgba.length < _pixelCount) {
      _rgba = Uint32List(2 * _rgba.length)..setAll(0, _rgba);
    }
    _rgba[p] =
        tile[i] | tile[i + 1] << 8 | tile[i + 2] << 16 | tile[i + 3] << 24;
    final v = p * _stride;
    _values[v] = pos;
    _values[v + 1] = coverage[pos];
    _values[v + 2] = tileManager.isPaintedPixel(tile, pos) ? 1 : 0;
    _values[v + 3] = wash?.pixelState(tx, ty, pos) ?? -1;
    _values[v + 4] = tx;
    _values[v + 5] = ty;
  }

  /// [keep]番目の点から先の画素を、覚えたのと逆の順に戻して忘れる。戻した
  /// 時点の油彩の筆の毛を返す。
  OilBristles? rollBack(int keep, TileManager tileManager) {
    final point = _first + keep;
    final start = _starts[point];
    for (var p = _pixelCount - 1; p >= start; p--) {
      final tile = _tiles[p];
      final v = p * _stride;
      final pos = _values[v];
      final rgba = _rgba[p];
      final i = pos * 4;
      tile[i] = rgba & 0xFF;
      tile[i + 1] = rgba >> 8 & 0xFF;
      tile[i + 2] = rgba >> 16 & 0xFF;
      tile[i + 3] = rgba >> 24 & 0xFF;
      _coverages[p][pos] = _values[v + 1];
      tileManager.setPaintedPixel(tile, pos, _values[v + 2] == 1);
      final wash = _values[v + 3];
      if (wash >= 0) {
        _washes[p]?.restorePixel(_values[v + 4], _values[v + 5], pos, wash);
      }
      _touched.add(_values[v + 4] << 24 | _values[v + 5]);
    }
    final oil = _oilBristles[point];
    _pixelCount = start;
    _pointCount = point;
    return oil;
  }

  /// 戻した画素のタイル（描き直して見せる）。
  List<(int, int)> takeTouched() {
    final touched = [for (final key in _touched) (key >> 24, key & 0xFFFFFF)];
    _touched.clear();
    return touched;
  }

  /// 最初の[count]点を、もう戻さない点として忘れる。
  void dropFront(int count) {
    if (count <= 0) return;
    _first += count;
    if (_first < _pointCount && _first > 64 && _first * 2 > _pointCount) {
      // 忘れた点の分を詰める（長い線で覚えが増え続けないように）。
      final offset = _starts[_first];
      final pixels = _pixelCount - offset;
      for (var p = 0; p < pixels; p++) {
        _tiles[p] = _tiles[offset + p];
        _coverages[p] = _coverages[offset + p];
        _washes[p] = _washes[offset + p];
      }
      _values.setRange(0, pixels * _stride, _values, offset * _stride);
      _rgba.setRange(0, pixels, _rgba, offset);
      final points = _pointCount - _first;
      for (var i = 0; i < points; i++) {
        _starts[i] = _starts[_first + i] - offset;
        _spans[i] = _spans[_first + i];
        _shapes[i] = _shapes[_first + i];
        _oilBristles[i] = _oilBristles[_first + i];
      }
      _pixelCount = pixels;
      _pointCount = points;
      _first = 0;
      return;
    }
    if (_first >= _pointCount) {
      _pixelCount = 0;
      _pointCount = 0;
      _first = 0;
    }
  }
}

/// A stroke's fade (フェード) along its length: [inValue] at the start rising
/// to full over [inRange] px, and full falling to [outValue] over the last
/// [outRange] px of a stroke [total] px long (no end ramp until it is known).
final class _FadeRamp {
  const _FadeRamp({
    required this.inValue,
    required this.inRange,
    required this.outValue,
    required this.outRange,
    required this.total,
    this.shrunk = false,
  });

  final double inValue;
  final double inRange;
  final double outValue;
  final double outRange;
  final double? total;

  /// Whether the ramps were shortened to fit a short stroke (so the start
  /// changes once the length is known, too).
  final bool shrunk;

  /// The fade [s] px along the stroke (0 to 1).
  double at(double s) {
    var fade = 1.0;
    if (inRange > 0 && inValue < 1 && s < inRange) {
      final p = s <= 0 ? 0.0 : s / inRange;
      fade = inValue + (1 - inValue) * DrawingEngine._taperShoulder(p);
    }
    final total = this.total;
    if (total != null && outRange > 0 && outValue < 1) {
      final left = total - s;
      if (left < outRange) {
        final p = left <= 0 ? 0.0 : left / outRange;
        fade *= outValue + (1 - outValue) * DrawingEngine._taperShoulder(p);
      }
    }
    return fade;
  }

  /// Whether the fade changes anywhere from [from] to [to] px along the
  /// stroke.
  bool changesWithin(double from, double to) {
    if (inRange > 0 && inValue < 1 && from < inRange) return true;
    final total = this.total;
    return total != null &&
        outRange > 0 &&
        outValue < 1 &&
        to > total - outRange;
  }
}

/// An ordinary brush's fade laid per pixel by where the pixel is along the
/// stroke (its distance along the stroke's direction from the dab), not by
/// the dab: dabs overlap, and each would otherwise lay its own fade over its
/// whole round footprint, the dab ahead (more opaque on the way in) reaching
/// further along the middle of the stroke than its edges, so the middle
/// would fade later than the edges.
final class _FadeAlong {
  const _FadeAlong(this.ramp, this.length, this.dx, this.dy);

  final _FadeRamp ramp;

  /// How far along the stroke the dab is, and the stroke's direction there
  /// (unit vector).
  final double length;
  final double dx;
  final double dy;

  /// The fade at canvas point ([x], [y]) of the dab centred at ([cx], [cy]).
  double at(double x, double y, double cx, double cy) {
    var s = length + (x - cx) * dx + (y - cy) * dy;
    if (s < 0) s = 0;
    final total = ramp.total;
    if (total != null && s > total) s = total;
    return ramp.at(s);
  }
}
