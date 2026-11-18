import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 韓国語の文で並べに日本語の中黒「・」（U+30FB）を使わない。韓国語では
/// 「·」（U+00B7）を使い、同じアプリの中で2つが混ざっていた（DISC444）。
void main() {
  test('Korean strings use · (U+00B7), not the Japanese ・ (U+30FB)', () {
    final arb =
        jsonDecode(File('lib/l10n/app_ko.arb').readAsStringSync())
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
