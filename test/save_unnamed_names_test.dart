import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/screens/save_tree/save_management_screen.dart';
import 'package:niarim/screens/save_tree/save_tree_screen.dart';
import 'package:niarim/screens/save_tree/widgets/save_screen_app_bar.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// メモを付けずに保存した保存を文の中で呼ぶ名前（DISC109）。
///
/// スロットへメモなしで保存すると、スロットのメモは「空」として残る。
/// 削除の確認・読み込みの確認・読み込みの知らせはその空のメモをそのまま
/// 名前に使い、「「」を削除しますか？」（簡体字は「要删除“”吗？」）、
/// 「セーブデータを読み込みました（）」と出ていた。スロットの行の見出しと
/// 同じ名前（「スロット1」）で呼ぶ。行のメモの代わりの名前・保存の
/// ダイアログの題も、見出しと違う形（「スロット 1」「存储槽 1」）をやめて
/// 見出しの形にそろえる。保存の一覧に空白だけのメモが残っている（前の版で
/// 付けた）と、スロットの行は空白を出し、メモの欄も空白で開いた。
///
/// ツリーの保存（メモが空白だけ）は、行の見出しが空になり、確認も
/// 「「   」を削除しますか？」だった。名前の無いツリーの保存は、行に出て
/// いる保存の日時で呼ぶ。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('niarim_save_unnamed_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<
    ({
      SaveTreeService saves,
      ProjectService projects,
      Project project,
      GlobalKey<NavigatorState> nav,
    })
  >
  open(WidgetTester tester, String language, {bool tree = false}) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': language,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final navKey = GlobalKey<NavigatorState>();
    late ProjectService projects;
    late SaveTreeService service;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            projects = context.read<ProjectService>();
            service = context.read<SaveTreeService>();
            return MaterialApp(
              navigatorKey: navKey,
              theme: context.watch<ThemeService>().themeData,
              locale: localeFromLanguageCode(language),
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
    service.setTreeMode(tree);
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'unnamed',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => SaveManagementScreen(
          projectId: project.id,
          entryMode: SaveTreeEntryMode.projectDetail,
        ),
      ),
    );
    await settleIo(tester, 4);
    return (saves: service, projects: projects, project: project, nav: navKey);
  }

  // 確認の文は、数と単位・韓国語の語を途中で切らないTextの仲間
  // （KeepTogetherText）でも描くので、型の同じものだけでなく仲間も読む。
  String dialogText(WidgetTester tester) => [
    for (final t in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate((widget) => widget is Text),
      ),
    ))
      t.data ?? t.textSpan?.toPlainText() ?? '',
  ].join(' / ');

  String snackText(WidgetTester tester) => [
    for (final t in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.bySubtype<Text>(),
      ),
    ))
      t.data ?? '',
  ].join(' / ');

  for (final language in ['ja', 'zh', 'ko', 'zh_Hant']) {
    testWidgets('$language: a slot saved without a memo is called by the slot '
        'name in the delete confirm, the load confirm and the loaded notice', (
      tester,
    ) async {
      final app = await open(tester, language);
      final screen = tester.element(find.byType(SaveManagementScreen));
      final l10n = AppLocalizations.of(screen)!;
      // スロットの見出しと同じ文字列で呼ぶ。
      final slotName = l10n.saveTreeSlotLabel(1);
      // 見出しと違う形（数の前に空白）。どこにも出ない。
      final otherForm = slotName.replaceFirst(RegExp(r'(\d+)$'), r' $1');
      expect(otherForm, isNot(slotName));
      final problems = <String>[];
      void noOtherForm(String where) {
        final found = find.textContaining(otherForm);
        if (found.evaluate().isNotEmpty) {
          problems.add('$where: 「$otherForm」が出ている');
        }
      }

      // スロット1へ、メモを空のまま保存の画面のダイアログで保存する。
      await tester.tap(find.byTooltip(l10n.saveTreeSlotWriteTooltip).first);
      await settleIo(tester, 3);
      final saveTitle = dialogText(tester);
      if (!saveTitle.contains(slotName)) {
        problems.add('保存のダイアログ: $saveTitle');
      }
      noOtherForm('保存のダイアログ');
      // スロットの呼び方は、スロットの画面の題・保存のダイアログの題・スロットの
      // ボタンの説明でも見出しと同じ（簡体字は見出しが「存储槽1」、画面の題が
      // 「存档槽」、ボタンの説明が「保存到此存档位」と3通りだった）。
      final slotWord = slotWordOf(l10n);
      for (final (where, shown) in [
        ('スロットの画面の題', l10n.saveTreeScreenTitleSlot),
        ('保存のダイアログの題', saveTitle),
        ('保存のボタンの説明', l10n.saveTreeSlotWriteTooltip),
      ]) {
        if (!shown.toLowerCase().contains(slotWord.toLowerCase())) {
          problems.add('$where「$shown」に見出しの「$slotWord」が無い');
        }
      }
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, l10n.commonSave),
        ),
      );
      await settleIo(tester, 12);
      expect(app.saves.getNodes(app.project.id), hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      noOtherForm('スロットの行');

      // 削除の確認。
      await tester.tap(find.byTooltip(l10n.saveTreeSlotDeleteTooltip).first);
      await settleIo(tester, 3);
      final deleteBody = dialogText(tester);
      if (!deleteBody.contains(l10n.confirmDeleteNamedBody(slotName))) {
        problems.add('削除の確認: $deleteBody');
      }
      noOtherForm('削除の確認');
      await tester.tap(find.text(l10n.commonCancel));
      await settleIo(tester, 3);

      // 読み込みの確認（保存の要約）と、読み込んだ知らせ。
      await tester.tap(find.byTooltip(l10n.saveTreeSlotLoadTooltip).first);
      await settleIo(tester, 3);
      final loadBody = dialogText(tester);
      if (!loadBody.contains(slotName)) {
        problems.add('読み込みの確認の要約: $loadBody');
      }
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(
            FilledButton,
            l10n.saveTreeRestoreAction,
          ),
        ),
      );
      await settleIo(tester, 10);
      final notice = snackText(tester);
      if (notice != l10n.saveTreeRestoredSnackbar(slotName)) {
        problems.add('読み込みの知らせ: $notice');
      }
      noOtherForm('読み込みの知らせ');
      expect(problems, isEmpty, reason: problems.join('\n'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('tree: a save named only with spaces shows the fallback title '
      'and is called by its save time in the delete confirm', (tester) async {
    final app = await open(tester, 'ja', tree: true);
    final node = (await tester.runAsync<SaveNode>(
      // 前の版の保存のダイアログは、メモの欄を空白だけにしてもそのまま保存した。
      () => app.saves.saveAsChild(
        projectId: app.project.id,
        project: app.project,
        scenes: app.projects.scenesOf(app.project.id),
        tileManager: app.projects.tileManagerOf(app.project.id),
        comment: '   ',
      ),
    ))!;
    await settleIo(tester, 4);
    final screen = tester.element(find.byType(SaveTreeScreen));
    final l10n = AppLocalizations.of(screen)!;
    final problems = <String>[];
    final row = find.ancestor(
      of: find.byKey(Key('saveRename_${node.id}')),
      matching: find.byType(ListTile),
    );
    expect(row, findsOneWidget);
    if (find
        .descendant(of: row, matching: find.text(l10n.saveTreeNodeDefaultTitle))
        .evaluate()
        .isEmpty) {
      problems.add('行の見出しが空');
    }
    await tester.tap(
      find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)),
    );
    await settleIo(tester, 3);
    await tester.tap(find.text(l10n.commonDelete).last);
    await settleIo(tester, 3);
    final at = node.savedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    final time =
        '${at.year}/${two(at.month)}/${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
    final body = dialogText(tester);
    // 行に出ている保存の日時で呼ぶ（空白だけの名前をかぎ括弧で囲まない）。
    if (!body.contains(time) ||
        body.contains(l10n.confirmDeleteNamedBody('   '))) {
      problems.add('削除の確認: $body');
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    await tester.tap(find.text(l10n.commonCancel));
    await settleIo(tester, 3);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 前の版でメモを空白だけにした保存の一覧（index.json）を読んで、保存の
  // 画面（スロット表示）を開く。
  Future<({SaveTreeService saves, String projectId, AppLocalizations l10n})>
  reopenWithSpacesSlotMemo(WidgetTester tester, {required bool tree}) async {
    final first = await open(tester, 'ja');
    await tester.runAsync(
      () => first.saves.saveToSlot(
        projectId: first.project.id,
        slotIndex: 0,
        project: first.project,
        scenes: first.projects.scenesOf(first.project.id),
        tileManager: first.projects.tileManagerOf(first.project.id),
      ),
    );
    await settleIo(tester, 4);
    await tester.pumpWidget(const SizedBox.shrink());
    // 一覧のスロットのメモを空白だけにする（前の版で付けたメモ）。
    final index = dir
        .listSync(recursive: true)
        .whereType<File>()
        .singleWhere(
          (f) =>
              f.path.endsWith('index.json') &&
              f.path.contains('${first.project.id}/SaveTree'),
        );
    final json = jsonDecode(index.readAsStringSync()) as Map<String, dynamic>;
    json['slotMemos'] = {'0': '   '};
    index.writeAsStringSync(jsonEncode(json));

    // 起動し直して開く。
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final providers = (await tester.runAsync(buildAppProviders))!;
    final navKey = GlobalKey<NavigatorState>();
    late SaveTreeService saves;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            saves = context.read<SaveTreeService>();
            return MaterialApp(
              navigatorKey: navKey,
              theme: context.watch<ThemeService>().themeData,
              locale: const Locale('ja'),
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
    expect(saves.slotDisplayMemoOf(first.project.id, 0), '   ');
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => tree
            ? SaveTreeScreen(projectId: first.project.id)
            : SaveManagementScreen(
                projectId: first.project.id,
                entryMode: SaveTreeEntryMode.projectDetail,
              ),
      ),
    );
    await settleIo(tester, 4);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(tree ? SaveTreeScreen : SaveManagementScreen)),
    )!;
    return (saves: saves, projectId: first.project.id, l10n: l10n);
  }

  Finder dialogField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  for (final tree in [false, true]) {
    testWidgets('${tree ? 'save tree screen' : 'save management screen'}: a '
        'slot memo of only spaces from an earlier list is shown like no memo '
        '(the slot name), not as a blank line', (tester) async {
      final app = await reopenWithSpacesSlotMemo(tester, tree: tree);
      final l10n = app.l10n;
      final slotName = l10n.saveTreeSlotLabel(1);
      final problems = <String>[];
      // スロットの行に空白だけの文が無い（メモの代わりにスロットの名前）。
      final blank = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data != null &&
            w.data!.isNotEmpty &&
            w.data!.trim().isEmpty,
      );
      if (blank.evaluate().isNotEmpty) {
        problems.add('空白だけの文が行に出ている（${blank.evaluate().length}個）');
      }
      if (find.text(slotName).evaluate().length < 2) {
        problems.add('メモの代わりにスロットの名前が出ていない');
      }
      // メモの欄は空で開く（空白だけのメモは「無い」と同じ）。
      await tester.tap(
        find.byKey(Key('saveSlotMemo_${app.projectId}_0')).first,
      );
      await settleIo(tester, 3);
      final field = tester.widget<TextField>(dialogField());
      if (field.controller!.text.isNotEmpty) {
        problems.add('メモの欄が「${field.controller!.text}」で開く');
      }
      await tester.tap(find.text(l10n.commonCancel));
      await settleIo(tester, 3);
      expect(problems, isEmpty, reason: problems.join('\n'));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    // 同じスロットへ「このスロットへ保存」で保存し直すとき：保存のダイアログの
    // メモの欄も空で開き（ヒントが見える）、空白だけを打って保存しても空白だけの
    // 名前を残さない（以前は欄が「   」で開き、そのまま保存すると保存の名前が
    // 「   」のまま残った）。
    testWidgets('${tree ? 'save tree screen' : 'save management screen'}: the '
        'slot save dialog opens with an empty memo for a memo of only spaces, '
        'and saving only spaces keeps no name', (tester) async {
      final app = await reopenWithSpacesSlotMemo(tester, tree: tree);
      final l10n = app.l10n;
      final problems = <String>[];
      await tester.tap(find.byTooltip(l10n.saveTreeSlotWriteTooltip).first);
      await settleIo(tester, 3);
      // 保存の管理は上書きの確認を挟む。
      if (dialogField().evaluate().isEmpty) {
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.commonOk),
          ),
        );
        await settleIo(tester, 3);
      }
      final opened = tester.widget<TextField>(dialogField()).controller!.text;
      if (opened.isNotEmpty) {
        problems.add('保存のダイアログのメモの欄が「$opened」で開く');
      }
      await tester.enterText(dialogField(), '   ');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, l10n.commonSave),
        ),
      );
      await settleIo(tester, 12);
      expect(find.byType(AlertDialog), findsNothing);
      final saved = app.saves
          .getNodes(app.projectId)
          .singleWhere((n) => n.slotIndex == 0);
      if (saved.comment != null) {
        problems.add('保存の名前が「${saved.comment}」のまま残る');
      }
      final memo = app.saves.slotDisplayMemoOf(app.projectId, 0);
      if (memo != null && memo.isNotEmpty) {
        problems.add('スロットのメモが「$memo」');
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  // ツリーの保存のダイアログでメモの欄に空白だけを打って保存しても、空白だけの
  // 名前の保存を作らない（行は既定の見出し、確認は保存の日時で呼ぶ）。
  testWidgets('tree: saving with only spaces in the memo field keeps no name', (
    tester,
  ) async {
    final app = await open(tester, 'ja', tree: true);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SaveTreeScreen)),
    )!;
    await tester.tap(find.byType(SaveTreeBarSaveButton));
    await settleIo(tester, 3);
    await tester.enterText(dialogField(), '   ');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, l10n.commonSave),
      ),
    );
    await settleIo(tester, 12);
    expect(find.byType(AlertDialog), findsNothing);
    final saved = app.saves.getNodes(app.project.id).single;
    expect(
      saved.comment,
      isNull,
      reason: '保存の名前が「${saved.comment}」になる（空白だけの名前は名前なし）',
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // スロット数を減らして残す保存を選ぶ画面の行も、スロットの行・確認・知らせと
  // 同じ名前（鉛筆で変えた・消したスロットのメモ）で呼ぶ。以前は保存したときの
  // 名前（node.comment）を出し、どの画面にも出ていない名前で残す保存を選ばせた。
  testWidgets('keep-selection rows call slot saves by the slot memo shown on '
      'the slot rows (renamed or cleared), not the name from save time', (
    tester,
  ) async {
    final app = await open(tester, 'ja');
    final id = app.project.id;
    for (final (slot, memo) in [(0, 'A'), (1, 'C'), (2, 'E')]) {
      await tester.runAsync(
        () => app.saves.saveToSlot(
          projectId: id,
          slotIndex: slot,
          project: app.project,
          scenes: app.projects.scenesOf(id),
          tileManager: app.projects.tileManagerOf(id),
          comment: memo,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    // 鉛筆のメモでスロット1の名前を変え、スロット2のメモを消す。
    await tester.runAsync(() => app.saves.setSlotMemo(id, 0, 'B'));
    await tester.runAsync(() => app.saves.setSlotMemo(id, 1, ''));
    await settleIo(tester, 3);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SaveManagementScreen)),
    )!;
    final slot2 = l10n.saveTreeSlotLabel(2);
    // スロットの行はメモの名前（B・スロット2・E）。
    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(find.text('C'), findsNothing);

    final flow = showSaveModeChangeFlowIfNeeded(
      context: app.nav.currentContext!,
      projectId: id,
      saveService: app.saves,
      newIsTreeMode: false,
      newSlotMax: 1,
      projectName: app.project.name,
    );
    await settleIo(tester, 4);
    await tester.tap(find.text(l10n.saveTreeSelectDataButton));
    await settleIo(tester, 3);
    // 選ぶ行（先頭にチェックボックス）の見出し。
    final rows = [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        if (tile.leading is Checkbox) (tile.title! as Text).data,
    ];
    expect(rows, ['B', slot2, 'E'], reason: '選んで残す画面の行がスロットの行と違う名前');
    await tester.tap(
      find.widgetWithText(OutlinedButton, l10n.saveTreeBackButton),
    );
    await settleIo(tester, 2);
    await tester.tap(find.widgetWithText(OutlinedButton, l10n.commonCancel));
    await settleIo(tester, 3);
    await tester.runAsync(() => flow);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('every slot string calls the slot by the word of the slot header '
      '(7 languages)', () {
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      final word = slotWordOf(l10n).toLowerCase();
      for (final (key, value) in [
        ('saveTreeScreenTitleSlot', l10n.saveTreeScreenTitleSlot),
        ('saveTreeSlotSaveDialogTitle', l10n.saveTreeSlotSaveDialogTitle(2)),
        ('saveTreeSlotWriteTooltip', l10n.saveTreeSlotWriteTooltip),
        ('saveTreeSlotLoadTooltip', l10n.saveTreeSlotLoadTooltip),
        ('saveTreeSlotDeleteTooltip', l10n.saveTreeSlotDeleteTooltip),
        ('helpSaveSlotTitle', l10n.helpSaveSlotTitle),
        ('helpSaveSlotDesc', l10n.helpSaveSlotDesc),
        ('helpAutoSaveDesc', l10n.helpAutoSaveDesc),
        ('tipsSaveSlotAutoSaveTitle', l10n.tipsSaveSlotAutoSaveTitle),
        ('tipsSaveSlotAutoSaveDesc', l10n.tipsSaveSlotAutoSaveDesc),
        ('perfSettingsSlotCountLabel', l10n.perfSettingsSlotCountLabel),
        ('perfSettingsSaveModeSlot', l10n.perfSettingsSaveModeSlot),
        ('perfSettingsQualityDescLow', l10n.perfSettingsQualityDescLow),
        ('perfSettingsQualityDescMedium', l10n.perfSettingsQualityDescMedium),
      ]) {
        if (!value.toLowerCase().contains(word)) {
          problems.add('${locale.toLanguageTag()} $key「$value」に「$word」が無い');
        }
      }
      // 中国語は、見出しと違う呼び方（存储槽・存档位〔簡体字〕、儲存槽・
      // 存檔位・儲存位〔繁体字〕。「儲存位置」〔保存先〕は別の語）をどの文にも
      // 使わない。
      final others = switch (locale) {
        Locale(languageCode: 'zh', scriptCode: 'Hant') => RegExp(
          '儲存槽|存檔位|儲存位(?!置)|存檔欄位',
        ),
        Locale(languageCode: 'zh') => RegExp('存储槽|存档位(?!置)|存档槽位'),
        _ => null,
      };
      if (others == null) continue;
      final arb = File(
        'lib/l10n/app_${locale.scriptCode == null ? locale.languageCode : '${locale.languageCode}_${locale.scriptCode}'}.arb',
      ).readAsStringSync();
      for (final entry in (jsonDecode(arb) as Map<String, dynamic>).entries) {
        if (entry.key.startsWith('@') || entry.value is! String) continue;
        final other = others.firstMatch(entry.value as String)?.group(0);
        if (other != null) {
          problems.add(
            '${locale.toLanguageTag()} ${entry.key}「${entry.value}」が'
            '「$other」と呼んでいる（見出しは「$word」）',
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}

/// スロットの見出し（「スロット1」「存档槽1」「Slot 1」）から数を除いた、
/// スロットの呼び方。
String slotWordOf(AppLocalizations l10n) =>
    l10n.saveTreeSlotLabel(1).replaceAll(RegExp(r'\s*\d+\s*'), '');
