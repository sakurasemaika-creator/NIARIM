import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/typing_aware_shortcuts.dart';

/// 画面全体のショートカットは、入力欄に入力している間は動かず（Ctrl+Z・
/// Ctrl+A等は入力欄の文字の操作になる）、入力を終えれば動く。
void main() {
  testWidgets('screen shortcuts pause while a text field has focus', (
    tester,
  ) async {
    var undo = 0;
    final field = FocusNode();
    final screen = FocusNode();
    addTearDown(field.dispose);
    addTearDown(screen.dispose);
    final controller = TextEditingController(text: 'abc');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TypingAwareShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
                undo++,
          },
          child: Focus(
            focusNode: screen,
            autofocus: true,
            child: Scaffold(
              body: TextField(focusNode: field, controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    Future<void> ctrlZ() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    await ctrlZ();
    expect(undo, 1, reason: 'no text field focused');
    field.requestFocus();
    await tester.pump();
    await ctrlZ();
    expect(undo, 1, reason: 'typing: the key belongs to the text field');
    screen.requestFocus();
    await tester.pump();
    await ctrlZ();
    expect(undo, 2);
  });

  for (final leave in ['Enter', 'unfocus']) {
    testWidgets('leaving a text field ($leave) gives the keys back to the '
        'screen', (tester) async {
      // キャンバスの色コード欄のように、入力欄が自分でフォーカスを戻さない
      // 場合も、画面のショートカットがすぐ効く（以前は画面を一度押すまで
      // 何も効かなかった）。
      var undo = 0;
      final field = FocusNode();
      final screen = FocusNode(debugLabel: 'screen');
      addTearDown(field.dispose);
      addTearDown(screen.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: TypingAwareShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyZ,
                control: true,
              ): () =>
                  undo++,
            },
            screenFocus: screen,
            child: Focus(
              focusNode: screen,
              autofocus: true,
              child: Scaffold(
                body: TextField(focusNode: field, onSubmitted: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      field.requestFocus();
      await tester.pump();
      if (leave == 'Enter') {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else {
        field.unfocus();
      }
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, screen);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(undo, 1);
    });
  }

  testWidgets('a dialog on top keeps its own focus', (tester) async {
    final screen = FocusNode(debugLabel: 'screen');
    addTearDown(screen.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TypingAwareShortcuts(
          bindings: const {},
          screenFocus: screen,
          child: Focus(
            focusNode: screen,
            autofocus: true,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(content: Text('dialog')),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final dialogFocus = FocusManager.instance.primaryFocus;
    expect(dialogFocus, isNot(screen));
    // ダイアログの中でフォーカスがスコープへ落ちても、下の画面へは戻さない。
    dialogFocus!.unfocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNot(screen));
  });

  test('Home, canvas and timeline use typing-aware screen shortcuts', () {
    for (final path in [
      'lib/screens/home/home_screen.dart',
      'lib/screens/canvas/canvas_screen.dart',
      'lib/screens/timeline/timeline_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      // 画面全体の割り当て（_buildShortcutBindings）は入力欄を避ける
      // TypingAwareShortcutsへ渡す。CallbackShortcutsへ戻すと、検索欄の
      // Ctrl+Aが作品の全選択になる等、入力欄より先にキーを取る。
      expect(source, contains('TypingAwareShortcuts(\n'), reason: path);
      expect(
        RegExp(
          r'CallbackShortcuts\(\s*bindings:\s*_buildShortcutBindings',
        ).hasMatch(source),
        isFalse,
        reason: path,
      );
      // 入力を終えたら画面のフォーカスへ戻す。
      expect(
        RegExp(
          r'TypingAwareShortcuts\(\s*bindings:\s*_buildShortcutBindings'
          r'\(context\),\s*screenFocus:',
        ).hasMatch(source),
        isTrue,
        reason: path,
      );
    }
  });
}
