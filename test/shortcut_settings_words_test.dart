// ショートカットの画面の文を、行に入る語の途中で折らない（DISC228）。
//
// - 足すシートの題（「Ctrl+Z에 무엇을 할당하시겠습니까?」）と画面の上の説明の
//   段落は普通の`Text`だったので、Flutterがハングルのどの字の間でも行を変えて
//   いた（「무 / 엇을」「할당하시겠습 / 니까?」「도 / 구」）。題の中のキーの組は、
//   修飾キーの「+」の後でだけ折る決まり（DISC158）のまま。
// - 一覧の行は、キーの印が行の4割（最低120px）に入れば名前の前に置いていたが、
//   名前の欄に名前の語が入るかを見ていなかったので、英語320px・文字2倍で名前の
//   欄が細くなり「Re / do」と語の途中で折れていた。
//
// 7言語×320/360/412px×文字1.0/1.3/2.0で、一覧の行の名前・説明の段落・足す
// シートの題と選ぶ行の文が、行に入る語（韓国語の語・欧文の語。付いている括弧・
// 引用符ごと）を途中で折らない
// こと（一覧の行の名前は、キーの印を上に置いたときの名前の欄に入る語）、
// はみ出さないことを見る。1語が行より広い語は、決まりが所有者の判断待ち
// （DISC155）なので数えずに出しておく。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/screens/settings/shortcut_settings_screen.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

/// 描いた文から、幅の無い字（語結合子・幅の無い空白）を除き、改行しない
/// 空白を普通の空白にしたもの。
String _plain(String text) => text
    .replaceAll('⁠', '')
    .replaceAll('​', '')
    .replaceAll(' ', ' ')
    .replaceAll(' ', ' ');

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

  /// 既定の7つに足す割り当て（名前の長い操作と、長いキーの組）。
  final extra = [
    ShortcutBinding(
      id: 'sc_test_prev',
      label: 'test',
      keyId: LogicalKeyboardKey.arrowLeft.keyId,
      control: true,
      shift: true,
      alt: true,
      meta: true,
      command: ShortcutCommand.previousFrame,
    ),
    ShortcutBinding(
      id: 'sc_test_layer',
      label: 'test',
      keyId: LogicalKeyboardKey.keyL.keyId,
      alt: true,
      command: ShortcutCommand.toggleLayerPanel,
    ),
    ShortcutBinding(
      id: 'sc_test_play',
      label: 'test',
      keyId: LogicalKeyboardKey.space.keyId,
      shift: true,
      command: ShortcutCommand.playPause,
    ),
  ];

  /// 押すキー（修飾キー、キー）。
  final presses = [
    ([LogicalKeyboardKey.controlLeft], LogicalKeyboardKey.keyB),
    (
      [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ],
      LogicalKeyboardKey.arrowLeft,
    ),
  ];

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('shortcut screen texts keep their words ($tag)', (
      tester,
    ) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      SharedPreferences.setMockInitialValues({});
      final shortcuts = ShortcutService();
      await tester.runAsync(shortcuts.init);
      for (final binding in extra) {
        shortcuts.addBinding(binding);
      }
      final settings = SettingsService();
      await tester.runAsync(settings.init);
      final brushes = BrushService();
      await tester.runAsync(brushes.init);
      final rootKey = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShortcutService>.value(value: shortcuts),
            ChangeNotifierProvider<SettingsService>.value(value: settings),
            ChangeNotifierProvider<BrushService>.value(value: brushes),
          ],
          child: RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              locale: locale,
              theme: ThemeService().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ShortcutSettingsScreen(),
            ),
          ),
        ),
      );
      final names = {
        for (final binding in shortcuts.bindings)
          _plain(shortcutDisplayLabel(l10n, binding)),
      };
      final problems = <String>[];
      final tooWide = <String>{};
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());

      void checkWords(String at, RenderParagraph paragraph, {double? fit}) {
        final shown = _plain(
          paragraph.text.toPlainText(includeSemanticsLabels: false),
        );
        final broken = brokenWordUnits(paragraph, fitWidth: fit);
        for (final word in broken.fits) {
          problems.add('$at「$shown」: $word');
        }
        for (final word in broken.tooWide) {
          tooWide.add('$at「$shown」: $word');
        }
        for (final char in ParagraphLines(paragraph).charsOutsideWidth()) {
          problems.add('$at「$shown」runs past its line: $char');
        }
      }

      Future<void> shoot(String name) async {
        if (shots == null) return;
        await tester.runAsync(() async {
          final boundary =
              rootKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$shots/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
          image.dispose();
        });
      }

      try {
        // 一覧と説明の段落。
        for (final width in [320.0, 360.0, 412.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 760);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pumpAndSettle();
            final at = '${width.toInt()}px x$scale';
            checkWords(
              '$at hint',
              textParagraphsIn(find.text(l10n.shortcutSettingsHint)).single,
            );
            final list = find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first;
            final position = tester.state<ScrollableState>(list).position;
            for (var i = 0; i < 20 && position.pixels > 0; i++) {
              position.jumpTo(0);
              await tester.pump();
            }
            final seen = <String>{};
            var shot = false;
            while (true) {
              for (final tile
                  in find
                      .descendant(
                        of: find.byType(ListView),
                        matching: find.byType(ListTile),
                      )
                      .evaluate()
                      .toList()) {
                final tileFinder = find.byElementPredicate((e) => e == tile);
                final tileRect = tester.getRect(tileFinder);
                // キーの印を上に置いたときの名前の欄の幅（行の左右の余白
                // 16・24と、削除のボタン48＋間16を除いた幅）。
                final fullTitle = tileRect.width - 40 - 64;
                for (final paragraph in textParagraphsIn(tileFinder)) {
                  final shown = _plain(
                    paragraph.text.toPlainText(includeSemanticsLabels: false),
                  );
                  if (!names.contains(shown)) continue;
                  seen.add(shown);
                  final fit = paragraph.constraints.maxWidth > fullTitle
                      ? paragraph.constraints.maxWidth
                      : fullTitle;
                  checkWords('$at row', paragraph, fit: fit);
                }
              }
              if (!shot && scale == 2.0 && width != 412) {
                shot = true;
                await shoot('DISC228-list-${tag}_${width.toInt()}_x2');
              }
              if (position.pixels >= position.maxScrollExtent) break;
              position.jumpTo(
                (position.pixels + position.viewportDimension * 0.6).clamp(
                  0,
                  position.maxScrollExtent,
                ),
              );
              await tester.pump();
            }
            final missing = names.difference(seen);
            if (missing.isNotEmpty) {
              problems.add('$at: rows not checked: ${missing.join(' | ')}');
            }
          }
        }
        // 足すシートの題と、選ぶ行。
        for (final (modifiers, key) in presses) {
          tester.view.physicalSize = const Size(412, 760);
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.pumpAndSettle();
          await tester.tap(find.byType(FloatingActionButton));
          await tester.pumpAndSettle();
          for (final modifier in modifiers) {
            await tester.sendKeyDownEvent(modifier);
          }
          await tester.sendKeyDownEvent(key);
          await tester.pumpAndSettle();
          await tester.sendKeyUpEvent(key);
          for (final modifier in modifiers.reversed) {
            await tester.sendKeyUpEvent(modifier);
          }
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          expect(sheet, findsOneWidget, reason: '$key');
          for (final width in [320.0, 360.0, 412.0]) {
            for (final scale in [1.0, 1.3, 2.0]) {
              tester.view.physicalSize = Size(width, 760);
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              await tester.pumpAndSettle();
              final at = '${key.keyLabel} ${width.toInt()}px x$scale sheet';
              final paragraphs = textParagraphsIn(sheet).toList();
              if (paragraphs.length < 3) {
                problems.add('$at: ${paragraphs.length} texts in the sheet');
              }
              for (final paragraph in paragraphs) {
                checkWords(at, paragraph);
              }
              if (scale == 2.0 && width == 320) {
                await shoot(
                  'DISC228-sheet-${key.keyLabel.replaceAll(' ', '')}-'
                  '${tag}_320_x2',
                );
              }
            }
          }
          // シートを閉じる（何も割り当てない）。
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
        }
        for (final error in errors) {
          problems.add(error.split('\n').first);
        }
      } finally {
        FlutterError.onError = onError;
      }
      for (final word in tooWide) {
        debugPrint('$tag wider than the line (DISC155): $word');
      }
      for (final problem in problems) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
