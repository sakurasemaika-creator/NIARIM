import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/save_tree/save_management_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/help_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// セーブツリーの画面の上部バー（DISC103）の残り：
/// - 画面を開いたまま文字の大きさを変えても、「保存」を文字かアイコンかで
///   決め直す（以前は開いたときの幅で決めたままで、2倍にすると「ヘルプ」が
///   戻るボタンに重なり、戻るボタンの右側を押すとヘルプが開いた）。
/// - アイコンだけの「保存」は、ボタンそのものが読み上げの名前を持つ
///   （以前は名前がボタンでない別の節にあり、labeledTapTargetGuidelineに
///   通らなかった）。
/// - 画面名の欄の幅が0になっても、画面名は読み上げの木に残る。
/// - 保存の無いツリーの「上部の『保存』ボタンで…」の案内は、ボタンが
///   アイコンだけでも分かるように保存のアイコンを添え、見出しは両端に
///   余白を取って中央にそろえる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim_save_app_bar_live_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'fr',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// 仏語・同梱のフォントで、保存の無い作品のセーブツリー（ツリー方式）を
  /// 開く。
  Future<void> openTree(
    WidgetTester tester, {
    required double width,
    required double scale,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await loadAppFonts(tester);
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
  }

  Finder inBar(Finder matching) =>
      find.descendant(of: find.byType(AppBar).last, matching: matching);

  /// 上部バーの「保存」が文字のボタンか（false＝アイコンだけ）と、決まりに
  /// 合わない所。
  (bool, List<String>) barState(WidgetTester tester, double width) {
    final problems = <String>[];
    final back = tester.getRect(inBar(find.byType(BackButton)));
    final help = tester.getRect(inBar(find.byType(HelpButton)));
    if (help.left < back.right) {
      problems.add(
        'Help (x=${help.left}) is over the back button '
        '(right=${back.right})',
      );
    }
    final labeled = inBar(
      find.widgetWithText(FilledButton, 'Enregistrer'),
    ).hitTestable();
    final compact = inBar(find.byTooltip('Enregistrer')).hitTestable();
    final isLabeled = labeled.evaluate().isNotEmpty;
    final save = isLabeled ? labeled : compact;
    if (save.evaluate().length != 1) {
      problems.add('Save is not in the bar');
    } else {
      final rect = tester.getRect(save);
      if (rect.left < help.right || rect.right > width) {
        problems.add('Save is at $rect (Help $help)');
      }
    }
    return (isLabeled, problems);
  }

  testWidgets('changing the text size while the save tree is open decides '
      'the Save button again (fr 320px)', (tester) async {
    await openTree(tester, width: 320, scale: 1);
    var (labeled, problems) = barState(tester, 320);
    expect(problems, isEmpty);
    expect(labeled, isTrue, reason: 'at x1.0 the labelled Save fits');

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    (labeled, problems) = barState(tester, 320);
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(labeled, isFalse, reason: 'the labelled Save no longer fits');
    // 戻るボタンの右の方を押すと戻る（ヘルプは開かない）。
    final back = tester.getRect(inBar(find.byType(BackButton)));
    final path = tester
        .hitTestOnBinding(Offset(back.right - 4, back.center.dy))
        .path
        .map((entry) => entry.target)
        .toSet();
    expect(
      path.contains(tester.renderObject(inBar(find.byType(BackButton)))),
      isTrue,
    );
    expect(
      path.contains(tester.renderObject(inBar(find.byType(HelpButton)))),
      isFalse,
      reason: 'a tap on the back button opens Help',
    );

    tester.platformDispatcher.textScaleFactorTestValue = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    (labeled, problems) = barState(tester, 320);
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(labeled, isTrue, reason: 'back at x1.0 the label fits again');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the icon-only Save has its name on the button itself '
      '(fr 320px x2.0)', (tester) async {
    final semantics = tester.ensureSemantics();
    await openTree(tester, width: 320, scale: 2);
    final (labeled, problems) = barState(tester, 320);
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(labeled, isFalse);
    expect(
      find.semantics.byPredicate(
        (node) =>
            node.label == 'Enregistrer' &&
            node.flagsCollection.isButton &&
            node.getSemanticsData().hasAction(SemanticsAction.tap),
      ),
      findsOne,
      reason: 'the tappable Save node has no name',
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    // 長押し・ホバーの名前（ツールチップ）は残る。
    expect(inBar(find.byTooltip('Enregistrer')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('a hidden screen name is read out also when its slot is 0px '
      'wide (fr 360px x2.0)', (tester) async {
    final semantics = tester.ensureSemantics();
    await openTree(tester, width: 360, scale: 2);
    expect(find.text('Arbre de sauvegarde'), findsNothing);
    expect(
      find.semantics.byLabel('Arbre de sauvegarde'),
      findsOne,
      reason: 'the screen name dropped out of the semantics tree',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('the empty tree hint shows the save icon and the heading keeps '
      'off the screen edges (fr 320px x2.0)', (tester) async {
    await openTree(tester, width: 320, scale: 2);
    final hint = find.textContaining(
      'Enregistrer',
      findRichText: true,
      skipOffstage: true,
    );
    final hintInBody = find.descendant(
      of: find.byType(Scaffold).last,
      matching: hint,
    );
    final bodyHints = hintInBody
        .evaluate()
        .where(
          (e) => find
              .descendant(of: find.byType(AppBar).last, matching: hint)
              .evaluate()
              .every((b) => b != e),
        )
        .toList();
    expect(bodyHints, hasLength(1));
    expect(
      find.descendant(
        of: find.byElementPredicate((e) => e == bodyHints.single),
        matching: find.byIcon(Icons.save),
      ),
      findsOneWidget,
      reason: 'the hint names a button that only shows an icon',
    );
    final heading = tester.getRect(find.text('Aucune donnée de sauvegarde'));
    expect(heading.left, greaterThanOrEqualTo(16));
    expect(heading.right, lessThanOrEqualTo(320 - 16));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
