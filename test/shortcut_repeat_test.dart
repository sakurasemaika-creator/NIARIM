import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/shortcut_binding.dart';

/// キーを押し続けたときの繰り返しで実行し直すのは、取り消し・やり直しと
/// コマ送りだけ。貼り付け・全選択等を繰り返すと、ホームでCtrl+Vを押し
/// 続けただけで作品の複製が次々にできていた。
void main() {
  ShortcutBinding binding({
    ShortcutCommand? command,
    String? toolKey,
    String? automationId,
  }) => ShortcutBinding(
    id: 'b',
    label: 'b',
    keyId: LogicalKeyboardKey.keyV.keyId,
    control: true,
    command: command,
    toolKey: toolKey,
    automationId: automationId,
  );

  const repeat = KeyRepeatEvent(
    physicalKey: PhysicalKeyboardKey.keyV,
    logicalKey: LogicalKeyboardKey.keyV,
    timeStamp: Duration.zero,
  );

  test('only undo, redo and frame stepping repeat while a key is held', () {
    for (final command in ShortcutCommand.values) {
      final repeats = binding(command: command).activator.includeRepeats;
      expect(
        repeats,
        ShortcutBinding.repeatableCommands.contains(command),
        reason: '$command',
      );
    }
    expect(ShortcutBinding.repeatableCommands, {
      ShortcutCommand.undo,
      ShortcutCommand.redo,
      ShortcutCommand.previousFrame,
      ShortcutCommand.nextFrame,
    });
    expect(binding(toolKey: 'pen').activator.includeRepeats, isFalse);
    expect(binding(automationId: 'a').activator.includeRepeats, isFalse);
  });

  testWidgets('a held paste key does not fire again', (tester) async {
    final paste = binding(command: ShortcutCommand.paste).activator;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    expect(paste.accepts(repeat, HardwareKeyboard.instance), isFalse);
    final undo = binding(command: ShortcutCommand.undo).activator;
    expect(undo.accepts(repeat, HardwareKeyboard.instance), isTrue);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  });
}
