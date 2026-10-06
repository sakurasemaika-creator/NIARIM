// 作品広場の画面に、7言語化されていない日本語の文字列リテラルが
// 残っていないことを確認する。
//
// 画面に出る文言はARB（lib/l10n/app_*.arb）から引くこと。日本語を直書きすると
// 他の6言語でも日本語のまま表示される。例外やステータス文字列を経由して
// 画面に出るもの（`_error = '…'`、`throw StateError('…')`等）も同じ。
//
// コメント中の日本語は対象外。文字列リテラルだけを、Dartの字句
// （コメント・raw文字列・三重引用符・`${}`内の入れ子の文字列）を
// たどって取り出して判定する。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 画面には出ない識別子として日本語を使っているもの（ファイル名→文字列）。
const Map<String, Map<String, String>> _allowed = {
  'community_screen.dart': {
    // HelpButton(topic:)の値はヘルプ項目の照合キー（help_screen.dartの
    // _HelpEntry.topicKey）で、表示文言はARBのhelpCommunityTitleから引く。
    '作品広場': 'ヘルプ項目の照合キー',
  },
};

final RegExp _japanese = RegExp(r'[぀-ヿ㐀-䶿一-鿿]');

/// [source]中の文字列リテラル（の中身）を、出現した行番号とともに返す。
List<(int, String)> stringLiterals(String source) =>
    (_LiteralScanner(source)..readCode(closeOnBrace: false)).literals;

class _LiteralScanner {
  _LiteralScanner(this.source);

  final String source;
  final List<(int, String)> literals = [];
  int i = 0;

  static final RegExp _identifierChar = RegExp(r'[A-Za-z0-9_$]');

  int _lineOf(int offset) =>
      '\n'.allMatches(source.substring(0, offset)).length + 1;

  bool _at(String s) => source.startsWith(s, i);

  /// コード部分を読み進める。[closeOnBrace]がtrueなら、対応の取れない`}`
  /// （文字列補間`${...}`の終わり）で止まる。
  void readCode({required bool closeOnBrace}) {
    var depth = 0;
    while (i < source.length) {
      final c = source[i];
      if (_at('//')) {
        final end = source.indexOf('\n', i);
        i = end < 0 ? source.length : end + 1;
      } else if (_at('/*')) {
        _skipBlockComment();
      } else if (c == "'" || c == '"') {
        _readString(raw: false);
      } else if (c == 'r' &&
          i + 1 < source.length &&
          (source[i + 1] == "'" || source[i + 1] == '"') &&
          (i == 0 || !_identifierChar.hasMatch(source[i - 1]))) {
        i++;
        _readString(raw: true);
      } else if (c == '{') {
        depth++;
        i++;
      } else if (c == '}') {
        i++;
        if (closeOnBrace && depth == 0) return;
        depth--;
      } else {
        i++;
      }
    }
  }

  /// Dartのブロックコメントは入れ子にできる。
  void _skipBlockComment() {
    var nest = 0;
    while (i < source.length) {
      if (_at('/*')) {
        nest++;
        i += 2;
      } else if (_at('*/')) {
        nest--;
        i += 2;
        if (nest == 0) return;
      } else {
        i++;
      }
    }
  }

  /// [i]は開き引用符を指している。
  void _readString({required bool raw}) {
    final start = i;
    final quote = source[i];
    final close = _at(quote * 3) ? quote * 3 : quote;
    i += close.length;
    final buffer = StringBuffer();
    while (i < source.length) {
      if (_at(close)) {
        i += close.length;
        break;
      }
      final c = source[i];
      if (!raw && c == r'\') {
        buffer.write(source.substring(i, i + 2));
        i += 2;
      } else if (!raw && _at(r'${')) {
        i += 2;
        readCode(closeOnBrace: true);
      } else {
        buffer.write(c);
        i++;
      }
    }
    literals.add((_lineOf(start), buffer.toString()));
  }
}

void main() {
  test('字句解析：コメントを除き、補間内の入れ子の文字列も拾う', () {
    final literals = stringLiterals('''
// '日本語のコメント'
/* '/* 入れ子 */' */
final a = 'ok';
final b = "外\${f('内側')}";
final c = r'raw\\';
final d = """三重""";
''').map((e) => e.$2).toList();
    expect(literals, unorderedEquals(['ok', '外', '内側', r'raw\', '三重']));
  });

  test('作品広場の画面に日本語の文字列リテラルが残っていない', () {
    final files =
        Directory('lib/screens/community')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);

    final offenders = <String>[];
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final allowed = _allowed[name] ?? const <String, String>{};
      for (final (line, text) in stringLiterals(file.readAsStringSync())) {
        if (!_japanese.hasMatch(text) || allowed.containsKey(text)) continue;
        offenders.add('$name:$line  $text');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '画面の文言はARBへ追加し、AppLocalizationsから引いてください'
          '（7言語すべてに手で訳を入れること）:\n${offenders.join('\n')}',
    );
  });

  test('許可リストの文字列は実際にソースに残っている', () {
    for (final MapEntry(key: name, value: allowed) in _allowed.entries) {
      final file = Directory('lib/screens/community')
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere((f) => f.uri.pathSegments.last == name);
      final literals = stringLiterals(
        file.readAsStringSync(),
      ).map((e) => e.$2).toSet();
      for (final text in allowed.keys) {
        expect(
          literals,
          contains(text),
          reason: '$name の「$text」は不要になったので許可リストから外す',
        );
      }
    }
  });
}
