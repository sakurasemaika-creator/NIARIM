import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/filter_def.dart';

/// Every texture-filter preset has a translated name, and the Tips page
/// names exactly the presets that exist (it once listed eight that had been
/// replaced).
void main() {
  const locales = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];
  String keyOf(AuroraHologramPreset preset) =>
      'filterAuroraHologramPreset'
      '${preset.name[0].toUpperCase()}${preset.name.substring(1)}';

  for (final locale in locales) {
    test('$locale names every texture preset, in the Tips too', () {
      final arb =
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      final tip = arb['tipsTexturePrismVhsDesc'] as String;
      for (final preset in AuroraHologramPreset.values) {
        final name = arb[keyOf(preset)] as String?;
        expect(name, isNotNull, reason: 'no name for ${preset.name}');
        expect(tip, contains(name), reason: 'Tips leave out ${preset.name}');
      }
      final presetKeys = arb.keys.where(
        (key) => key.startsWith('filterAuroraHologramPreset'),
      );
      expect(presetKeys.toSet(), {
        for (final preset in AuroraHologramPreset.values) keyOf(preset),
      }, reason: 'a name for a preset that no longer exists');
    });
  }
}
