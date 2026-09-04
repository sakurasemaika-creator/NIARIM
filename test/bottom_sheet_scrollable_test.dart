import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `showModalBottomSheet`で**件数が可変の一覧**を出しているのに、
/// スクロールできる形になっていない箇所が無いことを、ソースを走査して検証する。
///
/// `showModalBottomSheet`は既定で画面高の**9/16**（360x760の端末で約427dp）
/// までしか高さを取らない。`Column(mainAxisSize: min)`のまま項目を並べると、
/// 7〜8件を超えた時点で`RenderFlex overflowed`になり、**下の項目が縞模様で
/// 潰れて選べなくなる**。
///
/// 実際に踏んだ2件（どちらも`test/dialog_screenshot_audit_test.dart`が
/// 実画面を焼いたときに発覚）：
/// - ジェスチャー設定の割り当てシート：選択肢9件で77pxオーバーフロー
/// - クイックツールの「追加」シート：組み込みブラシ15件で**654px**
///   オーバーフロー。ブラシの大半が選べない状態だった
///
/// 件数が固定の短いシートでも、あとから項目が増えると同じことが起きる
/// （組み込みブラシは実際に増やされた）。`for (final x in ...)`で
/// 展開しているシートは必ずスクロール可能にすること
/// （`lib/widgets/scrollable_sheet_body.dart`の`ScrollableSheetBody`で包む）。
void main() {
  test('可変長の一覧を出すボトムシートは必ずスクロールできる', () {
    final offenders = <String>[];

    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      var searchFrom = 0;
      while (true) {
        final start = source.indexOf('showModalBottomSheet', searchFrom);
        if (start < 0) break;
        searchFrom = start + 1;

        // builderの中身を、次の`showModalBottomSheet`か十分な文字数までで
        // 切り出す（厳密な構文解析はしない。行数で切ると長いシートを
        // 取りこぼすため、次の出現位置までを見る）。
        final next = source.indexOf('showModalBottomSheet', start + 1);
        final end = next < 0
            ? source.length
            : (next < start + 4000 ? next : start + 4000);
        final body = source.substring(start, end);

        // 件数が可変＝コレクションをforで展開している、かどうか。
        final hasDynamicList = RegExp(r'for \(final \w+ in ').hasMatch(body);
        if (!hasDynamicList) continue;

        // スクロールできる形になっているか。
        final scrollable =
            body.contains('ScrollableSheetBody') ||
            body.contains('SingleChildScrollView') ||
            body.contains('ListView') ||
            body.contains('DraggableScrollableSheet') ||
            body.contains('isScrollControlled: true');
        if (scrollable) continue;

        final line = '\n'.allMatches(source.substring(0, start)).length + 1;
        offenders.add('${file.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '件数が可変の一覧をスクロールできないボトムシートで出している箇所がある。\n'
          'ScrollableSheetBodyで包むこと（下の項目が選べなくなる）:\n'
          '${offenders.join('\n')}',
    );
  });
}
