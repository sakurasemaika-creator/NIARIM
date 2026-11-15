// ヘルプの「活用Tips」の検索欄のヒントを「…」で切らずに全部出す（DISC226）。
//
// 検索欄は1行の`TextField`で、`InputDecoration.hintMaxLines`が無いとヒントも
// 1行に限られ、入らない分が省略記号で切れていた（仏語320px・文字1.3倍から
// 「Rechercher une a…」、英語・西語・日本語も320/360px・文字2倍で）。フォント
// 管理の検索欄・保存のダイアログのメモの欄（DISC192）と同じく、入らない
// ヒントは行を増やして全部出す。
//
// 7言語×320/360/412px×文字1.0/1.3/2.0で、ヒントが省略されないこと、行に入る
// 語を途中で折らないこと、欄がはみ出さないことと、ヒントを全部出しても打った
// 字で検索できることを見る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/tips/tips_screen.dart';
import 'package:niarim/services/theme_service.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET2_SHOTS'];
  var fontsLoaded = false;

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('the tips search hint is shown in full ($tag)', (tester) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      final rootKey = GlobalKey();
      final problems = <String>[];
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        await tester.pumpWidget(
          RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              locale: locale,
              theme: ThemeService().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const TipsScreen(),
            ),
          ),
        );
        for (final width in [320.0, 360.0, 412.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 740);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pumpAndSettle();
            final at = '${width.toInt()}px x$scale';
            final hint = textParagraphsIn(
              find.descendant(
                of: find.byType(InputDecorator),
                matching: find.text(l10n.tipsSearchHint),
              ),
            ).single;
            if (hint.didExceedMaxLines) {
              problems.add(
                '$at: the hint is cut: '
                '${ParagraphLines(hint).lines.join(' / ')}',
              );
            }
            for (final broken in wordsBrokenThatFit(hint)) {
              problems.add('$at hint: $broken');
            }
            final field = tester.getRect(find.byType(TextField));
            if (field.right > width + 0.5) {
              problems.add('$at: the field runs past the screen');
            }
            for (final error in errors) {
              problems.add('$at: ${error.split('\n').first}');
            }
            errors.clear();
            if (shots != null && scale == 2.0 && width != 412) {
              await tester.runAsync(() async {
                final boundary =
                    rootKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$shots/DISC226-${tag}_${width.toInt()}_x2.png',
                ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                image.dispose();
              });
            }
          }
        }
        // ヒントを全部出しても、欄は今までどおり打った字で探せる。
        final first = allTipEntries(l10n).first.$1;
        await tester.enterText(find.byType(TextField), first);
        await tester.pumpAndSettle();
        if (find
            .descendant(of: find.byType(ListView), matching: find.text(first))
            .evaluate()
            .isEmpty) {
          problems.add('typing「$first」does not find that tip');
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final problem in problems.take(20)) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
