import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// スタンプ描画エンジン（仕様書17：色情報はスタンプ画像自体が保持・
/// ブラシサイズに連動・回転／密度／散布に対応）。
class StampEngine {
  /// [texture]（texSize x texSize、RGBA）を、ストローク上の各[points]位置へ
  /// [stampSize]にスケーリングして合成する。
  Uint8List stampAlongPath({
    required Uint8List canvasData,
    required int width,
    required int height,
    required Uint8List texture,
    required int texSize,
    required List<ui.Offset> points,
    required double stampSize,
    bool rotation = false,
    double scatter = 0,
    double density = 1.0,
    int seed = 0,
  }) {
    final result = Uint8List.fromList(canvasData);
    final rand = math.Random(seed);
    for (int i = 0; i < points.length; i++) {
      if (density < 1.0 && rand.nextDouble() > density) continue;
      final p = points[i];
      double angle = 0;
      if (rotation && i > 0) {
        final prev = points[i - 1];
        angle = math.atan2(p.dy - prev.dy, p.dx - prev.dx);
      }
      double ox = p.dx, oy = p.dy;
      if (scatter > 0) {
        final normal = angle + math.pi / 2;
        final off = (rand.nextDouble() * 2 - 1) * scatter;
        ox += math.cos(normal) * off;
        oy += math.sin(normal) * off;
      }
      _blitStamp(result, width, height, texture, texSize, ox, oy, stampSize, angle);
    }
    return result;
  }

  void _blitStamp(Uint8List dst, int w, int h, Uint8List tex, int texSize,
      double cx, double cy, double size, double angle) {
    if (size <= 0) return;
    final half = size / 2;
    final minX = (cx - half).floor().clamp(0, w - 1);
    final maxX = (cx + half).ceil().clamp(0, w - 1);
    final minY = (cy - half).floor().clamp(0, h - 1);
    final maxY = (cy + half).ceil().clamp(0, h - 1);
    final cosA = math.cos(-angle);
    final sinA = math.sin(-angle);
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final dx = x - cx;
        final dy = y - cy;
        final rx = dx * cosA - dy * sinA;
        final ry = dx * sinA + dy * cosA;
        final u = ((rx / size) + 0.5) * texSize;
        final v = ((ry / size) + 0.5) * texSize;
        if (u < 0 || u >= texSize || v < 0 || v >= texSize) continue;
        final tIdx = (v.floor() * texSize + u.floor()) * 4;
        final ta = tex[tIdx + 3];
        if (ta == 0) continue;
        final dIdx = (y * w + x) * 4;
        final srcA = ta / 255.0;
        final dstA = dst[dIdx + 3] / 255.0;
        final outA = srcA + dstA * (1 - srcA);
        if (outA <= 0) continue;
        dst[dIdx] = ((tex[tIdx] * srcA + dst[dIdx] * dstA * (1 - srcA)) / outA).round().clamp(0, 255);
        dst[dIdx + 1] =
            ((tex[tIdx + 1] * srcA + dst[dIdx + 1] * dstA * (1 - srcA)) / outA).round().clamp(0, 255);
        dst[dIdx + 2] =
            ((tex[tIdx + 2] * srcA + dst[dIdx + 2] * dstA * (1 - srcA)) / outA).round().clamp(0, 255);
        dst[dIdx + 3] = (outA * 255).round().clamp(0, 255);
      }
    }
  }
}
