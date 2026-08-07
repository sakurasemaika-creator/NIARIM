import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../models/effect_filter_instance.dart';
import '../models/filter_def.dart';

/// 描画フィルターの本適用（低スペック端末でのUIスレッドブロック防止のため
/// compute()経由でバックグラウンドisolate実行する想定のトップレベル関数）。
Uint8List applyDrawFilterInIsolate(
    (Uint8List data, int width, int height, FilterDef filter) args) {
  final (data, width, height, filter) = args;
  final engine = FilterEngine();
  return switch (filter.kind) {
    FilterKind.gaussianBlur => engine.applyGaussianBlur(data, width, height, filter.strength),
    FilterKind.lensBlur => engine.applyLensBlur(data, width, height, filter.strength),
    FilterKind.animeStyle => engine.applyAnimeStyle(
        data,
        width,
        height,
        strength: filter.strength,
        colorCount: filter.colorLevels,
        edgeStrength: filter.edgeStrength,
      ),
    FilterKind.toneCurve => engine.applyToneCurve(
        data, width, height, toneCurvePoints(filter.toneCurvePreset)),
    FilterKind.levels => engine.applyLevels(
        data, width, height,
        inputBlack: filter.inputBlack,
        inputWhite: filter.inputWhite,
        outputBlack: filter.outputBlack,
        outputWhite: filter.outputWhite,
      ),
  };
}

/// トーンカーブのプリセット形状を制御点（0.0〜1.0の正規化座標）へ変換する
/// （仕様書20：トーンカーブ。プレビュー・本適用の両方から共通利用する）。
List<ui.Offset> toneCurvePoints(ToneCurvePreset preset) {
  return switch (preset) {
    ToneCurvePreset.linear => const [ui.Offset(0, 0), ui.Offset(1, 1)],
    ToneCurvePreset.brighten => const [ui.Offset(0, 0), ui.Offset(0.5, 0.65), ui.Offset(1, 1)],
    ToneCurvePreset.darken => const [ui.Offset(0, 0), ui.Offset(0.5, 0.35), ui.Offset(1, 1)],
    ToneCurvePreset.highContrast =>
      const [ui.Offset(0, 0), ui.Offset(0.25, 0.15), ui.Offset(0.75, 0.85), ui.Offset(1, 1)],
    ToneCurvePreset.lowContrast =>
      const [ui.Offset(0, 0.15), ui.Offset(0.5, 0.5), ui.Offset(1, 0.85)],
    ToneCurvePreset.invert => const [ui.Offset(0, 1), ui.Offset(1, 0)],
  };
}

class FilterEngine {
  /// タイムラインの演出フィルター一覧を、[frameIndex]が範囲内かつ有効なものだけ、
  /// タイムライン上の並び順（[effects]の順）に適用する（仕様書18：演出フィルター）。
  Uint8List applyEffectFilters(
    Uint8List data,
    int width,
    int height,
    List<EffectFilterInstance> effects,
    int frameIndex,
  ) {
    var result = data;
    for (final e in effects) {
      if (!e.enabled || frameIndex < e.startFrame || frameIndex > e.endFrame) continue;
      result = switch (e.type) {
        EffectFilterType.fade => applyFade(
            result,
            width,
            height,
            e.fadeColor,
            e.endFrame > e.startFrame
                ? (frameIndex - e.startFrame) / (e.endFrame - e.startFrame)
                : 1.0,
          ),
        EffectFilterType.gaussianBlur => applyGaussianBlur(result, width, height, e.param1),
        EffectFilterType.lensBlur => applyLensBlur(result, width, height, e.param1),
        EffectFilterType.mosaic => applyMosaic(result, width, height, e.param1.round()),
        EffectFilterType.chromaticAberration =>
          applyChromaticAberration(result, width, height, e.param1, 0),
        EffectFilterType.noise =>
          applyNoise(result, width, height, (e.param1 / 20).clamp(0.0, 1.0), NoiseType.gaussian),
      };
    }
    return result;
  }
  Uint8List applyGaussianBlur(Uint8List data, int width, int height, double strength) {
    final radius = strength.round().clamp(1, 20);
    final kernel = _gaussianKernel(radius);
    final tmp = _convolveH(data, width, height, kernel);
    return _convolveV(tmp, width, height, kernel);
  }

  Uint8List applyLensBlur(Uint8List data, int width, int height, double strength) {
    // レンズぼかし = 円形カーネルによるボックスブラー近似
    final radius = strength.round().clamp(1, 20);
    final result = Uint8List.fromList(data);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int r = 0, g = 0, b = 0, a = 0, count = 0;
        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            if (dx * dx + dy * dy > radius * radius) continue;
            final nx = (x + dx).clamp(0, width - 1);
            final ny = (y + dy).clamp(0, height - 1);
            final idx = (ny * width + nx) * 4;
            r += data[idx]; g += data[idx + 1];
            b += data[idx + 2]; a += data[idx + 3];
            count++;
          }
        }
        if (count == 0) continue;
        final idx = (y * width + x) * 4;
        result[idx] = (r / count).round();
        result[idx + 1] = (g / count).round();
        result[idx + 2] = (b / count).round();
        result[idx + 3] = (a / count).round();
      }
    }
    return result;
  }

  Uint8List applyMosaic(Uint8List data, int width, int height, int mosaicSize) {
    final size = mosaicSize.clamp(2, 64);
    final result = Uint8List.fromList(data);
    for (int y = 0; y < height; y += size) {
      for (int x = 0; x < width; x += size) {
        int r = 0, g = 0, b = 0, a = 0, count = 0;
        for (int dy = 0; dy < size && y + dy < height; dy++) {
          for (int dx = 0; dx < size && x + dx < width; dx++) {
            final idx = ((y + dy) * width + (x + dx)) * 4;
            r += data[idx]; g += data[idx + 1];
            b += data[idx + 2]; a += data[idx + 3];
            count++;
          }
        }
        if (count == 0) continue;
        final ar = (r / count).round();
        final ag = (g / count).round();
        final ab = (b / count).round();
        final aa = (a / count).round();
        for (int dy = 0; dy < size && y + dy < height; dy++) {
          for (int dx = 0; dx < size && x + dx < width; dx++) {
            final idx = ((y + dy) * width + (x + dx)) * 4;
            result[idx] = ar; result[idx + 1] = ag;
            result[idx + 2] = ab; result[idx + 3] = aa;
          }
        }
      }
    }
    return result;
  }

  Uint8List applyChromaticAberration(
      Uint8List data, int width, int height, double strength, double direction) {
    final shift = strength.round().clamp(1, 30);
    final dx = (math.cos(direction) * shift).round();
    final dy = (math.sin(direction) * shift).round();
    final result = Uint8List.fromList(data);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        // Rチャンネルをdx,dyずらす
        final rx = (x + dx).clamp(0, width - 1);
        final ry = (y + dy).clamp(0, height - 1);
        result[idx] = data[(ry * width + rx) * 4];
        // Bチャンネルを逆方向にずらす
        final bx = (x - dx).clamp(0, width - 1);
        final by = (y - dy).clamp(0, height - 1);
        result[idx + 2] = data[(by * width + bx) * 4 + 2];
      }
    }
    return result;
  }

  Uint8List applyNoise(Uint8List data, int width, int height, double strength, NoiseType type) {
    final result = Uint8List.fromList(data);
    final rng = math.Random();
    final s = (strength * 255).round().clamp(0, 255);
    for (int i = 0; i < result.length; i += 4) {
      if (result[i + 3] == 0) continue;
      final n = type == NoiseType.gaussian
          ? (_gaussianRandom(rng) * s).round().clamp(-s, s)
          : (rng.nextInt(s * 2 + 1) - s);
      result[i] = (result[i] + n).clamp(0, 255);
      result[i + 1] = (result[i + 1] + n).clamp(0, 255);
      result[i + 2] = (result[i + 2] + n).clamp(0, 255);
    }
    return result;
  }

  Uint8List applyAnimeStyle(Uint8List data, int width, int height, {
    required double strength,
    required int colorCount,
    required double edgeStrength,
  }) {
    // ① 色数削減（ポスタリゼーション）
    final step = (256 / colorCount.clamp(2, 32)).round();
    final posterized = Uint8List.fromList(data);
    for (int i = 0; i < posterized.length; i += 4) {
      posterized[i] = ((posterized[i] / step).round() * step).clamp(0, 255);
      posterized[i + 1] = ((posterized[i + 1] / step).round() * step).clamp(0, 255);
      posterized[i + 2] = ((posterized[i + 2] / step).round() * step).clamp(0, 255);
    }
    // ② エッジ検出（Sobelフィルタ）して輪郭を黒く
    if (edgeStrength > 0) {
      final edges = _sobelEdge(data, width, height);
      for (int i = 0; i < posterized.length; i += 4) {
        final e = (edges[i ~/ 4] * edgeStrength).clamp(0, 255).round();
        posterized[i] = (posterized[i] - e).clamp(0, 255);
        posterized[i + 1] = (posterized[i + 1] - e).clamp(0, 255);
        posterized[i + 2] = (posterized[i + 2] - e).clamp(0, 255);
      }
    }
    return posterized;
  }

  Uint8List applyFade(Uint8List data, int width, int height, ui.Color fadeColor, double progress) {
    final result = Uint8List.fromList(data);
    final fr = (fadeColor.r * 255).round();
    final fg = (fadeColor.g * 255).round();
    final fb = (fadeColor.b * 255).round();
    final t = progress.clamp(0.0, 1.0);
    for (int i = 0; i < result.length; i += 4) {
      result[i] = (result[i] * (1 - t) + fr * t).round().clamp(0, 255);
      result[i + 1] = (result[i + 1] * (1 - t) + fg * t).round().clamp(0, 255);
      result[i + 2] = (result[i + 2] * (1 - t) + fb * t).round().clamp(0, 255);
    }
    return result;
  }

  Uint8List applyToneCurve(Uint8List data, int width, int height, List<ui.Offset> curvePoints) {
    if (curvePoints.length < 2) return data;
    // LUT生成（0-255 → 0-255）
    final lut = List<int>.generate(256, (i) {
      final x = i / 255.0;
      // 線形補間
      for (int j = 0; j < curvePoints.length - 1; j++) {
        final p0 = curvePoints[j];
        final p1 = curvePoints[j + 1];
        if (x >= p0.dx && x <= p1.dx) {
          final t = (x - p0.dx) / (p1.dx - p0.dx);
          return ((p0.dy + t * (p1.dy - p0.dy)) * 255).round().clamp(0, 255);
        }
      }
      return i;
    });
    final result = Uint8List.fromList(data);
    for (int i = 0; i < result.length; i += 4) {
      result[i] = lut[result[i]];
      result[i + 1] = lut[result[i + 1]];
      result[i + 2] = lut[result[i + 2]];
    }
    return result;
  }

  Uint8List applyLevels(Uint8List data, int width, int height, {
    required int inputBlack,
    required int inputWhite,
    required int outputBlack,
    required int outputWhite,
  }) {
    final inRange = (inputWhite - inputBlack).clamp(1, 255);
    final outRange = outputWhite - outputBlack;
    final result = Uint8List.fromList(data);
    for (int i = 0; i < result.length; i += 4) {
      for (int c = 0; c < 3; c++) {
        final v = ((result[i + c] - inputBlack) / inRange * outRange + outputBlack)
            .round().clamp(0, 255);
        result[i + c] = v;
      }
    }
    return result;
  }

  // ─── ヘルパー ─────────────────────────────────────────────────────────

  List<double> _gaussianKernel(int radius) {
    final sigma = radius / 3.0;
    final kernel = List<double>.generate(radius * 2 + 1, (i) {
      final x = i - radius;
      return math.exp(-(x * x) / (2 * sigma * sigma));
    });
    final sum = kernel.fold(0.0, (a, b) => a + b);
    return kernel.map((v) => v / sum).toList();
  }

  Uint8List _convolveH(Uint8List data, int width, int height, List<double> kernel) {
    final radius = kernel.length ~/ 2;
    final result = Uint8List(data.length);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double r = 0, g = 0, b = 0, a = 0;
        for (int k = 0; k < kernel.length; k++) {
          final nx = (x + k - radius).clamp(0, width - 1);
          final idx = (y * width + nx) * 4;
          r += data[idx] * kernel[k];
          g += data[idx + 1] * kernel[k];
          b += data[idx + 2] * kernel[k];
          a += data[idx + 3] * kernel[k];
        }
        final idx = (y * width + x) * 4;
        result[idx] = r.round().clamp(0, 255);
        result[idx + 1] = g.round().clamp(0, 255);
        result[idx + 2] = b.round().clamp(0, 255);
        result[idx + 3] = a.round().clamp(0, 255);
      }
    }
    return result;
  }

  Uint8List _convolveV(Uint8List data, int width, int height, List<double> kernel) {
    final radius = kernel.length ~/ 2;
    final result = Uint8List(data.length);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double r = 0, g = 0, b = 0, a = 0;
        for (int k = 0; k < kernel.length; k++) {
          final ny = (y + k - radius).clamp(0, height - 1);
          final idx = (ny * width + x) * 4;
          r += data[idx] * kernel[k];
          g += data[idx + 1] * kernel[k];
          b += data[idx + 2] * kernel[k];
          a += data[idx + 3] * kernel[k];
        }
        final idx = (y * width + x) * 4;
        result[idx] = r.round().clamp(0, 255);
        result[idx + 1] = g.round().clamp(0, 255);
        result[idx + 2] = b.round().clamp(0, 255);
        result[idx + 3] = a.round().clamp(0, 255);
      }
    }
    return result;
  }

  List<int> _sobelEdge(Uint8List data, int width, int height) {
    final result = List<int>.filled(width * height, 0);
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int gx = 0, gy = 0;
        const kx = [-1, 0, 1, -2, 0, 2, -1, 0, 1];
        const ky = [-1, -2, -1, 0, 0, 0, 1, 2, 1];
        for (int ky2 = -1; ky2 <= 1; ky2++) {
          for (int kx2 = -1; kx2 <= 1; kx2++) {
            final idx = ((y + ky2) * width + (x + kx2)) * 4;
            final gray = (data[idx] * 0.299 + data[idx + 1] * 0.587 + data[idx + 2] * 0.114).round();
            final ki = (ky2 + 1) * 3 + (kx2 + 1);
            gx += gray * kx[ki];
            gy += gray * ky[ki];
          }
        }
        result[y * width + x] = math.sqrt(gx * gx + gy * gy).round().clamp(0, 255);
      }
    }
    return result;
  }

  double _gaussianRandom(math.Random rng) {
    // Box-Muller変換
    final u1 = rng.nextDouble();
    final u2 = rng.nextDouble();
    return math.sqrt(-2 * math.log(u1 + 1e-10)) * math.cos(2 * math.pi * u2);
  }
}

enum NoiseType { gaussian, uniform }

class EffectFilter {
  final EffectFilterType type;
  final int startFrame;
  final int endFrame;
  final Map<String, dynamic> parameters;
  final bool isEnabled;
  final bool isFavorite;

  const EffectFilter({
    required this.type,
    required this.startFrame,
    required this.endFrame,
    required this.parameters,
    this.isEnabled = true,
    this.isFavorite = false,
  });
}

enum EffectFilterType {
  fade, gaussianBlur, lensBlur, mosaic, chromaticAberration, noise,
}

enum DrawFilterType {
  animeBackground,
}

class DrawFilter {
  final DrawFilterType type;
  final Map<String, dynamic> parameters;
  final bool isFavorite;

  const DrawFilter({
    required this.type,
    this.parameters = const {},
    this.isFavorite = false,
  });
}
