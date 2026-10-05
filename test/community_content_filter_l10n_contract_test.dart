import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community content-filter wording is present in all seven locales', () {
    const files = [
      'app_ja.arb',
      'app_en.arb',
      'app_es.arb',
      'app_fr.arb',
      'app_ko.arb',
      'app_zh.arb',
      'app_zh_Hant.arb',
    ];
    for (final name in files) {
      final json =
          jsonDecode(File('lib/l10n/$name').readAsStringSync())
              as Map<String, dynamic>;
      expect(
        json['communityContainsGenerativeAiImageVideo'],
        isNotEmpty,
        reason: name,
      );
      expect(
        json['communityHideGenerativeAiImageVideo'],
        isNotEmpty,
        reason: name,
      );
      expect(json['communityMutedWords'], isNotEmpty, reason: name);
      expect(json['communityMutedWordsHint'], isNotEmpty, reason: name);
      expect(json['communityMutedTags'], isNotEmpty, reason: name);
      expect(json['communityMutedTagsHint'], isNotEmpty, reason: name);
    }

    final ja =
        jsonDecode(File('lib/l10n/app_ja.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(ja['communityContainsGenerativeAiImageVideo'], 'AI画像・AI動画使用');
    expect(ja['communityMutedWords'], 'ミュートタイトル登録');
    expect(ja['communityMutedTags'], 'ミュートタグ登録');
  });
}
