import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/services/theme_service.dart';

import 'font_coverage_test.dart' show cmapCodePoints;
import 'helpers/load_app_fonts.dart';

/// Every family in a text style's fallback list is loaded the first time text
/// in that style is laid out, and stays in memory until the app closes. Noto
/// Serif JP (13.6 MB) has no character that the body face (HakkouMincho) lacks,
/// so the body text's list leaves it out: the body text is drawn exactly as
/// with it, and the face is only loaded where it can draw something (the text
/// tool, share cards, text in another family that inherits the body list).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HakkouMincho has every character of Noto Serif JP', () {
    final noto = cmapCodePoints('assets/fonts/NotoSerifJP.ttf');
    final hakkou = cmapCodePoints('assets/fonts/HakkouMincho.ttf');
    expect(noto.difference(hakkou), isEmpty);
  });

  test('the body lists are the full lists without Noto Serif JP', () {
    for (final (code, full) in [
      ('ja', kBodyFontFallback),
      ('en', kBodyFontFallback),
      ('zh', kChineseBodyFontFallback),
      ('ko', kKoreanBodyFontFallback),
    ]) {
      final locale = Locale(code);
      final body = bodyFontFallbackFor(locale);
      expect(body, [
        for (final family in full)
          if (family != 'NotoSerifJP') family,
      ], reason: code);
      // HakkouMincho comes before where Noto Serif JP was.
      final families = [bodyFontFamilyFor(locale), ...full];
      expect(
        families.indexOf('HakkouMincho'),
        lessThan(families.indexOf('NotoSerifJP')),
        reason: code,
      );
      // Text in another family that inherits the body list keeps the full list.
      expect(fallbackUnderOtherFamily(body), full, reason: code);
      expect(
        fallbackUnderOtherFamily(kHeadingFontFallback),
        kHeadingFontFallback,
      );
      expect(fallbackUnderOtherFamily(null), isNull);
    }
  });

  test('the theme text does not name Noto Serif JP', () {
    final themes = ThemeService();
    addTearDown(themes.dispose);
    for (final code in ['ja', 'en', 'fr', 'zh', 'ko']) {
      final text = themes.themeDataFor(Locale(code)).textTheme;
      for (final style in [
        text.displayLarge,
        text.headlineSmall,
        text.titleMedium,
        text.titleSmall,
        text.bodyLarge,
        text.bodyMedium,
        text.bodySmall,
        text.labelLarge,
        text.labelSmall,
      ]) {
        expect(style?.fontFamilyFallback, isNot(contains('NotoSerifJP')));
      }
    }
  });

  testWidgets('body text is drawn exactly as with Noto Serif JP in the list', (
    tester,
  ) async {
    await loadAppFonts(tester);
    final noto = cmapCodePoints('assets/fonts/NotoSerifJP.ttf').toList()
      ..sort();
    final kept = <int>[
      for (final c in noto)
        if (c > 0x20 && (c < 0xD800 || c > 0xDFFF)) c,
    ];
    // Characters only the later families have (extended Latin, Hangul,
    // simplified Chinese), and ones no bundled face has.
    final extra = String.fromCharCodes([
      for (var c = 0x100; c < 0x250; c++) c,
      for (var c = 0xAC00; c < 0xAC00 + 400; c++) c,
      ...'这个简体字显示设置并输入'.runes,
      ...'ŉǅǈ⁂⅏㊿🎨'.runes,
    ]);
    final samples = <String>[
      extra,
      for (var i = 0; i < kept.length; i += 600)
        String.fromCharCodes(kept.sublist(i, (i + 600).clamp(0, kept.length))),
    ];

    Future<List<int>> draw(
      String text,
      String family,
      List<String> fallback,
      FontWeight weight,
    ) async {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: family,
            fontFamilyFallback: fallback,
            fontSize: 20,
            fontWeight: weight,
            color: const Color(0xFF000000),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 1600);
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), Offset.zero);
      final size = painter.size;
      painter.dispose();
      final picture = recorder.endRecording();
      final bytes = await tester.runAsync(() async {
        final image = await picture.toImage(
          size.width.ceil(),
          size.height.ceil(),
        );
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List().toList();
      });
      picture.dispose();
      return bytes!;
    }

    // The check can see a character drawn by Noto Serif JP instead.
    expect(
      await draw(samples[1], 'NotoSerifJP', const [], FontWeight.w400),
      isNot(await draw(samples[1], 'HakkouMincho', const [], FontWeight.w400)),
    );

    var compared = 0;
    for (final (code, full) in [
      ('ja', kBodyFontFallback),
      ('zh', kChineseBodyFontFallback),
      ('ko', kKoreanBodyFontFallback),
    ]) {
      final locale = Locale(code);
      final family = bodyFontFamilyFor(locale);
      for (final weight in [FontWeight.w400, FontWeight.w700]) {
        for (final text in samples) {
          final before = await draw(text, family, full, weight);
          final after = await draw(
            text,
            family,
            bodyFontFallbackFor(locale),
            weight,
          );
          expect(after, before, reason: '$code $weight');
          compared++;
        }
      }
    }
    expect(compared, greaterThan(100));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
