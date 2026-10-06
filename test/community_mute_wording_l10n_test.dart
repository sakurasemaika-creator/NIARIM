import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The display filters' mute entries must not read like blocking a user:
/// in Chinese 「屏蔽」/「封鎖」 is the word the plaza uses for the block
/// button, so the mute labels use 「静音」/「靜音」 instead. Their hints say
/// what is matched and that entries can be separated by more than ASCII
/// commas.
void main() {
  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('Chinese mute labels are distinct from the block wording', () {
    final zh = arb('zh');
    final hant = arb('zh_Hant');
    expect(zh['communityWorkDetailBlockButton'], '屏蔽');
    expect(hant['communityWorkDetailBlockButton'], '封鎖');
    for (final key in ['communityMutedWords', 'communityMutedTags']) {
      expect(zh[key], startsWith('静音'), reason: 'zh $key');
      expect(hant[key], startsWith('靜音'), reason: 'zh_Hant $key');
    }
    for (final key in [
      'communityMutedWords',
      'communityMutedWordsHint',
      'communityMutedTags',
      'communityMutedTagsHint',
    ]) {
      expect(zh[key], isNot(contains('屏蔽')), reason: 'zh $key');
      expect(hant[key], isNot(contains('封鎖')), reason: 'zh_Hant $key');
    }
  });

  test('the hints name the separators beyond the ASCII comma', () {
    final ja = arb('ja');
    for (final key in ['communityMutedWordsHint', 'communityMutedTagsHint']) {
      expect(ja[key], contains('「、」'), reason: key);
      expect(ja[key], contains('改行'), reason: key);
    }
    expect(arb('zh')['communityMutedWordsHint'], contains('顿号'));
    expect(arb('zh_Hant')['communityMutedWordsHint'], contains('頓號'));
    for (final locale in ['en', 'es', 'fr', 'ko']) {
      final hint = arb(locale)['communityMutedWordsHint'] as String;
      expect(hint.toLowerCase(), isNot(startsWith('comma-separated')));
    }
  });

  test('the help covers the display filters in every locale', () {
    for (final locale in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
      final help = arb(locale)['helpCommunityDesc'] as String;
      final aiLabel = arb(locale)['communityContainsGenerativeAiImageVideo'];
      expect(help, contains(aiLabel), reason: locale);
      expect(help, contains('#'), reason: locale);
    }
    expect(arb('ja')['helpCommunityDesc'], contains('「AI画像・AI動画使用」'));
  });
}
