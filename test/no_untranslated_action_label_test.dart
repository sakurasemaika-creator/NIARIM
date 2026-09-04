import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 画面の「名前を返す関数」で、l10nを使わずに**文字列を直書き**している
/// 箇所が無いことを見張る。
///
/// ジェスチャー設定・ペン入力設定の一覧が
/// `GestureAction.undo => 'Undo'` と直書きされていたため、日本語UIの
/// 一覧に「Undo」「Redo」だけ英語で並んでいた
/// （`build/all-route-screenshots/16_settings_gestures.png`で発覚）。
/// 同じ形の書き方が増えたら落ちるようにしておく。
void main() {
  test('switch式の分岐で表示名を直書きしていない', () {
    // `Enum.value => '文字列',` の形。表示名はl10nから取るのが決まり。
    final pattern = RegExp(r"^\s*[A-Za-z_]+\.[A-Za-z_]+ => '[^']+',\s*$");
    final offenders = <String>[];
    for (final dir in ['lib/screens', 'lib/widgets']) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: '表示名はARBへ足してl10n経由で出すこと:\n${offenders.join('\n')}',
    );
  });
}
