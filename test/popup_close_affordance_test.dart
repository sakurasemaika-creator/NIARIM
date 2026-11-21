import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ポップアップの「閉じる」×の置き方を機械的に見張る。
///
/// 閉じるボタンをダイアログ右上へ統一する一括変換
/// （`.github/scripts/standardize_popup_close.py`）は、×を
/// `AlertDialog`の`icon:`スロットへ入れる実装だった。ところが
/// Flutterの`AlertDialog`は**`icon`があるとタイトルを強制的に中央寄せ**に
/// する（`dialog.dart`の
/// `textAlign: icon == null ? TextAlign.start : TextAlign.center`）ため、
/// 変換した13ダイアログだけタイトルが中央寄せになり、他と不揃いになる。
/// あわせて、取り除いた閉じるボタンの跡に`actions: []`が残ると、
/// `AlertDialog`は空のアクション領域ぶんの余白を描いてしまう
/// （下部に無駄な空白が出る）。
///
/// どちらもダイアログ監査のPNGで実際に確認した見た目の後退なので、
/// 再発しないようソースを走査して検出する。
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('閉じる×はicon:スロットではなくタイトル行に置く', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('popup-standard-close')) continue;
        final window = lines
            .sublist(i, (i + 8).clamp(0, lines.length))
            .join('\n');
        if (window.contains('icon: Align(') ||
            window.contains('iconPadding:')) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'AlertDialogのicon:スロットへ×を入れるとタイトルが中央寄せになる。'
          'title: Row(...)の右端へ置くこと',
    );
  });

  test('空のactionsを残さない（下部に無駄な余白が出る）', () {
    final pattern = RegExp(r'actions: (?:const )?(?:<Widget>)?\[\]');
    final offenders = <String>[];
    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'actions自体を書かないこと');
  });
}
