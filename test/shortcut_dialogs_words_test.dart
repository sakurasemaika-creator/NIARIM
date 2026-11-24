// ショートカットを足す流れのダイアログ・シートの文を、行に入る語の途中で
// 折らない（DISC232）。
//
// キーを押すダイアログ（`_KeyCaptureDialog`）の題と説明、ツールを選ぶシート・
// 操作を選ぶシートの行、ブラシの太さのダイアログの題、すでに割り当てられて
// いるときの確かめのダイアログの本文は、普通の`Text`だったので、Flutterが
// ハングルのどの字の間でも行を変えていた（320/360pxの説明で「함 / 께」
// 「있습니 / 다）」「눌러주세 / 요」）。
//
// 7言語×320/360px×文字1.0/1.3/2.0で、それぞれの文が行に入る語（韓国語の語・
// 欧文の語。付いている括弧・引用符ごと）を途中で折らないこと、行からはみ
// 出さないことを見る。韓国語の語は、語の後ろに全角の開き括弧が続くとき
// （「눌러주세요（Ctrl・Shift・Alt」）は開き括弧の前で分けて数える（韓国語も
// 開き括弧の前では行を変えてよい。括弧の中まで1語として数えると、語より
// 広くなって「行より広い語」として数えられず、「눌러주세 / 요」を見逃す）。
// 確かめのダイアログの中のキーの組は、修飾キーの「+」の後でだけ折る
// （DISC158の決まり）。1語が行より広い語も失敗として
// 数える（所有者の判断、2026-11-22：行より広い1語は短い訳に替える）。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
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
    .replaceAll('\u2060', '')
    .replaceAll('\u200b', '')
    .replaceAll('\u00a0', ' ')
    .replaceAll('\u202f', ' ');

final RegExp _hangul = RegExp(r'[가-힣ᄀ-ᇿ㄰-㆏]');

/// 韓国語の語のうち、後ろに全角の開き括弧が続く語（括弧の前まで）が途中で
/// 折れている所。
List<String> _koreanWordsBeforeBrackets(RenderParagraph p) {
  final lines = ParagraphLines(p);
  final text = lines.visible;
  final out = <String>[];
  for (final token in RegExp(r'[^\s\u200b]+').allMatches(text)) {
    final word = token[0]!;
    final bracket = RegExp('[（「『【]').firstMatch(word);
    if (bracket == null || bracket.start == 0) continue;
    final head = word.substring(0, bracket.start);
    if (!_hangul.hasMatch(head)) continue;
    final start = token.start;
    final end = token.start + bracket.start;
    if (lines.breaksWithin(start, end).isEmpty) continue;
    final width = p
        .getBoxesForSelection(lines.sourceSelection(start, end))
        .fold<double>(0, (sum, box) => sum + box.right - box.left);
    if (width > p.constraints.maxWidth + 0.5) continue;
    out.add(
      '「$head」（${width.toStringAsFixed(0)}px）: ${lines.lines.join(' / ')}',
    );
  }
  return out;
}

/// キーの組[combo]が、修飾キーの「+」の後以外で折れている所。描いた文の
/// 幅の無い空白（折ってよい印）・改行しない空白は、元の文の字に戻して探す。
/// 文の中にキーの組が無ければnull。
List<String>? _comboBreaks(RenderParagraph p, String combo) {
  final lines = ParagraphLines(p);
  final text = lines.visible;
  // 幅の無い空白を除いた文と、その字の描いた文の中の位置。
  final plain = StringBuffer();
  final index = <int>[];
  for (var i = 0; i < text.length; i++) {
    if (text[i] == '\u200b') continue;
    plain.write(text[i] == '\u00a0' ? ' ' : text[i]);
    index.add(i);
  }
  final at = plain.toString().indexOf(combo);
  if (at < 0) return null;
  final out = <String>[];
  for (var k = at + 1; k < at + combo.length; k++) {
    if (lines.lineOf(index[k]) == lines.lineOf(index[k - 1])) continue;
    if (combo[k - 1] == '+' && combo[k] != '+') continue;
    out.add('「$combo」: ${lines.lines.join(' / ')}');
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET3_SHOTS'];
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

    testWidgets('shortcut add flow texts keep their words ($tag)', (
      tester,
    ) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
      tester.view.physicalSize = const Size(412, 760);
      tester.view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({});
      final shortcuts = ShortcutService();
      await tester.runAsync(shortcuts.init);
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
      await tester.pumpAndSettle();
      final problems = <String>{};
      final tooWide = <String>{};
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());

      // キーの組を含む文を見たか。
      var comboShown = false;

      void checkWords(String at, RenderParagraph paragraph, {String? combo}) {
        final shown = _plain(
          paragraph.text.toPlainText(includeSemanticsLabels: false),
        );
        final broken = brokenWordUnits(paragraph);
        for (final word in broken.fits) {
          problems.add('$at「$shown」: $word');
        }
        for (final word in broken.tooWide) {
          tooWide.add('$at「$shown」: $word');
        }
        for (final word in _koreanWordsBeforeBrackets(paragraph)) {
          problems.add('$at「$shown」: $word');
        }
        if (combo != null) {
          final breaks = _comboBreaks(paragraph, combo);
          if (breaks != null) comboShown = true;
          for (final word in breaks ?? const <String>[]) {
            problems.add('$at「$shown」: $word');
          }
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

      /// [scope]の中の文を、幅・文字の大きさごとに見る。
      Future<void> checkAll(
        String what,
        Finder Function() scope, {
        String? combo,
        int minTexts = 1,
      }) async {
        for (final width in [320.0, 360.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = Size(width, 760);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            await tester.pumpAndSettle();
            final at = '$what ${width.toInt()}px x$scale';
            final paragraphs = textParagraphsIn(scope()).toList();
            if (paragraphs.length < minTexts) {
              problems.add('$at: ${paragraphs.length} texts');
            }
            comboShown = false;
            for (final paragraph in paragraphs) {
              checkWords(at, paragraph, combo: combo);
            }
            if (combo != null && !comboShown) {
              problems.add('$at: 「$combo」 is not shown');
            }
            if (scale == 2.0) {
              await shoot('DISC232-$what-${tag}_${width.toInt()}_x2');
            }
            for (final error in errors) {
              problems.add('$at ${error.split('\n').first}');
            }
            errors.clear();
          }
        }
        tester.view.physicalSize = const Size(412, 760);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pumpAndSettle();
      }

      Future<void> press(
        List<LogicalKeyboardKey> modifiers,
        LogicalKeyboardKey key,
      ) async {
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
      }

      try {
        // キーを押すダイアログ。
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await checkAll('capture', () => find.byType(AlertDialog), minTexts: 3);
        // ツールを選ぶシートと、ブラシの太さのダイアログ。
        await press([LogicalKeyboardKey.controlLeft], LogicalKeyboardKey.keyB);
        await tester.tap(find.text(l10n.shortcutActionTypeTool));
        await tester.pumpAndSettle();
        await checkAll(
          'tools',
          () => find.byType(BottomSheet),
          minTexts: brushes.brushes.length + 3,
        );
        final brush = brushes.brushes.first;
        await tester.tap(
          find.descendant(
            of: find.byType(BottomSheet),
            // 組み込みのブラシはシートでも表示の言語の名前。
            matching: find.text(shortcutBrushName(l10n, brush)),
          ),
        );
        await tester.pumpAndSettle();
        await checkAll('size', () => find.byType(AlertDialog), minTexts: 3);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.commonCancel),
          ),
        );
        await tester.pumpAndSettle();
        // 操作を選ぶシートと、すでに割り当てられているときの確かめ（Ctrl+Zは
        // 最初から取り消しに割り当ててある）。
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await press([
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.shiftLeft,
          LogicalKeyboardKey.altLeft,
          LogicalKeyboardKey.metaLeft,
        ], LogicalKeyboardKey.arrowLeft);
        await tester.tap(find.text(l10n.shortcutActionTypeCommand));
        await tester.pumpAndSettle();
        await checkAll(
          'commands',
          () => find.byType(BottomSheet),
          minTexts: shortcutCommandLabels(l10n).length,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(l10n.shortcutCommandCopy),
          ),
        );
        await tester.pumpAndSettle();
        // 2つ目のCtrl+Shift+Alt+Meta+Arrow Leftを足して、確かめを出す。
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await press([
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.shiftLeft,
          LogicalKeyboardKey.altLeft,
          LogicalKeyboardKey.metaLeft,
        ], LogicalKeyboardKey.arrowLeft);
        await tester.tap(find.text(l10n.shortcutActionTypeCommand));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(l10n.shortcutCommandPreviousFrame),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await checkAll(
          'conflict',
          () => find.byType(AlertDialog),
          combo: 'Ctrl+Shift+Alt+Meta+Arrow Left',
          minTexts: 4,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.commonCancel),
          ),
        );
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = onError;
      }
      for (final word in tooWide) {
        problems.add('$tag wider than the line (DISC155): $word');
      }
      for (final problem in problems) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
