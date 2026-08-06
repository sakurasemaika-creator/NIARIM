import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/brush.dart';
import 'tile_manager.dart';

class DrawingEngine {
  final TileManager tileManager;

  final List<StrokePoint> _currentStroke = [];

  Brush? currentBrush;
  ui.Color currentColor = const ui.Color(0xFF000000);
  bool isEraser = false;

  DrawingEngine({required this.tileManager});

  void beginStroke(StrokePoint point, String layerId) {
    _currentStroke.clear();
    _currentStroke.add(point);
    _stampBrush(point.x, point.y, point.pressure, point.tiltX, point.tiltY, layerId);
  }

  void continueStroke(StrokePoint point, String layerId) {
    if (_currentStroke.isEmpty) {
      beginStroke(point, layerId);
      return;
    }
    _currentStroke.add(point);
    _renderStrokeSegment(
      _currentStroke[_currentStroke.length - 2],
      point,
      layerId,
    );
  }

  void endStroke() {
    _currentStroke.clear();
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

    // 筆圧反映
    switch (brush.pressureMode) {
      case PressureMode.size:
        size *= pressure;
      case PressureMode.opacity:
        opacity *= pressure;
      case PressureMode.sizeAndOpacity:
        size *= pressure;
        opacity *= pressure;
      case PressureMode.off:
        break;
    }

    // フェード
    if (brush.fadeMode != FadeMode.off) {
      opacity *= _calculateFade(brush, _currentStrokeLength());
    }
    // ストローク減衰
    if (brush.strokeDecay) {
      opacity *= _calculateDecay(_currentStrokeLength());
    }

    opacity = opacity.clamp(0.0, 1.0);
    size = size.clamp(0.5, 2000.0);

    final radius = size / 2.0;
    final alphaInt = (opacity * 255).round().clamp(0, 255);
    if (alphaInt == 0) return;

    // 傾き変形
    final tilt = calcTiltTransform(tiltX, tiltY);

    // ブラシスタンプを円形（またはドットペン）で描画
    _renderCircleStamp(
      x, y, radius, alphaInt, tilt,
      layerId, brush.dotPenMode, brush.blurRadius,
    );
  }

  void _renderCircleStamp(
    double cx,
    double cy,
    double radius,
    int alpha,
    ({double scaleX, double scaleY, double angle}) tilt,
    String layerId,
    bool dotPenMode,
    int blurRadius,
  ) {
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
            final dist = math.sqrt(
              (rdx / tilt.scaleX) * (rdx / tilt.scaleX) +
              (rdy / tilt.scaleY) * (rdy / tilt.scaleY),
            );

            double pixelAlpha;
            if (dotPenMode) {
              // ドットペン：エッジをシャープに
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
              pixelAlpha = (radius + 0.5 - dist).clamp(0.0, 1.0);
            }

            if (pixelAlpha <= 0) continue;
            final finalAlpha = (alpha * pixelAlpha).round().clamp(0, 255);

            if (isEraser) {
              tileManager.erasePixel(tile, px, py, finalAlpha);
            } else {
              tileManager.blendPixel(tile, px, py, ri, gi, bi, finalAlpha);
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
