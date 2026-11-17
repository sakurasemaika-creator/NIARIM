import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'premultiplied.dart';

/// トーン自由描画の確定処理（低スペック端末でのUIスレッドブロック防止のため
/// compute()経由のバックグラウンドisolateで実行する想定のトップレベル関数）。
Uint8List runToneStrokeInIsolate(
  ({
    bool erase,
    List<ui.Offset> points,
    double brushSize,
    ui.Color color,
    Uint8List canvasData,
    int canvasWidth,
    int canvasHeight,
    Uint8List toneTexture,
    int toneWidth,
    int toneHeight,
    int opacity,
  })
  args,
) {
  final engine = ToneEngine();
  return args.erase
      ? engine.eraseToneStroke(
          points: args.points,
          brushSize: args.brushSize,
          canvasData: args.canvasData,
          canvasWidth: args.canvasWidth,
          canvasHeight: args.canvasHeight,
          toneTexture: args.toneTexture,
          toneWidth: args.toneWidth,
          toneHeight: args.toneHeight,
        )
      : engine.drawToneStroke(
          points: args.points,
          brushSize: args.brushSize,
          color: args.color,
          canvasData: args.canvasData,
          canvasWidth: args.canvasWidth,
          canvasHeight: args.canvasHeight,
          toneTexture: args.toneTexture,
          toneWidth: args.toneWidth,
          toneHeight: args.toneHeight,
          opacity: args.opacity,
        );
}

/// トーン描画エンジン
/// サイズ一定・ループ・回転なし・密度なし・散布なし
class ToneEngine {
  /// ストローク軌跡にトーンを描画する。
  /// 既存ピクセルへは通常ブラシと同じsource-overで合成し、半透明トーンを
  /// 描いたときに既存の不透明画素そのものを半透明へ置換しない。
  /// トーン画像側のalphaも描画強度として反映するため、アンチエイリアスを
  /// 含むトーン素材の縁も滑らかに保たれる。
  Uint8List drawToneStroke({
    required List<ui.Offset> points,
    required double brushSize,
    required ui.Color color,
    required Uint8List canvasData,
    required int canvasWidth,
    required int canvasHeight,
    required Uint8List toneTexture,
    required int toneWidth,
    required int toneHeight,
    Uint8List? selectionMask,
    int opacity = 100,
  }) {
    if (points.isEmpty) return canvasData;
    final result = Uint8List.fromList(canvasData);
    final radius = (brushSize / 2).round();
    final toneOpacity = (color.a * opacity.clamp(0, 100) * 255 / 100).round();
    final srcR = (color.r * 255).round();
    final srcG = (color.g * 255).round();
    final srcB = (color.b * 255).round();
    final covered = Uint8List(canvasWidth * canvasHeight);

    for (final point in _samplePath(points, radius)) {
      final cx = point.dx.round();
      final cy = point.dy.round();

      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          if (dx * dx + dy * dy > radius * radius) continue;
          final px = cx + dx;
          final py = cy + dy;
          if (px < 0 || px >= canvasWidth || py < 0 || py >= canvasHeight) {
            continue;
          }
          if (selectionMask != null &&
              selectionMask[py * canvasWidth + px] == 0) {
            continue;
          }

          final tx = px % toneWidth;
          final ty = py % toneHeight;
          final toneIdx = (ty * toneWidth + tx) * 4;
          final coverage = toneTexture[toneIdx + 3];
          if (coverage == 0) continue;

          final pos = py * canvasWidth + px;
          if (covered[pos] != 0) continue;
          covered[pos] = 1;
          compositeMaskedColor(
            result,
            pos * 4,
            srcR,
            srcG,
            srcB,
            toneOpacity,
            coverage,
          );
        }
      }
    }
    return result;
  }

  /// The input device can send points farther apart than the brush diameter.
  /// Sample each segment densely enough to keep neighbouring dabs joined.
  Iterable<ui.Offset> _samplePath(List<ui.Offset> points, int radius) sync* {
    if (points.isEmpty) return;
    final spacing = math.max(0.75, radius / 2);
    yield points.first;
    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1];
      final to = points[i];
      final steps = ((to - from).distance / spacing).ceil();
      for (var step = 1; step <= steps; step++) {
        yield ui.Offset.lerp(from, to, step / steps)!;
      }
    }
  }

  /// トーン消しゴム：トーン形状でalphaを削る。
  /// トーン画像に中間alphaがある場合はその強度ぶんだけ消すことで、
  /// アンチエイリアス済みの縁を0/255へ潰さない。
  Uint8List eraseToneStroke({
    required List<ui.Offset> points,
    required double brushSize,
    required Uint8List canvasData,
    required int canvasWidth,
    required int canvasHeight,
    required Uint8List toneTexture,
    required int toneWidth,
    required int toneHeight,
    Uint8List? selectionMask,
  }) {
    final result = Uint8List.fromList(canvasData);
    final radius = (brushSize / 2).round();
    final covered = Uint8List(canvasWidth * canvasHeight);

    for (final point in _samplePath(points, radius)) {
      final cx = point.dx.round();
      final cy = point.dy.round();

      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          if (dx * dx + dy * dy > radius * radius) continue;
          final px = cx + dx;
          final py = cy + dy;
          if (px < 0 || px >= canvasWidth || py < 0 || py >= canvasHeight) {
            continue;
          }
          if (selectionMask != null &&
              selectionMask[py * canvasWidth + px] == 0) {
            continue;
          }

          final tx = px % toneWidth;
          final ty = py % toneHeight;
          final toneIdx = (ty * toneWidth + tx) * 4;
          final eraseStrength = toneTexture[toneIdx + 3] / 255.0;
          if (eraseStrength <= 0) continue;

          final pos = py * canvasWidth + px;
          if (covered[pos] != 0) continue;
          covered[pos] = 1;
          final canvasIdx = pos * 4;
          for (var channel = 0; channel < 4; channel++) {
            final index = canvasIdx + channel;
            result[index] = (result[index] * (1.0 - eraseStrength)).round();
          }
        }
      }
    }
    return result;
  }
}
