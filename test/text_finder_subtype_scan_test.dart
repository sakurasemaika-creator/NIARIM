import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 文を探すtestは`find.byType(Text)`ではなく`find.bySubtype<Text>()`を使う。
///
/// 語をつないで折り返す文（`KeepTogetherText`・`messageText`）は`Text`を
/// 継いだ別の型なので、`find.byType(Text)`では見つからない。見つからないと
/// 「文が出ていない」「1つだけ」を誤って確かめ、守りを外しても通った
/// （DISC256）。
void main() {
  test('no test looks for text with find.byType(Text)', () {
    final offenders = <String>[];
    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
      if (entity.path.endsWith('text_finder_subtype_scan_test.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('find.byType(Text)')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
