import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/fast_crc32.dart';
import 'package:niarim/engine/frame_png.dart';

/// The PNG frames the video exports hand to their encoders decode to exactly
/// the rendered bytes, as the image package's PNG did (same 8-bit RGBA
/// header), for any width (8-byte rows or not) and a frame not starting at
/// its buffer's first byte.
Uint8List _frame(Random random, int width, int height, {bool flat = false}) {
  final bytes = Uint8List(width * height * 4);
  for (var i = 0; i < bytes.length; i += 4) {
    if (flat && random.nextInt(8) != 0) {
      bytes.setAll(i, [250, 250, 250, 255]);
      continue;
    }
    final alpha = random.nextInt(256);
    bytes.setAll(i, [
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      alpha,
    ]);
  }
  return bytes;
}

void _expectDecodesTo(Uint8List png, Uint8List rgba, int width, int height) {
  final decoded = img.decodePng(png)!;
  expect(decoded.width, width);
  expect(decoded.height, height);
  expect(decoded.numChannels, 4);
  expect(decoded.bitsPerChannel, 8);
  expect(decoded.toUint8List(), rgba);
}

void main() {
  test('decodes to the frame for many sizes', () {
    final random = Random(1127);
    for (final (width, height) in [
      (1, 1),
      (2, 1),
      (1, 3),
      (3, 2),
      (5, 7),
      (64, 9),
      (255, 4),
      (256, 3),
      (257, 5),
      (640, 360),
    ]) {
      for (final flat in [false, true]) {
        final rgba = _frame(random, width, height, flat: flat);
        _expectDecodesTo(
          encodeFramePng(rgba, width, height),
          rgba,
          width,
          height,
        );
      }
    }
  });

  test('a frame inside a larger buffer, at an unaligned offset', () {
    final random = Random(27);
    const width = 6, height = 5;
    final rgba = _frame(random, width, height);
    for (final offset in [4, 8, 12]) {
      final buffer = Uint8List(offset + rgba.length + 16)..setAll(offset, rgba);
      final view = Uint8List.sublistView(buffer, offset, offset + rgba.length);
      _expectDecodesTo(
        encodeFramePng(view, width, height),
        rgba,
        width,
        height,
      );
    }
  });

  test('the header and chunks are those of an 8-bit RGBA PNG', () {
    const width = 300, height = 2;
    final png = encodeFramePng(Uint8List(width * height * 4), width, height);
    expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final data = ByteData.sublistView(png);
    var at = 8;
    final types = <String>[];
    while (at < png.length) {
      final length = data.getUint32(at);
      final type = String.fromCharCodes(png.sublist(at + 4, at + 8));
      types.add(type);
      final crc = data.getUint32(at + 8 + length);
      expect(
        crc,
        crc32Of(Uint8List.sublistView(png, at + 4, at + 8 + length)),
        reason: type,
      );
      if (type == 'IHDR') {
        expect(data.getUint32(at + 8), width);
        expect(data.getUint32(at + 12), height);
        expect(png.sublist(at + 16, at + 21), [8, 6, 0, 0, 0]);
      }
      if (type == 'IDAT') {
        // Filter type byte per row: the first row as it is, then "up".
        final filtered = ZLibCodec().decode(
          png.sublist(at + 8, at + 8 + length),
        );
        expect(filtered.length, height * (width * 4 + 1));
        expect(filtered[0], 0);
        expect(filtered[width * 4 + 1], 2);
      }
      at += 12 + length;
    }
    expect(types, ['IHDR', 'IDAT', 'IEND']);
  });
}
