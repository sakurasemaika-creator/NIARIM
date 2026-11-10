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
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';

import 'helpers/load_app_fonts.dart';

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
    if (_tagAt(bytes, rec) == 0x636D6170 /* 'cmap' */ ) {
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
        platformId == 0 ||
        (platformId == 3 && (encodingId == 1 || encodingId == 10));
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
  return buffer.toString().runes.where((r) => r > 0x20).toSet();
}

/// lib/l10nに手で書いたDartのファイル（生成物のapp_localizations*.dartは
/// 除く）の文字列リテラルから、画面に出うる文字を集める。
///
/// ARBの外に訳を持つラベル表（`*_labels.dart`）はARBの検査に入らず、
/// tool/build_fallback_fonts.py もかつては読まなかったため、簡体字の
/// 「币」「奖」やハングルの「혜」などが同梱フォントに無いまま画面に出ていた。
/// コメントは画面に出ないので除く。
Set<int> handWrittenL10nCharsOf(File dart) {
  final code = dart
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
  final literals = RegExp(
    r"'(?:[^'\\\n]|\\.)*'"
    '|'
    r'"(?:[^"\\\n]|\\.)*"',
  ).allMatches(code);
  final buffer = StringBuffer();
  for (final literal in literals) {
    final text = literal.group(0)!;
    buffer.write(
      text
          .substring(1, text.length - 1)
          .replaceAll(RegExp(r'\{[^}]*\}'), '')
          .replaceAll(RegExp(r'\\.'), ''),
    );
  }
  return buffer.toString().runes.where((r) => r > 0x20).toSet();
}

/// lib/l10nの手書きのDartファイル（生成物を除く）。
List<File> handWrittenL10nFiles() =>
    Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.uri.pathSegments.last.startsWith('app_localizations'),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// lib配下の手書きのDartファイル（lib/l10nの生成物を除く）すべて。
List<File> handWrittenLibFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.uri.pathSegments.last.startsWith('app_localizations'),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// 画面に何も描かれない字（空白・書式の制御文字・結合記号）。インクが
/// 無くて当然なので、インクの検査から除く。
final _invisible = RegExp(r'[\s\p{Cf}\p{Mn}\p{Me}]', unicode: true);

/// [runes]を1字ずつ[family]（代替は[fallback]）で描き、インクが1画素も
/// 出ない字を返す。
///
/// cmapに載っていても字形が空のことがある（くらむぼんの「＋」は空の字形で、
/// cmapに載っているので代替フォントにも回らず、見出しの「全機能＋全広告なし」
/// の「＋」が空白になっていた）。cmapだけでは見つからないので実際に描く。
Future<Set<int>> inklessRunes(
  List<int> runes, {
  required String family,
  required List<String> fallback,
}) async {
  const columns = 64;
  const cell = 40;
  final rows = (runes.length + columns - 1) ~/ columns;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var i = 0; i < runes.length; i++) {
    final builder =
        ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: family, fontSize: 20))
          ..pushStyle(
            ui.TextStyle(
              color: const ui.Color(0xFF000000),
              fontFamily: family,
              fontFamilyFallback: fallback,
              fontSize: 20,
            ),
          )
          ..addText(String.fromCharCode(runes[i]));
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: cell * 1.0));
    canvas.drawParagraph(
      paragraph,
      ui.Offset((i % columns) * cell + 8.0, (i ~/ columns) * cell + 6.0),
    );
    paragraph.dispose();
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(columns * cell, rows * cell);
  picture.dispose();
  final pixels = (await image.toByteData())!;
  final width = image.width;
  image.dispose();
  final inkless = <int>{};
  for (var i = 0; i < runes.length; i++) {
    final x0 = (i % columns) * cell;
    final y0 = (i ~/ columns) * cell;
    var ink = false;
    for (var y = y0; y < y0 + cell && !ink; y++) {
      for (var x = x0; x < x0 + cell; x++) {
        if (pixels.getUint8((y * width + x) * 4 + 3) > 0) {
          ink = true;
          break;
        }
      }
    }
    if (!ink) inkless.add(runes[i]);
  }
  return inkless;
}

/// くらむぼん（見出し用）がcmapに載せていながら空の字形で描く字。
/// 見出し・題・ボタン・メニューでは使わず、ASCIIの「+」等にすること。
const _kuramubonEmptyGlyphs = <int>{
  0xFF0B, // ＋
  0x2460, 0x2461, 0x2462, 0x2463, 0x2464, // ①〜⑤
  0x9760, // 靠
};

/// [_kuramubonEmptyGlyphs]の字を含むが、本文の書体（白光明朝）でだけ出す
/// 文言（説明・ヒント・空の一覧の案内・チュートリアルの手順・規約の本文）。
/// 見出しの書体で出す文言をここへ足してはいけない（その字が空白になる）。
const _bodyOnlyKeysWithEmptyHeadingGlyphs = <String>{
  'autofillPartEmpty',
  'autofillPresetEmptyHint',
  'colorPickerPaletteEmptyHint',
  'communityFloatingPreviewMoveHint',
  'filterFisheyeCanvasHint',
  'filterSphereCanvasHint',
  'helpDrawingFilterDesc',
  'helpHomeScreenDesc',
  'helpLayerDesc',
  'helpLayerGroupDesc',
  'helpWatermarkEntryDesc',
  'helpWorkspaceSettingsDesc',
  'licenseTermsArt10Body',
  'pcWorkspaceLayoutIntroHint',
  'projectListEmptyHint',
  'stampPixelModeHint',
  'timelineEffectFilterEmptyState',
  'timelineStackOrderHint',
  'timelineStackRangeOrderHint',
  'tipsFisheyeChromaticDesc',
  'tipsLeftHandedWorkspaceDesc',
  'tipsPcDexLayoutDesc',
  'tipsRoughLayerRescueDesc',
  'tipsSaveSlotAutoSaveDesc',
  'tipsSphereShadingDesc',
  'tutorialPage2Step1',
  'tutorialPage4Step2',
  'watermarkEmptyHint',
};

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

  final arbs =
      Directory('lib/l10n')
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
        reason:
            '本文用スタックに無い文字: '
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
        reason:
            '見出し用スタックに無い文字: '
            '${String.fromCharCodes(missing.take(30))}\n'
            'tool/build_fallback_fonts.py でフォントを再生成してください',
      );
    });
  }

  final handWritten = handWrittenL10nFiles();

  test('手書きのDartファイルから文字列の字だけを集め、生成物は数えない', () {
    final dir = Directory.systemTemp.createTempSync('l10n_literals');
    addTearDown(() => dir.deleteSync(recursive: true));
    final sample = File('${dir.path}/sample_labels.dart')
      ..writeAsStringSync(
        "// 註釈の字は画面に出ない\n"
        "const a = {'zh': '金币', 'ko': \"혜택 {n}\"};\n"
        "const b = 'it\\'s';\n",
      );
    final chars = String.fromCharCodes(handWrittenL10nCharsOf(sample));
    for (final shown in ['金', '币', '혜', '택', 'i', 't', 's']) {
      expect(chars, contains(shown));
    }
    for (final hidden in ['註', '釈', 'n', '{']) {
      expect(chars, isNot(contains(hidden)));
    }
    expect(
      handWritten.map((f) => f.uri.pathSegments.last),
      everyElement(isNot(startsWith('app_localizations'))),
    );
  });

  for (final dart in handWritten) {
    final name = dart.uri.pathSegments.last;

    test('$name の文言を本文用フォントだけで表示できる', () {
      final missing = handWrittenL10nCharsOf(dart)
        ..removeAll(bodyCoverage)
        ..removeAll(symbolsHandledBySystem);
      expect(
        missing,
        isEmpty,
        reason:
            '本文用スタックに無い文字: '
            '${String.fromCharCodes(missing.take(30))}\n'
            '文言はARB（lib/l10n/app_*.arb）へ移し、'
            'tool/build_fallback_fonts.py でフォントを再生成してください',
      );
    });

    test('$name の文言を見出し用フォントだけで表示できる', () {
      final missing = handWrittenL10nCharsOf(dart)
        ..removeAll(headingCoverage)
        ..removeAll(symbolsHandledBySystem);
      expect(
        missing,
        isEmpty,
        reason:
            '見出し用スタックに無い文字: '
            '${String.fromCharCodes(missing.take(30))}\n'
            '文言はARB（lib/l10n/app_*.arb）へ移し、'
            'tool/build_fallback_fonts.py でフォントを再生成してください',
      );
    });
  }

  test('lib配下の手書きのDartファイルの文字列を、両方のスタックで表示できる', () {
    // lib/l10nの外にも、7言語の文を手で書いた表があった（プライバシー
    // ポリシーの「学習データとして利用しない」条項。ハングルの「델」「학」、
    // 簡体字の「训」「练」がどの同梱フォントにも無かった）。
    // 文言はARBへ移すこと（tool/build_fallback_fonts.py はARBとlib/l10nだけを
    // 読むので、ほかの場所の字はサブセットに入らない）。
    final missing = <String>[];
    for (final file in handWrittenLibFiles()) {
      final chars = handWrittenL10nCharsOf(file)
        ..removeAll(symbolsHandledBySystem);
      final notBody = chars.difference(bodyCoverage);
      final notHeading = chars.difference(headingCoverage);
      if (notBody.isEmpty && notHeading.isEmpty) continue;
      missing.add(
        '${file.path}: 本文用に無い ${String.fromCharCodes(notBody)} / '
        '見出し用に無い ${String.fromCharCodes(notHeading)}',
      );
    }
    expect(
      missing,
      isEmpty,
      reason:
          '${missing.join('\n')}\n'
          '文言はARB（lib/l10n/app_*.arb）へ移し、'
          'tool/build_fallback_fonts.py でフォントを再生成してください',
    );
  });

  testWidgets('UIの字は、本文用・見出し用のどちらで描いてもインクが出る', (tester) async {
    await loadAppFonts(tester);
    final runes = <int>{
      for (final arb in arbs) ...uiCharsOf(arb),
      for (final dart in handWritten) ...handWrittenL10nCharsOf(dart),
    }..removeAll(symbolsHandledBySystem);
    runes.removeWhere((r) => _invisible.hasMatch(String.fromCharCode(r)));
    final sorted = runes.toList()..sort();
    expect(sorted.length, greaterThan(1000), reason: '字を集められていない');

    final body = (await tester.runAsync(
      () => inklessRunes(
        sorted,
        family: 'HakkouMincho',
        fallback: kBodyFontFallback,
      ),
    ))!;
    expect(body, isEmpty, reason: '本文用で空白になる字: ${String.fromCharCodes(body)}');

    final heading = (await tester.runAsync(
      () => inklessRunes(
        sorted,
        family: 'Kuramubon',
        fallback: kHeadingFontFallback,
      ),
    ))!;
    expect(
      heading.difference(_kuramubonEmptyGlyphs),
      isEmpty,
      reason:
          '見出し用で空白になる字（新しく見つかった）: '
          '${String.fromCharCodes(heading.difference(_kuramubonEmptyGlyphs))}',
    );

    // 見出し用で空白になる字は、本文の書体でだけ出す文言にしか使わない。
    final headingUses = <String>[];
    for (final arb in arbs) {
      final data = json.decode(arb.readAsStringSync()) as Map<String, dynamic>;
      data.forEach((key, value) {
        if (key.startsWith('@') || value is! String) return;
        if (_bodyOnlyKeysWithEmptyHeadingGlyphs.contains(key)) return;
        final empty = value.runes.where(heading.contains).toSet();
        if (empty.isEmpty) return;
        headingUses.add(
          '${arb.uri.pathSegments.last} $key: ${String.fromCharCodes(empty)}',
        );
      });
    }
    expect(
      headingUses,
      isEmpty,
      reason:
          'くらむぼんで空白になる字を使っている（見出し・ボタン・メニューなら'
          'ASCIIの「+」等にする。本文の書体でだけ出すなら一覧に足す）:\n'
          '${headingUses.join('\n')}',
    );
  });

  test('見出し用の代替フォントに明朝が混ざっていない', () {
    // 極太ゴシックの中に細い明朝が混ざると、同じ単語の中で浮いてしまう
    // （「550엔」のように極太の数字と細い明朝のハングルが並ぶ）。
    for (final family in kHeadingFontFallback) {
      expect(
        family.toLowerCase().contains('serif'),
        isFalse,
        reason: '見出し用の代替フォントに明朝($family)が入っている',
      );
    }
  });
}
