import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/filter_def.dart';
import '../models/layer.dart';
import 'blend_math.dart';
import 'premultiplied.dart';

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

  /// The background's tones around the subject: how dark its shadows and
  /// how bright its highlights are (luminance 0 to 1, a few percent in from
  /// each end), how saturated its most saturated colours are (0 to 1), and
  /// its average colour in the shadows, the middle tones and the
  /// highlights.
  final BackgroundTones tones;

  const BackgroundAcclimationAnalysis({
    required this.primaryDirectionDegrees,
    required this.primaryColor,
    required this.ambientColor,
    required this.shadowColor,
    required this.reflectionColor,
    required this.secondaryLights,
    required this.confidence,
    this.tones = BackgroundTones.neutral,
  });
}

/// [BackgroundAcclimationAnalysis.tones].
class BackgroundTones {
  final double low;
  final double high;
  final double saturation;
  final int shadow;
  final int middle;
  final int highlight;

  const BackgroundTones({
    required this.low,
    required this.high,
    required this.saturation,
    required this.shadow,
    required this.middle,
    required this.highlight,
  });

  /// No background to go by: the full range, no colour cast.
  static const neutral = BackgroundTones(
    low: 0,
    high: 1,
    saturation: 1,
    shadow: 0xFF404040,
    middle: 0xFF808080,
    highlight: 0xFFC0C0C0,
  );
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
/// 1. 対象の周囲を16方向へ分けて環境サンプリング（「ぼかし具合」だけ
///    ぼかした背景から）
/// 2. 明度・近さ・面積の一貫性から主光源と副光源を推定
/// 3. 周囲全体から環境光、下側から反射色を推定し、周囲の明るさの分布から
///    影・中間・ハイライトの色と明るさ・彩度の範囲を求める。影色は黒や
///    灰色ではなく、背景の影の部分の色を暗くしたもの
/// 4. 描いた色の明るさ・彩度を背景の範囲へ寄せ、明るさごとに背景の
///    同じ明るさの色みへ寄せる（カラーバランス）
/// 5. 環境光を対象全体にオーバーレイで重ね（全体の色の方向）、光源側から
///    影側へ対象全体にわたる明暗をハードライトで付ける（縁だけでなく描いた
///    内容全体が背景の色になじむ）
/// 6. 輪郭では法線と光源方向の一致度で光/影を強め、下からの照り返しと
///    局所背景色の色移りをスクリーンで、強い有色光（ネオン等）の副光源を
///    加算・発光で加える
/// 7. 元画素の明度・彩度を見て黒つぶれ・白飛び・高彩度破壊を抑制
///
/// レイヤーの画素は乗算済みなので、色は元の色（不透明度で割り戻した色）で
/// 扱い、書き戻すときに不透明度を掛け直す。結果は画素へ直接焼き込むので、
/// 合成モードを重ねて統合したときに見え方が変わることはない。
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
    // Every sample, for the background's tones.
    final toneSamples = <(double, double, int, double)>[];
    // Each direction's samples, for the colour of the light there.
    final sectorSamples = List.generate(
      sectorCount,
      (_) => <(double, double, int, double)>[],
    );

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
        final hi = math.max(r, math.max(g, b));
        final lo = math.min(r, math.min(g, b));
        final sample = (
          _luma(r, g, b),
          hi == 0 ? 0.0 : (hi - lo) / hi,
          _argb(r, g, b),
          w,
        );
        toneSamples.add(sample);
        sectorSamples[sector].add(sample);
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
        ? _lightColour(sectorSamples[best], sectors[best].color)
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
    final tones = _tonesOf(toneSamples);
    // Not black or grey: the colour of the background's own shadows (or,
    // where it has none to speak of, of the side away from the light),
    // dark enough that Hard Light deepens with it.
    final autoShadow = _shadowColour(
      tones.shadow,
      shadowAcc.weight > 0 ? shadowAcc.color : ambientColor,
    );
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
            color: _lightColour(sectorSamples[i], sectors[i].color),
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
      tones: tones,
    );
  }

  /// The colour of the light in one direction: the average of its
  /// brightest quarter of [samples] (luminance, saturation, colour, weight),
  /// not of all of them, so a neon sign among dark walls is a cyan light
  /// rather than a dull teal one, which Hard Light would darken with.
  /// [otherwise] without samples.
  static int _lightColour(
    List<(double, double, int, double)> samples,
    int otherwise,
  ) {
    if (samples.isEmpty) return otherwise;
    final sorted = [...samples]..sort((a, b) => b.$1.compareTo(a.$1));
    final total = sorted.fold(0.0, (sum, s) => sum + s.$4);
    final acc = _SectorAccumulator();
    var taken = 0.0;
    for (final s in sorted) {
      if (taken >= total * .25 && acc.weight > 0) break;
      acc.add((s.$3 >> 16) & 0xFF, (s.$3 >> 8) & 0xFF, s.$3 & 0xFF, s.$4);
      taken += s.$4;
    }
    return acc.weight > 0 ? acc.color : otherwise;
  }

  /// The background's tones from its samples (luminance, saturation,
  /// colour, weight): the luminance 5 % and 95 % of the way up, the
  /// saturation 90 % of the way up, and the average colours of the darkest
  /// third, the middle third and the lightest third.
  static BackgroundTones _tonesOf(List<(double, double, int, double)> samples) {
    if (samples.isEmpty) return BackgroundTones.neutral;
    final total = samples.fold(0.0, (sum, s) => sum + s.$4);
    if (total <= 0) return BackgroundTones.neutral;
    double percentile(List<(double, double)> values, double at) {
      values.sort((a, b) => a.$1.compareTo(b.$1));
      var reached = 0.0;
      for (final (value, weight) in values) {
        reached += weight;
        if (reached >= total * at) return value;
      }
      return values.last.$1;
    }

    final lumas = [for (final s in samples) (s.$1, s.$4)];
    final low = percentile(lumas, .05);
    final third = percentile(lumas, 1 / 3);
    final twoThirds = percentile(lumas, 2 / 3);
    final high = percentile(lumas, .95);
    final saturation = percentile([for (final s in samples) (s.$2, s.$4)], .9);
    // The average colour of the samples [take] keeps, or [otherwise] if it
    // keeps none.
    int average(bool Function(double luma) take, int otherwise) {
      final acc = _SectorAccumulator();
      for (final s in samples) {
        if (!take(s.$1)) continue;
        acc.add((s.$3 >> 16) & 0xFF, (s.$3 >> 8) & 0xFF, s.$3 & 0xFF, s.$4);
      }
      return acc.weight > 0 ? acc.color : otherwise;
    }

    final overall = average((l) => true, 0xFF808080);
    return BackgroundTones(
      low: low,
      high: high,
      saturation: saturation,
      shadow: average((l) => l <= third, overall),
      middle: average((l) => l > third && l < twoThirds, overall),
      highlight: average((l) => l >= twoThirds, overall),
    );
  }

  /// A shadow colour from the background's shadow [tone]: its hue and a
  /// little more of its saturation, at most a quarter as light (Hard Light
  /// deepens with a colour darker than middle grey). A tone too grey to
  /// carry a hue takes the hue of [fallback].
  static int _shadowColour(int tone, int fallback) {
    var source = tone;
    if (_chroma(source) < .06 && _chroma(fallback) >= .06) source = fallback;
    var r = ((source >> 16) & 0xFF) / 255;
    var g = ((source >> 8) & 0xFF) / 255;
    var b = (source & 0xFF) / 255;
    final l = r * 0.2126 + g * 0.7152 + b * 0.0722;
    // A little more saturated: shadows keep their colour.
    r = l + (r - l) * 1.2;
    g = l + (g - l) * 1.2;
    b = l + (b - l) * 1.2;
    final target = math.min(l, 0.25);
    final scale = l <= 0.0001 ? 0.0 : target / l;
    return _argb(
      (r * scale * 255).round(),
      (g * scale * 255).round(),
      (b * scale * 255).round(),
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
    final premultipliedSubject = subject;
    // Layer pixels are premultiplied: colours are judged and blended as
    // the colours they are, then multiplied back by their own opacity.
    subject = unpremultiplied(subject);
    // The background softened by 「ぼかし具合」: its light and colours are
    // taken from the blurred picture, so small details do not speckle the
    // drawing.
    background = unpremultiplied(
      blurredBackground(background, width, height, filter.bgBlendBlur),
    );
    final env = analysis ?? analyze(subject, background, width, height, filter);
    final result = Uint8List.fromList(premultipliedSubject);
    final count = width * height;
    final inside = Uint8List(count);
    var sumX = 0.0, sumY = 0.0, insideCount = 0;
    for (int p = 0; p < count; p++) {
      if (subject[p * 4 + 3] < 16) continue;
      inside[p] = 1;
      sumX += p % width;
      sumY += p ~/ width;
      insideCount++;
    }
    if (insideCount == 0) return result;
    // The body's centre and reach, for the light-to-shadow gradient that
    // runs across the whole drawing.
    final centreX = sumX / insideCount, centreY = sumY / insideCount;
    var reach = 1.0;
    for (int p = 0; p < count; p++) {
      if (inside[p] == 0) continue;
      final dx = p % width - centreX, dy = p ~/ width - centreY;
      reach = math.max(reach, math.sqrt(dx * dx + dy * dy));
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
    final toneMatch = global * (filter.bgBlendToneMatch / 100).clamp(0.0, 1.0);
    final primaryGlows = isGlowingLight(env.primaryColor);
    final tones = env.tones;

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

    int distAt(int x, int y) {
      if (x < 0 || y < 0 || x >= width || y >= height) return 0;
      return dist[y * width + x];
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
        var nlen = math.sqrt(nx * nx + ny * ny);
        if (nlen <= 0.001) {
          // Inside the shape the alpha is flat: the way out is where the
          // distance to the outline falls, so each side faces its own way
          // (the far side does not count as lit). Taken over 5 x 5 pixels:
          // the stepped distance's own slope fans out in streaks where two
          // edges' distances meet (a glowing light showed them as rays).
          nx = 0;
          ny = 0;
          for (var k = -2; k <= 2; k++) {
            nx += distAt(x - 2, y + k) - distAt(x + 2, y + k);
            ny += distAt(x + k, y - 2) - distAt(x + k, y + 2);
          }
          nlen = math.sqrt(nx * nx + ny * ny);
        }
        if (nlen > 0.001) {
          nx /= nlen;
          ny /= nlen;
        } else {
          nx = 0;
          ny = 0;
        }

        // Across the whole body the light falls off from the side towards
        // it to the far side, and the shadow the other way, so the middle
        // takes some of both (as under a large light source). At the outline
        // the edge's own facing takes over where it is stronger.
        final along = (((x - centreX) * lx + (y - centreY) * ly) / reach).clamp(
          -1.0,
          1.0,
        );
        // A glowing light lights mostly the outline facing it: in Add, the
        // whole body lit by it would glow.
        final facingLight = math.max(
          math.max(0.0, nx * lx + ny * ly) * edgeFalloff,
          (0.5 + 0.5 * along) * _bodyShading * (primaryGlows ? .35 : 1),
        );
        final facingShadow = math.max(
          math.max(0.0, -(nx * lx + ny * ly)) * edgeFalloff,
          (0.5 - 0.5 * along) * _bodyShading,
        );
        var r = subject[idx].toDouble();
        var g = subject[idx + 1].toDouble();
        var b = subject[idx + 2].toDouble();
        if (toneMatch > 0) (r, g, b) = _matchTones(r, g, b, tones, toneMatch);
        final originalLuma = _luma(r.round(), g.round(), b.round());
        final originalChroma = _rgbChroma(r, g, b);

        // 環境光は対象全体へオーバーレイで（全体の色の方向）。縁ほど少し
        // 強くする。
        final ambientAmount =
            global *
            ambientStrength *
            (0.70 + edgeFalloff * 0.30) *
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
          mode: LayerBlendMode.overlay,
        );

        final lightAmount =
            global *
            lightStrength *
            facingLight *
            _materialFactor(
              originalLuma,
              originalChroma,
              materialProtection,
              true,
            );
        // The main light in Hard Light, or, a strong coloured light (neon),
        // glowing in Add.
        (r, g, b) = _blendProtected(
          r,
          g,
          b,
          env.primaryColor,
          lightAmount,
          originalLuma,
          materialProtection,
          true,
          mode: primaryGlows
              ? LayerBlendMode.addition
              : LayerBlendMode.hardLight,
        );

        // Other lights: a strong coloured light (neon) glows in Add, the
        // rest light up in Screen.
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
            mode: isGlowingLight(entry.$3.color)
                ? LayerBlendMode.addition
                : LayerBlendMode.screen,
          );
        }

        final shadowAmount =
            global *
            shadowStrength *
            facingShadow *
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

        // 画面下から来る反射光（照り返し）をスクリーンで。下向きの輪郭
        // 法線ほど強く、対象の下側全体にも弱く返す。
        final reflectionFacing = math.max(
          math.max(0.0, ny) * edgeFalloff,
          math.max(0.0, (y - centreY) / reach) * _bodyShading * 0.5,
        );
        final reflectionAmount =
            global * reflectionStrength * reflectionFacing * 0.72;
        (r, g, b) = _blendProtected(
          r,
          g,
          b,
          env.reflectionColor,
          reflectionAmount,
          originalLuma,
          materialProtection,
          true,
          mode: LayerBlendMode.screen,
        );

        // 輪郭直近の背景色を局所的な色移り（周りからの反射）としてスクリーンで
        // 加える。近傍の実色を使うため「足元は地面色」などの意味認識を決め打ち
        // しない。
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
                mode: LayerBlendMode.screen,
              );
            }
          }
        }

        final nr = r.round().clamp(0, 255);
        final ng = g.round().clamp(0, 255);
        final nb = b.round().clamp(0, 255);
        // A pixel left as it was keeps its exact bytes.
        if (nr == subject[idx] &&
            ng == subject[idx + 1] &&
            nb == subject[idx + 2]) {
          continue;
        }
        // alphaは絶対に変更しない。
        final a = subject[idx + 3];
        result[idx] = premultipliedChannel(nr, a);
        result[idx + 1] = premultipliedChannel(ng, a);
        result[idx + 2] = premultipliedChannel(nb, a);
      }
    }
    return result;
  }

  /// How strongly the light-to-shadow gradient across the whole body lights
  /// and shades the drawing, relative to the outline facing the light.
  static const double _bodyShading = 0.8;

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

  static final Float64List _blendScratch = Float64List(3);

  /// [_blendProtected], for tests.
  @visibleForTesting
  static (double, double, double) blendForTest(
    double r,
    double g,
    double b,
    int color,
    double amount, {
    LayerBlendMode mode = LayerBlendMode.hardLight,
  }) => _blendProtected(r, g, b, color, amount, 0, 0, true, mode: mode);

  /// Whether a light of [color] is a strong coloured light (a neon sign, a
  /// lamp), which glows in Add rather than lighting up in Screen.
  @visibleForTesting
  static bool isGlowingLight(int color) {
    final hi = math.max(
      (color >> 16) & 0xFF,
      math.max((color >> 8) & 0xFF, color & 0xFF),
    );
    return _chroma(color) >= .6 && hi >= 180;
  }

  static (double, double, double) _blendProtected(
    double r,
    double g,
    double b,
    int color,
    double amount,
    double originalLuma,
    double protection,
    bool isLight, {
    LayerBlendMode mode = LayerBlendMode.hardLight,
  }) {
    final t = amount.clamp(0.0, 1.0);
    if (t <= 0) return (r, g, b);
    // The background's light and colour are laid over as a layer in [mode]
    // would be: the light and shadow in Hard Light (light colours brighten,
    // dark ones deepen, and the picture's own shading shows through), the
    // surroundings' colour in Overlay, reflected light in Screen and a
    // glowing light in Add.
    final out = _blendScratch;
    blendRgbOver(
      mode,
      r / 255,
      g / 255,
      b / 255,
      ((color >> 16) & 0xFF) / 255,
      ((color >> 8) & 0xFF) / 255,
      (color & 0xFF) / 255,
      t,
      out,
    );
    var nr = out[0] * 255;
    var ng = out[1] * 255;
    var nb = out[2] * 255;
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

  /// The drawing's colour ([r], [g], [b], 0 to 255) brought into the
  /// background's [tones] by [amount] (0 to 1): highlights brighter than
  /// the background's brightest are drawn back towards them, colours more
  /// saturated than the background's most saturated are toned down, and
  /// each tone takes some of the background's colour cast in that tone
  /// (its shadows', middle tones' or highlights'), keeping its brightness.
  /// Dark lines keep their darkness and colour.
  static (double, double, double) _matchTones(
    double r,
    double g,
    double b,
    BackgroundTones tones,
    double amount,
  ) {
    var l = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 255;
    if (l <= 0.0001) return (r, g, b);
    // Brightness: what is brighter than the background's highlights comes
    // most of the way down to them.
    final ceiling = math.min(1.0, tones.high + .05);
    if (l > ceiling) {
      final target = ceiling + (l - ceiling) * .35;
      final scale = (l + (target - l) * amount) / l;
      r *= scale;
      g *= scale;
      b *= scale;
      l *= scale;
    }
    final grey = l * 255;
    // Saturation: more saturated than the background's most saturated
    // colours, most of the way back to them.
    final hi = math.max(r, math.max(g, b));
    final lo = math.min(r, math.min(g, b));
    final saturation = hi <= 0 ? 0.0 : (hi - lo) / hi;
    final limit = math.min(1.0, tones.saturation + .08);
    if (saturation > limit) {
      final target =
          saturation +
          (limit + (saturation - limit) * .4 - saturation) * amount;
      // How much of the colour's distance from its grey keeps it at the
      // target saturation (the brightest channel comes down with the rest).
      final keep = (target * grey / ((hi - lo) - target * (hi - grey))).clamp(
        0.0,
        1.0,
      );
      r = grey + (r - grey) * keep;
      g = grey + (g - grey) * keep;
      b = grey + (b - grey) * keep;
    }
    // Colour balance: the background's colour in this tone, without its
    // brightness, so the drawing's brightness stays.
    final span = math.max(.05, tones.high - tones.low);
    final t = ((l - tones.low) / span).clamp(0.0, 1.0);
    final (from, to, k) = t < .5
        ? (tones.shadow, tones.middle, t * 2)
        : (tones.middle, tones.highlight, t * 2 - 1);
    double channel(int shift) =>
        ((from >> shift) & 0xFF) * (1 - k) + ((to >> shift) & 0xFF) * k;
    final tr = channel(16), tg = channel(8), tb = channel(0);
    final tl = tr * 0.2126 + tg * 0.7152 + tb * 0.0722;
    // Lines and other near-black stay as they are.
    final dark = ((l - .08) / .17).clamp(0.0, 1.0);
    final cast = amount * .3 * dark * dark * (3 - 2 * dark);
    return (
      (r + (tr - tl) * cast).clamp(0.0, 255.0),
      (g + (tg - tl) * cast).clamp(0.0, 255.0),
      (b + (tb - tl) * cast).clamp(0.0, 255.0),
    );
  }

  /// [background] (premultiplied RGBA) blurred by [radius] px: two passes
  /// of a box blur each way, close to a Gaussian. 0 leaves it as it is.
  @visibleForTesting
  static Uint8List blurredBackground(
    Uint8List background,
    int width,
    int height,
    double radius,
  ) {
    final box = (radius / 2).round();
    if (box <= 0 || width <= 0 || height <= 0) return background;
    var work = Float64List(width * height * 4);
    for (var i = 0; i < work.length; i++) {
      work[i] = background[i].toDouble();
    }
    var next = Float64List(work.length);
    void pass(int length, int lines, int Function(int line, int at) index) {
      final size = box * 2 + 1;
      for (var line = 0; line < lines; line++) {
        for (var c = 0; c < 4; c++) {
          var sum = 0.0;
          for (var k = -box; k <= box; k++) {
            sum += work[index(line, k.clamp(0, length - 1)) * 4 + c];
          }
          for (var at = 0; at < length; at++) {
            next[index(line, at) * 4 + c] = sum / size;
            final out = (at - box).clamp(0, length - 1);
            final into = (at + box + 1).clamp(0, length - 1);
            sum +=
                work[index(line, into) * 4 + c] -
                work[index(line, out) * 4 + c];
          }
        }
      }
      final swap = work;
      work = next;
      next = swap;
    }

    for (var round = 0; round < 2; round++) {
      pass(width, height, (y, x) => y * width + x);
      pass(height, width, (x, y) => y * width + x);
    }
    final out = Uint8List(background.length);
    for (var i = 0; i < out.length; i++) {
      out[i] = work[i].round().clamp(0, 255);
    }
    return out;
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
