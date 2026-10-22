import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_theme_preset.dart';

/// テーマの「操作不能リスク」を見つけるための保守的なヒューリスティック。
///
/// **この判定でユーザーの配色設定を拒否してはならない。** 色相の差などを
/// 人間が識別できるかすべて判定できるわけではなく、低い値は「必ず読めない」
/// ことを意味しない。ここでの目的は、ほぼ同色の文字/背景などで起動画面の
/// 操作導線が埋もれる危険がありそうな場合に、復旧ボタンを表示することだけ。
///
/// - テーマ・外観設定では、選ばれた色をそのまま保存する。
/// - 現在のテーマがリスク条件に該当すれば、起動画面右上に固定色リセットボタンを表示する。
/// - 判定は手動設定、プリセット適用、import、.niatra等の取り込み元を問わない。
///
/// ## 閾値
///
/// WCAGのコントラスト比（相対輝度比、1.0〜21.0）を、復旧ボタンを表示するか
/// 判断するための保守的な手掛かりとしてのみ用いる。一般的なアクセシビリティ基準
/// （通常文字4.5:1、大きな文字3:1等）を、ユーザー設定の保存条件として強制しない。
/// 「読みにくいだけ」は拒否理由ではなく、設定を拒否する用途にこの値を流用しない。
const double kMinReadableContrast = 1.4;

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

/// [preset]の中で、明るさの近さから操作不能リスクを保守的に検出する色の組み合わせ。
///
/// - 本文の文字色 × パネル背景色（一覧・設定画面の本文）
/// - 本文の文字色 × メニュー背景色（メニュー・ダイアログの文字）
/// - メニュー背景色 × アクセント色（起動画面の導線ボタン等の文字/背景）
///
/// 色相によっては相対輝度が近くても人間には区別できるため、これは警告表示の目安であり、
/// ユーザーの色選択を拒否したり、自動で別の色に差し替えたりする根拠にしてはならない。
List<({Color a, Color b})> readabilityCriticalPairs(AppThemePreset preset) => [
  (a: preset.textColor, b: preset.panelBgColor),
  (a: preset.textColor, b: preset.menuBgColor),
  (a: preset.menuBgColor, b: preset.accentColor),
];

/// 現在のテーマが、起動画面に復旧ボタンを表示する対象になりそうか。
/// 設定時の保存拒否には絶対に使用しない。
bool isThemeAtLockoutRisk(AppThemePreset preset) => readabilityCriticalPairs(
  preset,
).any((p) => contrastRatio(p.a, p.b) < kMinReadableContrast);

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
