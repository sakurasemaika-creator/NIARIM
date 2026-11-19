// 保存のダイアログ（保存の管理のスロット・セーブツリーの「保存」・セーブ
// ツリーの画面のスロット表示）のメモの欄のヒントを「…」で切らずに全部出し、
// 上書きの注意を韓国語の語の途中で折らない（DISC192）。
//
// メモの欄は1行の欄なので、ヒントも1行（TextFieldはヒントの行数を欄の行数に
// 合わせる）で、仏語・320px・文字2倍で「ex. : Arrière-plan…」と省略記号で
// 切れていた。ヒントは行を増やして全部出す（フォント管理の検索欄と同じ）。
// 上書きの注意（「既存データ（日時）を上書きします。」）は普通のTextで、
// 韓国語の語が音節の間で折れた。
//
// 7言語×320/360/412px×文字1.0/1.3/2.0×キーボードを閉じた・開いた状態で、
// ヒントが切れていないこと、ヒントと注意の語が途中で折れないこと（注意は
// ダイアログが取れる幅に入る語）、打っている欄がキーボードの上にあること、
// はみ出さないことを見張る。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/save_tree/save_tree_screen.dart';
import 'package:niarim/screens/save_tree/widgets/save_display_name.dart'
    show formatSaveTime;
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
/// ダイアログの中身の左右の余白。
const _minDialogWidth = 280.0;
const _screenMargin = 16.0;
const _usualMargin = 40.0;
const _dialogPadding = 24.0;

/// 幅[width]の画面で、ダイアログが少なくとも取れる幅。
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
    tempDir = Directory.systemTemp.createTempSync('niarim_save_hint_');
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
  /// 調べる。[warning]は上書きの注意の文（無ければnull）。
  Future<List<String>> sweep(
    WidgetTester tester,
    AppLocalizations l10n,
    String where, {
    String? warning,
  }) async {
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
            // メモの欄のヒントは、省略記号で切らずに全部出す。
            final hint = textParagraphsIn(
              find.descendant(
                of: find.descendant(
                  of: dialog,
                  matching: find.byType(InputDecorator),
                ),
                matching: find.text(l10n.saveTreeCommentHint),
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
            // 上書きの注意は、ダイアログが取れる幅に入る語を途中で折らない。
            if (warning != null) {
              final note = textParagraphsIn(
                find.descendant(
                  of: dialog,
                  matching: find.byWidgetPredicate(
                    (w) => w is Text && w.data == warning,
                  ),
                ),
              ).single;
              final room = _dialogRoom(width) - 2 * _dialogPadding;
              for (final broken in wordsBrokenThatFit(
                note,
                fitWidth: room > note.constraints.maxWidth
                    ? room
                    : note.constraints.maxWidth,
              )) {
                problems.add('$at warning: $broken');
              }
            }
            // 打っている欄は、キーボードの上にある。
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

  /// [language]のアプリで作品を1つ作り、[saved]ならスロット1へ保存してから、
  /// 保存の画面を開く。作品のIDと、スロット1の保存（あれば）を返す。
  Future<(String, SaveNode?)> openSaveScreen(
    WidgetTester tester,
    String language, {
    required bool tree,
    bool saved = false,
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
    final projects = home.read<ProjectService>();
    final saves = home.read<SaveTreeService>()..setTreeMode(tree);
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'Storyboard',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    SaveNode? node;
    if (saved) {
      node = await tester.runAsync(
        () => saves.saveToSlot(
          projectId: project.id,
          slotIndex: 0,
          project: project,
          scenes: projects.scenesOf(project.id),
          tileManager: projects.tileManagerOf(project.id),
        ),
      );
    }
    appRouter.push('/save-tree/${project.id}');
    await settleIo(tester, 6);
    tester.takeException();
    return (project.id, node);
  }

  String warningOf(AppLocalizations l10n, SaveNode node) =>
      l10n.saveTreeSlotOverwriteWarning(
        formatSaveTime(node.savedAt, l10n.localeName),
      );

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

  void report(List<String> problems) {
    for (final problem in problems.take(12)) {
      debugPrint(problem);
    }
    expect(problems, isEmpty, reason: '${problems.length} problems');
  }

  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();
    final language = tag.replaceAll('-', '_');
    final l10n = lookupAppLocalizations(locale);

    testWidgets('the slot save dialog shows its whole hint and keeps the '
        'warning words whole ($tag)', (tester) async {
      final (_, node) = await openSaveScreen(
        tester,
        language,
        tree: false,
        saved: true,
      );
      await tester.tap(find.byTooltip(l10n.saveTreeSlotWriteTooltip).first);
      await settleIo(tester, 3);
      // 保存のあるスロットは、上書きを確かめてから保存のダイアログを開く。
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l10n.commonOk),
        ),
      );
      await settleIo(tester, 3);
      final problems = await sweep(
        tester,
        l10n,
        'slot',
        warning: warningOf(l10n, node!),
      );
      await closeDialog(tester, l10n);
      report(problems);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });

    testWidgets('the tree save dialog shows its whole hint ($tag)', (
      tester,
    ) async {
      await openSaveScreen(tester, language, tree: true);
      await tester.tap(find.byIcon(Icons.save).last);
      await settleIo(tester, 3);
      final problems = await sweep(tester, l10n, 'tree');
      await closeDialog(tester, l10n);
      report(problems);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });

    testWidgets('the save tree screen slot dialog shows its whole hint and '
        'keeps the warning words whole ($tag)', (tester) async {
      final (id, node) = await openSaveScreen(
        tester,
        language,
        tree: false,
        saved: true,
      );
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
      final problems = await sweep(
        tester,
        l10n,
        'save tree slots',
        warning: warningOf(l10n, node!),
      );
      await closeDialog(tester, l10n);
      report(problems);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.go('/');
    });
  }
}
