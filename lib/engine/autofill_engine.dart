import 'dart:math' as math;
import 'dart:typed_data';
import '../models/autofill_gradient.dart';
import '../models/autofill_preset.dart';

enum AutofillMode { repaint, colorUpdate }

class AutofillEngine {
  /// 塗りなおし：形状を破棄して領域再判定→塗りなおす
  Uint8List repaint({
    required Uint8List lineartData,
    required int width,
    required int height,
    required AutofillPart part,
  }) {
    final result = Uint8List(width * height * 4);
    _floodFillRegion(lineartData, result, width, height, part);
    return result;
  }

  /// 色更新：形状維持・不透明度ロックして最新色で塗りつぶす
  Uint8List colorUpdate({
    required Uint8List existingData,
    required int width,
    required int height,
    required AutofillPart part,
  }) {
    final result = Uint8List.fromList(existingData);
    final gradient = part.gradient;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (result[i + 3] == 0) continue;
        final argb = gradient != null
            ? _gradientColorAt(gradient, x, y, width, height)
            : part.color;
        result[i]     = (argb >> 16) & 0xFF;
        result[i + 1] = (argb >> 8) & 0xFF;
        result[i + 2] = argb & 0xFF;
      }
    }
    return result;
  }

  /// 4パターン処理の統合エントリポイント
  Uint8List? execute({
    required AutofillMode mode,
    required Uint8List? lineartData,
    required Uint8List? existingData,
    required int width,
    required int height,
    required AutofillPart part,
  }) {
    if (lineartData == null && existingData == null) return null;
    if (existingData == null) {
      return repaint(lineartData: lineartData!, width: width, height: height, part: part);
    }
    return switch (mode) {
      AutofillMode.repaint => lineartData != null
          ? repaint(lineartData: lineartData, width: width, height: height, part: part)
          : Uint8List(width * height * 4),
      AutofillMode.colorUpdate =>
          colorUpdate(existingData: existingData, width: width, height: height, part: part),
    };
  }

  void _floodFillRegion(
    Uint8List lineartData,
    Uint8List outputData,
    int width,
    int height,
    AutofillPart part,
  ) {
    final gradient = part.gradient;
    final fr = (part.color >> 16) & 0xFF;
    final fg = (part.color >> 8) & 0xFF;
    final fb = part.color & 0xFF;

    final visited = List<bool>.filled(width * height, false);

    bool isLineart(int x, int y) {
      final idx = (y * width + x) * 4;
      return lineartData[idx + 3] > 128;
    }

    void fill(int startX, int startY) {
      if (isLineart(startX, startY)) return;
      final queue = <(int, int)>[(startX, startY)];
      visited[startY * width + startX] = true;
      while (queue.isNotEmpty) {
        final (cx, cy) = queue.removeAt(0);
        final idx = (cy * width + cx) * 4;
        if (gradient != null) {
          final argb = _gradientColorAt(gradient, cx, cy, width, height);
          outputData[idx]     = (argb >> 16) & 0xFF;
          outputData[idx + 1] = (argb >> 8) & 0xFF;
          outputData[idx + 2] = argb & 0xFF;
        } else {
          outputData[idx]     = fr;
          outputData[idx + 1] = fg;
          outputData[idx + 2] = fb;
        }
        outputData[idx + 3] = 255;
        for (final (nx, ny) in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]) {
          if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
          final ni = ny * width + nx;
          if (visited[ni] || isLineart(nx, ny)) continue;
          visited[ni] = true;
          queue.add((nx, ny));
        }
      }
    }

    final outside = List<bool>.filled(width * height, false);
    final outerQueue = <(int, int)>[];
    for (int x = 0; x < width; x++) {
      if (!isLineart(x, 0)) { outside[x] = true; outerQueue.add((x, 0)); }
      if (!isLineart(x, height-1)) { outside[(height-1)*width+x] = true; outerQueue.add((x, height-1)); }
    }
    for (int y = 1; y < height - 1; y++) {
      if (!isLineart(0, y)) { outside[y*width] = true; outerQueue.add((0, y)); }
      if (!isLineart(width-1, y)) { outside[y*width+width-1] = true; outerQueue.add((width-1, y)); }
    }
    while (outerQueue.isNotEmpty) {
      final (cx, cy) = outerQueue.removeAt(0);
      for (final (nx, ny) in [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]) {
        if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
        final ni = ny * width + nx;
        if (outside[ni] || isLineart(nx, ny)) continue;
        outside[ni] = true;
        outerQueue.add((nx, ny));
      }
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = y * width + x;
        if (!outside[i] && !isLineart(x, y) && !visited[i]) {
          fill(x, y);
        }
      }
    }
  }

  bool isUpToDate({
    required int lineartHash,
    required int presetHash,
    required int lastUpdateHash,
  }) =>
      (lineartHash ^ presetHash) == lastUpdateHash;

  // ─── グラデーション（仕様書20：塗り色設定・グラデーション） ─────────────

  /// キャンバス座標(x, y)におけるグラデーション色をARGB intで返す。
  int _gradientColorAt(AutofillGradient g, int x, int y, int width, int height) {
    double t;
    switch (g.type) {
      case AutofillGradientType.linear:
        final rad = g.angle * math.pi / 180;
        final dx = math.cos(rad);
        final dy = math.sin(rad);
        // 中心を原点とした正規化座標を方向ベクトルへ投影し、対角成分で0〜1へ正規化する
        final nx = (x / width) - 0.5;
        final ny = (y / height) - 0.5;
        final proj = nx * dx + ny * dy;
        const halfDiagonal = 0.70710678; // sqrt(0.5^2 + 0.5^2)
        t = (proj + halfDiagonal) / (halfDiagonal * 2);
      case AutofillGradientType.radialCenterOut:
      case AutofillGradientType.radialOutCenter:
        final cx = g.centerX * width;
        final cy = g.centerY * height;
        final maxRadius = math.sqrt(width * width + height * height) / 2;
        final dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        t = maxRadius > 0 ? dist / maxRadius : 0;
        if (g.type == AutofillGradientType.radialOutCenter) t = 1 - t;
    }
    return _sampleGradient(g.colors, g.stops, t.clamp(0.0, 1.0));
  }

  int _sampleGradient(List<int> colors, List<double> stops, double t) {
    if (colors.isEmpty) return 0xFF000000;
    if (colors.length == 1) return colors.first;
    if (t <= stops.first) return colors.first;
    if (t >= stops.last) return colors.last;
    for (int i = 0; i < stops.length - 1; i++) {
      if (t >= stops[i] && t <= stops[i + 1]) {
        final range = stops[i + 1] - stops[i];
        final localT = range > 0 ? (t - stops[i]) / range : 0.0;
        return _lerpColor(colors[i], colors[i + 1], localT);
      }
    }
    return colors.last;
  }

  int _lerpColor(int a, int b, double t) {
    final ar = (a >> 16) & 0xFF, ag = (a >> 8) & 0xFF, ab = a & 0xFF;
    final br = (b >> 16) & 0xFF, bg = (b >> 8) & 0xFF, bb = b & 0xFF;
    final r = (ar + (br - ar) * t).round().clamp(0, 255);
    final g = (ag + (bg - ag) * t).round().clamp(0, 255);
    final bl = (ab + (bb - ab) * t).round().clamp(0, 255);
    return 0xFF000000 | (r << 16) | (g << 8) | bl;
  }
}
