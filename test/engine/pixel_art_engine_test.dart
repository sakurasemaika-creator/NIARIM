import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/pixel_art_engine.dart';
import 'package:niarim/models/pixel_color_mode.dart';

void main() {
  const engine = PixelArtEngine();

  test('transparent diagonal keeps hard source alpha', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255, 0, 0, 0, 0,
      255, 0, 0, 255, 255, 0, 0, 255,
    ]);
    final out = engine.convert(input, 2, 2, pixelSize: 1, colorMode: PixelColorMode.none);
    expect([out[3], out[7], out[11], out[15]], [255, 0, 255, 255]);
  });

  test('horizontal opaque boundary stays hard', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255, 255, 0, 0, 255,
      0, 0, 255, 255, 0, 0, 255, 255,
    ]);
    final out = engine.convert(input, 2, 2, pixelSize: 1, colorMode: PixelColorMode.none);
    expect(out.sublist(0, 3), [255, 0, 0]);
    expect(out.sublist(8, 11), [0, 0, 255]);
  });


  test('pixelSize 1 shared color route obeys strict requested color count', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255,
      0, 255, 0, 255,
      0, 0, 255, 255,
      255, 255, 0, 255,
    ]);
    final out = engine.convert(
      input,
      4,
      1,
      pixelSize: 1,
      colorMode: PixelColorMode.count,
      colorLevels: 2,
    );
    final colors = <String>{};
    for (var i = 0; i < out.length; i += 4) {
      colors.add('${out[i]},${out[i + 1]},${out[i + 2]}');
      expect(out[i + 3], 255);
    }
    expect(colors.length, lessThanOrEqualTo(2));
  });

  test('vertical opaque boundary stays hard', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255, 0, 0, 255, 255,
      255, 0, 0, 255, 0, 0, 255, 255,
    ]);
    final out = engine.convert(input, 2, 2,
        pixelSize: 1, colorMode: PixelColorMode.none);
    expect(out.sublist(0, 3), [255, 0, 0]);
    expect(out.sublist(4, 7), [0, 0, 255]);
    expect(out.sublist(8, 11), [255, 0, 0]);
    expect(out.sublist(12, 15), [0, 0, 255]);
  });

  test('opaque source pixels stay opaque and transparent pixels stay transparent', () {
    final input = Uint8List.fromList([
      20, 40, 60, 255, 0, 0, 0, 0,
      80, 100, 120, 255, 0, 0, 0, 0,
    ]);
    final out = engine.convert(input, 2, 2,
        pixelSize: 2, colorMode: PixelColorMode.none);
    expect([out[3], out[7], out[11], out[15]], [255, 0, 255, 0]);
  });

  test('one-color explicit palette does not create semi-transparent fringe', () {
    final input = Uint8List.fromList([
      200, 20, 30, 255, 0, 0, 0, 0,
      200, 20, 30, 255, 0, 0, 0, 0,
    ]);
    final out = engine.convert(
      input,
      2,
      2,
      pixelSize: 2,
      colorMode: PixelColorMode.explicit,
      paletteColors: const [0xff336699],
    );
    expect([out[3], out[7], out[11], out[15]], [255, 0, 255, 0]);
    expect(out.sublist(0, 3), [0x33, 0x66, 0x99]);
    expect(out.sublist(8, 11), [0x33, 0x66, 0x99]);
  });

  test('opaque diagonal crossing may use a middle color', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255, 0, 0, 255, 255,
      0, 0, 255, 255, 255, 0, 0, 255,
    ]);
    final out = engine.convert(input, 2, 2, pixelSize: 1, colorMode: PixelColorMode.none);
    expect(out.sublist(4, 7), [128, 0, 128]);
    expect([out[3], out[7], out[11], out[15]], [255, 255, 255, 255]);
  });

  test('explicit palette never invents an unavailable middle color', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255, 0, 0, 255, 255,
      0, 0, 255, 255, 255, 0, 0, 255,
    ]);
    final out = engine.convert(
      input,
      2,
      2,
      pixelSize: 1,
      colorMode: PixelColorMode.explicit,
      paletteColors: const [0xffff0000, 0xff0000ff],
    );
    final used = <int>{};
    for (var i = 0; i < out.length; i += 4) {
      used.add((out[i] << 16) | (out[i + 1] << 8) | out[i + 2]);
    }
    expect(used.difference({0xff0000, 0x0000ff}), isEmpty);
  });

  test('count mode limits the total number of output colors', () {
    final input = Uint8List.fromList([
      255, 0, 0, 255, 0, 255, 0, 255,
      0, 0, 255, 255, 255, 255, 0, 255,
      255, 0, 255, 255, 0, 255, 255, 255,
    ]);
    final out = engine.convert(
      input,
      3,
      2,
      pixelSize: 1,
      colorMode: PixelColorMode.count,
      colorLevels: 3,
    );
    final used = <int>{};
    for (var i = 0; i < out.length; i += 4) {
      if (out[i + 3] == 0) continue;
      used.add((out[i] << 16) | (out[i + 1] << 8) | out[i + 2]);
    }
    expect(used.length, lessThanOrEqualTo(3));
  });
}
