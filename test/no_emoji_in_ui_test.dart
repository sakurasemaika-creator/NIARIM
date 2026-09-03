import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// アプリ内の文言に**絵文字を混ぜない**という方針を機械的に守るテスト。
///
/// 意味を表す記号はすべてMaterialアイコン（`Icon(Icons.xxx)`）で表す。
/// 絵文字は端末・OSバージョン・フォント設定によって字形も色も大きく変わり、
/// 同梱フォント（Kuramubon・HakkouMincho・Notoサブセット）にも入っていない
/// ため、アプリの他の文字から明らかに浮く。過去に
/// - 素材一覧の「⚠ 不足」
/// - ヘルプ本文の「更新マーク（❗）」
/// が混ざっていて、どちらもアイコン表現へ置き換えた。
///
/// 対象は7言語のARB（＝実際に画面へ出る文言）。ソースコードのコメントに
/// 出てくる「→」等の記号は画面に出ないので対象外。
void main() {
  /// 画面に出ると浮く「絵文字」の範囲。矢印（→）や約物は含めない。
  bool isEmoji(int rune) =>
      (rune >= 0x1F000 && rune <= 0x1FAFF) || // 各種絵文字
      (rune >= 0x1F1E6 && rune <= 0x1F1FF) || // 国旗
      const {
        0x2764, // ❤
        0x2B50, // ⭐
        0x2705, // ✅
        0x274C, // ❌
        0x2757, // ❗
        0x2753, // ❓
        0x26A0, // ⚠
        0x26A1, // ⚡
        0x2728, // ✨
        0x231B, // ⌛
        0x23F0, // ⏰
      }.contains(rune) ||
      rune == 0xFE0F; // 絵文字表示への異体字セレクタ

  test('7言語のARBの文言に絵文字が含まれていない', () {
    final offenders = <String>[];
    for (final file in Directory('lib/l10n').listSync().whereType<File>()) {
      if (!file.path.endsWith('.arb')) continue;
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in json.entries) {
        // "@キー" はメタ情報（description等）で画面には出ない。
        if (entry.key.startsWith('@')) continue;
        final value = entry.value;
        if (value is! String) continue;
        final found = value.runes.where(isEmoji).toList();
        if (found.isEmpty) continue;
        final chars = found.map(String.fromCharCode).toSet().join();
        offenders.add(
          '${file.path.split('/').last} の ${entry.key}: [$chars]  "$value"',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'アプリ内の文言に絵文字が含まれている。'
          'Icon(Icons.xxx)へ置き換えること:\n${offenders.join('\n')}',
    );
  });
}
