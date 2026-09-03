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
    final opacityFactor = (opacity.clamp(0, 100)) / 100.0;
    final srcR = color.r;
    final srcG = color.g;
    final srcB = color.b;

    for (final point in points) {
      final cx = point.dx.round();
      final cy = point.dy.round();

      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          if (dx * dx + dy * dy > radius * radius) continue;
          final px = cx + dx;
          final py = cy + dy;
          if (px < 0 || px >= canvasWidth || py < 0 || py >= canvasHeight)
            continue;
          if (selectionMask != null &&
              selectionMask[py * canvasWidth + px] == 0)
            continue;

          final tx = px % toneWidth;
          final ty = py % toneHeight;
          final toneIdx = (ty * toneWidth + tx) * 4;
          final toneAlpha = toneTexture[toneIdx + 3] / 255.0;
          if (toneAlpha <= 0) continue;

          final canvasIdx = (py * canvasWidth + px) * 4;
          final srcA = (color.a * opacityFactor * toneAlpha).clamp(0.0, 1.0);
          if (srcA <= 0) continue;
          final dstA = result[canvasIdx + 3] / 255.0;
          final outA = srcA + dstA * (1.0 - srcA);
          if (outA <= 0) continue;

          final dstR = result[canvasIdx] / 255.0;
          final dstG = result[canvasIdx + 1] / 255.0;
          final dstB = result[canvasIdx + 2] / 255.0;
          final keep = dstA * (1.0 - srcA);

          result[canvasIdx] = ((srcR * srcA + dstR * keep) / outA * 255)
              .round()
              .clamp(0, 255);
          result[canvasIdx + 1] = ((srcG * srcA + dstG * keep) / outA * 255)
              .round()
              .clamp(0, 255);
          result[canvasIdx + 2] = ((srcB * srcA + dstB * keep) / outA * 255)
              .round()
              .clamp(0, 255);
          result[canvasIdx + 3] = (outA * 255).round().clamp(0, 255);
        }
      }
    }
    return result;
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

    for (final point in points) {
      final cx = point.dx.round();
      final cy = point.dy.round();

      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          if (dx * dx + dy * dy > radius * radius) continue;
          final px = cx + dx;
          final py = cy + dy;
          if (px < 0 || px >= canvasWidth || py < 0 || py >= canvasHeight)
            continue;
          if (selectionMask != null &&
              selectionMask[py * canvasWidth + px] == 0)
            continue;

          final tx = px % toneWidth;
          final ty = py % toneHeight;
          final toneIdx = (ty * toneWidth + tx) * 4;
          final eraseStrength = toneTexture[toneIdx + 3] / 255.0;
          if (eraseStrength <= 0) continue;

          final canvasIdx = (py * canvasWidth + px) * 4;
          final oldA = result[canvasIdx + 3];
          final newA = (oldA * (1.0 - eraseStrength)).round().clamp(0, 255);
          result[canvasIdx + 3] = newA;
          if (newA == 0) {
            result[canvasIdx] = 0;
            result[canvasIdx + 1] = 0;
            result[canvasIdx + 2] = 0;
          }
        }
      }
    }
    return result;
  }
}
