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
const Map<String, Map<String, String>> _allowed = {};

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

  test('ホームの画面の文言の欄に英語の直書きが無い', () {
    // Text(…)・tooltip:・title: 等へ英語の文を直に書くと、日本語以外の
    // どの言語でも英語のまま出る（「Change thumbnail」「Restore from Trash」が
    // 実際にそうなっていた）。かな・漢字の見張りでは見つからない。
    final slot = RegExp(
      r"(\bText\(|\b(tooltip|title|subtitle|label|message|semanticsLabel|"
      r"hintText|labelText|helperText|suffixText|prefixText|content):)"
      r'''\s*(const\s+)?(Text\(\s*)?(['"])((?:(?!\5)[^\\]|\\.)*)\5''',
    );
    final interpolation = RegExp(r'\$\{[^}]*\}|\$[A-Za-z_]\w*');
    final latinWord = RegExp('[A-Za-z]{2,}');
    // 訳さない固有名詞だけ。
    const properNouns = {'NIARIM'};
    final offenders = <String>[];
    for (final file in _homeFiles()) {
      final source = file.readAsStringSync();
      for (final match in slot.allMatches(source)) {
        final start = source.lastIndexOf('\n', match.start) + 1;
        if (source.substring(start, match.start).trimLeft().startsWith('//')) {
          continue;
        }
        final text = match.group(6)!;
        if (properNouns.contains(text) ||
            !latinWord.hasMatch(text.replaceAll(interpolation, ''))) {
          continue;
        }
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        offenders.add('${file.path}:${line + 1}  $text');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '画面の文言はARBへ追加し、7言語すべてに手で訳を入れること:\n'
          '${offenders.join('\n')}',
    );
  });

  test('ホームの画面で言語コードの手書きの表を作らない', () {
    // 'ja' / 'zh' で分ける表は、繁体字（zh_Hant）が簡体字になり、スペイン語・
    // フランス語が英語になる。ARBへ足すこと。
    final offenders = <String>[];
    // languageCode・toLanguageTag()・localeName との比較、startsWith、
    // switch の case と switch 式の分岐のどれで分けても見つける。
    final table = RegExp(
      r"(languageCode|toLanguageTag\(\)|localeName|toString\(\))\s*[!=]=\s*"
      r"'(ja|zh|ko|en|es|fr)([-_][A-Za-z]+)?'"
      r"|\.startsWith\(\s*'(ja|zh|ko|en|es|fr)([-_][A-Za-z]+)?'\s*\)"
      r"|\bcase\s+'(ja|zh|ko|en|es|fr)([-_][A-Za-z]+)?'"
      r"|^\s*'(ja|ko|zh|en|es|fr)([-_][A-Za-z]+)?'\s*(=>|:)",
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
