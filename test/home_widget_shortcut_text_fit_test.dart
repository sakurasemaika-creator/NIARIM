import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/home_widget_refresh.dart';
import 'package:niarim/services/home_widget_service.dart';
import 'package:niarim/services/shortcut_widget_renderer.dart';

import 'helpers/load_app_fonts.dart';

/// 「作品をつくる」「作品広場」のホーム画面ウィジェットの文言が、どの言語・
/// どの形（正方形・横長・縦長）でも省略記号で切れず、語の途中で折れず、
/// タイルの中に収まることを見張る。
///
/// 以前は作品広場の題を1行・説明を1行に限って「…」で切っていて、
/// スペイン語「Plaza de O…」・フランス語「Place des …」・英語の説明
/// 「Browse posted …」になり、韓国語の「애니메이션 만들기」は「만들｜기」と
/// 語の途中で折れていた。焼いた画像は`build/home-widget-shortcut-fit/`へ
/// 保存する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const locales = [
    Locale('ja'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];
  final cjk = RegExp(r'[぀-ヿ㐀-鿿豈-﫿]');

  testWidgets('どの言語・形でも文言が切れず、語の途中で折れず、タイルに収まる', (tester) async {
    await loadAppFonts(tester);
    final out = Directory('build/home-widget-shortcut-fit')
      ..createSync(recursive: true);

    for (final locale in locales) {
      final l10n = lookupAppLocalizations(locale);
      final tag = locale.toLanguageTag();
      for (final kind in const [HomeWidgetKind.create, HomeWidgetKind.plaza]) {
        for (final shape in ShortcutWidgetShape.values) {
          final where = '$tag ${kind.name} ${shape.name}';
          final fit = ShortcutWidgetFit.of(
            label: shortcutWidgetLabel(l10n, kind),
            subLabel: shortcutWidgetSubLabel(l10n, kind),
            locale: locale,
            shape: shape,
          );
          final width = ShortcutWidgetFit.textWidthFor(shape, fit.iconSize);
          var textHeight = 0.0;
          for (final (text, size, bold) in [
            (fit.label, fit.labelSize, true),
            if (fit.subLabel != null) (fit.subLabel!, fit.subLabelSize, false),
          ]) {
            final painter = TextPainter(
              text: TextSpan(
                text: text,
                style: shortcutWidgetTextStyle(
                  locale: locale,
                  color: Colors.white,
                  size: size,
                  bold: bold,
                ),
              ),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
            )..layout(maxWidth: width);
            textHeight += painter.height;
            expect(painter.didExceedMaxLines, isFalse, reason: where);
            // 行の変わり目は空白の所か、中国語・日本語の字の間だけ。
            final lines = painter.computeLineMetrics();
            var offset = 0;
            for (var i = 0; i < lines.length - 1; i++) {
              final boundary = painter.getLineBoundary(
                TextPosition(offset: offset),
              );
              final end = boundary.end;
              final before = text.substring(0, end).trimRight();
              final after = text.substring(end).trimLeft();
              final lastChar = before.characters.last;
              final nextChar = after.characters.first;
              final atSpace =
                  end < text.length &&
                  (text[end - 1].trim().isEmpty || text[end].trim().isEmpty);
              final betweenCjk =
                  cjk.hasMatch(lastChar) || cjk.hasMatch(nextChar);
              expect(
                atSpace || betweenCjk,
                isTrue,
                reason: '$where: 「$before｜$after」で語の途中で折れた',
              );
              offset = end;
            }
            painter.dispose();
          }
          final tile = ShortcutWidgetDesign.tileSizeOf(shape);
          final room =
              tile.height - ShortcutWidgetDesign.verticalPadding * 2 + 0.01;
          final needed = ShortcutWidgetFit.sideBySide(shape)
              ? (fit.iconSize > textHeight ? fit.iconSize : textHeight)
              : fit.iconSize + ShortcutWidgetDesign.gapAfterIcon + textHeight;
          expect(needed, lessThanOrEqualTo(room), reason: where);
          // 入る言語では元の意匠（アイコン60・文字18）のまま。
          if (tag == 'ja') {
            expect(fit.iconSize, ShortcutWidgetDesign.iconSize, reason: where);
            expect(fit.labelSize, ShortcutWidgetDesign.labelSize);
          }

          final bytes = await tester.runAsync(() async {
            final image = await renderShortcutWidgetImage(
              icon: shortcutWidgetIcon(kind),
              label: shortcutWidgetLabel(l10n, kind),
              subLabel: shortcutWidgetSubLabel(l10n, kind),
              locale: locale,
              colors: const [Color(0xFFFF5C7A), Color(0xFFFF9AAE)],
              foreground: Colors.white,
              shape: shape,
              scale: 2,
            );
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            return data!.buffer.asUint8List();
          });
          await tester.runAsync(
            () => File(
              '${out.path}/$tag-${kind.name}-${shape.name}.png',
            ).writeAsBytes(bytes!),
          );
        }
      }
    }
  });
}
