import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/save_tree/save_management_screen.dart';
import 'package:niarim/screens/save_tree/save_tree_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/help_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// 保存の画面（保存の管理＝スロット、セーブツリーの画面のスロット表示と
/// ツリー表示）の上部バーは、7言語×文字の大きさ1.0/1.3/2.0×幅320/360/1280で
/// はみ出さず、右の操作が左の戻るボタンに重ならず、画面名は入るときだけ
/// 省略記号で切らずに出す（所有者の判断4）。以前はツリー表示・仏語・320px・
/// 文字2倍で右に84px（360pxで44px）はみ出し、同梱のフォントでは「ヘルプ」が
/// 戻るボタンに重なり、画面名は多くの幅で「Arbre d…」のように切れていた。
/// 「保存」は文字のボタンが入らないときアイコンのボタンになり、名前は
/// ツールチップ（長押し・ホバー）と読み上げで出る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  const locales = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  const screens = ['save slots', 'save tree slots', 'save tree'];
  const widths = [320.0, 360.0, 1280.0];
  const scales = [1.0, 1.3, 2.0];

  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim_save_app_bar_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// 全部の組み合わせで上部バーを開き、決まりに合わない所を返す。
  Future<List<String>> sweep(WidgetTester tester) async {
    final providers = (await tester.runAsync(buildAppProviders))!;
    final navKey = GlobalKey<NavigatorState>();
    late ProjectService projects;
    late SaveTreeService saves;
    Future<void> pumpApp(String code) async {
      final parts = code.split('_');
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (context) {
              projects = context.read<ProjectService>();
              saves = context.read<SaveTreeService>();
              return MaterialApp(
                navigatorKey: navKey,
                theme: context.watch<ThemeService>().themeData,
                locale: Locale.fromSubtags(
                  languageCode: parts.first,
                  scriptCode: parts.length > 1 ? parts.last : null,
                ),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const Scaffold(body: SizedBox.shrink()),
              );
            },
          ),
        ),
      );
      await tester.pump();
    }

    await pumpApp('ja');
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: '上部バー',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    final problems = <String>[];
    final overflows = <String>[];
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      overflows.add(
        RegExp(r'overflowed by [\d.]+ pixels on the \w+').stringMatch(text) ??
            text.split('\n').first,
      );
    };
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    try {
      for (final code in locales) {
        await pumpApp(code);
        final l10n = lookupAppLocalizations(
          Locale.fromSubtags(
            languageCode: code.split('_').first,
            scriptCode: code.contains('_') ? code.split('_').last : null,
          ),
        );
        for (final screen in screens) {
          final tree = screen == 'save tree';
          saves.setTreeMode(tree);
          final title = tree
              ? l10n.saveTreeScreenTitleTree
              : l10n.saveTreeScreenTitleSlot;
          for (final width in widths) {
            for (final scale in scales) {
              final cell = '$code $screen ${width.toInt()}px x$scale';
              tester.view.physicalSize = Size(width, 800);
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              overflows.clear();
              navKey.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => screen == 'save tree slots'
                      ? SaveTreeScreen(projectId: project.id)
                      : SaveManagementScreen(projectId: project.id),
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
              final exception = tester.takeException();
              if (exception != null || overflows.isNotEmpty) {
                problems.add('$cell: ${overflows.toSet()} $exception');
              }
              final bar = find.byType(AppBar).last;
              final back = tester.getRect(
                find.descendant(of: bar, matching: find.byType(BackButton)),
              );
              final help = tester.getRect(
                find.descendant(of: bar, matching: find.byType(HelpButton)),
              );
              if (help.left < back.right) {
                problems.add(
                  '$cell: Help (x=${help.left}) is over the back button '
                  '(right=${back.right})',
                );
              }
              for (final element
                  in find
                      .descendant(of: bar, matching: find.text(title))
                      .evaluate()) {
                final paragraph = element.renderObject! as RenderParagraph;
                if (paragraph.didExceedMaxLines) {
                  problems.add('$cell: the title is cut with an ellipsis');
                }
              }
              if (tree) {
                final labeled = find.descendant(
                  of: bar,
                  matching: find.widgetWithText(FilledButton, l10n.commonSave),
                );
                final compact = find.descendant(
                  of: bar,
                  matching: find.byTooltip(l10n.commonSave),
                );
                final save = labeled.evaluate().isNotEmpty ? labeled : compact;
                if (save.evaluate().length != 1) {
                  problems.add('$cell: Save is not in the bar');
                } else {
                  final rect = tester.getRect(save);
                  if (rect.left < back.right || rect.right > width) {
                    problems.add('$cell: Save is at $rect');
                  }
                  // 入る幅（1280px）では、文字のボタンと画面名のまま。
                  if (width == 1280 && save == compact) {
                    problems.add('$cell: Save lost its label where it fits');
                  }
                }
              }
              if (width == 1280 &&
                  find
                      .descendant(of: bar, matching: find.text(title))
                      .evaluate()
                      .isEmpty) {
                problems.add('$cell: the title is hidden where it fits');
              }
              navKey.currentState!.pop();
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
              tester.takeException();
            }
          }
        }
      }
    } finally {
      // 失敗のexpectより前に戻す（戻さないとテストの仕組みが失敗を扱えない）。
      FlutterError.onError = original;
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    return problems;
  }

  testWidgets('the save screens app bars fit every locale, text size and '
      'width (test font)', (tester) async {
    final problems = await sweep(tester);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('the save screens app bars fit every locale, text size and '
      'width (bundled fonts)', (tester) async {
    await loadAppFonts(tester);
    final problems = await sweep(tester);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  testWidgets('a title that does not fit is still read out, and the compact '
      'Save keeps its name', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final navKey = GlobalKey<NavigatorState>();
    late ProjectService projects;
    late SaveTreeService saves;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            projects = context.read<ProjectService>();
            saves = context.read<SaveTreeService>();
            return MaterialApp(
              navigatorKey: navKey,
              theme: context.watch<ThemeService>().themeData,
              locale: const Locale('fr'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const Scaffold(body: SizedBox.shrink()),
            );
          },
        ),
      ),
    );
    saves.setTreeMode(true);
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: '上部バー',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => SaveManagementScreen(projectId: project.id),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Arbre de sauvegarde'), findsNothing);
    expect(find.bySemanticsLabel('Arbre de sauvegarde'), findsOneWidget);
    // 読み上げの木（端末へ渡す方）に画面名が残っている。
    expect(find.semantics.byLabel('Arbre de sauvegarde'), findsOne);
    final save = find.byTooltip('Enregistrer');
    expect(save, findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
    // アイコンだけのボタンも、読み上げでは「保存」の名前を持つ（測るための
    // 見えない文字のボタンは読み上げに出ない）。
    expect(
      find.semantics.byPredicate((node) => node.tooltip == 'Enregistrer'),
      findsOne,
    );
    expect(find.semantics.byLabel('Enregistrer'), findsNothing);
    // 押すと保存のダイアログが開く。
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
