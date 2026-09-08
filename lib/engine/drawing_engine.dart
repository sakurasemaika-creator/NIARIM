import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/brush.dart';
import 'brush_texture_cache.dart';
import 'tile_manager.dart';

final _jitterRng = math.Random();

// カリグラフィーブラシのペン先の扁平度（幅:高さ）。値が大きいほど、
// ペン先の向きに直交する方向へ動かした時の線が太く、平行な方向は細くなる。
const double kCalligraphyNibAspect = 2.6;

class DrawingEngine {
  final TileManager tileManager;

  final List<StrokePoint> _currentStroke = [];

  // 1ストローク内の各画素の最大カバレッジを保持する。
  // ブラシ不透明度50%の線をspacing=1で引いた際、同じ画素へ多数のスタンプが
  // 重なって100%近くまで濃くなるのを防ぐ。別ストロークではリセットされるため、
  // 線同士を交差させた箇所は通常のsource-overどおり濃くなる。
  final Map<String, Uint8List> _strokeCoverageByTile = {};

  // ブラシの密度・散布を入力moveイベント数から独立させるため、ストロークを
  // またいで「直前のスタンプから進んだ距離」を保持する。各move区間の先頭で
  // spacingをリセットすると、同じ直線でもOSのイベント密度によって結果が
  // 変わるため、StampEngineと同じくパス長基準で再サンプリングする。
  double _distanceSinceLastBrushStamp = 0.0;
  bool _hasStampedCurrentStroke = false;
  String? _activeLayerId;
  math.Random _scatterRng = math.Random(0);

  Brush? currentBrush;
  ui.Color currentColor = const ui.Color(0xFF000000);
  bool isEraser = false;

  // 定規など、手ブレ補正より後に必ず満たすべき最終座標制約。
  ui.Offset Function(ui.Offset)? pointConstraint;

  // 手ブレ補正用：直近の平滑化済み座標（ON/OFF・強度調整）
  StrokePoint? _smoothed;

  DrawingEngine({required this.tileManager});

  void beginStroke(StrokePoint point, String layerId) {
    _currentStroke.clear();
    _strokeCoverageByTile.clear();
    _smoothed = point;
    final effective = _applyPointConstraint(point);
    _activeLayerId = layerId;
    _distanceSinceLastBrushStamp = 0.0;
    _hasStampedCurrentStroke = false;
    _scatterRng = math.Random(0);
    _currentStroke.add(effective);
    final brush = currentBrush;
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

  void continueStroke(StrokePoint point, String layerId) {
    if (_currentStroke.isEmpty) {
      beginStroke(point, layerId);
      return;
    }
    final effective = _applyPointConstraint(_applyStabilization(point));
    final from = _currentStroke.last;
    // 区間を描画してから終点を履歴へ追加する。これにより
    // _renderStrokeSegment() が取得するbaseStrokeLengthは必ず区間開始時点までの
    // 累積距離となり、OSから届くmoveイベント数に依存しない。
    _renderStrokeSegment(from, effective, layerId);
    _currentStroke.add(effective);
  }

  void endStroke() {
    // 回転/散布ONでPointerDown→Upだけのタップだった場合は進行方向が存在しない。
    // その場合だけ中心位置へ1回描画し、散布は行わない。
    if (!_hasStampedCurrentStroke &&
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
    _currentStroke.clear();
    _strokeCoverageByTile.clear();
    _smoothed = null;
    _activeLayerId = null;
    _distanceSinceLastBrushStamp = 0.0;
    _hasStampedCurrentStroke = false;
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

  /// 手ブレ補正：入力座標を直近の平滑化済み座標へ指数移動平均で追従させる。
  /// strengthが高いほど追従を遅くし、線が滑らかになる（軽量・毎ピクセル計算なし）。
  StrokePoint _applyStabilization(StrokePoint raw) {
    final brush = currentBrush;
    if (brush == null || !brush.stabilization) {
      _smoothed = raw;
      return raw;
    }
    final prev = _smoothed ?? raw;
    final strength = brush.stabilizationStrength.clamp(0, 100) / 100.0;
    final factor = (1.0 - strength * 0.85).clamp(0.05, 1.0);
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
  void commitShapePath(
    List<StrokePoint> pathPoints,
    String layerId, {
    bool closeLoop = false,
  }) {
    if (currentBrush == null || pathPoints.isEmpty) return;
    _currentStroke.clear();
    _strokeCoverageByTile.clear();
    _activeLayerId = layerId;
    _distanceSinceLastBrushStamp = 0.0;
    _hasStampedCurrentStroke = false;
    _scatterRng = math.Random(0);

    final first = pathPoints.first;
    _currentStroke.add(first);
    final brush = currentBrush!;
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
      _renderStrokeSegment(_currentStroke.last, to, layerId);
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

    final safeDensity = brush.density.clamp(0.1, 5.0).toDouble();
    final spacing = _brushStampSpacing(brush, safeDensity);
    final pathAngle = math.atan2(to.y - from.y, to.x - from.x);
    // この区間より前に実際に進んだ距離。各補間スタンプでは
    // base + consumed を使うため、1回の大きなmoveでも多数の小さなmoveでも
    // フェード/ストローク減衰が同じ距離位置で同じ値になる。
    final baseStrokeLength = _currentStrokeLength();

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
    final factor = switch (brush.id) {
      'Brush0018' => 0.68,
      'Brush0019' => 0.72,
      'Brush0020' => 0.76,
      'Brush0021' => 1.35,
      _ => 0.0,
    };
    if (factor > 0) {
      return math.max(1.0, brush.size * factor / safeDensity);
    }
    return math.max(1.0, brush.spacing.toDouble() / safeDensity);
  }

  double _stableDouble(double value) => (value * 1000000).round() / 1000000;

  void _stampBrush(
    double x,
    double y,
    double pressure,
    double tiltX,
    double tiltY,
    String layerId, {
    double? strokeLengthOverride,
    double pathAngle = 0.0,
    bool applyScatter = true,
  }) {
    if (currentBrush == null) return;
    final brush = currentBrush!;

    var size = brush.size;
    var opacity = brush.opacity / 100.0;

    // 筆圧強度0%では筆圧の影響を無効化し、100%では端末からのpressureを
    // そのまま反映する。中間値は「筆圧なし(1.0)」と生pressureを線形補間する。
    final rawPressure = pressure.clamp(0.0, 1.0);
    final pressureStrength = brush.pressureStrength.clamp(0, 100) / 100.0;
    final effectivePressure = 1.0 - (1.0 - rawPressure) * pressureStrength;

    // 筆圧反映
    switch (brush.pressureMode) {
      case PressureMode.size:
        size *= effectivePressure;
      case PressureMode.opacity:
        opacity *= effectivePressure;
      case PressureMode.sizeAndOpacity:
        size *= effectivePressure;
        opacity *= effectivePressure;
      case PressureMode.off:
        break;
    }

    final strokeLength = strokeLengthOverride ?? _currentStrokeLength();

    // フェード仕様は「ストロークが進むにつれて不透明度・サイズが減少」。
    // 同じ係数を両方へ適用し、終端で薄いだけの同径線にならないようにする。
    if (brush.fadeMode != FadeMode.off) {
      final fade = _calculateFade(brush, strokeLength);
      opacity *= fade;
      size *= fade;
    }
    // ストローク減衰はインク切れ表現なので、不透明度だけを減らして太さは維持する。
    if (brush.strokeDecay) {
      opacity *= _calculateDecay(strokeLength);
    }

    opacity = opacity.clamp(0.0, 1.0);
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

    final radius = size / 2.0;
    final alphaInt = (opacity * 255).round().clamp(0, 255);
    if (alphaInt == 0) return;

    // グリッターペンは大きな六角形フレークとして描画する。粒ごとに向きを
    // ランダム化し、同じ向きの六角形が機械的に並ぶ見た目を避ける。
    // ラメペンを含む他ブラシは従来どおり円形スタンプのまま。
    final isGlitterHexagon = brush.id == 'Brush0016';
    final isChainLink =
        brush.id == 'Brush0018' ||
        brush.id == 'Brush0019' ||
        brush.id == 'Brush0020';
    final isBallChain = brush.id == 'Brush0021';
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
    final chainAspect = switch (brush.id) {
      'Brush0018' => 0.64,
      'Brush0019' => 0.56,
      'Brush0020' => 0.50,
      _ => 1.0,
    };
    final chainThickness = switch (brush.id) {
      'Brush0018' => 0.25,
      'Brush0019' => 0.19,
      'Brush0020' => 0.14,
      _ => 0.0,
    };

    // 傾き変形：カリグラフィーブラシ（ペン先角度固定）の場合は、実際の
    // スタイラス傾きに関わらず常に固定角度へ扁平化したペン先を使う。
    var tilt = brush.calligraphyAngle != null
        ? (
            scaleX: kCalligraphyNibAspect,
            scaleY: 1.0,
            angle: brush.calligraphyAngle! * math.pi / 180,
          )
        : calcTiltTransform(tiltX, tiltY);
    // 回転ONではブラシ先端をパス接線方向へ追従させる。固定角度ブラシは
    // その角度を接線方向へのオフセットとして保持する。
    if (brush.rotation) {
      final angleOffset = brush.calligraphyAngle == null
          ? 0.0
          : brush.calligraphyAngle! * math.pi / 180.0;
      tilt = (
        scaleX: tilt.scaleX,
        scaleY: tilt.scaleY,
        angle: pathAngle + angleOffset,
      );
    }
    final stylusTiltMagnitude =
        brush.calligraphyAngle == null && !brush.rotation
        ? math.sqrt(tiltX * tiltX + tiltY * tiltY).clamp(0.0, 1.0)
        : 0.0;

    // 自作ブラシ（ブラシ画像からのブラシ作成）が選択され、
    // 事前読み込み済みの場合はその形状を、それ以外は円形（またはピクセル
    // モード）でスタンプする。
    final texturePath = brush.customImagePath;
    final customTexture = texturePath != null
        ? getCachedBrushTexture(texturePath)
        : null;
    _renderCircleStamp(
      stampX,
      stampY,
      radius,
      alphaInt,
      tilt,
      layerId,
      brush.pixelMode,
      brush.blurRadius,
      customTexture,
      stylusTiltMagnitude: stylusTiltMagnitude,
      edgeJitter: brush.edgeJitter,
      edgeJitterStrength: brush.edgeJitterStrength,
      hexagon: isGlitterHexagon,
      particleRotation: particleRotation,
      chainLink: isChainLink,
      chainAspect: chainAspect,
      chainThickness: chainThickness,
      ballChain: isBallChain,
    );
  }

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
    bool edgeJitter = false,
    int edgeJitterStrength = 50,
    bool hexagon = false,
    double particleRotation = 0.0,
    bool chainLink = false,
    double chainAspect = 1.0,
    double chainThickness = 0.0,
    bool ballChain = false,
  }) {
    final r = currentColor.r;
    final g = currentColor.g;
    final b = currentColor.b;
    final ri = (r * 255).round();
    final gi = (g * 255).round();
    final bi = (b * 255).round();

    // 影響範囲のタイルを特定
    final effectiveRadius = radius * math.max(tilt.scaleX, tilt.scaleY);
    final blur = blurRadius.toDouble();
    final totalRadius = effectiveRadius + blur;

    final minTx = ((cx - totalRadius) / TileManager.tileSize).floor();
    final maxTx = ((cx + totalRadius) / TileManager.tileSize).floor();
    final minTy = ((cy - totalRadius) / TileManager.tileSize).floor();
    final maxTy = ((cy + totalRadius) / TileManager.tileSize).floor();

    for (int ty = minTy; ty <= maxTy; ty++) {
      for (int tx = minTx; tx <= maxTx; tx++) {
        if (tx < 0 || ty < 0) continue;
        final tile = tileManager.getOrCreateTile(layerId, tx, ty);
        final tileOriginX = tx * TileManager.tileSize;
        final tileOriginY = ty * TileManager.tileSize;
        final coverageKey = '$layerId:$tx:$ty';
        final coverage = _strokeCoverageByTile.putIfAbsent(
          coverageKey,
          () => Uint8List(TileManager.tileSize * TileManager.tileSize),
        );

        // タイル内の影響ピクセル範囲
        final localMinX = math.max(0, (cx - totalRadius - tileOriginX).floor());
        final localMaxX = math.min(
          TileManager.tileSize - 1,
          (cx + totalRadius - tileOriginX).ceil(),
        );
        final localMinY = math.max(0, (cy - totalRadius - tileOriginY).floor());
        final localMaxY = math.min(
          TileManager.tileSize - 1,
          (cy + totalRadius - tileOriginY).ceil(),
        );

        for (int py = localMinY; py <= localMaxY; py++) {
          for (int px = localMinX; px <= localMaxX; px++) {
            final worldX = tileOriginX + px + 0.5;
            final worldY = tileOriginY + py + 0.5;
            final dx = worldX - cx;
            final dy = worldY - cy;

            // 傾き変形を適用した楕円距離
            final cosA = math.cos(-tilt.angle);
            final sinA = math.sin(-tilt.angle);
            final rdx = dx * cosA - dy * sinA;
            final rdy = dx * sinA + dy * cosA;
            final ux = rdx / tilt.scaleX;
            final uy = rdy / tilt.scaleY;
            final dist = math.sqrt(ux * ux + uy * uy);

            double pixelAlpha;
            if (customTexture != null) {
              // 自作ブラシ画像：楕円内をテクスチャのアルファでサンプリング
              if (dist > radius) {
                pixelAlpha = 0.0;
              } else {
                final nx = (ux / radius).clamp(-1.0, 1.0);
                final ny = (uy / radius).clamp(-1.0, 1.0);
                final texX = (((nx + 1) / 2) * (brushTextureSize - 1))
                    .round()
                    .clamp(0, brushTextureSize - 1);
                final texY = (((ny + 1) / 2) * (brushTextureSize - 1))
                    .round()
                    .clamp(0, brushTextureSize - 1);
                final texIdx = (texY * brushTextureSize + texX) * 4;
                pixelAlpha = customTexture[texIdx + 3] / 255.0;
              }
            } else if (chainLink) {
              // 中抜き楕円リンク。接線座標へ揃えたあと、リンク固有の交互角度
              // だけ回す。outer/innerの楕円距離差で肉厚を作るため、拡縮しても
              // リングの穴が潰れずチェーンとして読める。
              final cosL = math.cos(-particleRotation);
              final sinL = math.sin(-particleRotation);
              final lx = ux * cosL - uy * sinL;
              final ly = ux * sinL + uy * cosL;
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
              final cosH = math.cos(-particleRotation);
              final sinH = math.sin(-particleRotation);
              final hx = ux * cosH - uy * sinH;
              final hy = ux * sinH + uy * cosH;
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
              // ソフトブラシ：ガウス的なフォールオフ
              if (dist <= radius) {
                pixelAlpha = 1.0;
              } else if (dist <= radius + blur) {
                final t = (dist - radius) / blur;
                pixelAlpha = 1.0 - t * t;
              } else {
                pixelAlpha = 0.0;
              }
            } else {
              // 通常ブラシ／ボールチェーン：アンチエイリアス。ボールチェーンは
              // 円形そのものを保ち、専用spacingで粒がつながり過ぎないようにする。
              if (edgeJitter && dist > radius - 1.5) {
                final maxJitter = edgeJitterStrength / 100.0 * 2.5;
                final jitter = (_jitterRng.nextDouble() - 0.5) * maxJitter * 2;
                pixelAlpha = (radius + 0.5 - dist + jitter).clamp(0.0, 1.0);
              } else {
                pixelAlpha = (radius + 0.5 - dist).clamp(0.0, 1.0);
              }
            }

            if (pixelAlpha <= 0) continue;

            // スタイラスを寝かせた場合は、傾き方向（+rdx）をペン先側として濃く、
            // 反対側を薄くする。形状の引き伸ばしだけで一様濃度にならないよう、
            // 元の円座標ux/radiusに沿って緩やかな線形濃度勾配を掛ける。
            // カリグラフィー固定角度ではスタイラス傾きではないため適用しない。
            if (stylusTiltMagnitude > 0.0001 && radius > 0) {
              final alongTilt = (ux / radius).clamp(-1.0, 1.0);
              final shadeStrength = 0.40 * stylusTiltMagnitude;
              final shade = (1.0 + alongTilt * shadeStrength).clamp(0.45, 1.0);
              pixelAlpha *= shade;
            }

            final desiredAlpha = (alpha * pixelAlpha).round().clamp(0, 255);
            if (desiredAlpha <= 0) continue;

            // 同一ストローク内では、同じ画素へのスタンプ重複を加算せず
            // 「そのストロークがこの画素をどこまで覆ったか」の最大値だけを採用する。
            final coveragePos = py * TileManager.tileSize + px;
            final oldCoverage = coverage[coveragePos];
            if (desiredAlpha <= oldCoverage) continue;
            final incrementalAlpha = oldCoverage >= 255
                ? 0
                : (((desiredAlpha - oldCoverage) * 255) / (255 - oldCoverage))
                      .round()
                      .clamp(0, 255);
            coverage[coveragePos] = desiredAlpha;
            if (incrementalAlpha <= 0) continue;

            if (isEraser) {
              tileManager.erasePixel(tile, px, py, incrementalAlpha);
            } else if (currentBrush!.mixingMode != BrushMixingMode.off) {
              final idx = (py * TileManager.tileSize + px) * 4;
              if (tile[idx + 3] > 0) {
                final below = ui.Color.fromARGB(
                  tile[idx + 3],
                  tile[idx],
                  tile[idx + 1],
                  tile[idx + 2],
                );
                final selected = ui.Color.fromARGB(255, ri, gi, bi);
                final rate = currentBrush!.mixingRate / 100.0;
                final mixed = currentBrush!.mixingMode == BrushMixingMode.bleed
                    ? bleedColor(below, selected, rate, _currentStroke.length)
                    : mixColor(below, selected, rate);
                tileManager.blendPixel(
                  tile,
                  px,
                  py,
                  (mixed.r * 255).round(),
                  (mixed.g * 255).round(),
                  (mixed.b * 255).round(),
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
        tileManager.markDirty(layerId, tx, ty);
      }
    }
  }

  // ─── ユーティリティ ───────────────────────────────────────────────────

  double _distance(StrokePoint a, StrokePoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _currentStrokeLength() {
    if (_currentStroke.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < _currentStroke.length; i++) {
      total += _distance(_currentStroke[i - 1], _currentStroke[i]);
    }
    return total;
  }

  double _calculateFade(Brush brush, double strokeLength) {
    return switch (brush.fadeMode) {
      FadeMode.weak => (1.0 - strokeLength / 1000).clamp(0.3, 1.0),
      FadeMode.medium => (1.0 - strokeLength / 500).clamp(0.1, 1.0),
      FadeMode.strong => (1.0 - strokeLength / 200).clamp(0.0, 1.0),
      FadeMode.custom =>
        brush.fadeCustom != null
            ? () {
                final progress = (strokeLength / brush.fadeCustom!.distancePx)
                    .clamp(0.0, 1.0);
                return brush.fadeCustom!.startValue / 100 +
                    (brush.fadeCustom!.endValue / 100 -
                            brush.fadeCustom!.startValue / 100) *
                        progress;
              }()
            : 1.0,
      FadeMode.off => 1.0,
    };
  }

  double _calculateDecay(double strokeLength) =>
      (1.0 - strokeLength / 2000).clamp(0.05, 1.0);

  ui.Color mixColor(ui.Color below, ui.Color selected, double rate) {
    final r = (below.r * rate + selected.r * (1 - rate)).clamp(0.0, 1.0);
    final g = (below.g * rate + selected.g * (1 - rate)).clamp(0.0, 1.0);
    final b = (below.b * rate + selected.b * (1 - rate)).clamp(0.0, 1.0);
    return ui.Color.from(alpha: 1.0, red: r, green: g, blue: b);
  }

  ui.Color bleedColor(
    ui.Color below,
    ui.Color selected,
    double rate,
    int strokeStep,
  ) {
    final decay = (1.0 - strokeStep * 0.01).clamp(0.0, 1.0);
    return mixColor(below, selected, rate * decay);
  }

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
