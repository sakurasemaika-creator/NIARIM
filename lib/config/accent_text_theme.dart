import 'package:flutter/material.dart';

/// 差し色で背景の上に直接描く文字・アイコンの色（テーマ・外観の
/// 「アクセントの文字・アイコン色」）。
///
/// 差し色（`colorScheme.primary`）は下線・塗りのボタン・FAB等の「塗り」に
/// 使い、選択中のタブ名・枠や文字のボタン・空の表示のアイコン等の「背景の
/// 上の文字」にはこちらを使う。差し色1色で両方を兼ねていたため、明るい
/// 差し色を選ぶと背景の上の文字が読めなかった。ユーザーが選んだ色を
/// そのまま使い、自動では差し替えない。
@immutable
class AccentTextTheme extends ThemeExtension<AccentTextTheme> {
  const AccentTextTheme(this.color);

  final Color color;

  /// テーマに設定されていなければ差し色。
  static Color of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AccentTextTheme>()?.color ??
        theme.colorScheme.primary;
  }

  @override
  AccentTextTheme copyWith({Color? color}) =>
      AccentTextTheme(color ?? this.color);

  @override
  AccentTextTheme lerp(AccentTextTheme? other, double t) => other == null
      ? this
      : AccentTextTheme(Color.lerp(color, other.color, t)!);
}
