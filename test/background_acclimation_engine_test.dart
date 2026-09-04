import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/background_acclimation_engine.dart';
import 'package:niarim/models/filter_def.dart';

/// 環境光エンジン（背景馴染ませの拡張）が、実際に呼んで動くことを検証する。
///
/// エンジンが先にpushされ`FilterDef`側の15フィールドが後追いだった期間、
/// `flutter analyze`が29 errorsになり**APKビルドが静的解析の段階で落ちて**
/// いた（その後、上流の「環境光推定v2」でモデル側が揃った）。
/// コンパイルが通ることと実際に動くことは別なので、エンジンの不変条件
/// （alphaを触らない・強さ0で無変更・強さと変化量が単調）を直接叩いて確かめる。

/// 左上が明るく右下が暗い背景。光源が左上（135度付近）にあるように見える。
Uint8List _background(int w, int h) {
  final o = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final t = 1.0 - (x / (w - 1) + y / (h - 1)) / 2;
      o[i] = (60 + 180 * t).round();
      o[i + 1] = (70 + 170 * t).round();
      o[i + 2] = (90 + 150 * t).round();
      o[i + 3] = 255;
    }
  }
  return o;
}

/// 中央に置いた不透明な円（被写体）。周囲は完全に透明。
Uint8List _subject(int w, int h) {
  final o = Uint8List(w * h * 4);
  final cx = w / 2, cy = h / 2, r = math.min(w, h) * 0.28;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = x - cx, dy = y - cy;
      if (dx * dx + dy * dy > r * r) continue;
      final i = (y * w + x) * 4;
      o[i] = 200;
      o[i + 1] = 160;
      o[i + 2] = 140;
      o[i + 3] = 255;
    }
  }
  return o;
}

FilterDef _def({
  double strength = 60,
  bool autoLight = true,
  double materialProtection = 50,
}) => FilterDef(
  id: 'bg',
  name: 'bg',
  kind: FilterKind.backgroundBlend,
  bgBlendStrength: strength,
  bgBlendAutoLight: autoLight,
  bgBlendMaterialProtection: materialProtection,
);

void main() {
  const w = 96, h = 96;

  test('analyzeが背景から光源方向と色を推定する', () {
    final analysis = BackgroundAcclimationEngine.analyze(
      _subject(w, h),
      _background(w, h),
      w,
      h,
      _def(),
    );
    expect(analysis.confidence, greaterThan(0), reason: '被写体も背景もあるのに推定できていない');
    expect(analysis.primaryDirectionDegrees, inInclusiveRange(0, 360));
    // 左上が明るい背景なので、光源は左上側（90〜270度の間）に推定されるはず。
    expect(
      analysis.primaryDirectionDegrees,
      inInclusiveRange(90, 270),
      reason: '明るいのは左上なのに光源方向が右下側になっている',
    );
    // 光の色は影の色より明るい。
    int luma(int c) =>
        (((c >> 16) & 0xFF) * 299 +
            ((c >> 8) & 0xFF) * 587 +
            (c & 0xFF) * 114) ~/
        1000;
    expect(
      luma(analysis.primaryColor),
      greaterThan(luma(analysis.shadowColor)),
      reason: '光の色が影の色より暗い',
    );
  });

  test('applyが被写体だけを変え、alphaと背景側は一切触らない', () {
    final subject = _subject(w, h);
    final out = BackgroundAcclimationEngine.apply(
      Uint8List.fromList(subject),
      _background(w, h),
      w,
      h,
      _def(),
    );
    expect(out, hasLength(subject.length));

    var changedInside = 0, insideTotal = 0;
    for (var p = 0; p < w * h; p++) {
      final i = p * 4;
      // alphaは絶対に変わらない（エンジンのコメントで明言されている不変条件）。
      expect(out[i + 3], subject[i + 3], reason: 'alphaが変わっている（画素$p）');
      if (subject[i + 3] == 0) {
        // 透明部分（背景側）のRGBも触らない。
        expect(out[i], subject[i]);
        expect(out[i + 1], subject[i + 1]);
        expect(out[i + 2], subject[i + 2]);
      } else {
        insideTotal++;
        if (out[i] != subject[i] ||
            out[i + 1] != subject[i + 1] ||
            out[i + 2] != subject[i + 2]) {
          changedInside++;
        }
      }
    }
    expect(insideTotal, greaterThan(500), reason: '被写体が小さすぎて検証にならない');
    expect(
      changedInside / insideTotal,
      greaterThan(0.2),
      reason: '被写体がほとんど変化していない（エンジンが効いていない）',
    );
  });

  test('強さ0なら完全に無変更、強くするほど変化が大きい', () {
    final subject = _subject(w, h);
    final bg = _background(w, h);
    double diff(Uint8List a, Uint8List b) {
      var s = 0.0;
      for (var i = 0; i < a.length; i++) {
        s += (a[i] - b[i]).abs();
      }
      return s / a.length;
    }

    final zero = BackgroundAcclimationEngine.apply(
      Uint8List.fromList(subject),
      bg,
      w,
      h,
      _def(strength: 0),
    );
    expect(diff(subject, zero), 0, reason: '強さ0でも変化している');

    final weak = BackgroundAcclimationEngine.apply(
      Uint8List.fromList(subject),
      bg,
      w,
      h,
      _def(strength: 30),
    );
    final strong = BackgroundAcclimationEngine.apply(
      Uint8List.fromList(subject),
      bg,
      w,
      h,
      _def(strength: 100),
    );
    expect(
      diff(subject, strong),
      greaterThan(diff(subject, weak)),
      reason: '強さを上げても変化が増えていない',
    );
  });

  test('素材感の保護を強めるほど元の色が残る', () {
    final subject = _subject(w, h);
    final bg = _background(w, h);
    double diff(Uint8List a, Uint8List b) {
      var s = 0.0;
      for (var i = 0; i < a.length; i++) {
        s += (a[i] - b[i]).abs();
      }
      return s / a.length;
    }

    final low = BackgroundAcclimationEngine.apply(
      Uint8List.fromList(subject),
      bg,
      w,
      h,
      _def(strength: 100, materialProtection: 0),
    );
    final high = BackgroundAcclimationEngine.apply(
      Uint8List.fromList(subject),
      bg,
      w,
      h,
      _def(strength: 100, materialProtection: 100),
    );
    expect(
      diff(subject, high),
      lessThan(diff(subject, low)),
      reason: '保護を強めたのに変化量が減っていない',
    );
  });

  test('背景が無い・寸法が不正でも落ちずに元データを返す', () {
    final subject = _subject(w, h);
    expect(
      BackgroundAcclimationEngine.apply(
        Uint8List.fromList(subject),
        null,
        w,
        h,
        _def(),
      ),
      orderedEquals(subject),
    );
    expect(
      BackgroundAcclimationEngine.apply(
        Uint8List.fromList(subject),
        Uint8List(4),
        w,
        h,
        _def(),
      ),
      orderedEquals(subject),
    );
    // 被写体が1画素も無い場合はフォールバック推定へ倒れる（例外にしない）。
    final empty = BackgroundAcclimationEngine.analyze(
      Uint8List(w * h * 4),
      _background(w, h),
      w,
      h,
      _def(),
    );
    expect(empty.confidence, 0);
  });

  test('FilterDefの新しい項目がJSONで往復する', () {
    const def = FilterDef(
      id: 'x',
      name: 'x',
      kind: FilterKind.backgroundBlend,
      bgBlendAutoLight: false,
      bgBlendSamplingBand: 33,
      bgBlendStrength: 71,
      bgBlendSoftness: 12,
      bgBlendLightColor: 0xFF102030,
      bgBlendLightStrength: 41,
      bgBlendShadowColor: 0xFF203040,
      bgBlendShadowStrength: 42,
      bgBlendAmbientColor: 0xFF304050,
      bgBlendAmbientStrength: 43,
      bgBlendReflectionColor: 0xFF405060,
      bgBlendReflectionStrength: 44,
      bgBlendColorBleed: 45,
      bgBlendSecondaryStrength: 46,
      bgBlendMaterialProtection: 47,
    );
    final back = FilterDef.fromJson(def.toJson());
    expect(back.bgBlendAutoLight, isFalse);
    expect(back.bgBlendSamplingBand, 33);
    expect(back.bgBlendStrength, 71);
    expect(back.bgBlendSoftness, 12);
    expect(back.bgBlendLightColor, 0xFF102030);
    expect(back.bgBlendLightStrength, 41);
    expect(back.bgBlendShadowColor, 0xFF203040);
    expect(back.bgBlendShadowStrength, 42);
    expect(back.bgBlendAmbientColor, 0xFF304050);
    expect(back.bgBlendAmbientStrength, 43);
    expect(back.bgBlendReflectionColor, 0xFF405060);
    expect(back.bgBlendReflectionStrength, 44);
    expect(back.bgBlendColorBleed, 45);
    expect(back.bgBlendSecondaryStrength, 46);
    expect(back.bgBlendMaterialProtection, 47);

    // 古い保存データ（新項目が無いJSON）でも既定値へ倒れて読める。
    final legacy = Map<String, dynamic>.from(def.toJson())
      ..removeWhere((k, v) => k.startsWith('bgBlend') && k != 'bgBlendColor');
    final migrated = FilterDef.fromJson(legacy);
    expect(migrated.bgBlendAutoLight, isTrue);
    expect(migrated.bgBlendStrength, 70);
    expect(migrated.bgBlendMaterialProtection, 75);
  });
}
