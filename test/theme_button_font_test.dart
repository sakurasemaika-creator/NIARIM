import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/theme_service.dart';

/// テーマが各ボタンへ与えるラベル書式に、**必ずアプリ同梱フォントが
/// 指定されている**ことを検証する。
///
/// `XxxButton.styleFrom(textStyle: ...)`へ素の`TextStyle()`を渡すと、
/// それがラベル書式を丸ごと決めてしまい`ThemeData.fontFamily`は継承されない。
/// その状態だとラベルだけ端末標準フォント（Roboto等）で描かれ、周囲の
/// 同梱フォントから明確に浮く。AppBarの`titleTextStyle`で一度踏んだ罠だが、
/// `filledButtonTheme`でも同じことが起きていた（「投稿機能は準備中です」の
/// OKボタンをPNGへ焼いて目視して発覚）。
///
/// SnackBarの`contentTextStyle`もまったく同じ形で踏んでいた（テーマ一覧の
/// 操作をPNGへ焼いて目視したところ、SnackBarの文字だけ豆腐＝端末標準
/// フォントになっていて発覚）。
///
/// 同種のThemeDataを新設したら、ここへ足すこと。
void main() {
  test('ボタン系テーマのラベル書式が同梱フォントを指定している', () {
    final theme = ThemeService().themeData;

    final targets = <String, TextStyle?>{
      'filledButtonTheme': theme.filledButtonTheme.style?.textStyle?.resolve(
        <WidgetState>{},
      ),
      'elevatedButtonTheme': theme.elevatedButtonTheme.style?.textStyle
          ?.resolve(<WidgetState>{}),
      'outlinedButtonTheme': theme.outlinedButtonTheme.style?.textStyle
          ?.resolve(<WidgetState>{}),
      'textButtonTheme': theme.textButtonTheme.style?.textStyle?.resolve(
        <WidgetState>{},
      ),
    };

    // SnackBarの本文書式も同じ罠を踏む（ボタンと同じくThemeData.fontFamilyを
    // 継承しない）。アプリ中のSnackBarすべてに効くので一緒に見張る。
    targets['snackBarTheme'] = theme.snackBarTheme.contentTextStyle;

    for (final entry in targets.entries) {
      final style = entry.value;
      // textStyle自体を指定していないテーマは、textThemeから正しく継承
      // されるので問題ない（＝nullは合格）。
      if (style == null) continue;
      expect(
        style.fontFamily,
        isNotNull,
        reason:
            '${entry.key}のtextStyleにfontFamilyが無い。'
            'textTheme.labelLarge等を土台にして上書きすること'
            '（素のTextStyle()を渡すと端末標準フォントになる）',
      );
      expect(
        style.fontFamilyFallback,
        isNotNull,
        reason: '${entry.key}のtextStyleにfontFamilyFallbackが無い',
      );
      expect(
        style.fontFamilyFallback,
        isNotEmpty,
        reason: '${entry.key}のfontFamilyFallbackが空',
      );
    }
  });

  testWidgets('FilledButtonのラベルが実際に同梱フォントで描かれる', (tester) async {
    final theme = ThemeService().themeData;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('OK')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 実際にレンダリングへ渡るTextSpanのfontFamilyを見る
    // （ThemeDataの値ではなく、ウィジェットツリーで解決された最終形）。
    TextStyle? resolved;
    for (final element in tester.allElements) {
      final widget = element.widget;
      if (widget is RichText) {
        final span = widget.text;
        if (span is TextSpan && span.toPlainText() == 'OK') {
          resolved = span.style;
        }
      }
    }
    expect(resolved, isNotNull, reason: 'ラベルのTextSpanが見つからない');
    expect(
      resolved!.fontFamily,
      'HakkouMincho',
      reason: 'FilledButtonのラベルが端末標準フォントで描かれている',
    );
    expect(resolved.fontFamilyFallback, isNotEmpty);
  });
}
