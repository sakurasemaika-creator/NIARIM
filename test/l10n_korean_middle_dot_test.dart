import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 韓国語・中国語の文で並べに日本語の中黒「・」（U+30FB）を使わない。
/// 韓国語は「·」（U+00B7）、中国語は「、」（英数字の間は「/」、箇条書きは
/// 「• 」）を使う。同じ言語の中で記号が混ざっていた（DISC444・450）。
void main() {
  for (final locale in ['ko', 'zh', 'zh_Hant']) {
    test('$locale strings do not use the Japanese ・ (U+30FB)', () {
      final arb =
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      final offenders = [
        for (final entry in arb.entries)
          if (!entry.key.startsWith('@') &&
              entry.value is String &&
              (entry.value as String).contains('・'))
            entry.key,
      ];
      expect(offenders, isEmpty);
    });
  }
}
