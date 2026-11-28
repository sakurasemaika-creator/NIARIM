// 「テーマ・外観」の上部バーで、復旧ボタン（読めないテーマのときだけ出る固定色の
// ボタン）が「？」（ヘルプ）に重ならない。
//
// 復旧ボタンを「？」のすぐ右に間を取らずに並べていたので、復旧ボタンの白黒の
// 輪が「？」の押せる所に接し、重なって見えた（利用者の動きでの確認）。
//
// 7言語×320〜430pxとPCの幅×文字1.0/2.0で、「？」と復旧ボタンの間が8px以上
// 空き、どちらも画面と上部バーの中にあり、画面名（出ているとき）とも重ならない
// ことを見張る。復旧ボタンの色は変えない（固定色のまま）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/screens/settings/theme_settings_screen.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/fit_or_hide_title.dart';
import 'package:niarim/widgets/help_button.dart';
import 'package:niarim/widgets/theme_rescue_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 文字も背景も同じ色＝読めないテーマ（復旧ボタンが出る）。
const _unreadable = AppThemePreset(
  id: 'unreadable_spacing_test',
  name: 'unreadable',
  accentColor: Color(0xFF336699),
  textColor: Color(0xFF336699),
  buttonTextColor: Color(0xFF336699),
  menuTextColor: Color(0xFF336699),
  selectionTextColor: Color(0xFF336699),
  panelBgColor: Color(0xFF336699),
  menuBgColor: Color(0xFF336699),
  selectionColor: Color(0xFF336699),
  updateMarkColor: Color(0xFF336699),
);

void main() {
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    testWidgets('the rescue button keeps clear of the help button ($tag)', (
      tester,
    ) async {
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final dir = Directory.systemTemp.createTempSync('niarim_rescue_bar_');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(
          providers: providers!,
          child: Builder(
            builder: (context) => MaterialApp(
              locale: locale,
              theme: context.watch<ThemeService>().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ThemeSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .element(find.byType(ThemeSettingsScreen))
          .read<ThemeService>()
          .restoreCurrent(_unreadable);
      await tester.pumpAndSettle();

      final problems = <String>[];
      for (final width in [320.0, 360.0, 390.0, 412.0, 430.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 780);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpAndSettle();
          final at = '${width.toInt()}px x$scale';
          final error = tester.takeException();
          if (error != null) problems.add('$at: $error');
          // 画面の見本の中にも上部バーがあるので、「？」の上部バー。
          final bar = tester.getRect(
            find.ancestor(
              of: find.byType(HelpButton),
              matching: find.byType(AppBar),
            ),
          );
          final help = tester.getRect(find.byType(HelpButton));
          final rescue = tester.getRect(find.byType(ThemeRescueButton));
          if (rescue.left - help.right < 8 && help.left - rescue.right < 8) {
            problems.add(
              '$at: the rescue button $rescue is not 8px clear of the help '
              'button $help',
            );
          }
          for (final (name, rect) in [('help', help), ('rescue', rescue)]) {
            if (rect.left < 0 || rect.right > width) {
              problems.add('$at: the $name button $rect leaves the screen');
            }
            if (rect.top < bar.top || rect.bottom > bar.bottom) {
              problems.add('$at: the $name button $rect leaves the bar $bar');
            }
          }
          final title = find.descendant(
            of: find.byType(FitOrHideTitle),
            matching: find.byType(RichText),
          );
          for (final element in title.evaluate()) {
            final rect = tester.getRect(find.byWidget(element.widget));
            if (rect.overlaps(help) || rect.overlaps(rescue)) {
              problems.add('$at: the title $rect runs under the buttons');
            }
          }
        }
      }
      for (final problem in problems.take(12)) {
        debugPrint('$tag $problem');
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
