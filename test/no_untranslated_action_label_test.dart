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

  test('画面の文言・接尾辞・ヒントに日本語を直書きしていない', () {
    // `Text('日本語')`・`suffixText: '枚'`等。英語や韓国語等の表示でも日本語の
    // まま出る（フレームの一括追加の題名と「枚」、新規作成の「秒」が実際に
    // そうなっていた）。
    final pattern = RegExp(
      r"(Text\(|suffixText:|prefixText:|hintText:|labelText:|helperText:|"
      r"tooltip:|semanticsLabel:|message:)\s*'[^']*"
      r"[\u3040-\u30ff\u4e00-\u9fff][^']*'",
    );
    final offenders = <String>[];
    for (final dir in ['lib/screens', 'lib/widgets']) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trimLeft().startsWith('//')) continue;
          if (pattern.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: '文言はARBへ足してl10n経由で出すこと:\n${offenders.join('\n')}',
    );
  });
}
