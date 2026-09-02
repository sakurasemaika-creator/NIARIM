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

  Brush? currentBrush;
  ui.Color currentColor = const ui.Color(0xFF000000);
  bool isEraser = false;

  // 手ブレ補正用：直近の平滑化済み座標（ON/OFF・強度調整）
  StrokePoint? _smoothed;

  DrawingEngine({required this.tileManager});

  void beginStroke(StrokePoint point, String layerId) {
    _currentStroke.clear();
    _strokeCoverageByTile.clear();
    _smoothed = point;
    _currentStroke.add(point);
    _stampBrush(point.x, point.y, point.pressure, point.tiltX, point.tiltY, layerId);
  }

  void continueStroke(StrokePoint point, String layerId) {
    if (_currentStroke.isEmpty) {
      beginStroke(point, layerId);
      return;
    }
    final effective = _applyStabilization(point);
    _currentStroke.add(effective);
    _renderStrokeSegment(
      _currentStroke[_currentStroke.length - 2],
      effective,
      layerId,
    );
  }

  void endStroke() {
    _currentStroke.clear();
    _strokeCoverageByTile.clear();
    _smoothed = null;
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
  void commitShapePath(List<StrokePoint> pathPoints, String layerId, {bool closeLoop = false}) {
    if (currentBrush == null || pathPoints.isEmpty) return;
    _currentStroke.clear();
    _strokeCoverageByTile.clear();
    final first = pathPoints.first;
    _currentStroke.add(first);
    _stampBrush(first.x, first.y, first.pressure, first.tiltX, first.tiltY, layerId);
    for (int i = 1; i < pathPoints.length; i++) {
      final to = pathPoints[i];
      _renderStrokeSegment(_currentStroke.last, to, layerId);
      _currentStroke.add(to);
    }
    if (closeLoop && pathPoints.length > 1) {
      _renderStrokeSegment(_currentStroke.last, first, layerId);
    }
    _currentStroke.clear();
    _strokeCoverageByTile.clear();
  }

  void _renderStrokeSegment(StrokePoint from, StrokePoint to, String layerId) {
    if (currentBrush == null) return;
    final brush = currentBrush!;
    final distance = _distance(from, to);
    final spacing = math.max(1.0, brush.spacing.toDouble());
    final steps = math.max(1, (distance / spacing).ceil());

    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final x = from.x + (to.x - from.x) * t;
      final y = from.y + (to.y - from.y) * t;
      final pressure = from.pressure + (to.pressure - from.pressure) * t;
      final tiltX = from.tiltX + (to.tiltX - from.tiltX) * t;
      final tiltY = from.tiltY + (to.tiltY - from.tiltY) * t;
      _stampBrush(x, y, pressure, tiltX, tiltY, layerId);
    }
  }

  void _stampBrush(
    double x,
    double y,
    double pressure,
    double tiltX,
    double tiltY,
    String layerId,
  ) {
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

    // フェード仕様は「ストロークが進むにつれて不透明度・サイズが減少」。
    // 同じ係数を両方へ適用し、終端で薄いだけの同径線にならないようにする。
    if (brush.fadeMode != FadeMode.off) {
      final fade = _calculateFade(brush, _currentStrokeLength());
      opacity *= fade;
      size *= fade;
    }
    // ストローク減衰はインク切れ表現なので、不透明度だけを減らして太さは維持する。
    if (brush.strokeDecay) {
      opacity *= _calculateDecay(_currentStrokeLength());
    }

    opacity = opacity.clamp(0.0, 1.0);
    size = size.clamp(0.5, 2000.0);

    final radius = size / 2.0;
    final alphaInt = (opacity * 255).round().clamp(0, 255);
    if (alphaInt == 0) return;

    // 傾き変形：カリグラフィーブラシ（ペン先角度固定）の場合は、実際の
    // スタイラス傾きに関わらず常に固定角度へ扁平化したペン先を使う。
    final tilt = brush.calligraphyAngle != null
        ? (
            scaleX: kCalligraphyNibAspect,
            scaleY: 1.0,
            angle: brush.calligraphyAngle! * math.pi / 180,
          )
        : calcTiltTransform(tiltX, tiltY);
    final stylusTiltMagnitude = brush.calligraphyAngle == null
        ? math.sqrt(tiltX * tiltX + tiltY * tiltY).clamp(0.0, 1.0)
        : 0.0;

    // 自作ブラシ（ブラシ画像からのブラシ作成）が選択され、
    // 事前読み込み済みの場合はその形状を、それ以外は円形（またはピクセル
    // モード）でスタンプする。
    final texturePath = brush.customImagePath;
    final customTexture = texturePath != null ? getCachedBrushTexture(texturePath) : null;
    _renderCircleStamp(
      x, y, radius, alphaInt, tilt,
      layerId, brush.pixelMode, brush.blurRadius, customTexture,
      stylusTiltMagnitude: stylusTiltMagnitude,
      edgeJitter: brush.edgeJitter,
      edgeJitterStrength: brush.edgeJitterStrength,
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
        final localMaxX = math.min(TileManager.tileSize - 1, (cx + totalRadius - tileOriginX).ceil());
        final localMinY = math.max(0, (cy - totalRadius - tileOriginY).floor());
        final localMaxY = math.min(TileManager.tileSize - 1, (cy + totalRadius - tileOriginY).ceil());

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
                final texX =
                    (((nx + 1) / 2) * (brushTextureSize - 1)).round().clamp(0, brushTextureSize - 1);
                final texY =
                    (((ny + 1) / 2) * (brushTextureSize - 1)).round().clamp(0, brushTextureSize - 1);
                final texIdx = (texY * brushTextureSize + texX) * 4;
                pixelAlpha = customTexture[texIdx + 3] / 255.0;
              }
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
              // 通常ブラシ：アンチエイリアス
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
                final below =
                    ui.Color.fromARGB(tile[idx + 3], tile[idx], tile[idx + 1], tile[idx + 2]);
                final selected = ui.Color.fromARGB(255, ri, gi, bi);
                final rate = currentBrush!.mixingRate / 100.0;
                final mixed = currentBrush!.mixingMode == BrushMixingMode.bleed
                    ? bleedColor(below, selected, rate, _currentStroke.length)
                    : mixColor(below, selected, rate);
                tileManager.blendPixel(
                  tile, px, py,
                  (mixed.r * 255).round(), (mixed.g * 255).round(), (mixed.b * 255).round(),
                  incrementalAlpha,
                );
              } else {
                tileManager.blendPixel(tile, px, py, ri, gi, bi, incrementalAlpha);
              }
            } else {
              tileManager.blendPixel(tile, px, py, ri, gi, bi, incrementalAlpha);
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
      FadeMode.weak   => (1.0 - strokeLength / 1000).clamp(0.3, 1.0),
      FadeMode.medium => (1.0 - strokeLength / 500).clamp(0.1, 1.0),
      FadeMode.strong => (1.0 - strokeLength / 200).clamp(0.0, 1.0),
      FadeMode.custom => brush.fadeCustom != null
          ? () {
              final progress = (strokeLength / brush.fadeCustom!.distancePx).clamp(0.0, 1.0);
              return brush.fadeCustom!.startValue / 100 +
                  (brush.fadeCustom!.endValue / 100 - brush.fadeCustom!.startValue / 100) * progress;
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

  ui.Color bleedColor(ui.Color below, ui.Color selected, double rate, int strokeStep) {
    final decay = (1.0 - strokeStep * 0.01).clamp(0.0, 1.0);
    return mixColor(below, selected, rate * decay);
  }

  ({double scaleX, double scaleY, double angle}) calcTiltTransform(
      double tiltX, double tiltY) {
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
