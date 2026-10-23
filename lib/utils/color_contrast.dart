import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_theme_preset.dart';

/// テーマが操作不能になる場合の復旧導線を判定する。
///
/// 色差ではなく「背景上の文字・主要アイコンがほとんど読めない」ことが対象。
/// APCAの知覚的文字コントラストを正常・色覚模擬後の実表示色で求める。
/// 文字色や背景色を自動補正したり、ユーザーの色設定を拒否しない。
/// 判定はThemeService側で現在テーマごとにキャッシュし、
/// 描画フレーム、スクロール、アニメーションでは再計算しない。
/// sRGBの相対輝度（WCAG 2.1の定義）。
double relativeLuminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// 2色のコントラスト比（1.0＝同じ色、21.0＝白と黒）。
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// APCA-W3 0.0.98G (sRGB)の背景上の文字コントラスト（Lc）。
///
/// foregroundは実際に描画する文字/アイコン、backgroundは直下の背景。
/// 値の符号は文字と背景の明暗方向を表す。復旧リスクでは絶対値を使う。
/// https://github.com/Myndex/SAPC-APCA/blob/master/documentation/README.md
///
/// APCAの一般的な合否を判定する関数ではなく、文字が消えかける
/// 低コントラスト領域だけを検出する。色相の違いだけでは判定しない。
double apcaContrast(Color foreground, Color background) {
  double screenY(Color color) {
    final y = 0.2126729 * math.pow(color.r, 2.4).toDouble() +
        0.7151522 * math.pow(color.g, 2.4).toDouble() +
        0.0721750 * math.pow(color.b, 2.4).toDouble();
    return y < 0.022 ? y + math.pow(0.022 - y, 1.414) : y;
  }

  final textY = screenY(foreground);
  final backgroundY = screenY(background);
  if ((backgroundY - textY).abs() < 0.0005) return 0;

  final raw = backgroundY > textY
      ? 1.14 * (math.pow(backgroundY, 0.56) - math.pow(textY, 0.57))
      : 1.14 * (math.pow(backgroundY, 0.65) - math.pow(textY, 0.62));
  if (raw.abs() < 0.1) return 0;
  return (raw - (raw > 0 ? 0.027 : -0.027)) * 100;
}

/// 配色を自由に使えるよう、「著しく判読しにくく自力復旧が難しい」
/// 場合だけ救済ボタンを表示するための経験的な厳しい閾値。
/// |Lc| 10未満の場合のみ対象（ちょうど10は非対象）。
/// 通常の文字の可読性基準・保存条件ではない。
/// APCAは非常に低いコントラストをLc 0に丸め、次の非ゼロ値は
/// おおむね|Lc| 7.3以上になるため、閾値5では多くの危険な例が
/// Lc 0以外で検出されない。正常色覚・1型・2型・3型を同じ閾値で扱う。
const double kThemeRescueUnusableTextLc = 10.0;

/// 本当に重要なUI文字と背景だけをテストする。
/// 正常色覚をまず判定し、|Lc|10以上だった場合に1/2/3型の模擬を実施。
/// いずれか**1つでも**|Lc|10未満ならtrue。すべて10以上ならfalse。
/// 文字サイズや字体、表示倍率そのものの推定は行わず、
/// 低スペック端末でも短時間で済む一定個数の計算に限定する。
bool isEssentialTextNearlyInvisible(Color foreground, Color background) {
  if (apcaContrast(foreground, background).abs() <
      kThemeRescueUnusableTextLc) {
    return true;
  }
  for (final type in const [
    ColorVisionType.protanopia,
    ColorVisionType.deuteranopia,
    ColorVisionType.tritanopia,
  ]) {
    if (apcaContrast(
          simulateColorVision(foreground, type),
          simulateColorVision(background, type),
        ).abs() <
        kThemeRescueUnusableTextLc) {
      return true;
    }
  }
  return false;
}

/// Keeps the preferred foreground when it meets normal-text contrast on the
/// actual opaque background, otherwise chooses the more legible neutral.
Color contrastingForeground(Color background, Color preferred) {
  if (preferred.a == 1 && contrastRatio(background, preferred) >= 4.5) {
    return preferred;
  }
  return contrastRatio(background, Colors.black) >=
          contrastRatio(background, Colors.white)
      ? Colors.black
      : Colors.white;
}

/// Machado–Oliveira–Fernandes (2009) による線形sRGB色覚模擬行列。
/// Severity 1.0 は二色覚に相当、0.6 は異常三色覚の例。個人差を示す診断ではない。
/// https://www.inf.ufrgs.br/~oliveira/pubs_files/CVD_Simulation/CVD_Simulation.html
enum ColorVisionType {
  protanopia,
  protanomaly,
  deuteranopia,
  deuteranomaly,
  tritanopia,
  tritanomaly,
}

const Map<ColorVisionType, List<double>> _colorVisionMatrices = {
  ColorVisionType.protanopia: [
    0.152286, 1.052583, -0.204868,
    0.114503, 0.786281, 0.099216,
    -0.003882, -0.048116, 1.051998,
  ],
  ColorVisionType.protanomaly: [
    0.385450, 0.769005, -0.154455,
    0.100526, 0.829802, 0.069673,
    -0.007442, -0.022190, 1.029632,
  ],
  ColorVisionType.deuteranopia: [
    0.367322, 0.860646, -0.227968,
    0.280085, 0.672501, 0.047413,
    -0.011820, 0.042940, 0.968881,
  ],
  ColorVisionType.deuteranomaly: [
    0.498864, 0.674741, -0.173604,
    0.205199, 0.754872, 0.039929,
    -0.011131, 0.030969, 0.980162,
  ],
  ColorVisionType.tritanopia: [
    1.255528, -0.076749, -0.178779,
    -0.078411, 0.930809, 0.147602,
    0.004733, 0.691367, 0.303900,
  ],
  ColorVisionType.tritanomaly: [
    1.104996, -0.046633, -0.058363,
    -0.032137, 0.971635, 0.060503,
    0.001336, 0.317922, 0.680742,
  ],
};

double _toLinear(double v) =>
    v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _toSrgb(double v) {
  final c = v.clamp(0.0, 1.0).toDouble();
  return c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1 / 2.4) - 0.055;
}

/// 実際の画面に使われる色を、色覚特性のシミュレーションへ変換する。
Color simulateColorVision(Color color, ColorVisionType type) {
  final matrix = _colorVisionMatrices[type]!;
  final channels = [
    _toLinear(color.r),
    _toLinear(color.g),
    _toLinear(color.b),
  ];
  double transformed(int row) => _toSrgb(
    matrix[row * 3] * channels[0] +
        matrix[row * 3 + 1] * channels[1] +
        matrix[row * 3 + 2] * channels[2],
  );
  int toByte(double v) => (v * 255).round().clamp(0, 255).toInt();
  return Color.fromARGB(
    toByte(color.a),
    toByte(transformed(0)),
    toByte(transformed(1)),
    toByte(transformed(2)),
  );
}

/// OKLabの知覚色空間（Björn Ottossonの変換式）。
({double l, double a, double b}) _okLab(Color color) {
  final r = _toLinear(color.r);
  final g = _toLinear(color.g);
  final b = _toLinear(color.b);
  final l = math.pow(
    0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
    1 / 3,
  ).toDouble();
  final m = math.pow(
    0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
    1 / 3,
  ).toDouble();
  final s = math.pow(
    0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    1 / 3,
  ).toDouble();
  return (
    l: 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    a: 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    b: 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  );
}

/// OKLab内の距離。人間が必ず区別できる・できないという保証ではない。
double okLabDistance(Color a, Color b) {
  final x = _okLab(a);
  final y = _okLab(b);
  return math.sqrt(
    math.pow(x.l - y.l, 2) +
        math.pow(x.a - y.a, 2) +
        math.pow(x.b - y.b, 2),
  );
}

/// OKLab(0〜1近辺)でほぼ同じ色とみなす、復旧ボタン表示専用の厳しい
/// 経験的閾値。厳密な識別限界は文字サイズ・周辺色・観察条件等で異なる。
const double kMaxConfusableOkLabDistance = 0.045;

/// 色覚種別ごとの知覚色差。nullは正常色覚（色覚変換なし）。
/// 正常色覚、1型、2型（加えて3型）の結果を個別に計算して判定する。
double perceivedColorDistance(
  Color first,
  Color second, {
  ColorVisionType? visionType,
}) {
  if (visionType == null) return okLabDistance(first, second);
  return okLabDistance(
    simulateColorVision(first, visionType),
    simulateColorVision(second, visionType),
  );
}

/// 通常と色覚特性の例のうち、いずれかでほぼ区別できない色ペアか。
/// 結果は表示判定のみに使い、ユーザーの配色を変更しない。
bool isColorVisionPairConfusable(Color a, Color b) {
  for (final type in ColorVisionType.values) {
    if (perceivedColorDistance(a, b, visionType: type) <
        kMaxConfusableOkLabDistance) {
      return true;
    }
  }
  return false;
}

/// [preset]の重要な操作において、実際に重なる文字・アイコンと背景を判定する。
///
/// - 本文の文字色 × パネル背景色（一覧・設定画面の本文）
/// - メニュー文字色 × メニュー背景色（メニュー・上部バー）
/// - 本文文字色 × メニュー背景色（ダイアログ本文）
/// - ボタン文字色 × アクセント色・選択色（起動画面の導線）
/// - 選択中文字色 × 選択色（選択背景上のラベル）
///
/// 色面を区別できるかではなく、小さな文字・アイコンを視認できるかの目安。
/// ユーザーの色選択を拒否したり、自動で別の色に差し替えてはならない。
List<({Color a, Color b})> readabilityCriticalPairs(AppThemePreset preset) {
  // 実描画に合わせ、透過カラーは使用面の背景へ合成してから比較する。
  // 異なる場所で使われる無関係な色は比較しない。
  final panel = opaqueOver(preset.panelBgColor, Colors.black);
  final menu = opaqueOver(preset.menuBgColor, panel);
  final accent = opaqueOver(preset.accentColor, panel);
  final selection = opaqueOver(preset.selectionColor, panel);
  // 起動画面の主要ボタンは独立したbuttonTextColorで描画する。
  final splashForeground = preset.buttonTextColor;
  final menuForeground = preset.menuTextColor;
  return [
    // 一般的な一覧・設定項目の本文/パネル背景
    (a: opaqueOver(preset.textColor, panel), b: panel),
    // 上部バー・メニューの文字と、メニュー背景
    (a: opaqueOver(menuForeground, menu), b: menu),
    // ダイアログ本文や入力欄など、本文文字がメニュー色の面に載る場合
    (a: opaqueOver(preset.textColor, menu), b: menu),
    // 起動画面「作品をつくる」の文字・アイコン/アクセント色
    (a: opaqueOver(splashForeground, accent), b: accent),
    // 起動画面「作品広場」の文字・アイコン/選択色
    (a: opaqueOver(splashForeground, selection), b: selection),
    // 「選択中」ラベルが選択色に埋もれる場合
    (a: opaqueOver(preset.selectionTextColor, selection), b: selection),
  ];
}

/// 実際に重なる操作に不可欠な文字・アイコンが、少なくとも1つの
/// 視覚条件でほぼ識別不能になりそうな場合にだけ復旧ボタンを表示。
/// 選んだテーマの保存、色の変更、その他のUI配色には一切影響させない。
bool isThemeAtLockoutRisk(AppThemePreset preset) =>
    readabilityCriticalPairs(preset).any(
      (pair) => isEssentialTextNearlyInvisible(pair.a, pair.b),
    );

/// 既存テスト/呼び出しとの互換用の反転判定。
/// 文字を人間が必ず読めるという保証ではなく、リセットボタンを表示する目安の否定形にすぎない。
bool isThemeReadable(AppThemePreset preset) => !isThemeAtLockoutRisk(preset);

/// [color]を[under]の上に重ねたときに見える不透明な色。[color]が既に
/// 不透明ならそのまま返す。[under]自体が半透明なら黒の上に重ねる（画面の
/// いちばん下は黒）。
///
/// テーマの色はカラーピッカーで透明度も選べるため、そのまま下地に使うと
/// ダイアログ・トーストの後ろの画面が透けて見える。下地はこれで不透明に
/// してから使う。
Color opaqueOver(Color color, Color under) {
  if (color.a >= 1) return color;
  final base = under.a >= 1 ? under : Color.alphaBlend(under, Colors.black);
  return Color.alphaBlend(color, base);
}
