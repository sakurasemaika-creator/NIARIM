// ホームの画面（lib/screens/home/**）に、ARBを通らない日本語・中国語・韓国語の
// 文字列リテラルが残っていないことを見張る。
//
// 画面の文言はARB（lib/l10n/app_*.arb）へ足し、AppLocalizationsから引くこと。
// languageCodeで分けた手書きの表（日本語・英語だけ、または繁体字が簡体字に
// なる表）がホームに何度も入り込んでいたため、文字列リテラルそのものを禁止
// する。コメントの中の日本語は対象外（字句をたどって文字列だけを取り出す）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'community_no_hardcoded_text_test.dart' show stringLiterals;

/// かな・漢字・ハングル・全角記号（「・」「、」を含む）。
final RegExp _cjk = RegExp(r'[　-ヿ㐀-䶿一-鿿가-힯＀-￯]');

/// まだ直していないもの（ファイル名 → 文字列 → 理由）。直したら外すこと。
const Map<String, Map<String, String>> _allowed = {
  'home_screen.dart': {
    // 複製の名前の言語は、貼り付けの件数の内訳（所有者の判断6）と一緒に
    // 別の単位で直す。
    ' (コピー)': '複製の名前（判断6の単位で直す）',
    r'$sourceName (コピー)': '複製の名前（判断6の単位で直す）',
    r'$sourceName (コピー $number)': '複製の名前（判断6の単位で直す）',
    r'/$name (コピー $counter)$ext': '複製の名前（判断6の単位で直す）',
    r'/$stem (コピー $n)$extension': '複製の名前（判断6の単位で直す）',
  },
};

List<File> _homeFiles() =>
    Directory('lib/screens/home')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('ホームの画面にARBを通らないかな・漢字・ハングルの文字列が無い', () {
    final files = _homeFiles();
    expect(files, isNotEmpty);
    final offenders = <String>[];
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final allowed = _allowed[name] ?? const <String, String>{};
      for (final (line, text) in stringLiterals(file.readAsStringSync())) {
        if (!_cjk.hasMatch(text) || allowed.containsKey(text)) continue;
        offenders.add('${file.path}:$line  $text');
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

  test('ホームの許可リストの文字列は実際にソースに残っている', () {
    final files = _homeFiles();
    for (final MapEntry(key: name, value: allowed) in _allowed.entries) {
      final file = files.firstWhere((f) => f.uri.pathSegments.last == name);
      final literals = stringLiterals(
        file.readAsStringSync(),
      ).map((e) => e.$2).toSet();
      for (final text in allowed.keys) {
        expect(
          literals,
          contains(text),
          reason: '$name の「$text」は直ったので許可リストから外す',
        );
      }
    }
  });

  test('ホームの画面で言語コードの手書きの表を作らない', () {
    // 'ja' / 'zh' で分ける表は、繁体字（zh_Hant）が簡体字になり、スペイン語・
    // フランス語が英語になる。ARBへ足すこと。
    final offenders = <String>[];
    final table = RegExp(
      r"languageCode\s*==\s*'(ja|zh|ko|en|es|fr)'|^\s*'(ja|ko|zh|es|fr)'\s*=>",
      multiLine: true,
    );
    for (final file in _homeFiles()) {
      final source = file.readAsStringSync();
      for (final match in table.allMatches(source)) {
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        offenders.add('${file.path}:${line + 1}  ${match.group(0)!.trim()}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
