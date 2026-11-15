// メニュー・シートの「ゴミ箱へ移動」の項目を、`colorScheme.error`で書かないことの
// 見張り（ソースの走査）。
//
// `colorScheme.error`は差し色から作られる色で、テーマ・外観で選ぶ色ではない。
// メニューを暗くした自作テーマでは、暗いメニューに暗い赤（#BA1A1A、2.2:1）で
// 書かれて読みにくかった（A003の3周目）。項目名はメニューの文字色のまま、
// 危ない操作であることは先頭のアイコン（Icons.delete_outline）と文で伝える。
// 実際の色は home_a003_visual_findings_test の「ゴミ箱へ移動」の見張りが
// 本物のアプリで確かめる。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// [source]の[start]の「(」に対応する「)」までの中身。
String _callBody(String source, int start) {
  var depth = 0;
  for (var i = start; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  return source.substring(start);
}

void main() {
  test('メニュー・シートの「ゴミ箱へ移動」はエラーの色で書かず、印のアイコンを付ける', () {
    final labels = RegExp(
      r'l10n\.(homeMoveToTrash|projectDetailTrashMenuItem)\b|\bdeleteLabel\b',
    );
    final items = RegExp(r'\b(PopupMenuItem|ListTile)(<[^>(]*>)?\(');
    final offenders = <String>[];
    var checked = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in items.allMatches(source)) {
        final body = _callBody(source, match.end - 1);
        if (!labels.hasMatch(body)) continue;
        checked++;
        final line = source.substring(0, match.start).split('\n').length;
        final where = '${file.path}:$line';
        if (body.contains('.error')) offenders.add('$where uses .error');
        if (!body.contains('Icons.delete_outline')) {
          offenders.add('$where has no Icons.delete_outline');
        }
      }
    }
    expect(checked, greaterThanOrEqualTo(8), reason: 'items found: $checked');
    expect(offenders, isEmpty);
  });
}
