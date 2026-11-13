import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/custom_automation_builtin_presets.dart';
import 'package:niarim/utils/custom_automation_labels.dart';

/// The Tips page names the official automation presets by the names the
/// app shows for them in that language; it must list exactly the presets
/// that exist (a removed preset left in the text sends people looking for
/// something that is not there).
void main() {
  const locales = {
    'ja': Locale('ja'),
    'en': Locale('en'),
    'es': Locale('es'),
    'fr': Locale('fr'),
    'ko': Locale('ko'),
    'zh': Locale('zh'),
    'zh_Hant': Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  };
  // Each language quotes the names its own way.
  final quoted = RegExp(r'「(.+?)」|“(.+?)”|«\s?(.+?)\s?»');

  for (final MapEntry(key: name, value: locale) in locales.entries) {
    test(
      'Tips in $name name exactly the built-in automation presets',
      () async {
        final l10n = await AppLocalizations.delegate.load(locale);
        final presetNames = {
          for (final preset in CustomAutomationBuiltinPresets.all())
            customAutomationDisplayName(l10n, preset.name),
        };
        final arb =
            jsonDecode(File('lib/l10n/app_$name.arb').readAsStringSync())
                as Map<String, dynamic>;
        final text = arb['tipsOfficialAutomationPresetsDesc'] as String;
        final named = {
          for (final match in quoted.allMatches(text))
            (match.group(1) ?? match.group(2) ?? match.group(3))!,
        };
        expect(named, presetNames);
      },
    );
  }
}
