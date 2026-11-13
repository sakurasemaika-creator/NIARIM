// ホーム・作品広場以外で、画面や画像に出る文を「日本語か、それ以外は英語」の
// 手書きの表で持っていたファイルを見張る（所有者の判断10「すべて多言語対応
// させてください」）。
//
// 見張るもの：
// - かな・漢字・ハングルの文字列リテラル（コメントは対象外）
// - `ja ? '…' : '…'` のように言語で分ける手書きの表と、その下請けの
//   `String t(String j, String e)`
// - 文の欄（Text(…)・tooltip:・label: 等）への英語の直書き
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'community_no_hardcoded_text_test.dart' show stringLiterals;

/// 見張るファイル。ここに足したファイルは、文をすべてARBから引くこと。
const List<String> _guardedFiles = [
  'lib/screens/settings/theme_preview_gallery_screen.dart',
];

/// かな・漢字・ハングル・全角記号。
final RegExp _cjk = RegExp(r'[　-ヿ㐀-䶿一-鿿가-힯＀-￯]');

/// コメントを除いたソース（文字列リテラルの中身はそのまま残す）。
String _withoutComments(String source) {
  final out = StringBuffer();
  var i = 0;
  String? quote;
  while (i < source.length) {
    final c = source[i];
    if (quote != null) {
      out.write(c);
      if (c == r'\' && i + 1 < source.length) {
        out.write(source[i + 1]);
        i += 2;
        continue;
      }
      if (source.startsWith(quote, i)) {
        out.write(source.substring(i + 1, i + quote.length));
        i += quote.length;
        quote = null;
        continue;
      }
      i++;
      continue;
    }
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      i = end < 0 ? source.length : end + 2;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = source.startsWith(c * 3, i) ? c * 3 : c;
      out.write(quote);
      i += quote.length;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

void main() {
  test('見張るファイルにARBを通らないかな・漢字・ハングルの文字列が無い', () {
    final offenders = <String>[];
    for (final path in _guardedFiles) {
      for (final (line, text) in stringLiterals(
        File(path).readAsStringSync(),
      )) {
        if (_cjk.hasMatch(text)) offenders.add('$path:$line  $text');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '文はARBへ足し、AppLocalizationsから引くこと（7言語すべてに手で'
          '訳を入れる）:\n${offenders.join('\n')}',
    );
  });

  test('見張るファイルで「日本語か英語か」の手書きの表を作らない', () {
    // `ja ? '…' : '…'`・`japanese ? …`・`isJapanese ? …` と、表を引く下請けの
    // `String t(String j, String e)`。言語コードの比較で分ける表も見る。
    final table = RegExp(
      r"\b(ja|japanese|isJapanese|isJa)\s*\?\s*['"
      '"'
      r"]"
      r"|\bString\s+\w+\(\s*String\s+\w+\s*,\s*String\s+\w+\s*\)\s*=>\s*"
      r"(ja|japanese|isJapanese|isJa)\s*\?"
      r"|(languageCode|toLanguageTag\(\)|localeName)\s*[!=]=\s*"
      r"'(ja|zh|ko|en|es|fr)([-_][A-Za-z]+)?'",
    );
    final offenders = <String>[];
    for (final path in _guardedFiles) {
      final source = _withoutComments(File(path).readAsStringSync());
      for (final match in table.allMatches(source)) {
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        offenders.add('$path:${line + 1}  ${match.group(0)!.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('見張るファイルの文の欄に英語の直書きが無い', () {
    final slot = RegExp(
      r"(\bText\(|\b(tooltip|title|subtitle|label|message|semanticsLabel|"
      r"hintText|labelText|helperText|suffixText|prefixText|content):)"
      r'''\s*(const\s+)?(Text\(\s*)?(['"])((?:(?!\5)[^\\]|\\.)*)\5''',
    );
    final interpolation = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_]\w*');
    final latinWord = RegExp('[A-Za-z]{2,}');
    // 訳さない固有名詞・形式名と、本物の画面がどの言語でも同じに出すもの。
    const properNouns = {
      'NIARIM',
      'MP4',
      'GIF',
      'AVI',
      // 新規プロジェクト・プロジェクト詳細の本物の画面も「FPS」のまま。
      'FPS',
      // 本物のシーンの既定の名前（Scene.displayName）。見本はそれに合わせる。
      'Scene1',
    };
    final offenders = <String>[];
    for (final path in _guardedFiles) {
      final source = _withoutComments(File(path).readAsStringSync());
      for (final match in slot.allMatches(source)) {
        final text = match.group(6)!;
        if (properNouns.contains(text) ||
            !latinWord.hasMatch(text.replaceAll(interpolation, ''))) {
          continue;
        }
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        offenders.add('$path:${line + 1}  $text');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
