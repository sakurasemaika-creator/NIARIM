import 'dart:typed_data';
import 'dart:ui' as ui;

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
    }) args) {
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
  /// ストローク軌跡にトーンを描画する
  /// [points] ストローク点列
  /// [brushSize] ブラシサイズ（トーンパターン自体のサイズは変化しない）
  /// [color] 現在色
  /// [toneTexture] トーンテクスチャ (RGBA)
  /// [toneWidth] / [toneHeight] テクスチャサイズ
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
    final opacityFactor = opacity / 100.0;

    for (final point in points) {
      final cx = point.dx.round();
      final cy = point.dy.round();

      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          if (dx * dx + dy * dy > radius * radius) continue;
          final px = cx + dx;
          final py = cy + dy;
          if (px < 0 || px >= canvasWidth || py < 0 || py >= canvasHeight) continue;
          if (selectionMask != null && selectionMask[py * canvasWidth + px] == 0) continue;

          // トーンテクスチャをループ参照
          final tx = px % toneWidth;
          final ty = py % toneHeight;
          final toneIdx = (ty * toneWidth + tx) * 4;
          if (toneTexture[toneIdx + 3] == 0) continue; // 透明部分は透過維持

          final canvasIdx = (py * canvasWidth + px) * 4;
          result[canvasIdx] = (color.r * 255).round();
          result[canvasIdx + 1] = (color.g * 255).round();
          result[canvasIdx + 2] = (color.b * 255).round();
          result[canvasIdx + 3] = ((color.a * opacityFactor) * 255).round();
        }
      }
    }
    return result;
  }

  /// トーン消しゴム：トーン形状で透明色を描画
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

    for (final point in points) {
      final cx = point.dx.round();
      final cy = point.dy.round();

      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          if (dx * dx + dy * dy > radius * radius) continue;
          final px = cx + dx;
          final py = cy + dy;
          if (px < 0 || px >= canvasWidth || py < 0 || py >= canvasHeight) continue;
          if (selectionMask != null && selectionMask[py * canvasWidth + px] == 0) continue;

          final tx = px % toneWidth;
          final ty = py % toneHeight;
          final toneIdx = (ty * toneWidth + tx) * 4;
          if (toneTexture[toneIdx + 3] == 0) continue;

          final canvasIdx = (py * canvasWidth + px) * 4;
          result[canvasIdx] = 0;
          result[canvasIdx + 1] = 0;
          result[canvasIdx + 2] = 0;
          result[canvasIdx + 3] = 0;
        }
      }
    }
    return result;
  }
}
