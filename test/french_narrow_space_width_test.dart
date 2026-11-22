import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';

import 'helpers/load_app_fonts.dart';

/// 仏語の「? ! ;」の前の細い改行しない空白（U+202F）は、本文（白光明朝）・
/// 見出し（くらむぼん）のどちらでも普通の空白より狭く描かれる。
///
/// どちらの書体の文字の表（cmap）にもU+202Fは無いが、文字の並べ方を決める
/// HarfBuzzは、書体に無い空白の類を書体自身の空白で描き、U+202Fはその
/// 半分の幅にする（白光明朝0.127em・くらむぼん0.1em）。そのため代替の
/// DelaGothicOneの0.48emのU+202Fは使われない（DISC568は表だけを見た誤り）。
/// 代替の並びや書体を変えて、この半分の幅が崩れないことを見張る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double width(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final result = painter.width;
    painter.dispose();
    return result;
  }

  double height(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final result = painter.height;
    painter.dispose();
    return result;
  }

  testWidgets('U+202F is about half a normal space in body and headings', (
    tester,
  ) async {
    await loadAppFonts(tester);
    for (final (name, style) in [
      (
        'body',
        const TextStyle(
          fontFamily: 'HakkouMincho',
          fontFamilyFallback: kBodyFontFallback,
          fontSize: 100,
        ),
      ),
      (
        'heading',
        const TextStyle(
          fontFamily: 'Kuramubon',
          fontFamilyFallback: kHeadingFontFallback,
          fontSize: 100,
        ),
      ),
    ]) {
      final narrow = width('x x', style) - width('xx', style);
      final normal = width('x x', style) - width('xx', style);
      debugPrint(
        '$name: narrow ${narrow.toStringAsFixed(2)}, '
        'normal ${normal.toStringAsFixed(2)}',
      );
      expect(narrow, greaterThan(0), reason: '$name: the space is drawn');
      expect(
        narrow,
        closeTo(normal / 2, 0.5),
        reason: '$name: half of the font’s own space, not a fallback glyph',
      );
      expect(
        height('x x', style),
        height('x x', style),
        reason: '$name: line height',
      );
    }
  });
}
