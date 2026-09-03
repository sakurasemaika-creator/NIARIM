import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/text_render.dart';
import 'package:niarim/models/text_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');

  setUpAll(() async {
    out.createSync(recursive: true);
    final loader = FontLoader('HakkouMincho')
      ..addFont(rootBundle.load('assets/fonts/HakkouMincho.ttf'));
    await loader.load();
  });

  test('実フォント横書き：英数字・日本語が文字形として描画される', () async {
    const text = TextObject(
      id: 'horizontal',
      text: 'NIARIM 12 あいう',
      fontFamily: 'HakkouMincho',
      fontSize: 34,
      color: ui.Color(0xFF202020),
      position: ui.Offset(18, 42),
    );
    final rgba = await rasterizeTextObject(text, 360, 150);
    expect(rgba, isNotNull);
    await _saveRgba(
      rgba!,
      360,
      150,
      '${out.path}/text_realfont_horizontal.png',
    );

    final bounds = _alphaBounds(rgba, 360, 150);
    expect(bounds.width, greaterThan(150));
    expect(bounds.height, greaterThan(15));
    expect(bounds.width, greaterThan(bounds.height * 3));
    _expectGlyphLikeCoverage(rgba, 360, bounds, 'horizontal');
  });

  test('実フォント縦書き：日本語正立・12縦中横・A回転を含む縦組みになる', () async {
    const text = TextObject(
      id: 'vertical',
      text: '縦書12A',
      fontFamily: 'HakkouMincho',
      fontSize: 34,
      color: ui.Color(0xFF202020),
      direction: TextWritingDirection.vertical,
      position: ui.Offset(120, 16),
    );
    final rgba = await rasterizeTextObject(text, 280, 300);
    expect(rgba, isNotNull);
    await _saveRgba(rgba!, 280, 300, '${out.path}/text_realfont_vertical.png');

    final bounds = _alphaBounds(rgba, 280, 300);
    expect(bounds.height, greaterThan(bounds.width * 2));
    expect(_countNonTransparent(rgba), greaterThan(300));
    _expectGlyphLikeCoverage(rgba, 280, bounds, 'vertical');
  });

  test('横書きルビ：基底文字の上側へルビが追加され、通常本文より上へ広がる', () async {
    const plain = TextObject(
      id: 'plain',
      text: '漢字です',
      fontFamily: 'HakkouMincho',
      fontSize: 40,
      position: ui.Offset(40, 55),
      color: ui.Color(0xFF202020),
    );
    const ruby = TextObject(
      id: 'ruby',
      text: '{漢字|かんじ}です',
      fontFamily: 'HakkouMincho',
      fontSize: 40,
      position: ui.Offset(40, 55),
      color: ui.Color(0xFF202020),
    );
    final plainRgba = (await rasterizeTextObject(plain, 320, 180))!;
    final rubyRgba = (await rasterizeTextObject(ruby, 320, 180))!;
    await _saveRgba(
      rubyRgba,
      320,
      180,
      '${out.path}/text_realfont_ruby_horizontal.png',
    );

    final pb = _alphaBounds(plainRgba, 320, 180);
    final rb = _alphaBounds(rubyRgba, 320, 180);
    expect(
      _countNonTransparent(rubyRgba),
      greaterThan(_countNonTransparent(plainRgba)),
    );
    expect(
      rb.height,
      greaterThan(pb.height),
      reason: 'ruby should occupy extra vertical space',
    );
  });

  test('縦書きルビ：基底文字列の右側へルビ列が追加される', () async {
    const plain = TextObject(
      id: 'vp',
      text: '漢字',
      fontFamily: 'HakkouMincho',
      fontSize: 42,
      direction: TextWritingDirection.vertical,
      position: ui.Offset(90, 25),
      color: ui.Color(0xFF202020),
    );
    const ruby = TextObject(
      id: 'vr',
      text: '{漢字|かんじ}',
      fontFamily: 'HakkouMincho',
      fontSize: 42,
      direction: TextWritingDirection.vertical,
      position: ui.Offset(90, 25),
      color: ui.Color(0xFF202020),
    );
    final p = (await rasterizeTextObject(plain, 260, 220))!;
    final r = (await rasterizeTextObject(ruby, 260, 220))!;
    await _saveRgba(r, 260, 220, '${out.path}/text_realfont_ruby_vertical.png');
    final pb = _alphaBounds(p, 260, 220);
    final rb = _alphaBounds(r, 260, 220);
    expect(_countNonTransparent(r), greaterThan(_countNonTransparent(p)));
    expect(
      rb.width,
      greaterThan(pb.width),
      reason: 'vertical ruby should add pixels to the side',
    );
  });

  test('回転と拡大：同じ文字列を90度回転すると主軸が入れ替わり、scale 1.5で面積が増える', () async {
    const base = TextObject(
      id: 'base',
      text: 'NIARIM',
      fontFamily: 'HakkouMincho',
      fontSize: 36,
      position: ui.Offset(90, 90),
      color: ui.Color(0xFF202020),
    );
    final normal = (await rasterizeTextObject(base, 420, 300))!;
    final rotated = (await rasterizeTextObject(
      base.copyWith(rotation: 90),
      420,
      300,
    ))!;
    final scaled = (await rasterizeTextObject(
      base.copyWith(scale: 1.5),
      420,
      300,
    ))!;
    await _saveRgba(
      rotated,
      420,
      300,
      '${out.path}/text_realfont_rotated90.png',
    );
    await _saveRgba(scaled, 420, 300, '${out.path}/text_realfont_scale150.png');

    final nb = _alphaBounds(normal, 420, 300);
    final rb = _alphaBounds(rotated, 420, 300);
    final sb = _alphaBounds(scaled, 420, 300);
    expect(nb.width, greaterThan(nb.height));
    expect(rb.height, greaterThan(rb.width));
    expect(sb.width, greaterThan(nb.width * 1.35));
    expect(sb.height, greaterThan(nb.height * 1.25));
  });

  test('縁取り：本文の周囲だけに指定色ピクセルが増え、本文自体も残る', () async {
    const text = TextObject(
      id: 'outline',
      text: '輪郭',
      fontFamily: 'HakkouMincho',
      fontSize: 52,
      position: ui.Offset(70, 55),
      color: ui.Color(0xFF2030C0),
      outline: TextOutline(
        enabled: true,
        color: ui.Color(0xFFE03030),
        width: 4,
      ),
    );
    final rgba = (await rasterizeTextObject(text, 320, 190))!;
    await _saveRgba(rgba, 320, 190, '${out.path}/text_realfont_outline.png');
    var blue = 0;
    var red = 0;
    for (var i = 0; i < rgba.length; i += 4) {
      if (rgba[i + 3] == 0) continue;
      if (rgba[i + 2] > rgba[i] + 30) blue++;
      if (rgba[i] > rgba[i + 2] + 30) red++;
    }
    expect(blue, greaterThan(50), reason: 'main glyph pixels must remain');
    expect(
      red,
      greaterThan(50),
      reason: 'outline color must appear around glyphs',
    );
  });

  test('ピクセル文字：実フォントでも中間alphaを完全除去し、輪郭形状は維持', () async {
    const text = TextObject(
      id: 'pixel',
      text: 'DOT 文字',
      fontFamily: 'HakkouMincho',
      fontSize: 38,
      position: ui.Offset(30, 50),
      color: ui.Color(0xCC202020),
      opacity: 0.8,
    );
    final normal = (await rasterizeTextObject(text, 320, 180))!;
    final pixel = (await rasterizeTextObject(text, 320, 180, pixelMode: true))!;
    await _saveRgba(
      pixel,
      320,
      180,
      '${out.path}/text_realfont_pixel_mode.png',
    );

    final expectedMax = (0xCC / 255 * 0.8 * 255).round();
    final alphaSet = <int>{};
    for (var i = 3; i < pixel.length; i += 4) {
      alphaSet.add(pixel[i]);
    }
    expect(
      alphaSet.every((a) => a == 0 || (a - expectedMax).abs() <= 1),
      isTrue,
    );
    expect(_countNonTransparent(pixel), greaterThan(100));
    final nb = _alphaBounds(normal, 320, 180);
    final pb = _alphaBounds(pixel, 320, 180);
    expect((nb.width - pb.width).abs(), lessThanOrEqualTo(2));
    expect((nb.height - pb.height).abs(), lessThanOrEqualTo(2));
  });
}

void _expectGlyphLikeCoverage(
  Uint8List rgba,
  int width,
  ui.Rect bounds,
  String label,
) {
  final x0 = bounds.left.floor();
  final x1 = bounds.right.ceil();
  final y0 = bounds.top.floor();
  final y1 = bounds.bottom.ceil();
  var occupied = 0;
  var total = 0;
  var transparentInside = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      total++;
      if (rgba[(y * width + x) * 4 + 3] > 0) {
        occupied++;
      } else {
        transparentInside++;
      }
    }
  }
  final ratio = total == 0 ? 0.0 : occupied / total;
  expect(
    ratio,
    greaterThan(0.03),
    reason: '$label must visibly render glyph strokes',
  );
  expect(
    ratio,
    lessThan(0.70),
    reason: '$label must not collapse into solid tofu rectangles',
  );
  expect(
    transparentInside,
    greaterThan(50),
    reason: '$label should contain normal glyph gaps/counters',
  );
}

ui.Rect _alphaBounds(Uint8List d, int width, int height) {
  var minX = width, minY = height, maxX = -1, maxY = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (d[(y * width + x) * 4 + 3] == 0) continue;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  if (maxX < minX) return ui.Rect.zero;
  return ui.Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    (maxX + 1).toDouble(),
    (maxY + 1).toDouble(),
  );
}

int _countNonTransparent(Uint8List d) {
  var n = 0;
  for (var i = 3; i < d.length; i += 4) {
    if (d[i] > 0) n++;
  }
  return n;
}

Future<void> _saveRgba(
  Uint8List rgba,
  int width,
  int height,
  String path,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
}
