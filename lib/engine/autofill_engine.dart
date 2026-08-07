import 'dart:math' as math;
import 'dart:typed_data';
import '../models/autofill_gradient.dart';
import '../models/autofill_preset.dart';

enum AutofillMode { repaint, colorUpdate }

class AutofillEngine {
  /// 塗りなおし：形状を破棄して領域再判定→塗りなおす
  /// [toneTexture]が指定され[part].useTone==trueの場合は、単色/グラデーションの
  /// 代わりにトーンパターンで塗る（仕様書20：トーン設定、バケツトーンエンジンと
  /// 同じループ配置方式）。
  Uint8List repaint({
    required Uint8List lineartData,
    required int width,
    required int height,
    required AutofillPart part,
    Uint8List? toneTexture,
    int toneWidth = 64,
    int toneHeight = 64,
  }) {
    final result = Uint8List(width * height * 4);
    _floodFillRegion(lineartData, result, width, height, part,
        toneTexture: toneTexture, toneWidth: toneWidth, toneHeight: toneHeight);
    return result;
  }

  /// 色更新：形状維持・不透明度ロックして最新色で塗りつぶす
  Uint8List colorUpdate({
    required Uint8List existingData,
    required int width,
    required int height,
    required AutofillPart part,
    Uint8List? toneTexture,
    int toneWidth = 64,
    int toneHeight = 64,
  }) {
    final result = Uint8List.fromList(existingData);
    final gradient = part.gradient;
    final useTone = part.useTone && toneTexture != null;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (result[i + 3] == 0) continue;
        if (useTone) {
          final tx = x % toneWidth;
          final ty = y % toneHeight;
          final toneIdx = (ty * toneWidth + tx) * 4;
          if (toneTexture[toneIdx + 3] == 0) {
            result[i + 3] = 0;
            continue;
          }
        }
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
    Uint8List? toneTexture,
    int toneWidth = 64,
    int toneHeight = 64,
  }) {
    if (lineartData == null && existingData == null) return null;
    if (existingData == null) {
      return repaint(
          lineartData: lineartData!, width: width, height: height, part: part,
          toneTexture: toneTexture, toneWidth: toneWidth, toneHeight: toneHeight);
    }
    return switch (mode) {
      AutofillMode.repaint => lineartData != null
          ? repaint(lineartData: lineartData, width: width, height: height, part: part,
              toneTexture: toneTexture, toneWidth: toneWidth, toneHeight: toneHeight)
          : Uint8List(width * height * 4),
      AutofillMode.colorUpdate => colorUpdate(
          existingData: existingData, width: width, height: height, part: part,
          toneTexture: toneTexture, toneWidth: toneWidth, toneHeight: toneHeight),
    };
  }

  /// 線画色設定を適用した線画レイヤーのRGBAバッファを返す（仕様書20：線画色設定）。
  /// アルファ値（線の形状）はそのまま維持し、不透明ピクセルのRGBのみ差し替える。
  /// 不透明度は「塗り色の不透明度は100%固定」と同じ理由でレイヤー不透明度側
  /// （AutofillPart.lineOpacityをLayer.opacityへ反映）で管理するため、ここでは
  /// アルファを変更しない。
  Uint8List recolorLineart({
    required Uint8List lineartData,
    required int width,
    required int height,
    required AutofillPart part,
  }) {
    if (part.lineColorMode == AutofillLineColorMode.specified && part.lineColor == 0xFF000000) {
      // デフォルト設定（変更なし）の場合はそのまま返す
      return lineartData;
    }
    final result = Uint8List.fromList(lineartData);
    final gradient = part.gradient;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        if (result[idx + 3] == 0) continue;
        final int argb;
        switch (part.lineColorMode) {
          case AutofillLineColorMode.specified:
            argb = part.lineColor;
          case AutofillLineColorMode.sameAsFill:
            argb = gradient != null ? _gradientColorAt(gradient, x, y, width, height) : part.color;
          case AutofillLineColorMode.traceAdjust:
            final baseArgb =
                gradient != null ? _gradientColorAt(gradient, x, y, width, height) : part.color;
            argb = _traceAdjustColor(baseArgb, part.traceHue, part.traceSaturation, part.traceLightness);
        }
        result[idx]     = (argb >> 16) & 0xFF;
        result[idx + 1] = (argb >> 8) & 0xFF;
        result[idx + 2] = argb & 0xFF;
      }
    }
    return result;
  }

  void _floodFillRegion(
    Uint8List lineartData,
    Uint8List outputData,
    int width,
    int height,
    AutofillPart part, {
    Uint8List? toneTexture,
    int toneWidth = 64,
    int toneHeight = 64,
  }) {
    final gradient = part.gradient;
    final fr = (part.color >> 16) & 0xFF;
    final fg = (part.color >> 8) & 0xFF;
    final fb = part.color & 0xFF;
    final useTone = part.useTone && toneTexture != null;

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
        bool paint = true;
        if (useTone) {
          final tx = cx % toneWidth;
          final ty = cy % toneHeight;
          final toneIdx = (ty * toneWidth + tx) * 4;
          paint = toneTexture[toneIdx + 3] > 0;
        }
        if (paint) {
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
        }
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

  // ─── 色トレス・線画馴染ませ（仕様書20：線画色設定） ─────────────────────
  // 塗り色のHSLへ色相・彩度・明度のオフセットを適用し、線画を塗り色に
  // 馴染ませた色へ変換する（彩度は絶対値として置き換え、色相・明度は
  // オフセットとして加算する）。

  int _traceAdjustColor(int argb, double hueOffset, double saturationAbs, double lightnessOffset) {
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8) & 0xFF) / 255.0;
    final b = (argb & 0xFF) / 255.0;
    final (h, _, l) = _rgbToHsl(r, g, b);
    final newH = (h + hueOffset) % 360;
    final newS = (saturationAbs / 100.0).clamp(0.0, 1.0);
    final newL = (l + lightnessOffset / 100.0).clamp(0.0, 1.0);
    final (nr, ng, nb) = _hslToRgb(newH < 0 ? newH + 360 : newH, newS, newL);
    return 0xFF000000 |
        ((nr * 255).round().clamp(0, 255) << 16) |
        ((ng * 255).round().clamp(0, 255) << 8) |
        (nb * 255).round().clamp(0, 255);
  }

  (double, double, double) _rgbToHsl(double r, double g, double b) {
    final maxV = math.max(r, math.max(g, b));
    final minV = math.min(r, math.min(g, b));
    final l = (maxV + minV) / 2;
    if (maxV == minV) return (0, 0, l);
    final d = maxV - minV;
    final s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
    double h;
    if (maxV == r) {
      h = ((g - b) / d) % 6;
    } else if (maxV == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h *= 60;
    if (h < 0) h += 360;
    return (h, s, l);
  }

  (double, double, double) _hslToRgb(double h, double s, double l) {
    if (s == 0) return (l, l, l);
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    final hk = h / 360;
    double hue2rgb(double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }
    return (hue2rgb(hk + 1 / 3), hue2rgb(hk), hue2rgb(hk - 1 / 3));
  }
}
