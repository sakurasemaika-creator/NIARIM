// 保存のダイアログ（保存の管理のスロット・セーブツリーの「保存」・セーブ
// ツリーの画面のスロット表示）で、題とボタンの名前が語の途中で折れない
// （DISC172）。
//
// 320px・文字2倍の仏語で「Enregistre / r」（保存のボタン）・「Enregistrer dans
// l’emplac / ement 1」（題）と語の途中で切れていた。2つのボタンはもう縦に
// 並んでいたが、ダイアログが画面の左右に40pxずつ空けるので、ボタンの段は
// 192pxしかなく、1つの語（「Enregistrer」）がボタンに入らなかった。狭い画面
// では左右の空きを縮め、語がボタン・題の1行に入るようにする。
//
// ダイアログはMaterialの最小の幅（280px）を、画面の左右に16pxずつ残せる限り
// 取る。7言語×320/360/412px×文字1.0/1.3/2.0×キーボードを閉じた・開いた状態で、
// その幅に入る語が途中で折れないこと（韓国語の説明の語も）、ダイアログが
// はみ出さないこと、打っている欄がキーボードの上に見えることを見張る。広い
// 画面では、ダイアログの左右の空きは今までどおり（40px以上）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/save_tree/save_tree_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';
import 'helpers/word_breaks.dart';

const _height = 740.0;
const _keyboard = 280.0;

/// Materialのダイアログの最小の幅・画面の左右に残す空きの下限と既定・
/// ダイアログの中身の左右の余白・ボタンの中の左右の余白。
const _minDialogWidth = 280.0;
const _screenMargin = 16.0;
const _usualMargin = 40.0;
const _dialogPadding = 24.0;
const _buttonPadding = 12.0;

/// 幅[width]の画面で、ダイアログが少なくとも取れる幅（最小の幅280pxを、
/// 左右に16pxずつ残せる限り。広い画面では既定の空き40pxを除いた幅）。
double _dialogRoom(double width) {
  final usual = width - 2 * _usualMargin;
  final widest = width - 2 * _screenMargin;
  final room = usual > _minDialogWidth ? usual : _minDialogWidth;
  return room < widest ? room : widest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  var fontsLoaded = false;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_save_words_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio()
      ..resetViewInsets();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  Future<void> settleIo(WidgetTester tester, [int rounds = 6]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 開いている保存のダイアログを、幅・文字の大きさ・キーボードを変えながら
  /// 調べる。
  Future<List<String>> sweep(WidgetTester tester, String where) async {
    final problems = <String>[];
    final errors = <String>[];
    final onError = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString());
    try {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final keyboard in [false, true]) {
            tester.view.physicalSize = Size(width, _height);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            tester.view.viewInsets = FakeViewPadding(
              bottom: keyboard ? _keyboard : 0,
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            final at =
                '$where ${width.toInt()}px x$scale'
                '${keyboard ? ' keyboard' : ''}';
            final dialog = find.byType(AlertDialog);
            expect(dialog, findsOneWidget, reason: at);
            final room = _dialogRoom(width) - 2 * _dialogPadding;
            final inButtons = <RenderParagraph>{
              for (final type in [TextButton, FilledButton])
                for (final button
                    in find
                        .descendant(of: dialog, matching: find.byType(type))
                        .evaluate())
                  ...textParagraphsIn(
                    find.byElementPredicate((e) => identical(e, button)),
                  ),
            };
            for (final paragraph in textParagraphsIn(dialog)) {
              final inButton = inButtons.contains(paragraph);
              final fit = inButton ? room - 2 * _buttonPadding : room;
              for (final broken in wordsBrokenThatFit(
                paragraph,
                fitWidth: fit > paragraph.constraints.maxWidth
                    ? fit
                    : paragraph.constraints.maxWidth,
              )) {
                problems.add('$at ${inButton ? 'button' : 'text'}: $broken');
              }
            }
            // 打っている欄は、キーボードの上の、ダイアログの見えている所にある。
            if (keyboard) {
              final field = tester.getRect(
                find.descendant(
                  of: dialog,
                  matching: find.byType(EditableText),
                ),
              );
              if (field.bottom > _height - _keyboard + 0.5) {
                problems.add('$at: the field is under the keyboard ($field)');
              }
            }
            for (final error in errors) {
              problems.add('$at: $error');
            }
            errors.clear();
          }
        }
      }
    } finally {
      FlutterError.onError = onError;
    }
    tester.view.resetViewInsets();
    tester.view.physicalSize = const Size(360, _height);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pump();
    return problems;
  }

  /// [language]のアプリで作品を1つ作り、保存の画面を開く。
  Future<String> openSaveScreen(
    WidgetTester tester,
    String language, {
    required bool tree,
  }) async {
    if (!fontsLoaded) {
      await loadAppFonts(tester);
      fontsLoaded = true;
    }
    tester.view.physicalSize = const Size(360, _height);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': language,
    });
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settleIo(tester, 4);
    final home = tester.element(find.byType(HomeScreen));
    final service = home.read<ProjectService>();
    home.read<SaveTreeService>().setTreeMode(tree);
    final project = (await tester.runAsync(
      () => service.createProject(
        name: 'Storyboard',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    appRouter.push('/save-tree/${project.id}');
    await settleIo(tester, 6);
    // 画面そのもののはみ出し（ダイアログと関係ない）は見ない。
    tester.takeException();
    return project.id;
  }

  Future<void> closeDialog(WidgetTester tester, AppLocalizations l10n) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.commonCancel),
      ),
    );
    for (
      var i = 0;
      i < 20 && find.byType(AlertDialog).evaluate().isNotEmpty;
      i++
    ) {
      await settleIo(tester, 1);
    }
    expect(find.byType(AlertDialog), findsNothing);
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final language = tag.replaceAll('-', '_');
    final l10n = lookupAppLocalizations(locale);

    testWidgets('the slot save dialog keeps its words whole ($tag)', (
      tester,
    ) async {
      await openSaveScreen(tester, language, tree: false);
      await tester.tap(find.byTooltip(l10n.saveTreeSlotWriteTooltip).first);
      await settleIo(tester, 3);
      final problems = await sweep(tester, 'slot');
      await closeDialog(tester, l10n);
      for (final problem in problems.take(10)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });

    testWidgets('the tree save dialog keeps its words whole ($tag)', (
      tester,
    ) async {
      await openSaveScreen(tester, language, tree: true);
      await tester.tap(find.byIcon(Icons.save).last);
      await settleIo(tester, 3);
      final problems = await sweep(tester, 'tree');
      await closeDialog(tester, l10n);
      for (final problem in problems.take(10)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });

    testWidgets('the save tree screen slot dialog keeps its words whole '
        '($tag)', (tester) async {
      final id = await openSaveScreen(tester, language, tree: false);
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (context) => MaterialApp(
              locale: locale,
              theme: context.watch<ThemeService>().themeDataFor(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SaveTreeScreen(
                projectId: id,
                entryMode: SaveTreeEntryMode.projectDetail,
              ),
            ),
          ),
        ),
      );
      await settleIo(tester, 6);
      tester.takeException();
      final write = find.byTooltip(l10n.saveTreeSlotWriteTooltip).first;
      await tester.ensureVisible(write);
      await tester.pump();
      await tester.tap(write);
      await settleIo(tester, 3);
      final problems = await sweep(tester, 'save tree slots');
      await closeDialog(tester, l10n);
      for (final problem in problems.take(10)) {
        debugPrint(problem);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });
  }

  // 広い画面・既定の文字の大きさでは、ダイアログの形（左右の空き）は今までの
  // まま（狭い画面だけ空きを縮める）。
  testWidgets('a wide screen keeps the usual dialog margins', (tester) async {
    await openSaveScreen(tester, 'fr', tree: false);
    final l10n = lookupAppLocalizations(const Locale('fr'));
    tester.view.physicalSize = const Size(412, _height);
    await tester.pump();
    await tester.tap(find.byTooltip(l10n.saveTreeSlotWriteTooltip).first);
    await settleIo(tester, 3);
    final dialog = tester.getRect(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(dialog.left, greaterThanOrEqualTo(_usualMargin - 0.5));
    expect(dialog.right, lessThanOrEqualTo(412 - _usualMargin + 0.5));
    // ボタンの名前は1行（「Annuler」「Enregistrer」）。
    for (final type in [TextButton, FilledButton]) {
      final label = textParagraphsIn(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(type),
        ),
      ).single;
      expect(ParagraphLines(label).lines, hasLength(1));
    }
    await closeDialog(tester, l10n);
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  });
}
