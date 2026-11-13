import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/save_tree/widgets/save_rename_button.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

/// 鉛筆で開くメモのダイアログ（保存の無いスロット・保存のあるスロット・
/// ツリーの保存の名前）は、複数行の欄でEnterが改行になり、確定できなかった
/// （同じスロットのメモを書く保存のダイアログはEnterで保存する）。メモは
/// 1行の名前として出す（スロット・ツリーの行は1行）ので改行は要らない：
/// Enterで確定し、次の画面を描く前の2回目のEnter・押下で二重に確定しない
/// （下の画面まで閉じない）。貼り付けた改行は空白にし、改行の入った前の
/// メモも語を失わずに開いて保存できる。空にして確定すればメモを消せる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
  });

  /// 端末のEnterと同じ：欄が複数行の入力（TextInputType.multiline）なら、
  /// Androidのエンジンは動作に関係なく改行を入れ（欄の動作は送らない）、
  /// Linux・Windowsのエンジンは動作が改行のときに改行を入れる。それ以外は
  /// 欄の動作（完了など）を送る。
  Future<void> pressEnter(WidgetTester tester) async {
    final args = tester.testTextInput.setClientArgs!;
    final type = (args['inputType'] as Map)['name'] as String;
    final action = TextInputAction.values.byName(
      (args['inputAction'] as String).split('.').last,
    );
    if (type == 'TextInputType.multiline') {
      final field = tester.state<EditableTextState>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(EditableText),
        ),
      );
      final value = field.textEditingValue;
      final selection = value.selection.isValid
          ? value.selection
          : TextSelection.collapsed(offset: value.text.length);
      tester.testTextInput.updateEditingValue(value.replaced(selection, '\n'));
      if (action == TextInputAction.newline) {
        await tester.testTextInput.receiveAction(action);
      }
      return;
    }
    await tester.testTextInput.receiveAction(action);
  }

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  testWidgets('the pencil memo dialog on the save slots screen takes typing '
      'at once and Enter saves the memo without a line break', (tester) async {
    final dir = Directory.systemTemp.createTempSync('niarim_memo_enter_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => dir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final ctx = tester.element(find.byType(Navigator).first);
    final saves = ctx.read<SaveTreeService>()..setTreeMode(false);
    final project = (await tester.runAsync(
      () => ctx.read<ProjectService>().createProject(
        name: 'メモ',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      ),
    ))!;
    appRouter.push('/save-tree/${project.id}?entry=projectDetail');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(Key('saveSlotMemo_${project.id}_2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(field).focusNode.hasFocus,
      isTrue,
      reason: 'typing before a click goes nowhere',
    );
    tester.testTextInput.enterText('次はここ');
    await tester.pump();
    await pressEnter(tester);
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'Enter put a line break into the memo instead of saving it',
    );
    expect(saves.slotMemoOf(project.id, 2), '次はここ');
    expect(find.text('次はここ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    appRouter.go('/');
  });

  /// 鉛筆のボタンだけを、戻れる画面（下の画面）の上に出す。
  Future<_CountingSaves> openEditor(
    WidgetTester tester, {
    String initialMemo = '',
    SaveNode? node,
  }) async {
    final saves = _CountingSaves();
    addTearDown(saves.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SaveTreeService>.value(
        value: saves,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('保存の画面')),
                        body: Center(
                          child: node == null
                              ? SaveSlotMemoButton(
                                  projectId: 'memo',
                                  slotIndex: 0,
                                  initialMemo: initialMemo,
                                )
                              : SaveRenameButton(
                                  node: node,
                                  fallbackName: '保存',
                                ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('開く'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    return saves;
  }

  testWidgets('two Enters before the next frame save the memo once and keep '
      'the screen under the dialog', (tester) async {
    final saves = await openEditor(tester);
    tester.testTextInput.enterText('線画まで');
    await tester.pump();
    await pressEnter(tester);
    await pressEnter(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saves.memoCalls, ['線画まで'], reason: 'Enter confirmed twice');
    expect(
      find.text('保存の画面'),
      findsOneWidget,
      reason: 'the second Enter closed the screen under the dialog',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('two presses of Save before the next frame save the memo once '
      'and keep the screen under the dialog', (tester) async {
    final saves = await openEditor(tester);
    tester.testTextInput.enterText('線画まで');
    await tester.pump();
    final save = find.widgetWithText(FilledButton, '保存');
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saves.memoCalls, ['線画まで']);
    expect(
      find.text('保存の画面'),
      findsOneWidget,
      reason: 'the second press closed the screen under the dialog',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pasted line breaks become spaces', (tester) async {
    final saves = await openEditor(tester);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '線画\nまで\r\n下塗り',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );
    await tester.pump();
    expect(fieldText(tester), '線画 まで 下塗り');
    await pressEnter(tester);
    await tester.pumpAndSettle();
    expect(saves.memoCalls, ['線画 まで 下塗り']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a memo saved with a line break before still opens and saves '
      'with all of its words', (tester) async {
    final saves = await openEditor(tester, initialMemo: '線画\nまで');
    expect(fieldText(tester), contains('線画'));
    expect(fieldText(tester), contains('まで'));
    await pressEnter(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saves.memoCalls, ['線画 まで']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing the memo and pressing Enter still clears it', (
    tester,
  ) async {
    final saves = await openEditor(tester, initialMemo: 'A');
    tester.testTextInput.enterText('');
    await tester.pump();
    await pressEnter(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saves.memoCalls, ['']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enter renames a save of the tree once', (tester) async {
    final node = SaveNode(
      id: 'save_1_0',
      projectId: 'memo',
      savedAt: DateTime(2026, 11, 13),
      comment: '最初',
    );
    final saves = await openEditor(tester, node: node);
    tester.testTextInput.enterText('分岐前');
    await tester.pump();
    await pressEnter(tester);
    await pressEnter(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saves.renameCalls, ['分岐前']);
    expect(find.text('保存の画面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// メモ・名前を確定した回数と中身を数える（ファイルには書かない）。
class _CountingSaves extends SaveTreeService {
  final List<String> memoCalls = [];
  final List<String> renameCalls = [];

  @override
  Future<bool> setSlotMemo(String projectId, int slotIndex, String memo) async {
    memoCalls.add(memo);
    return true;
  }

  @override
  Future<bool> renameSave(String projectId, String nodeId, String name) async {
    renameCalls.add(name);
    return true;
  }
}
