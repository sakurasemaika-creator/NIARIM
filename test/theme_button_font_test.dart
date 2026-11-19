import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/theme_service.dart';

import 'helpers/load_app_fonts.dart';

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
      // 文字つきの浮かぶボタン（FloatingActionButton.extended）のラベル。
      // 指定しないとMaterialの既定（labelLarge＝白光明朝）になる（DISC224）。
      'floatingActionButtonTheme.extendedTextStyle':
          theme.floatingActionButtonTheme.extendedTextStyle,
    };

    for (final button in const [
      'filledButtonTheme',
      'elevatedButtonTheme',
      'outlinedButtonTheme',
      'textButtonTheme',
      'floatingActionButtonTheme.extendedTextStyle',
    ]) {
      expect(
        targets[button]?.fontFamily,
        'Kuramubon',
        reason: '$button must use the specified action-label font',
      );
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
                    FilledButton.tonal(
                      onPressed: () {},
                      child: const Text('淡い塗り'),
                    ),
                    TextButton(onPressed: () {}, child: const Text('文字')),
                    OutlinedButton(onPressed: () {}, child: const Text('枠')),
                    ElevatedButton(onPressed: () {}, child: const Text('浮き')),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('文字つきの浮き'),
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

    for (final label in ['塗り', '淡い塗り', '文字', '枠', '浮き', '文字つきの浮き']) {
      final style = spanStyle(label);
      expect(style, isNotNull, reason: '$labelのラベルが見つからない');
      expect(style!.fontFamily, 'Kuramubon', reason: '$labelのボタン');
      // 見出し用の代替列（明朝を含まない）。
      expect(style.fontFamilyFallback, kHeadingFontFallback, reason: label);
    }

    expect(spanStyle('塗り')?.color, theme.colorScheme.onPrimary);
    expect(spanStyle('淡い塗り')?.color, theme.colorScheme.onSecondaryContainer);

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

  test('outlined/text action buttons explicitly use the current accent', () {
    final theme = ThemeService().themeData;
    final accent = theme.colorScheme.primary;
    expect(
      theme.outlinedButtonTheme.style?.foregroundColor?.resolve(
        <WidgetState>{},
      ),
      accent,
    );
    expect(
      theme.textButtonTheme.style?.foregroundColor?.resolve(<WidgetState>{}),
      accent,
    );
  });

  // 文字つきの浮かぶボタン（「Ajouter」「追加」「新增」）のラベルも、ほかの
  // ボタンと同じくくらむぼん（DISC224）。テーマに extendedTextStyle が無く、
  // Materialの既定（labelLarge＝本文の書体の白光明朝。中国語は Noto Serif SC）
  // で描かれていた。言語ごとのテーマ（themeDataFor）で本物のボタンを描き、
  // ラベルの書体・代替の列と、ボタンの色・高さ・形が変わらないことを見る。
  final shots = Platform.environment['NIARIM_SET2_SHOTS'];
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    testWidgets('extended floating action button labels use the button font '
        '($tag)', (tester) async {
      await loadAppFonts(tester);
      tester.view.physicalSize = const Size(360, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final l10n = lookupAppLocalizations(locale);
      final theme = ThemeService().themeDataFor(locale);
      final rootKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: rootKey,
          child: MaterialApp(
            locale: locale,
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: const SizedBox.expand(),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: Text(l10n.commonAdd),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = tester.widget<RichText>(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == l10n.commonAdd,
          ),
        ),
      );
      final style = label.text.style!;
      final problems = <String>[
        if (style.fontFamily != headingFontFamilyFor(locale))
          '「${l10n.commonAdd}」is drawn in ${style.fontFamily}',
        if (!listEquals(style.fontFamilyFallback, headingFontFallbackFor(locale)))
          '「${l10n.commonAdd}」falls back to ${style.fontFamilyFallback}',
        // ラベルの色・大きさはボタンの決まりのまま（色は前景色、大きさは
        // labelLarge と同じ）。
        if (style.color != theme.colorScheme.onPrimary)
          'label colour ${style.color} is not onPrimary',
        if (style.fontSize != theme.textTheme.labelLarge!.fontSize)
          'label size ${style.fontSize} is not labelLarge',
      ];
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(FloatingActionButton),
              matching: find.byType(Material),
            )
            .first,
      );
      if (material.color != theme.colorScheme.primary) {
        problems.add('button colour ${material.color} is not primary');
      }
      if (material.elevation != 0) {
        problems.add('button elevation ${material.elevation}');
      }
      final size = tester.getSize(find.byType(FloatingActionButton));
      if (size.height != 56) problems.add('button height ${size.height}');
      debugPrint(
        '$tag「${l10n.commonAdd}」 ${style.fontFamily} '
        '${size.width.toStringAsFixed(1)}x${size.height}',
      );
      if (shots != null) {
        await tester.runAsync(() async {
          final boundary =
              rootKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$shots/DISC224-$tag.png',
          ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
          image.dispose();
        });
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }
}
