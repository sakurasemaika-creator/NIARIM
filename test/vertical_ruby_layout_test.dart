// 縦書きのルビは、基底文字の列の右に取った空きに置き、基底文字に重ねない。
//
// 実際に使ってみたとき（2026-11-27）、縦書きの「{漢|かん}」のルビが基底文字の
// 右半分の上に重なっていた（列の幅は文字1つ分で、ルビをその6割の所から描いていた）。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/text_render.dart';
import 'package:niarim/models/text_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('HakkouMincho')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/HakkouMincho.ttf').readAsBytesSync(),
          ),
        ),
      );
    await loader.load();
  });

  const width = 200;
  const height = 240;

  TextObject vertical(String text) => TextObject(
    id: text,
    text: text,
    fontFamily: 'HakkouMincho',
    fontSize: 48,
    position: const ui.Offset(40, 20),
    color: const ui.Color(0xFF202020),
    direction: TextWritingDirection.vertical,
  );

  int alpha(Uint8List rgba, int x, int y) => rgba[(y * width + x) * 4 + 3];

  for (final text in const ['{漢|かん}字', '{漢字|かんじ}です']) {
    test(
      '$text: the ruby stands right of the characters, not on them',
      () async {
        final plain = (await rasterizeTextObject(
          vertical(text.replaceAll(RegExp(r'[{}]|\|[^}]*'), '')),
          width,
          height,
        ))!;
        final ruby = (await rasterizeTextObject(
          vertical(text),
          width,
          height,
        ))!;
        var right = -1;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            if (alpha(plain, x, y) > 0 && x > right) right = x;
          }
        }
        expect(right, greaterThan(0));
        // The characters are drawn as without ruby: no ruby on them.
        for (var y = 0; y < height; y++) {
          for (var x = 0; x <= right; x++) {
            expect(
              alpha(ruby, x, y),
              alpha(plain, x, y),
              reason: 'ruby drawn over the characters at ($x, $y)',
            );
          }
        }
        // And the ruby is there, right of them.
        var rubyInk = 0;
        for (var y = 0; y < height; y++) {
          for (var x = right + 1; x < width; x++) {
            if (alpha(ruby, x, y) > 0) rubyInk++;
          }
        }
        expect(rubyInk, greaterThan(20));
      },
    );
  }
}
