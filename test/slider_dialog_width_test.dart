import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// スライダーを置くダイアログは横に広げる（`SizedBox(width: 480)`）。
///
/// `AlertDialog`は既定で幅280pxしかなく、スライダー本体が100px前後しか
/// 残らなかった（タイムラインの「〇〇クリップを追加」の開始・長さ、透かしの
/// 角度など）。`AlertDialog(`の括弧の中に`Slider(`か`LabeledSlider(`があれば、
/// 同じ括弧の中に`width: 480`があることを確かめる。
void main() {
  test('dialogs holding a slider are widened to 480', () {
    final slider = RegExp(r'\b(?:Labeled)?Slider\(');
    final wide = RegExp(r'width:\s*480\b');
    final narrow = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in RegExp(r'\bAlertDialog\(').allMatches(source)) {
        var depth = 1;
        var i = match.end;
        while (depth > 0 && i < source.length) {
          final char = source[i];
          if (char == '(') depth++;
          if (char == ')') depth--;
          i++;
        }
        final body = source.substring(match.start, i);
        if (slider.hasMatch(body) && !wide.hasMatch(body)) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          narrow.add('${entity.path}:${line + 1}');
        }
      }
    }
    expect(narrow, isEmpty);
  });
}
