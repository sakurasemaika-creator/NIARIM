import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/l10n/autofill_names.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new users receive the built-in gray underpaint preset', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AutofillPresetService();
    await service.init();

    final preset = service.presets.firstWhere(
      (item) => item.id == 'builtin_gray_underpaint',
    );
    expect(preset.name, 'グレー単色の下塗り');
    expect(preset.parts, hasLength(1));
    expect(preset.parts.single.name, '下塗り');
    expect(preset.parts.single.color, 0xFF808080);
  });

  test(
    'existing user presets are preserved while missing built-in is added',
    () async {
      const custom = AutofillPreset(
        id: 'user_custom',
        name: '自作プリセット',
        parts: [AutofillPart(id: 'user_part', name: '自作', color: 0xFF123456)],
      );
      SharedPreferences.setMockInitialValues({
        'autofill_presets': [jsonEncode(custom.toJson())],
      });

      final service = AutofillPresetService();
      await service.init();

      expect(service.presets.where((p) => p.id == 'user_custom'), hasLength(1));
      expect(
        service.presets.where((p) => p.id == 'builtin_gray_underpaint'),
        hasLength(1),
      );
    },
  );
  test('locale labels leave saved names and explicit renames intact', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AutofillPresetService();
    await service.init();
    addTearDown(service.dispose);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('autofill_presets');
    final lead = service.presets.singleWhere((p) => p.id == 'p1');
    final english = lookupAppLocalizations(const Locale('en'));
    final japanese = lookupAppLocalizations(const Locale('ja'));
    expect(lead.displayName(english), 'Protagonist');
    expect(lead.displayName(japanese), '主人公');
    expect(lead.parts.first.displayName(english), 'Hair');
    expect(lead.parts[1].displayName(english), 'Hair shadow 1');
    expect(lead.parts.first.displayName(japanese), '髪');

    for (final locale in AppLocalizations.supportedLocales) {
      final labels = lookupAppLocalizations(locale);
      for (final preset in service.presets) {
        expect(preset.displayName(labels), isNotEmpty);
        for (final part in preset.parts) {
          expect(part.displayName(labels), isNotEmpty);
        }
      }
      if (locale.languageCode != 'ja') {
        expect(
          lead.parts.first.displayName(labels),
          isNot(lead.parts.first.name),
        );
      }
    }
    expect(prefs.getStringList('autofill_presets'), saved);

    // From the English UI, the user can deliberately choose the Japanese
    // spelling even though it equals the originally saved default.
    await service.updatePreset(
      lead.copyWith(
        name: '主人公',
        nameCustomized: true,
        parts: [
          lead.parts.first.copyWith(name: '髪', nameCustomized: true),
          ...lead.parts.skip(1),
        ],
      ),
    );
    final restarted = AutofillPresetService();
    addTearDown(restarted.dispose);
    await restarted.init();
    final renamed = restarted.presets.singleWhere((p) => p.id == lead.id);
    expect(renamed.displayName(english), '主人公');
    expect(renamed.parts.first.displayName(english), '髪');
    expect(renamed.parts[1].displayName(english), 'Hair shadow 1');

    const imported = AutofillPreset(id: 'shared', name: '主人公');
    expect(imported.displayName(english), '主人公');
    const legacy = AutofillPreset(id: 'p1', name: 'My sample');
    expect(legacy.displayName(japanese), 'My sample');
  });
}
