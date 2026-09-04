import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_theme_preset.dart';

/// テーマ配色の「読めるかどうか」を機械的に判定するためのユーティリティ。
///
/// テーマ・外観設定では文字色も背景色も自由に選べるため、**背景と文字を
/// 同じ（かごく近い）色にしてしまうと、設定画面の文字まで読めなくなり、
/// 自力で元に戻せなくなる**（いわゆる詰み）。これを防ぐために、
/// - テーマ・外観設定では、その組み合わせを保存させない
///   （`theme_settings_screen.dart`）
/// - それでも読めないテーマになってしまった場合に備えて、起動画面へ
///   固定色のリセットボタンを出す（`splash_screen.dart`）。
///   本アプリは未リリースのため「この判定より前に保存された設定」は
///   存在しない。残っている経路は**引き継ぎファイル（.niatra）の取り込み**
///   （他人の端末で作られたテーマがそのまま入ってくる）だけ。
/// の2段構えにしている。
///
/// ## しきい値について
///
/// 判定はWCAG 2.1のコントラスト比（相対輝度の比、1.0〜21.0）。ただし
/// **アクセシビリティ基準（AA＝4.5、大きい文字＝3.0）は使わない**。
/// このアプリの既定テーマは「珊瑚ピンクの上に白抜き文字」のような、
/// 彩度の高いポップな配色を意図的に採っており、AA基準では既定テーマ自体が
/// 弾かれてしまう。ここで防ぎたいのは見やすさの最適化ではなく
/// **「文字がまったく見えない状態で操作不能になること」**だけ。
///
/// 実測値（`test/color_contrast_test.dart`が機械的に守っている）：
/// - 組み込み28プリセットの最小値：約1.75
///   （「ライトブルー（ライト）」の、水色のアクセント色に白抜き文字）
/// - まったく同じ色どうし：1.0
/// - 見分けがつかないほど近い色（#336699と#3A6FA0）：約1.13
///
/// この間を取って1.4。組み込みテーマは全て通り、「同じ色にしてしまった」
/// 「ほとんど同じ色にしてしまった」は確実に弾ける。
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

/// [preset]の中で「これが潰れると操作不能になる」色の組み合わせ。
///
/// - 本文の文字色 × パネル背景色（一覧・設定画面の本文）
/// - 本文の文字色 × メニュー背景色（メニュー・ダイアログの文字）
/// - メニュー背景色 × アクセント色（起動画面の導線ボタンとホーム画面
///   ウィジェットは、アクセント色の上にメニュー背景色で文字を置く）
List<({Color a, Color b})> readabilityCriticalPairs(AppThemePreset preset) => [
  (a: preset.textColor, b: preset.panelBgColor),
  (a: preset.textColor, b: preset.menuBgColor),
  (a: preset.menuBgColor, b: preset.accentColor),
];

/// [preset]の全ての重要な組み合わせが[kMinReadableContrast]以上か。
bool isThemeReadable(AppThemePreset preset) =>
    readabilityCriticalPairs(preset)
        .every((p) => contrastRatio(p.a, p.b) >= kMinReadableContrast);
