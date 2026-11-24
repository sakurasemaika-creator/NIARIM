// ヘルプの「活用Tips」で、カテゴリの見出しの行（カテゴリ名。以前はアイコン＋
// カテゴリ名）が横にはみ出さない（DISC160）。
//
// 見出しの行はアイコンとカテゴリ名を幅の決まらない`Row`に並べていたので、
// カテゴリ名が1行で画面に入らない言語・文字の大きさ（仏語360px・文字2倍の
// 「Astuces pour travailler plus vite」等）では、名前が折り返されずに行が
// 157pxはみ出していた（アプリのエラーの記録に「A RenderFlex overflowed by
// 157 pixels on the right.」）。
//
// 7言語×320/360/412px×文字1.0/1.3/2.0で、すべてのカテゴリの見出しが
// はみ出さず、カテゴリ名を最後まで出し（省略しない）、行に入る語を途中で
// 折らない（韓国語の語も）ことを見張る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/tips/tips_screen.dart';
import 'package:niarim/services/theme_service.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/word_breaks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET1_SHOTS'];
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
    final categories = [
      l10n.tipsCategoryVideo,
      l10n.tipsCategoryEfficiency,
      l10n.tipsCategoryDrawing,
      l10n.tipsCategoryEffects,
      l10n.tipsCategoryExport,
    ];

    testWidgets('tips category headers fit the line ($tag)', (tester) async {
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
            final list = find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first;
            for (final (index, title) in categories.indexed) {
              final header = find.text(title, skipOffstage: false);
              await tester.scrollUntilVisible(
                header,
                120,
                scrollable: list,
                maxScrolls: 400,
              );
              await tester.pumpAndSettle();
              final paragraph = textParagraphsIn(header).single;
              // 名前は最後まで出す（省略しない・はみ出さない）。
              if (paragraph.didExceedMaxLines) {
                problems.add('$at「$title」is cut short');
              }
              // 見出しの行（名前を置く余白つきの行。分類の印は付けなくなった）。
              final row = tester.getRect(
                find.ancestor(of: header, matching: find.byType(Padding)).first,
              );
              final text = tester.getRect(header);
              if (text.right > row.right + 0.5 || row.right > width + 0.5) {
                problems.add(
                  '$at「$title」runs past the line '
                  '(text ${text.right.toStringAsFixed(0)}px, '
                  'row ${row.right.toStringAsFixed(0)}px)',
                );
              }
              for (final broken in wordsBrokenThatFit(paragraph)) {
                problems.add('$at「$title」: $broken');
              }
              if (shots != null && scale == 2.0 && width != 412 && index == 1) {
                await tester.runAsync(() async {
                  final boundary =
                      rootKey.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary;
                  final image = await boundary.toImage(pixelRatio: 1);
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File(
                    '$shots/DISC160-${tag}_${width.toInt()}_x2.png',
                  ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                  image.dispose();
                });
              }
            }
            await tester.drag(list, const Offset(0, 20000));
            await tester.pumpAndSettle();
            for (final error in errors) {
              problems.add('$at: ${error.split('\n').first}');
            }
            errors.clear();
          }
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final problem in problems.take(12)) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
