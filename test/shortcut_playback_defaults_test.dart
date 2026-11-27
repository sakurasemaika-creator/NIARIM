// 再生・一時停止・コマ送りの既定のキー（所有者の判断、2026-11-27、全部入りの
// 作品づくりの判断カードJ18）：Space・←・→。初めての端末にも、前の版から
// 使っている端末にも1度だけ足し、利用者が消したら足し直さない。
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ShortcutBinding? keyOf(ShortcutService s, ShortcutCommand command) =>
      s.bindings.where((b) => b.command == command).firstOrNull;

  test('a new installation has Space, ← and → for playback', () async {
    SharedPreferences.setMockInitialValues({});
    final s = ShortcutService();
    await s.init();
    expect(
      keyOf(s, ShortcutCommand.playPause)?.keyId,
      LogicalKeyboardKey.space.keyId,
    );
    expect(
      keyOf(s, ShortcutCommand.previousFrame)?.keyId,
      LogicalKeyboardKey.arrowLeft.keyId,
    );
    expect(
      keyOf(s, ShortcutCommand.nextFrame)?.keyId,
      LogicalKeyboardKey.arrowRight.keyId,
    );
  });

  test(
    'an earlier installation gets them once, and not again after removal',
    () async {
      // Saved before the playback keys: only undo.
      SharedPreferences.setMockInitialValues({
        'shortcut_bindings': [
          '{"id":"default_undo","label":"Undo","keyId":${LogicalKeyboardKey.keyZ.keyId},"control":true,"command":"undo"}',
        ],
      });
      final first = ShortcutService();
      await first.init();
      final play = keyOf(first, ShortcutCommand.playPause);
      expect(play, isNotNull);
      first.removeBinding(play!.id);
      await Future<void>.delayed(Duration.zero);

      final again = ShortcutService();
      await again.init();
      expect(keyOf(again, ShortcutCommand.playPause), isNull);
      expect(keyOf(again, ShortcutCommand.nextFrame), isNotNull);
    },
  );

  test('a key already used for something else is not taken', () async {
    SharedPreferences.setMockInitialValues({
      'shortcut_bindings': [
        '{"id":"mine","label":"Mine","keyId":${LogicalKeyboardKey.space.keyId},"command":"toggleLayerPanel"}',
      ],
    });
    final s = ShortcutService();
    await s.init();
    expect(keyOf(s, ShortcutCommand.playPause), isNull);
    expect(
      s.bindings.where((b) => b.keyId == LogicalKeyboardKey.space.keyId),
      hasLength(1),
    );
  });
}
