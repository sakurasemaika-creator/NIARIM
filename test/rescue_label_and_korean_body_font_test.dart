// 救済ボタンのラベルと、韓国語の本文の代替書体を見張る。
//
// - 救済ボタン「テーマをもとに戻す」はボタンなので、ほかのボタンと同じく
//   見出しの書体（日本語などはくらむぼん、中国語・韓国語はその言語の書体）で
//   描く。以前は書体の指定が無く、テーマの本文（白光明朝）で描かれていた。
// - 韓国語の本文の部分フォントに無い字（利用者が打つ全角英数字・かな・漢字）は
//   明朝で補う。以前は先頭の極太のDela Gothic Oneが描き、作品名「ＡＢＣ全角」の
//   「ＡＢＣ」だけが極太だった。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/theme_rescue_button.dart';

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

/// Dark pixels of [text] drawn at 64px: the extra-bold face has far more ink
/// than the Mincho face, while full-width glyphs have the same advance in both.
Future<int> _inkOf(
  WidgetTester tester,
  String text,
  String family, {
  List<String>? fallback,
}) async {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: 64,
        color: const Color(0xFF000000),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset.zero);
  final width = painter.width.ceil();
  final height = painter.height.ceil();
  painter.dispose();
  final picture = recorder.endRecording();
  final bytes = await tester.runAsync(() async {
    final image = await picture.toImage(width, height);
    final data = await image.toByteData();
    image.dispose();
    return data!;
  });
  picture.dispose();
  var ink = 0;
  for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
    if (bytes.getUint8(i) > 128) ink++;
  }
  return ink;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFont('HakkouMincho', 'assets/fonts/HakkouMincho.ttf');
    await _loadFont('DelaGothicOne', 'assets/fonts/DelaGothicOne-Regular.ttf');
    await _loadFont('NotoSerifKRSubset', 'assets/fonts/NotoSerifKRSubset.ttf');
  });

  for (final (code, family, fallback) in [
    ('ja', 'Kuramubon', kHeadingFontFallback),
    ('fr', 'Kuramubon', kHeadingFontFallback),
    ('ko', 'NotoSerifKRSubset', kKoreanBodyFontFallback),
    ('zh', 'NotoSerifSCSubset', kChineseBodyFontFallback),
  ]) {
    testWidgets('the rescue button label uses the button face ($code)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(fontFamily: 'HakkouMincho'),
          home: const Scaffold(body: Center(child: ThemeRescueButton())),
        ),
      );
      await tester.pumpAndSettle();
      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(ThemeRescueButton),
              matching: find.byType(Text),
            ),
          )
          .toList();
      expect(labels, hasLength(2), reason: 'outline and fill');
      for (final label in labels) {
        expect(label.style?.fontFamily, family);
        expect(label.style?.fontFamilyFallback, fallback);
      }
    });
  }

  test('Korean body text falls back to the Mincho face first', () {
    expect(bodyFontFallbackFor(const Locale('ko')).first, 'HakkouMincho');
    expect(
      bodyFontFallbackFor(const Locale('ko')),
      isNot(contains('NotoSerifKRSubset')),
    );
  });

  testWidgets(
    'full-width Latin typed in Korean body text is drawn in Mincho, not the '
    'extra-bold face',
    (tester) async {
      const typed = 'ＡＢＣ';
      final korean = await _inkOf(
        tester,
        typed,
        bodyFontFamilyFor(const Locale('ko')),
        fallback: bodyFontFallbackFor(const Locale('ko')),
      );
      final mincho = await _inkOf(tester, typed, 'HakkouMincho');
      final extraBold = await _inkOf(tester, typed, 'DelaGothicOne');
      expect(
        extraBold,
        greaterThan(mincho * 3 ~/ 2),
        reason: 'the two faces must differ for this check to mean anything',
      );
      expect(korean, mincho);
    },
  );
}
