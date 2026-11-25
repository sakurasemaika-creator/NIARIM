import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../models/app_theme_preset.dart';
import 'color_contrast.dart';

/// 警告色（テーマ・外観の「警告色」）の既定の決め方と、警告色・更新マーク色
/// （注意色）の上に書く文字色の選び方。
///
/// 警告色は取り消せない操作（削除・完全削除・上書き・全データの削除）と、
/// 作品が保存できない・失われうる失敗の知らせだけに使う。組み込みの28の
/// テーマの警告色はここで決めた値を定数として持ち
/// （`test/theme_warning_color_test.dart`が決め方で計算し直して見張る）、
/// 警告色を持たない古い保存・引き継ぎ・書き出したテーマは読み込むときに
/// その色から同じ決め方で決める。
///
/// 決め方：
/// 1. 色相はOKLCHの[kWarningHue]（sRGBの赤の色相、朱に近い赤）。彩度は
///    [kWarningMaxChroma]（その明るさでsRGBに入らなければ入る最大）。
/// 2. 明るさ（OKLabのL）は、パネルの背景が明るいテーマ（相対輝度0.5より
///    大きい。テーマの明暗の決め方と同じ）は0.80から、暗いテーマは0.40から、
///    背景から離れる向きへ0.005ずつたどる。
/// 3. 8bitのsRGBに丸めた色が次をすべて満たす最初の明るさを使う（背景に
///    いちばん近い＝いちばん鮮やかな赤）：
///    - パネルの背景・メニューの背景の上でAPCAの|Lc|が[kWarningMinLc]以上、
///      WCAG 2のコントラスト比が[kWarningMinContrastRatio]以上（小さな知らせの
///      文も読める。以前のMaterialのエラーの色が守っていた比）
///    - 警告色の上の文字色（[readableInkOn]）が警告色の上で同じ2つを満たす
///    - 差し色・更新マーク色からCIELABのΔE*ab（CIE76）が[kWarningMinDeltaE]
///      以上（赤・ピンクの差し色のテーマでも、主な操作と見分けられる）
/// 4. どの明るさでも満たせない配色（灰色の中ほどの背景等）では、0.20〜0.95の
///    明るさのうち、いちばん足りない条件の割合が最も大きい色を使う。
const double kWarningHue = 29;
const double kWarningMaxChroma = 0.22;
const double kWarningMinLc = 60;
const double kWarningMinContrastRatio = 4.5;
const double kWarningMinDeltaE = 20;

/// [preset]の警告色の既定（[AppThemePreset.warningColor]を持たないとき）。
Color defaultWarningColorFor(AppThemePreset preset) {
  final panel = opaqueOver(preset.panelBgColor, const Color(0xFF000000));
  final menu = opaqueOver(preset.menuBgColor, panel);
  final accent = opaqueOver(preset.accentColor, panel);
  final caution = opaqueOver(preset.updateMarkColor, panel);
  final inks = themeInksOf(preset);
  final light = panel.computeLuminance() > 0.5;

  /// 条件ごとの満たし方（1以上で満たす）のうち、いちばん小さいもの。
  double weakest(Color warning) {
    final on = readableInkOn(warning, inks);
    return [
      apcaContrast(warning, panel).abs() / kWarningMinLc,
      apcaContrast(warning, menu).abs() / kWarningMinLc,
      apcaContrast(on, warning).abs() / kWarningMinLc,
      contrastRatio(warning, panel) / kWarningMinContrastRatio,
      contrastRatio(warning, menu) / kWarningMinContrastRatio,
      contrastRatio(on, warning) / kWarningMinContrastRatio,
      cielabDeltaE(warning, accent) / kWarningMinDeltaE,
      cielabDeltaE(warning, caution) / kWarningMinDeltaE,
    ].reduce(math.min);
  }

  for (var i = 0; ; i++) {
    final lightness = light ? 0.80 - 0.005 * i : 0.40 + 0.005 * i;
    if (lightness < 0.20 - 1e-9 || lightness > 0.95 + 1e-9) break;
    final candidate = _warningAt(lightness);
    if (weakest(candidate) >= 1) return candidate;
  }
  Color? best;
  var bestScore = double.negativeInfinity;
  for (var i = 0; i <= 150; i++) {
    final candidate = _warningAt(0.20 + 0.005 * i);
    final score = weakest(candidate);
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }
  return best!;
}

/// [preset]の警告色が決め方どおり（利用者が選んでいない）か。テーマ・外観で
/// 警告色以外の色（背景・差し色等）を変えるとき、決め方どおりなら警告色も
/// 変えた後の色で決め直す（背景を暗くしても読める赤のまま。差し色と同じ色の
/// 選択色が差し色に付いていくのと同じ）。利用者が選んだ警告色はそのまま。
bool warningFollowsRule(AppThemePreset preset) =>
    preset.warningColor.toARGB32() == defaultWarningColorFor(preset).toARGB32();

/// テーマ自身の文字色・背景色（不透明にしたもの）。警告色・注意色の上の
/// 文字は、この中から選ぶ（黒・白に決め打ちしない）。
List<Color> themeInksOf(AppThemePreset preset) {
  final panel = opaqueOver(preset.panelBgColor, const Color(0xFF000000));
  final menu = opaqueOver(preset.menuBgColor, panel);
  return [
    panel,
    menu,
    opaqueOver(preset.textColor, panel),
    opaqueOver(preset.menuTextColor, menu),
    opaqueOver(preset.buttonTextColor, panel),
  ];
}

/// [inks]のうち、[fill]の上でAPCAの|Lc|がいちばん大きい色（同じなら先の色）。
Color readableInkOn(Color fill, List<Color> inks) {
  var best = inks.first;
  var bestLc = -1.0;
  for (final ink in inks) {
    final lc = apcaContrast(ink, fill).abs();
    if (lc > bestLc) {
      best = ink;
      bestLc = lc;
    }
  }
  return best;
}

/// OKLabの明るさ[lightness]の警告色（色相[kWarningHue]、8bitのsRGB）。
Color _warningAt(double lightness) {
  final hue = kWarningHue * math.pi / 180;
  // sRGBに入る最大の彩度を二分法で探す。
  var low = 0.0;
  var high = kWarningMaxChroma;
  if (_inGamut(_oklchToLinear(lightness, high, hue))) {
    low = high;
  } else {
    for (var i = 0; i < 30; i++) {
      final mid = (low + high) / 2;
      if (_inGamut(_oklchToLinear(lightness, mid, hue))) {
        low = mid;
      } else {
        high = mid;
      }
    }
  }
  final linear = _oklchToLinear(lightness, low, hue);
  int byte(double v) {
    final c = v.clamp(0.0, 1.0);
    final s = c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
    return (s * 255).round().clamp(0, 255);
  }

  return Color.fromARGB(255, byte(linear.$1), byte(linear.$2), byte(linear.$3));
}

bool _inGamut((double, double, double) rgb) {
  const eps = 1e-6;
  return rgb.$1 >= -eps &&
      rgb.$1 <= 1 + eps &&
      rgb.$2 >= -eps &&
      rgb.$2 <= 1 + eps &&
      rgb.$3 >= -eps &&
      rgb.$3 <= 1 + eps;
}

/// OKLCH（Björn Ottossonの変換式）から線形sRGBへ。
(double, double, double) _oklchToLinear(
  double lightness,
  double chroma,
  double hue,
) {
  final a = chroma * math.cos(hue);
  final b = chroma * math.sin(hue);
  final l = math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3);
  final m = math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3);
  final s = math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3);
  return (
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
  );
}
