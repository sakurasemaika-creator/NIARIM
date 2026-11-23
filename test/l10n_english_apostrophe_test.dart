// 英語の文のアポストロフィを ’ にそろえる（DISC597）。
//
// 英語の文で、まっすぐな ' と組版の ’ が混ざっていた（' が180か所・’ が
// 131か所。「can't」の隣に「you’re」）。仏語はすでに ’ にそろえてあり
// （l10n_french_typography_test）、Webの英語・仏語も ’ にそろえた。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test("英語の文のアポストロフィは ’ にそろえる（' を使わない）", () {
    final values =
        (jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
                as Map<String, dynamic>)
            .entries
            .where(
              (entry) => !entry.key.startsWith('@') && entry.value is String,
            );
    final offenders = [
      for (final MapEntry(:key, :value) in values)
        if ((value as String).contains("'")) '$key: $value',
    ];
    expect(
      offenders,
      isEmpty,
      reason: '${offenders.length}件:\n${offenders.take(30).join('\n')}',
    );
  });
}
