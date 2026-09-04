import 'dart:math' as math;
import 'dart:typed_data';

import '../models/filter_def.dart';

/// 背景馴染ませ v2 の解析結果。画像認識やネットワーク処理には頼らず、
/// 対象シルエット周囲の画素だけから環境光を推定する。
class BackgroundAcclimationAnalysis {
  final double primaryDirectionDegrees;
  final int primaryColor;
  final int ambientColor;
  final int shadowColor;
  final int reflectionColor;
  final List<BackgroundAcclimationLight> secondaryLights;
  final double confidence;

  const BackgroundAcclimationAnalysis({
    required this.primaryDirectionDegrees,
    required this.primaryColor,
    required this.ambientColor,
    required this.shadowColor,
    required this.reflectionColor,
    required this.secondaryLights,
    required this.confidence,
  });
}

class BackgroundAcclimationLight {
  final double directionDegrees;
  final int color;
  final double score;

  const BackgroundAcclimationLight({
    required this.directionDegrees,
    required this.color,
    required this.score,
  });
}

class _SectorAccumulator {
  double r = 0;
  double g = 0;
  double b = 0;
  double luminance = 0;
  double luminanceSq = 0;
  double weight = 0;
  int samples = 0;

  void add(int rr, int gg, int bb, double w) {
    r += rr * w;
    g += gg * w;
    b += bb * w;
    final l = BackgroundAcclimationEngine._luma(rr, gg, bb);
    luminance += l * w;
    luminanceSq += l * l * w;
    weight += w;
    samples++;
  }

  int get color {
    if (weight <= 0) return 0xFF808080;
    return BackgroundAcclimationEngine._argb(
      (r / weight).round(),
      (g / weight).round(),
      (b / weight).round(),
    );
  }

  double get meanLuminance => weight <= 0 ? 0 : luminance / weight;

  double get consistency {
    if (weight <= 0) return 0;
    final mean = meanLuminance;
    final variance = math.max(0.0, luminanceSq / weight - mean * mean);
    // 輝度が激しく散っている方向を「巨大な白壁＝光源」と誤認しにくくする。
    return (1.0 - math.sqrt(variance).clamp(0.0, 0.5) * 1.5).clamp(0.0, 1.0);
  }
}

/// 背景馴染ませ v2。
///
/// 1. 対象の周囲を16方向へ分けて環境サンプリング
/// 2. 明度・近さ・面積の一貫性から主光源と副光源を推定
/// 3. 周囲全体から環境光、反対側から影色、下側から反射色を独立推定
/// 4. 対象の輪郭法線と光源方向の一致度で光/影を乗せる
/// 5. 輪郭から内側へ距離減衰させ、局所背景色の色移りも加える
/// 6. 元画素の明度・彩度を見て黒つぶれ・白飛び・高彩度破壊を抑制
///
/// すべて決定論的な画素処理で、AI画像認識・通信は不要。
class BackgroundAcclimationEngine {
  static const int sectorCount = 16;

  static BackgroundAcclimationAnalysis analyze(
    Uint8List subject,
    Uint8List background,
    int width,
    int height,
    FilterDef filter,
  ) {
    if (width <= 0 ||
        height <= 0 ||
        subject.length < width * height * 4 ||
        background.length < width * height * 4) {
      return _fallback(filter);
    }

    int minX = width;
    int minY = height;
    int maxX = -1;
    int maxY = -1;
    double sx = 0;
    double sy = 0;
    int opaqueCount = 0;
    final boundary = <int>[];

    bool opaqueAt(int x, int y) {
      if (x < 0 || y < 0 || x >= width || y >= height) return false;
      return subject[(y * width + x) * 4 + 3] >= 16;
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!opaqueAt(x, y)) continue;
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        sx += x;
        sy += y;
        opaqueCount++;
        if (!opaqueAt(x - 1, y) ||
            !opaqueAt(x + 1, y) ||
            !opaqueAt(x, y - 1) ||
            !opaqueAt(x, y + 1)) {
          boundary.add(y * width + x);
        }
      }
    }

    if (opaqueCount == 0 || boundary.isEmpty) return _fallback(filter);
    final cx = sx / opaqueCount;
    final cy = sy / opaqueCount;
    final subjectSpan = math.max(maxX - minX + 1, maxY - minY + 1);
    final band = filter.bgBlendSamplingBand.round().clamp(
      4,
      math.max(4, math.min(120, subjectSpan)),
    );
    final sectors = List.generate(sectorCount, (_) => _SectorAccumulator());
    final ambient = _SectorAccumulator();
    final lower = _SectorAccumulator();

    // 大画像でも境界全点×bandにならないよう境界を最大4096点へ間引く。
    final stride = math.max(1, (boundary.length / 4096).ceil());
    for (int bi = 0; bi < boundary.length; bi += stride) {
      final p = boundary[bi];
      final bx = p % width;
      final by = p ~/ width;
      double rx = bx - cx;
      double ry = by - cy;
      var len = math.sqrt(rx * rx + ry * ry);
      if (len < 0.5) continue;
      rx /= len;
      ry /= len;
      var angle = math.atan2(ry, rx);
      if (angle < 0) angle += math.pi * 2;
      final sector =
          ((angle / (math.pi * 2)) * sectorCount).floor() % sectorCount;

      for (int d = 2; d <= band; d += d < 12 ? 2 : 4) {
        final x = (bx + rx * d).round();
        final y = (by + ry * d).round();
        if (x < 0 || y < 0 || x >= width || y >= height) break;
        if (opaqueAt(x, y)) continue;
        final idx = (y * width + x) * 4;
        final a = background[idx + 3];
        if (a < 16) continue;
        final proximity = 1.0 / (1.0 + d * 0.055);
        final alphaWeight = a / 255.0;
        final w = proximity * alphaWeight;
        final r = background[idx];
        final g = background[idx + 1];
        final b = background[idx + 2];
        sectors[sector].add(r, g, b, w);
        ambient.add(r, g, b, w);
        if (ry > 0.35) lower.add(r, g, b, w * ry);
      }
    }

    if (ambient.weight <= 0) return _fallback(filter);

    final scores = List<double>.filled(sectorCount, 0);
    double bestScore = -1;
    int best = 0;
    for (int i = 0; i < sectorCount; i++) {
      final s = sectors[i];
      if (s.weight <= 0) continue;
      final area = math.log(1 + s.samples) / math.log(128);
      final chroma = _chroma(s.color);
      // 白〜暖色の直射もネオンのような高彩度光も拾えるよう、色の強さを少量加点。
      final score =
          s.meanLuminance * 0.68 +
          s.consistency * 0.16 +
          area.clamp(0.0, 1.0) * 0.10 +
          chroma * 0.06;
      scores[i] = score;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }

    final autoDirection = (best + 0.5) * 360.0 / sectorCount;
    final direction = filter.bgBlendAutoLight
        ? autoDirection
        : filter.bgBlendDirection;
    final primaryColor = filter.bgBlendLightColor == -1
        ? sectors[best].color
        : filter.bgBlendLightColor;
    final ambientColor = filter.bgBlendAmbientColor != -1
        ? filter.bgBlendAmbientColor
        : (filter.bgBlendColor != -1 ? filter.bgBlendColor : ambient.color);

    final opposite = (best + sectorCount ~/ 2) % sectorCount;
    final shadowAcc = _SectorAccumulator();
    for (final offset in const [-1, 0, 1]) {
      final s = sectors[(opposite + offset + sectorCount) % sectorCount];
      if (s.weight <= 0) continue;
      shadowAcc.r += s.r;
      shadowAcc.g += s.g;
      shadowAcc.b += s.b;
      shadowAcc.luminance += s.luminance;
      shadowAcc.luminanceSq += s.luminanceSq;
      shadowAcc.weight += s.weight;
      shadowAcc.samples += s.samples;
    }
    final autoShadow = shadowAcc.weight > 0
        ? _darkenPreserveHue(shadowAcc.color, 0.24)
        : _darkenPreserveHue(ambientColor, 0.28);
    final shadowColor = filter.bgBlendShadowColor == -1
        ? autoShadow
        : filter.bgBlendShadowColor;
    final reflectionColor = filter.bgBlendReflectionColor == -1
        ? (lower.weight > 0 ? lower.color : ambientColor)
        : filter.bgBlendReflectionColor;

    final secondary = <BackgroundAcclimationLight>[];
    if (filter.bgBlendSecondaryStrength > 0) {
      final candidates = List<int>.generate(sectorCount, (i) => i)
        ..sort((a, b) => scores[b].compareTo(scores[a]));
      for (final i in candidates) {
        if (i == best || scores[i] <= 0) continue;
        final ringDistance = math.min(
          (i - best).abs(),
          sectorCount - (i - best).abs(),
        );
        if (ringDistance <= 2) continue;
        if (scores[i] < bestScore * 0.62) continue;
        if (secondary.any((l) {
          final li = (l.directionDegrees / 360 * sectorCount).floor();
          final d = math.min((li - i).abs(), sectorCount - (li - i).abs());
          return d <= 2;
        })) {
          continue;
        }
        secondary.add(
          BackgroundAcclimationLight(
            directionDegrees: (i + 0.5) * 360.0 / sectorCount,
            color: sectors[i].color,
            score: scores[i] / math.max(bestScore, 0.0001),
          ),
        );
        if (secondary.length >= 2) break;
      }
    }

    final sorted = scores.where((v) => v > 0).toList()..sort();
    final median = sorted.isEmpty ? 0.0 : sorted[sorted.length ~/ 2];
    final confidence = bestScore <= 0
        ? 0.0
        : ((bestScore - median) / bestScore).clamp(0.0, 1.0);

    return BackgroundAcclimationAnalysis(
      primaryDirectionDegrees: direction,
      primaryColor: primaryColor,
      ambientColor: ambientColor,
      shadowColor: shadowColor,
      reflectionColor: reflectionColor,
      secondaryLights: secondary,
      confidence: confidence,
    );
  }

  static Uint8List apply(
    Uint8List subject,
    Uint8List? background,
    int width,
    int height,
    FilterDef filter, {
    BackgroundAcclimationAnalysis? analysis,
  }) {
    if (background == null ||
        background.length < width * height * 4 ||
        subject.length < width * height * 4) {
      return Uint8List.fromList(subject);
    }
    final env = analysis ?? analyze(subject, background, width, height, filter);
    final result = Uint8List.fromList(subject);
    final count = width * height;
    final inside = Uint8List(count);
    for (int p = 0; p < count; p++) {
      inside[p] = subject[p * 4 + 3] >= 16 ? 1 : 0;
    }

    // 3-4 chamfer近似の距離変換。輪郭から内側への減衰をO(N)で得る。
    const inf = 1 << 28;
    final dist = Int32List(count);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = y * width + x;
        if (inside[p] == 0) {
          dist[p] = 0;
          continue;
        }
        final boundary =
            x == 0 ||
            y == 0 ||
            x == width - 1 ||
            y == height - 1 ||
            inside[p - 1] == 0 ||
            inside[p + 1] == 0 ||
            inside[p - width] == 0 ||
            inside[p + width] == 0;
        dist[p] = boundary ? 0 : inf;
      }
    }
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = y * width + x;
        if (dist[p] == 0) continue;
        var d = dist[p];
        if (x > 0) d = math.min(d, dist[p - 1] + 3);
        if (y > 0) d = math.min(d, dist[p - width] + 3);
        if (x > 0 && y > 0) d = math.min(d, dist[p - width - 1] + 4);
        if (x + 1 < width && y > 0) d = math.min(d, dist[p - width + 1] + 4);
        dist[p] = d;
      }
    }
    for (int y = height - 1; y >= 0; y--) {
      for (int x = width - 1; x >= 0; x--) {
        final p = y * width + x;
        if (dist[p] == 0) continue;
        var d = dist[p];
        if (x + 1 < width) d = math.min(d, dist[p + 1] + 3);
        if (y + 1 < height) d = math.min(d, dist[p + width] + 3);
        if (x + 1 < width && y + 1 < height) {
          d = math.min(d, dist[p + width + 1] + 4);
        }
        if (x > 0 && y + 1 < height) {
          d = math.min(d, dist[p + width - 1] + 4);
        }
        dist[p] = d;
      }
    }

    final influence = math.max(1.0, filter.bgBlendLength);
    final softness = (filter.bgBlendSoftness / 100).clamp(0.0, 1.0);
    final gamma = 0.55 + (1.0 - softness) * 2.2;
    final global = (filter.bgBlendStrength / 100).clamp(0.0, 1.0);
    final lightStrength = (filter.bgBlendLightStrength / 100).clamp(0.0, 1.0);
    final shadowStrength = (filter.bgBlendShadowStrength / 100).clamp(0.0, 1.0);
    final ambientStrength = (filter.bgBlendAmbientStrength / 100).clamp(
      0.0,
      1.0,
    );
    final reflectionStrength = (filter.bgBlendReflectionStrength / 100).clamp(
      0.0,
      1.0,
    );
    final bleedStrength = (filter.bgBlendColorBleed / 100).clamp(0.0, 1.0);
    final secondaryStrength = (filter.bgBlendSecondaryStrength / 100).clamp(
      0.0,
      1.0,
    );
    final materialProtection = (filter.bgBlendMaterialProtection / 100).clamp(
      0.0,
      1.0,
    );

    final primaryRad = env.primaryDirectionDegrees * math.pi / 180.0;
    final lx = math.cos(primaryRad);
    final ly = math.sin(primaryRad);
    final secondaryVectors = env.secondaryLights.map((l) {
      final rad = l.directionDegrees * math.pi / 180.0;
      return (math.cos(rad), math.sin(rad), l);
    }).toList();

    int alphaAt(int x, int y) {
      if (x < 0 || y < 0 || x >= width || y >= height) return 0;
      return subject[(y * width + x) * 4 + 3];
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = y * width + x;
        if (inside[p] == 0) continue;
        final idx = p * 4;
        final edgeDistance = dist[p] / 3.0;
        final edgeT = (1.0 - edgeDistance / influence).clamp(0.0, 1.0);
        final edgeFalloff = math.pow(edgeT, gamma).toDouble();

        // アルファ勾配の逆向き＝外向き輪郭法線。
        var nx = (alphaAt(x - 1, y) - alphaAt(x + 1, y)).toDouble();
        var ny = (alphaAt(x, y - 1) - alphaAt(x, y + 1)).toDouble();
        final nlen = math.sqrt(nx * nx + ny * ny);
        if (nlen > 0.001) {
          nx /= nlen;
          ny /= nlen;
        } else {
          // 内側画素では近似的に主光源方向を使い、環境光中心の処理にする。
          nx = lx;
          ny = ly;
        }

        final facingLight = math.max(0.0, nx * lx + ny * ly);
        final facingShadow = math.max(0.0, -(nx * lx + ny * ly));
        var r = subject[idx].toDouble();
        var g = subject[idx + 1].toDouble();
        var b = subject[idx + 2].toDouble();
        final originalLuma = _luma(r.round(), g.round(), b.round());
        final originalChroma = _rgbChroma(r, g, b);

        // 環境光は対象全体へごく弱く。中央まで均一に強く染めない。
        final ambientAmount =
            global *
            ambientStrength *
            (0.22 + edgeFalloff * 0.30) *
            _materialFactor(
              originalLuma,
              originalChroma,
              materialProtection,
              false,
            );
        (r, g, b) = _blendProtected(
          r,
          g,
          b,
          env.ambientColor,
          ambientAmount,
          originalLuma,
          materialProtection,
          false,
        );

        final lightAmount =
            global *
            lightStrength *
            facingLight *
            edgeFalloff *
            _materialFactor(
              originalLuma,
              originalChroma,
              materialProtection,
              true,
            );
        (r, g, b) = _blendProtected(
          r,
          g,
          b,
          env.primaryColor,
          lightAmount,
          originalLuma,
          materialProtection,
          true,
        );

        for (final entry in secondaryVectors) {
          final facing = math.max(0.0, nx * entry.$1 + ny * entry.$2);
          if (facing <= 0) continue;
          final amount =
              global *
              secondaryStrength *
              entry.$3.score *
              facing *
              edgeFalloff *
              0.72;
          (r, g, b) = _blendProtected(
            r,
            g,
            b,
            entry.$3.color,
            amount,
            originalLuma,
            materialProtection,
            true,
          );
        }

        final shadowAmount =
            global *
            shadowStrength *
            facingShadow *
            edgeFalloff *
            _materialFactor(
              originalLuma,
              originalChroma,
              materialProtection,
              false,
            );
        (r, g, b) = _blendProtected(
          r,
          g,
          b,
          env.shadowColor,
          shadowAmount,
          originalLuma,
          materialProtection,
          false,
        );

        // 画面下から来る反射光。下向きの輪郭法線ほど強くする。
        final reflectionFacing = math.max(0.0, ny);
        final reflectionAmount =
            global * reflectionStrength * reflectionFacing * edgeFalloff * 0.72;
        (r, g, b) = _blendProtected(
          r,
          g,
          b,
          env.reflectionColor,
          reflectionAmount,
          originalLuma,
          materialProtection,
          true,
        );

        // 輪郭直近の背景色を局所的な色移りとして加える。近傍の実色を使うため
        // 「足元は地面色」などの意味認識を決め打ちしない。
        if (bleedStrength > 0 && edgeFalloff > 0.05 && nlen > 0.001) {
          final sampleDistance = math.max(
            2.0,
            math.min(filter.bgBlendSamplingBand, 18.0),
          );
          final bx = (x + nx * sampleDistance).round();
          final by = (y + ny * sampleDistance).round();
          if (bx >= 0 && by >= 0 && bx < width && by < height) {
            final bi = (by * width + bx) * 4;
            if (background[bi + 3] >= 16) {
              final localColor = _argb(
                background[bi],
                background[bi + 1],
                background[bi + 2],
              );
              final amount = global * bleedStrength * edgeFalloff * 0.36;
              (r, g, b) = _blendProtected(
                r,
                g,
                b,
                localColor,
                amount,
                originalLuma,
                materialProtection,
                false,
              );
            }
          }
        }

        result[idx] = r.round().clamp(0, 255);
        result[idx + 1] = g.round().clamp(0, 255);
        result[idx + 2] = b.round().clamp(0, 255);
        // alphaは絶対に変更しない。
      }
    }
    return result;
  }

  static BackgroundAcclimationAnalysis _fallback(FilterDef filter) {
    final base = filter.bgBlendColor == -1 ? 0xFF808080 : filter.bgBlendColor;
    final direction = filter.bgBlendDirection;
    return BackgroundAcclimationAnalysis(
      primaryDirectionDegrees: direction,
      primaryColor: filter.bgBlendLightColor == -1
          ? _lighten(base, 0.18)
          : filter.bgBlendLightColor,
      ambientColor: filter.bgBlendAmbientColor == -1
          ? base
          : filter.bgBlendAmbientColor,
      shadowColor: filter.bgBlendShadowColor == -1
          ? _darkenPreserveHue(base, 0.25)
          : filter.bgBlendShadowColor,
      reflectionColor: filter.bgBlendReflectionColor == -1
          ? base
          : filter.bgBlendReflectionColor,
      secondaryLights: const [],
      confidence: 0,
    );
  }

  static double _materialFactor(
    double luma,
    double chroma,
    double protection,
    bool isLight,
  ) {
    if (protection <= 0) return 1;
    // 白は増光を抑え、黒は輝度上昇を抑え、高彩度色は元の色相を守る。
    final highlightGuard = isLight
        ? (1.0 - math.max(0.0, (luma - 0.70) / 0.30) * 0.78)
        : 1.0;
    final blackGuard = isLight ? (0.72 + luma * 0.28) : (0.82 + luma * 0.18);
    final chromaGuard = 1.0 - chroma * 0.34;
    final guarded = highlightGuard * blackGuard * chromaGuard;
    return 1.0 + (guarded - 1.0) * protection;
  }

  static (double, double, double) _blendProtected(
    double r,
    double g,
    double b,
    int color,
    double amount,
    double originalLuma,
    double protection,
    bool isLight,
  ) {
    final t = amount.clamp(0.0, 1.0);
    if (t <= 0) return (r, g, b);
    final tr = ((color >> 16) & 0xFF).toDouble();
    final tg = ((color >> 8) & 0xFF).toDouble();
    final tb = (color & 0xFF).toDouble();
    var nr = r + (tr - r) * t;
    var ng = g + (tg - g) * t;
    var nb = b + (tb - b) * t;
    if (protection > 0) {
      final nl = _luma(nr.round(), ng.round(), nb.round());
      final maxDelta = isLight
          ? 0.34 * (1.0 - protection * 0.58)
          : 0.30 * (1.0 - protection * 0.48);
      final minL = math.max(0.0, originalLuma - maxDelta);
      final maxL = math.min(1.0, originalLuma + maxDelta);
      final clampedL = nl.clamp(minL, maxL);
      if (nl > 0.0001 && clampedL != nl) {
        final scale = clampedL / nl;
        nr *= scale;
        ng *= scale;
        nb *= scale;
      }
    }
    return (nr.clamp(0.0, 255.0), ng.clamp(0.0, 255.0), nb.clamp(0.0, 255.0));
  }

  static double _luma(int r, int g, int b) =>
      (r * 0.2126 + g * 0.7152 + b * 0.0722) / 255.0;

  static double _rgbChroma(double r, double g, double b) {
    final hi = math.max(r, math.max(g, b));
    final lo = math.min(r, math.min(g, b));
    return (hi - lo) / 255.0;
  }

  static double _chroma(int color) => _rgbChroma(
    ((color >> 16) & 0xFF).toDouble(),
    ((color >> 8) & 0xFF).toDouble(),
    (color & 0xFF).toDouble(),
  );

  static int _argb(int r, int g, int b) {
    final rr = r < 0 ? 0 : (r > 255 ? 255 : r);
    final gg = g < 0 ? 0 : (g > 255 ? 255 : g);
    final bb = b < 0 ? 0 : (b > 255 ? 255 : b);
    return 0xFF000000 | (rr << 16) | (gg << 8) | bb;
  }

  static int _lighten(int color, double amount) {
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;
    return _argb(
      (r + (255 - r) * amount).round(),
      (g + (255 - g) * amount).round(),
      (b + (255 - b) * amount).round(),
    );
  }

  static int _darkenPreserveHue(int color, double amount) {
    final r = (color >> 16) & 0xFF;
    final g = (color >> 8) & 0xFF;
    final b = color & 0xFF;
    final scale = 1.0 - amount.clamp(0.0, 0.9);
    return _argb((r * scale).round(), (g * scale).round(), (b * scale).round());
  }
}
