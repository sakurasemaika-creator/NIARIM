import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/screens/settings/shortcut_settings_screen.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 既定のショートカット一覧が**表示言語に追従する**ことを検証する。
///
/// 既定の割り当ては初回起動時に英語のラベル（'Undo'・'Select All'等）を
/// そのまま保存するため、一覧でそれを出すと日本語UIの中に英語だけが
/// 並ぶ（`build/all-route-screenshots/21_settings_shortcuts.png`で発覚）。
/// 一覧では`shortcutDisplayLabel`で言語ごとの名前に置き換えている。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('既定ショートカットの表示名が7言語すべてで翻訳される', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ShortcutService();
    await service.init();
    final defaults = service.bindings
        .where((b) => b.id.startsWith('default_'))
        .toList();
    expect(defaults, isNotEmpty, reason: '既定のショートカットが作られていない');

    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final binding in defaults) {
        final shown = shortcutDisplayLabel(l10n, binding);
        expect(
          shown,
          shortcutCommandLabels(l10n)[binding.command],
          reason: '$locale の表示名がコマンドの訳と一致しない',
        );
        // 日本語UIで英語のまま出ていた不具合そのものを直接押さえる
        // （英語ロケールでは訳文＝保存済みラベルなので対象外）。
        if (locale.languageCode == 'ja') {
          expect(
            shown,
            isNot(equals(binding.label)),
            reason: '"${binding.label}" が保存済みの英語ラベルのまま出ている',
          );
        }
      }
    }
  });

  test('利用者が付けた名前はそのまま出す', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ja'));
    const custom = ShortcutBinding(
      id: 'user_1234',
      label: 'わたしのショートカット',
      keyId: 0x00000061,
      command: ShortcutCommand.undo,
    );
    expect(shortcutDisplayLabel(l10n, custom), 'わたしのショートカット');
  });
}
