import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
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

    for (final button in const [
      'filledButtonTheme', 'elevatedButtonTheme',
      'outlinedButtonTheme', 'textButtonTheme',
    ]) {
      expect(targets[button]?.fontFamily, 'Kuramubon',
        reason: '$button must use the specified action-label font');
    }

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

  // 書体の決まり（2026-10-23 ユーザー指定）：見出し・タイトル・ボタンは
  // くらむぼん、説明文・本文・エラー文・注釈は白光明朝。実際に描かれる
  // TextSpanの書体で確かめる（ThemeDataの値ではなく、ウィジェットツリーで
  // 解決された最終形）。
  testWidgets('ボタンはくらむぼん、SnackBarとダイアログの本文は白光明朝', (tester) async {
    final theme = ThemeService().themeData;
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return Center(
                child: Wrap(
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('塗り')),
                    TextButton(onPressed: () {}, child: const Text('文字')),
                    OutlinedButton(onPressed: () {}, child: const Text('枠')),
                    ElevatedButton(onPressed: () {}, child: const Text('浮き')),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    TextStyle? spanStyle(String text) {
      for (final element in tester.allElements) {
        final widget = element.widget;
        if (widget is RichText) {
          final span = widget.text;
          if (span is TextSpan && span.toPlainText() == text) {
            return span.style;
          }
        }
      }
      return null;
    }

    for (final label in ['塗り', '文字', '枠', '浮き']) {
      final style = spanStyle(label);
      expect(style, isNotNull, reason: '$labelのラベルが見つからない');
      expect(style!.fontFamily, 'Kuramubon', reason: '$labelのボタン');
      // 見出し用の代替列（明朝を含まない）。
      expect(style.fontFamilyFallback, kHeadingFontFallback, reason: label);
    }

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('ゴミ箱へ移動しました'),
        action: SnackBarAction(label: '元に戻す', onPressed: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(spanStyle('ゴミ箱へ移動しました')?.fontFamily, 'HakkouMincho');
    // SnackBarの操作ボタンは小さく、くらむぼんの太字だと潰れるので
    // 白光明朝のまま（ユーザー指定）。
    expect(spanStyle('元に戻す')?.fontFamily, 'HakkouMincho');

    showDialog<void>(
      context: ctx,
      builder: (_) =>
          const AlertDialog(title: Text('ダイアログの題'), content: Text('ダイアログの説明文')),
    );
    await tester.pumpAndSettle();
    expect(spanStyle('ダイアログの題')?.fontFamily, 'Kuramubon');
    expect(spanStyle('ダイアログの説明文')?.fontFamily, 'HakkouMincho');
  });
}
