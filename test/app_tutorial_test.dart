import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/help/help_screen.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/first_use_tooltip_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:niarim/widgets/app_tutorial.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// 使い方（図つきの数ページ）：初回起動で出て、スキップ・最後の
/// 「はじめる」・戻る操作のどれで閉じても次からは出ない。ホームのメニュー
/// （ヘルプ・活用Tipsの並び）とヘルプから見直せ、設定から機能の説明
/// （吹き出し）をもう一度出せる。どの言語・
/// 文字の大きさ・画面の形でも、ボタンが画面に収まり手順を読み切れる。
void main() {
  final captureRoot = Platform.environment['NIARIM_TUTORIAL_CAPTURE'];

  Future<void> openApp(
    WidgetTester tester, {
    required bool firstLaunch,
    String route = '/home',
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    SharedPreferences.setMockInitialValues({
      'first_launch': firstLaunch,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('app-tutorial-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go(route);
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pumpAndSettle();
  }

  final ja = lookupAppLocalizations(const Locale('ja'));

  testWidgets('first launch: skipping closes the guide for good', (
    tester,
  ) async {
    await openApp(tester, firstLaunch: true);
    expect(find.byType(AppTutorial), findsOneWidget);
    expect(find.text(ja.tutorialPage1Title), findsOneWidget);
    expect(find.text(ja.homeFirstLaunchMessage), findsOneWidget);
    await tester.tap(find.byKey(const Key('tutorialSkip')));
    await tester.pumpAndSettle();
    expect(find.byType(AppTutorial), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getBool('first_launch'),
      isFalse,
    );
    appRouter.go('/');
    await tester.pumpAndSettle();
    appRouter.go('/home');
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(AppTutorial), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('first launch: the back button also closes it for good', (
    tester,
  ) async {
    await openApp(tester, firstLaunch: true);
    expect(find.byType(AppTutorial), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppTutorial), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool('first_launch'),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pages turn with Next and by swiping, and announce the page', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openApp(tester, firstLaunch: true);
    final titles = [
      ja.tutorialPage1Title,
      ja.tutorialPage2Title,
      ja.tutorialPage3Title,
      ja.tutorialPage4Title,
      ja.tutorialPage5Title,
      ja.tutorialPage6Title,
    ];
    for (var i = 0; i < titles.length; i++) {
      expect(find.text(titles[i]), findsOneWidget, reason: 'page ${i + 1}');
      expect(
        find.bySemanticsLabel(ja.tutorialPageIndicator(i + 1, titles.length)),
        findsOneWidget,
      );
      final last = i == titles.length - 1;
      expect(
        find.byKey(const Key('tutorialSkip')),
        findsNWidgets(last ? 0 : 1),
      );
      expect(
        find.byKey(const Key('tutorialStart')),
        findsNWidgets(last ? 1 : 0),
      );
      if (last) break;
      if (i.isEven) {
        await tester.tap(find.byKey(const Key('tutorialNext')));
      } else {
        await tester.fling(
          find.byKey(const Key('tutorialPages')),
          const Offset(-300, 0),
          1000,
        );
      }
      await tester.pumpAndSettle();
    }
    // 戻る向きにもめくれる。
    await tester.fling(
      find.byKey(const Key('tutorialPages')),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text(titles[4]), findsOneWidget);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the home menu reopens the guide next to Help and Tips', (
    tester,
  ) async {
    await openApp(tester, firstLaunch: false);
    // メニューは右上のボタンから開く。
    await tester.tap(find.byKey(const Key('homeMenuButton')));
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('homeDrawerTutorial'));
    expect(entry, findsOneWidget);
    expect(
      find.descendant(of: entry, matching: find.text(ja.homeDrawerTutorial)),
      findsOneWidget,
    );
    // ヘルプ・活用Tipsのすぐ上に並ぶ。
    final help = tester.getRect(find.text(ja.homeDrawerHelp));
    final tipsRow = tester.getRect(find.text(ja.homeDrawerTips));
    expect(tester.getRect(entry).bottom, lessThanOrEqualTo(help.top + 1));
    expect(help.bottom, lessThanOrEqualTo(tipsRow.top + 1));
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(AppTutorial), findsOneWidget);
    await tester.tap(find.byKey(const Key('tutorialSkip')));
    await tester.pumpAndSettle();
    expect(find.byType(AppTutorial), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings bring back the feature tips', (tester) async {
    await openApp(tester, firstLaunch: false, route: '/settings');
    final tips = tester
        .element(find.byType(Scaffold).first)
        .read<FirstUseTooltipService>();
    expect(tips.hasSeen(kAllFirstUseTooltipKeys.first), isTrue);
    // 使い方の入口はホームのメニューにあり、設定には置かない。
    expect(find.text(ja.homeDrawerTutorial), findsNothing);

    final tile = find.text(ja.settingsTipsResetTitle);
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    for (final key in kAllFirstUseTooltipKeys) {
      expect(tips.hasSeen(key), isFalse, reason: key);
    }
    expect(find.text(ja.settingsTipsResetDone), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getStringList(
        firstUseTooltipsSeenKey,
      ),
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('help opens the guide unless something is being looked up', (
    tester,
  ) async {
    await openApp(tester, firstLaunch: false, route: '/help');
    final entry = find.byKey(const Key('helpTutorialButton'));
    expect(entry, findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(AppTutorial), findsOneWidget);
    await tester.tap(find.byKey(const Key('tutorialSkip')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ペン');
    await tester.pumpAndSettle();
    expect(entry, findsNothing);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(entry, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a help page opened for one topic shows only that topic', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await tester.runAsync(themes.init);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: themes.themeData,
        home: const HelpScreen(initialTopic: '作品広場'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('helpTutorialButton')), findsNothing);
  });

  testWidgets('every page fits every language, text size and screen', (
    tester,
  ) async {
    await loadAppFonts(tester);
    SharedPreferences.setMockInitialValues({});
    final themes = ThemeService();
    await tester.runAsync(themes.init);
    final boundary = GlobalKey();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    const sizes = [
      Size(320, 568),
      Size(390, 844),
      Size(640, 360),
      Size(1280, 800),
    ];
    var shots = 0;
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = appLocalizationsFor(locale);
      final titles = [
        l10n.tutorialPage1Title,
        l10n.tutorialPage2Title,
        l10n.tutorialPage3Title,
        l10n.tutorialPage4Title,
        l10n.tutorialPage5Title,
        l10n.tutorialPage6Title,
      ];
      final lastSteps = [
        l10n.tutorialPage1Step3,
        l10n.tutorialPage2Step3,
        l10n.tutorialPage3Step3,
        l10n.tutorialPage4Step3,
        l10n.tutorialPage5Step3,
        l10n.tutorialPage6Step3,
      ];
      for (final size in sizes) {
        for (final scale in [1.0, 2.0]) {
          final label =
              '$locale ${size.width.toInt()}x'
              '${size.height.toInt()} x$scale';
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            KeyedSubtree(
              key: ValueKey(label),
              child: RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  locale: locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: themes.themeData,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () => AppTutorial.show(context),
                          child: const Text('open'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          for (var page = 0; page < titles.length; page++) {
            final where = '$label page ${page + 1}';
            expect(tester.takeException(), isNull, reason: where);
            final last = page == titles.length - 1;
            final action = find.byKey(
              Key(last ? 'tutorialStart' : 'tutorialNext'),
            );
            final buttons = [
              action,
              if (!last) find.byKey(const Key('tutorialSkip')),
            ];
            final bar = tester.getRect(action);
            for (final button in buttons) {
              final rect = tester.getRect(button);
              expect(
                rect.left >= 0 &&
                    rect.top >= 0 &&
                    rect.right <= size.width &&
                    rect.bottom <= size.height,
                isTrue,
                reason: '$where button $rect',
              );
              // 折り返しても単語の途中では切れない。
              final paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(of: button, matching: find.byType(RichText)),
              );
              expect(
                paragraph.size.width + .01,
                greaterThanOrEqualTo(
                  paragraph.getMinIntrinsicWidth(double.infinity),
                ),
                reason: '$where label',
              );
            }
            // 見出しも最後の手順も、スクロールすればボタンの上で読める。
            for (final text in [titles[page], lastSteps[page]]) {
              final finder = find.text(text);
              expect(finder, findsOneWidget, reason: '$where $text');
              await tester.ensureVisible(finder);
              await tester.pumpAndSettle();
              final rect = tester.getRect(finder);
              expect(rect.top, greaterThanOrEqualTo(0), reason: where);
              expect(
                rect.bottom,
                lessThanOrEqualTo(bar.top),
                reason: '$where $text',
              );
              expect(rect.right, lessThanOrEqualTo(size.width), reason: where);
            }
            final capture =
                captureRoot != null &&
                (scale == 1 || size.width == 320) &&
                (locale.languageCode == 'ja' || page == 0 || size.width == 320);
            if (capture) {
              shots++;
              await tester.runAsync(() async {
                final image =
                    await (boundary.currentContext!.findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage();
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                image.dispose();
                final file = File(
                  '$captureRoot/${locale.toLanguageTag()}-'
                  '${size.width.toInt()}x${size.height.toInt()}-'
                  'x${scale.toStringAsFixed(0)}-p${page + 1}.png',
                )..createSync(recursive: true);
                file.writeAsBytesSync(data!.buffer.asUint8List());
              });
            }
            await tester.tap(action);
            await tester.pumpAndSettle();
          }
          expect(find.byType(AppTutorial), findsNothing, reason: label);
        }
      }
    }
    if (captureRoot != null) debugPrint('tutorial captures: $shots');
  });
}
