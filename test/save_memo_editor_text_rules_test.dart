import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/save_node.dart';
import 'package:niarim/screens/save_tree/widgets/save_rename_button.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 鉛筆で開くメモのダイアログの文字の決まり（DISC101の残り）。
/// - メモは1行の名前なので、`\r`・`\n`だけでなく、行・段落の区切り
///   （U+2028・U+2029・U+0085）や縦タブ・改ページも空白にする（残すと、
///   1行の行にはメモの前半しか出ない）。
/// - 保存のダイアログ（字数の上限なし）で100字より長く付けた名前は、
///   鉛筆のダイアログで1字直しただけで100字に切らない。
/// - ツリーの保存の名前は空にできないので、空の間は「保存」を押せず、
///   Enterでも閉じない（以前は確定したように閉じ、何も変わらず何も
///   言わなかった）。スロットのメモは空にして消せる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'language': 'ja'});
  });

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

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  SaveNode treeSave(String name) => SaveNode(
    id: 'save_1_0',
    projectId: 'memo',
    savedAt: DateTime(2026, 11, 13),
    comment: name,
  );

  const separators = {
    'U+2028': ' ',
    'U+2029': ' ',
    'U+0085': '\u0085',
    'U+000B': '\u000B',
    'U+000C': '\u000C',
  };

  testWidgets('pasted Unicode line and paragraph separators become spaces, '
      'so the memo is one line in the one-line rows', (tester) async {
    final saves = await openEditor(tester);
    final pasted = '線画${separators.values.join('まで')}下塗り';
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: pasted,
        selection: TextSelection.collapsed(offset: pasted.length),
      ),
    );
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final memo = saves.memoCalls.single;
    for (final MapEntry(key: name, value: separator) in separators.entries) {
      expect(memo.contains(separator), isFalse, reason: '$name survived');
    }
    expect(memo, '線画 まで まで まで まで 下塗り');
    // 1行の行（スロット・ツリーの行と同じmaxLines: 1）にメモ全体が出る。
    final painter = TextPainter(
      text: TextSpan(text: memo),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 4000);
    expect(painter.computeLineMetrics(), hasLength(1));
    painter.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a memo saved with a Unicode line separator before opens as '
      'one line with all of its words', (tester) async {
    final saves = await openEditor(tester, initialMemo: '線画 まで\u0085下塗り');
    expect(fieldText(tester), '線画 まで 下塗り');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(saves.memoCalls, ['線画 まで 下塗り']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a save name longer than 100 characters keeps all of its '
      'characters when one is deleted, and the counter shows it is long', (
    tester,
  ) async {
    final long = '${'線画' * 60}X'; // 121字（保存のダイアログには上限が無い）
    final saves = await openEditor(tester, node: treeSave(long));
    expect(fieldText(tester).characters.length, 121);
    // 最後の「X」を1字消す。
    final shorter = long.substring(0, long.length - 1);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: shorter,
        selection: TextSelection.collapsed(offset: shorter.length),
      ),
    );
    await tester.pump();
    expect(
      fieldText(tester),
      shorter,
      reason: 'one deleted character cut the name to 100 characters',
    );
    // 上限より長いことは欄の数（エラーの色）で見える。
    final decorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(decorator.decoration.errorText, isNotNull);
    expect(find.text('120/100'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(saves.renameCalls, [shorter]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a name of 100 characters or fewer still stops at 100', (
    tester,
  ) async {
    await openEditor(tester, node: treeSave('最初'));
    tester.testTextInput.enterText('線' * 130);
    await tester.pump();
    expect(fieldText(tester).characters.length, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tree save cannot be renamed to blank: Save is disabled, '
      'Enter keeps the dialog open, and nothing is renamed', (tester) async {
    final saves = await openEditor(tester, node: treeSave('最初'));
    final save = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '保存'),
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    tester.testTextInput.enterText('   ');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(save).onPressed,
      isNull,
      reason: 'Save can be pressed with a blank name',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: 'a blank name closed the dialog as if it was saved',
    );
    expect(saves.renameCalls, isEmpty);
    // 名前を打ち直せば保存できる。
    tester.testTextInput.enterText('分岐前');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(saves.renameCalls, ['分岐前']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slot memo can still be cleared with a blank text', (
    tester,
  ) async {
    final saves = await openEditor(tester, initialMemo: 'A');
    final save = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, '保存'),
    );
    tester.testTextInput.enterText('');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saves.memoCalls, ['']);
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
