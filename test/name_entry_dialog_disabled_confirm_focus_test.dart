import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/name_entry_dialog.dart';

/// 名前が空のときに押せない「変更」をマウス・ペンで押しても、入力欄から
/// フォーカスが外れない（続けて打った名前が欄に入る）。以前は押せない
/// ボタンも「欄の外」として欄のフォーカスを外し、続けて打った字はどこにも
/// 入らなかった。押せるときに押して確定できなかった（保存の失敗）ときも、
/// 欄のまま打ち直せる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> open(
    WidgetTester tester, {
    String initialName = '',
    Future<void> Function(String name)? onSubmit,
  }) async {
    final submitted = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => NameEntryDialog(
                    title: 'Rename',
                    confirmLabel: 'Change',
                    cancelLabel: 'Cancel',
                    initialName: initialName,
                    failureText: (_) => 'Could not rename',
                    onSubmit: onSubmit ?? (name) async => submitted.add(name),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return submitted;
  }

  bool fieldHasFocus(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.stylus]) {
    testWidgets('the disabled confirm button keeps the field focused '
        '(${kind.name})', (tester) async {
      final submitted = await open(tester);
      expect(fieldHasFocus(tester), isTrue);
      final confirm = find.widgetWithText(FilledButton, 'Change');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(confirm, kind: kind);
      await tester.pumpAndSettle();
      expect(
        fieldHasFocus(tester),
        isTrue,
        reason: 'the click on the disabled button took the focus',
      );
      // 続けて打った名前が欄に入り、確定できる。
      tester.testTextInput.enterText('Sketches');
      await tester.pump();
      expect(find.text('Sketches'), findsOneWidget);
      await tester.tap(confirm, kind: kind);
      await tester.pumpAndSettle();
      expect(submitted, ['Sketches']);
      expect(find.byType(NameEntryDialog), findsNothing);
    });
  }

  testWidgets('after a failed confirm the field stays focused (mouse)', (
    tester,
  ) async {
    await open(
      tester,
      initialName: 'Old',
      onSubmit: (_) async => throw StateError('disk full'),
    );
    final confirm = find.widgetWithText(FilledButton, 'Change');
    await tester.tap(confirm, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Could not rename'), findsOneWidget);
    expect(fieldHasFocus(tester), isTrue);
    tester.testTextInput.enterText('New');
    await tester.pump();
    expect(find.text('New'), findsOneWidget);
  });
}
