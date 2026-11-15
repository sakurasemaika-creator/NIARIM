// ショートカットを足すシートの題（「Ctrl+Shift+Alt++ に何を割り当てますか？」）で、
// キーの組を修飾キーの「+」の後でだけ折り返す（DISC158）。
//
// 一覧のキーのチップ（DISC132）は修飾キーの「+」の後だけで折り返すが、シートの
// 題の文の中のキーの組は普通の文として折り返していたので、キーが「+」のとき
// 「要为Ctrl+Shift+Alt+ / +分配什么？」と、キーの「+」が行の頭に来た（最後の
// 修飾キーのつなぎの「+」か、キーの「+」か見分けられない）。キーの名前の
// 空白（「Arrow Left」）でも折れうる。
//
// 本物のショートカットの画面で「追加」→キーを押す（Ctrl+Shift+Alt++、
// Ctrl+Shift+Alt+Meta+Arrow Left、Ctrl+Shift+Alt+Meta+Numpad Add）と開くシートの
// 題を、7言語×320/360/412px×文字1.0/1.3/2.0で並べ、キーの組の中で行が変わるのは
// 修飾キーの「+」の後だけ（キーが「+」なら最後の修飾キーの「+」の後でも変えない）
// であること、題の行がはみ出さないことを見張る。
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

const _modifierNames = ['Ctrl', 'Shift', 'Alt', 'Meta'];

/// [combo]（[_modifierNames]の順に「+」でつないだ修飾キーとキーの名前）の中で、
/// 行を変えてよい所（[combo]の中の位置）。
Set<int> _allowedBreaks(String combo) {
  var at = 0;
  final allowed = <int>{};
  for (final name in _modifierNames) {
    if (!combo.startsWith('$name+', at)) continue;
    at += name.length + 1;
    allowed.add(at);
  }
  // キーが「+」なら、最後の修飾キーの「+」の後でも変えない。
  if (combo.substring(at) == '+') allowed.remove(at);
  allowed.remove(combo.length);
  return allowed;
}

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

  /// 押すキー（修飾キー、キー）と、題に出るキーの組。
  final presses = [
    (
      [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.altLeft,
      ],
      LogicalKeyboardKey.add,
      'Ctrl+Shift+Alt++',
    ),
    (
      [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ],
      LogicalKeyboardKey.arrowLeft,
      'Ctrl+Shift+Alt+Meta+Arrow Left',
    ),
    (
      [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ],
      LogicalKeyboardKey.numpadAdd,
      'Ctrl+Shift+Alt+Meta+Numpad Add',
    ),
  ];

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('the key combo in the add sheet title breaks only after a '
        'modifier\'s "+" ($tag)', (tester) async {
      if (!fontsLoaded) {
        await loadAppFonts(tester);
        fontsLoaded = true;
      }
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
      final problems = <String>[];
      final errors = <String>[];
      final onError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        for (final (modifiers, key, combo) in presses) {
          tester.view.physicalSize = const Size(412, 760);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          await tester.pumpAndSettle();
          await tester.tap(find.byType(FloatingActionButton));
          await tester.pumpAndSettle();
          for (final modifier in modifiers) {
            await tester.sendKeyDownEvent(modifier);
          }
          // 「+」のキーは、テストの対応表に物理キーが無いので「=」の位置を渡す
          // （USの配列でShiftと押すと「+」）。
          final physical = key == LogicalKeyboardKey.add
              ? PhysicalKeyboardKey.equal
              : null;
          await tester.sendKeyDownEvent(key, physicalKey: physical);
          await tester.pumpAndSettle();
          await tester.sendKeyUpEvent(key, physicalKey: physical);
          for (final modifier in modifiers.reversed) {
            await tester.sendKeyUpEvent(modifier);
          }
          await tester.pumpAndSettle();
          final title = l10n
              .shortcutChooseActionTitle(combo)
              .replaceAll('\u00A0', ' ');
          final sheet = find.byType(BottomSheet);
          expect(sheet, findsOneWidget, reason: combo);

          for (final width in [320.0, 360.0, 412.0]) {
            for (final scale in [1.0, 1.3, 2.0]) {
              tester.view.physicalSize = Size(width, 760);
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              await tester.pumpAndSettle();
              final at = '$combo ${width.toInt()}px x$scale';
              RenderParagraph? paragraph;
              for (final element
                  in find
                      .descendant(of: sheet, matching: find.byType(RichText))
                      .evaluate()) {
                final p = element.renderObject! as RenderParagraph;
                final plain = p.text
                    .toPlainText(includeSemanticsLabels: false)
                    .replaceAll('​', '')
                    .replaceAll('⁠', '')
                    .replaceAll(' ', ' ');
                if (plain == title) paragraph = p;
              }
              if (paragraph == null) {
                problems.add('$at: the title「$title」is not in the sheet');
                continue;
              }
              final lines = ParagraphLines(paragraph);
              // 幅の無い空白を除き、改行しない空白を普通の空白にした文と、
              // その字が描いた段落の何行目か。
              final plain = StringBuffer();
              final lineOf = <int?>[];
              for (var i = 0; i < lines.visible.length; i++) {
                final char = lines.visible[i];
                if (char == '​') continue;
                plain.write(char == ' ' ? ' ' : char);
                lineOf.add(lines.lineOf(i));
              }
              final start = plain.toString().indexOf(combo);
              if (start < 0) {
                problems.add('$at: 「$combo」is not in「$plain」');
                continue;
              }
              final allowed = _allowedBreaks(combo);
              for (var k = 1; k < combo.length; k++) {
                final before = lineOf[start + k - 1];
                final after = lineOf[start + k];
                if (before == null || after == null || before == after) {
                  continue;
                }
                if (!allowed.contains(k)) {
                  problems.add(
                    '$at: breaks inside the key combo after '
                    '「${combo.substring(0, k)}」: ${lines.lines.join(' / ')}',
                  );
                }
              }
              if (paragraph.size.width >
                  tester.getSize(sheet).width - 2 * 12 + 0.5) {
                problems.add('$at: the title is wider than the sheet');
              }
              if (shots != null &&
                  scale == 2.0 &&
                  width == 320 &&
                  combo == presses.first.$3) {
                await tester.runAsync(() async {
                  final boundary =
                      rootKey.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary;
                  final image = await boundary.toImage(pixelRatio: 1);
                  final data = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File(
                    '$shots/DISC158-${tag}_320_x2.png',
                  ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                  image.dispose();
                });
              }
            }
          }
          for (final error in errors) {
            problems.add('$combo: ${error.split('\n').first}');
          }
          errors.clear();
          // シートを閉じる（何も割り当てない）。
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          expect(sheet, findsNothing);
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
