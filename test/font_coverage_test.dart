// 7言語すべてのUI文言が、同梱フォントだけで表示できることを確認する。
//
// アプリは7言語（ja/en/es/fr/ko/zh/zh_Hant）に対応しているが、同梱している
// 日本語系フォントはハングルと簡体字を持たない。補わないとこれらは端末の
// システムフォント任せになり、端末ごとに見た目が変わって明朝で統一した
// 意匠が崩れる（ハングルを持たない端末では豆腐になる）。
//
// 【重要1】カバー判定は本文用スタックと見出し用スタックで**別々に**行う。
// 2つは別のフォントスタックなので、片方が持っていてももう片方の字抜けは
// 埋まらない。和集合で判定すると見落とす。
//
// 【重要2】cmapはUnicodeのサブテーブルだけを読む。cmapにはMacintosh用の
// レガシーサブテーブル（platformID=1）が同居していることがあり、そこの
// コード値はUnicodeではないマルチバイトコードなので、Unicodeとして数えると
// 「収録していない字を収録済み」と誤判定する（公式サイト側でこれにより
// 91字が欠落する不具合を起こした）。
//
// lib/l10n/*.arb へ文言を追加したあとにフォントの再生成
// （tool/build_fallback_fonts.py）を忘れると、このテストが落ちる。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';

/// フォントのcmapから収録文字（コードポイント）を取り出す。
/// Unicodeサブテーブル（platformID=0、またはplatformID=3かつ
/// encodingID=1/10）のみを対象にする。
Set<int> cmapCodePoints(String path) {
  final bytes = ByteData.sublistView(File(path).readAsBytesSync());
  final tableStart = _tagAt(bytes, 0) == 0x74746366 /* 'ttcf' */
      ? bytes.getUint32(12)
      : 0;
  final numTables = bytes.getUint16(tableStart + 4);
  var cmapOffset = -1;
  for (var i = 0; i < numTables; i++) {
    final rec = tableStart + 12 + i * 16;
    if (_tagAt(bytes, rec) == 0x636D6170 /* 'cmap' */) {
      cmapOffset = bytes.getUint32(rec + 8);
      break;
    }
  }
  if (cmapOffset < 0) return <int>{};

  final result = <int>{};
  final numSubtables = bytes.getUint16(cmapOffset + 2);
  for (var i = 0; i < numSubtables; i++) {
    final rec = cmapOffset + 4 + i * 8;
    final platformId = bytes.getUint16(rec);
    final encodingId = bytes.getUint16(rec + 2);
    final isUnicode =
        platformId == 0 || (platformId == 3 && (encodingId == 1 || encodingId == 10));
    if (!isUnicode) continue;
    final sub = cmapOffset + bytes.getUint32(rec + 4);
    switch (bytes.getUint16(sub)) {
      case 4:
        result.addAll(_format4(bytes, sub));
      case 12:
        result.addAll(_format12(bytes, sub));
    }
  }
  return result;
}

int _tagAt(ByteData b, int offset) => b.getUint32(offset);

Set<int> _format4(ByteData b, int o) {
  final out = <int>{};
  final segCountX2 = b.getUint16(o + 6);
  final segCount = segCountX2 ~/ 2;
  final endsAt = o + 14;
  final startsAt = endsAt + segCountX2 + 2;
  final deltasAt = startsAt + segCountX2;
  final rangesAt = deltasAt + segCountX2;
  for (var i = 0; i < segCount; i++) {
    final end = b.getUint16(endsAt + i * 2);
    final start = b.getUint16(startsAt + i * 2);
    final delta = b.getInt16(deltasAt + i * 2);
    final rangeOffset = b.getUint16(rangesAt + i * 2);
    for (var c = start; c <= end && c != 0xFFFF; c++) {
      int glyph;
      if (rangeOffset == 0) {
        glyph = (c + delta) & 0xFFFF;
      } else {
        final gi = rangesAt + i * 2 + rangeOffset + (c - start) * 2;
        if (gi + 2 > b.lengthInBytes) continue;
        glyph = b.getUint16(gi);
        if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
      }
      if (glyph != 0) out.add(c);
    }
  }
  return out;
}

Set<int> _format12(ByteData b, int o) {
  final out = <int>{};
  final numGroups = b.getUint32(o + 12);
  for (var i = 0; i < numGroups; i++) {
    final g = o + 16 + i * 12;
    final start = b.getUint32(g);
    final end = b.getUint32(g + 4);
    if (end - start > 200000) continue;
    for (var c = start; c <= end; c++) {
      out.add(c);
    }
  }
  return out;
}

/// フォント名（pubspec.yamlのfamily）からアセットのパスを引く。
const Map<String, String> _fontFiles = {
  'HakkouMincho': 'assets/fonts/HakkouMincho.ttf',
  'Kuramubon': 'assets/fonts/Kuramubon.otf',
  'NotoSerifJP': 'assets/fonts/NotoSerifJP.ttf',
  'DelaGothicOne': 'assets/fonts/DelaGothicOne-Regular.ttf',
  'NotoSerifKRSubset': 'assets/fonts/NotoSerifKRSubset.ttf',
  'NotoSerifSCSubset': 'assets/fonts/NotoSerifSCSubset.ttf',
  'NotoSansKRBlackSubset': 'assets/fonts/NotoSansKRBlackSubset.ttf',
  'NotoSansSCBlackSubset': 'assets/fonts/NotoSansSCBlackSubset.ttf',
};

Set<int> coverageOf(List<String> stack) {
  final out = <int>{};
  for (final family in stack) {
    final path = _fontFiles[family];
    if (path == null) {
      throw StateError('$family のフォントファイルが_fontFilesに登録されていない');
    }
    out.addAll(cmapCodePoints(path));
  }
  return out;
}

/// ARBから画面に出る文字を集める。{count}のようなプレースホルダーは
/// 実文字ではないので除く。
Set<int> uiCharsOf(File arb) {
  final data = json.decode(arb.readAsStringSync()) as Map<String, dynamic>;
  final buffer = StringBuffer();
  data.forEach((key, value) {
    if (key.startsWith('@') || value is! String) return;
    buffer.write(value.replaceAll(RegExp(r'\{[^}]*\}'), ''));
  });
  return buffer
      .toString()
      .runes
      .where((r) => r > 0x20)
      .toSet();
}

void main() {
  // 記号・絵文字は本文用フォントの担当範囲ではなく、端末の絵文字フォントが
  // 受け持つ（元のNotoフォントにも入っていない）。判定から除く。
  const symbolsHandledBySystem = <int>{
    0x21BA, // ↺ 反時計回りの矢印
    0x2733, // ✳ 八方向アスタリスク
    0x2757, // ❗ 感嘆符
  };

  // cmapの読み取りは重いので一度だけ行う。
  late final Set<int> bodyCoverage;
  late final Set<int> headingCoverage;
  setUpAll(() {
    bodyCoverage = coverageOf([...kBodyFontFallback, 'HakkouMincho']);
    headingCoverage = coverageOf([...kHeadingFontFallback, 'Kuramubon']);
  });

  final arbs = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('検証対象のARBが7言語ぶんある', () {
    expect(arbs.length, 7, reason: '対応言語が増減している');
  });

  for (final arb in arbs) {
    final name = arb.uri.pathSegments.last;

    test('$name のUI文言を本文用フォントだけで表示できる', () {
      final missing = uiCharsOf(arb)
        ..removeAll(bodyCoverage)
        ..removeAll(symbolsHandledBySystem);
      expect(
        missing,
        isEmpty,
        reason: '本文用スタックに無い文字: '
            '${String.fromCharCodes(missing.take(30))}\n'
            'tool/build_fallback_fonts.py でフォントを再生成してください',
      );
    });

    test('$name のUI文言を見出し用フォントだけで表示できる', () {
      final missing = uiCharsOf(arb)
        ..removeAll(headingCoverage)
        ..removeAll(symbolsHandledBySystem);
      expect(
        missing,
        isEmpty,
        reason: '見出し用スタックに無い文字: '
            '${String.fromCharCodes(missing.take(30))}\n'
            'tool/build_fallback_fonts.py でフォントを再生成してください',
      );
    });
  }

  test('見出し用の代替フォントに明朝が混ざっていない', () {
    // 極太ゴシックの中に細い明朝が混ざると、同じ単語の中で浮いてしまう
    // （「550엔」のように極太の数字と細い明朝のハングルが並ぶ）。
    for (final family in kHeadingFontFallback) {
      expect(family.toLowerCase().contains('serif'), isFalse,
          reason: '見出し用の代替フォントに明朝($family)が入っている');
    }
  });
}
