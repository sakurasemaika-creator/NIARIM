// 使用フォントに収録されていない文字が、それぞれの改変元フォントで
// 補われることを確認する。
//
// くらむぼん（8,262文字）は改変元のDela Gothic One（9,030文字）より収録
// 文字が少なく、未収録の文字はそのままだと豆腐（□）になる。テーマ側の
// fontFamilyFallbackで「Dela Gothic One → Noto Serif JP」の順に補うよう
// 配線しているため、それが将来壊れないよう固定する。
//
// 判定方法：フォールバックが効いていれば、補完側フォントで直接描いた場合と
// 同じ字幅になる。効いていなければ豆腐（.notdef）の幅になり一致しない。
// なおflutter testは既定で実フォントを読み込まない（すべて同じテスト用
// フォントで描かれ字幅に差が出ない）ため、実物をFontLoaderで登録する。
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';

Future<void> loadFont(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

double widthOf(String text, String family, {List<String>? fallback}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: 64,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadFont('Kuramubon', 'assets/fonts/Kuramubon.otf');
    await loadFont('DelaGothicOne', 'assets/fonts/DelaGothicOne-Regular.ttf');
    await loadFont('NotoSerifJP', 'assets/fonts/NotoSerifJP.ttf');
    await loadFont('HakkouMincho', 'assets/fonts/HakkouMincho.ttf');
  });

  // くらむぼんに無く、改変元のDela Gothic Oneにある文字。
  const inDelaOnly = '〖';
  // くらむぼんにもDela Gothic Oneにも無く、Noto Serif JPにある文字。
  const inNotoOnly = '丂';

  test('代替フォント列が改変元フォントを先頭に持つ', () {
    expect(kHeadingFontFallback.first, 'DelaGothicOne',
        reason: 'くらむぼんの補完は、まず改変元のDela Gothic Oneで行う');
    expect(kBodyFontFallback, contains('NotoSerifJP'),
        reason: '白光明朝の補完には改変元のNoto Serif JPを含める');
  });

  testWidgets('くらむぼん未収録の文字が改変元のDela Gothic Oneで補われる',
      (WidgetTester tester) async {
    final fallbackWidth =
        widthOf(inDelaOnly, 'Kuramubon', fallback: kHeadingFontFallback);
    final directWidth = widthOf(inDelaOnly, 'DelaGothicOne');
    final noFallbackWidth = widthOf(inDelaOnly, 'Kuramubon');

    expect(fallbackWidth, closeTo(directWidth, 0.5),
        reason: 'Dela Gothic Oneで描いた場合と字幅が一致しない＝補われていない');
    expect(fallbackWidth, isNot(closeTo(noFallbackWidth, 0.5)),
        reason: 'フォールバック有無で字幅が同じ＝そもそも補完が起きていない');
  });

  testWidgets('本文用スタックではDela Gothic Oneにも無い文字がNoto Serif JPで補われる',
      (WidgetTester tester) async {
    final fallbackWidth =
        widthOf(inNotoOnly, 'Kuramubon', fallback: kBodyFontFallback);
    final directWidth = widthOf(inNotoOnly, 'NotoSerifJP');
    expect(fallbackWidth, closeTo(directWidth, 0.5),
        reason: 'Noto Serif JPで描いた場合と字幅が一致しない＝補われていない');
  });

  testWidgets('コード中で直接くらむぼんを指定した箇所もテーマから代替フォントを継承する',
      (WidgetTester tester) async {
    // アプリ全体で187箇所ある`TextStyle(fontFamily: 'Kuramubon')`のような
    // 直接指定は、fontFamilyFallbackを書いていなくても祖先のテキスト
    // スタイルから継承される。テーマ側の並びが正しければ全箇所が
    // 自動的に補われる、という前提を固定する。
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            fontFamily: 'HakkouMincho',
            fontFamilyFallback: kBodyFontFallback,
          ),
        ),
      ),
      home: const Scaffold(
        body: Text(inDelaOnly, style: TextStyle(fontFamily: 'Kuramubon')),
      ),
    ));
    final richText = tester.widget<RichText>(find.byType(RichText).first);
    final resolved = (richText.text as TextSpan).style!;
    expect(resolved.fontFamily, 'Kuramubon');
    expect(resolved.fontFamilyFallback, kBodyFontFallback,
        reason: '直接指定した箇所が代替フォント列を引き継げていない');
  });
}
