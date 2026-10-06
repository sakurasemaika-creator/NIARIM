import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/custom_automation_builtin_presets.dart';

/// The Tips page names the official automation presets by their shipped
/// names; it must list exactly the presets that exist (a removed preset left
/// in the text sends people looking for something that is not there).
void main() {
  const locales = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  final presetNames = {
    for (final preset in CustomAutomationBuiltinPresets.all()) preset.name,
  };

  for (final locale in locales) {
    test('Tips in $locale name exactly the built-in automation presets', () {
      final arb =
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      final text = arb['tipsOfficialAutomationPresetsDesc'] as String;
      final named = {
        for (final match in RegExp(r'「(.+?)」').allMatches(text))
          match.group(1)!,
      };
      expect(named, presetNames);
    });
  }
}
