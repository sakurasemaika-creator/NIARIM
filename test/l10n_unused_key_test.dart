// ARBに「どこからも参照されていない文言」が溜まらないようにする。
//
// 未使用キーはコンパイルエラーにならないため、画面の作り直しや名称変更の
// たびに静かに残り続ける。文言が増えるとサブセットフォント
// （tool/build_fallback_fonts.py）に含める文字も増えるので、放置すると
// APKサイズにも効いてくる。
//
// 判定は「識別子としてDartソースのどこかに現れるか」という緩い基準。
// `AppLocalizations.of(context)!.key` のような書き方も拾えるようにするため
// で、コメント内の言及も使用扱いになる。緩い側に倒しているのは、
// 実際に使っているキーを誤って未使用と判定して消すほうが害が大きいため。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ARBのキーはすべてどこかのDartソースから参照されている', () {
    final arb = jsonDecode(
      File('lib/l10n/app_ja.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final keys = arb.keys.where((k) => !k.startsWith('@')).toList();

    final buffer = StringBuffer();
    for (final dir in ['lib', 'test', 'tool']) {
      final root = Directory(dir);
      if (!root.existsSync()) continue;
      for (final f in root.listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        // 生成物（app_localizations*.dart）は全キーを含むので除外する。
        if (f.path.contains('lib/l10n/app_localizations')) continue;
        buffer.writeln(f.readAsStringSync());
      }
    }
    final words = RegExp(r'[A-Za-z_][A-Za-z0-9_]*')
        .allMatches(buffer.toString())
        .map((m) => m.group(0)!)
        .toSet();

    final unused = keys.where((k) => !words.contains(k)).toList();
    expect(
      unused,
      isEmpty,
      reason: '未使用のARBキーが${unused.length}件あります。'
          '画面へ配線するか、7言語すべてのARBから削除してください：$unused',
    );
  });
}
