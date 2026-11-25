import 'package:flutter/material.dart';

/// 警告色と注意色（テーマ・外観の「警告色」「更新マーク色」）。
///
/// ふだんの画面は基本の色（背景・文字・差し色）だけで描き、ちゃんと見て
/// ほしい所だけをこの2つで目立たせる（所有者の判断）。色だけで伝えず、
/// いつも印のアイコンと文を添える。
///
/// - [warning]：取り消せない操作（削除・完全削除・ゴミ箱を空にする・上書き・
///   全データの削除）の確かめのボタンとメニューの項目、作品が保存できない・
///   失われうる失敗の知らせだけ。
/// - [caution]（＝更新マーク色）：更新の印と、何も失われないが気をつけて
///   ほしい知らせ（読み込めない・つながらない〔やり直せる〕・上限に近い等）
///   だけ。飾り・選択の縁・ふつうの情報には使わない。
///
/// 画面からはこのクラス（[warningFilledButtonStyle]・`IconNotice.warning`・
/// `IconNotice.caution`・`MenuActionLabel(destructive: true)`）を通して使い、
/// `colorScheme.error`・`updateMarkColor`を直接使わない
/// （`test/no_error_colour_notices_test.dart`が見張る）。
@immutable
class SignalColors extends ThemeExtension<SignalColors> {
  const SignalColors({
    required this.warning,
    required this.onWarning,
    required this.caution,
    required this.onCaution,
  });

  /// 警告色（不透明）。
  final Color warning;

  /// 警告色で塗った面の上の文字・アイコン（テーマ自身の文字色・背景色の
  /// うち、警告色の上でいちばん読める色）。
  final Color onWarning;

  /// 注意色（更新マーク色、不透明）。
  final Color caution;

  /// 注意色で塗った面の上の文字（更新の数のバッジ等）。
  final Color onCaution;

  /// テーマに設定されていなければ、Materialのエラーの色と既定の更新マーク色。
  static SignalColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<SignalColors>() ??
        SignalColors(
          warning: theme.colorScheme.error,
          onWarning: theme.colorScheme.onError,
          caution: const Color(0xFFFFB020),
          onCaution: theme.colorScheme.onSurface,
        );
  }

  @override
  SignalColors copyWith({
    Color? warning,
    Color? onWarning,
    Color? caution,
    Color? onCaution,
  }) => SignalColors(
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    caution: caution ?? this.caution,
    onCaution: onCaution ?? this.onCaution,
  );

  @override
  SignalColors lerp(SignalColors? other, double t) => other == null
      ? this
      : SignalColors(
          warning: Color.lerp(warning, other.warning, t)!,
          onWarning: Color.lerp(onWarning, other.onWarning, t)!,
          caution: Color.lerp(caution, other.caution, t)!,
          onCaution: Color.lerp(onCaution, other.onCaution, t)!,
        );
}

/// 取り消せない操作を確かめるボタン（`FilledButton`）の塗り：警告色の面に
/// 警告色の上の文字色。[style]（余白等）を渡すとそれに重ねる。押せない間は
/// テーマの押せないボタンの色のまま。
ButtonStyle warningFilledButtonStyle(
  BuildContext context, [
  ButtonStyle? style,
]) {
  final signals = SignalColors.of(context);
  final warning = FilledButton.styleFrom(
    backgroundColor: signals.warning,
    foregroundColor: signals.onWarning,
  );
  return style == null ? warning : style.merge(warning);
}
