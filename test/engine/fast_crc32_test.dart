import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/fast_crc32.dart';
import 'package:niarim/engine/tile_manager.dart';

/// The 8-bytes-at-a-time CRC-32 gives the same value as `package:archive`'s
/// byte-at-a-time `getCrc32` (the value zip readers check) for every length,
/// including the tails shorter than 8 bytes.
void main() {
  test('the check value of the standard', () {
    expect(crc32Of(Uint8List.fromList('123456789'.codeUnits)), 0xCBF43926);
    expect(crc32Of(Uint8List(0)), 0);
  });

  test('every length from 0 to 300 bytes', () {
    final random = Random(1127);
    for (var n = 0; n <= 300; n++) {
      final bytes = Uint8List.fromList([
        for (var i = 0; i < n; i++) random.nextInt(256),
      ]);
      expect(crc32Of(bytes), getCrc32(bytes), reason: 'length $n');
    }
  });

  test('tiles: random, transparent, opaque, and a view into a buffer', () {
    final random = Random(27);
    final length = TileManager.tileSize * TileManager.tileSize * 4;
    final tiles = <Uint8List>[
      Uint8List.fromList([
        for (var i = 0; i < length; i++) random.nextInt(256),
      ]),
      Uint8List(length),
      Uint8List(length)..fillRange(0, length, 0xFF),
      Uint8List.fromList([for (var i = 0; i < length; i++) i % 251]),
    ];
    for (final tile in tiles) {
      expect(crc32Of(tile), getCrc32(tile));
    }
    // Not starting at the buffer's first byte, and an odd length.
    final view = Uint8List.sublistView(tiles.first, 3, length - 5);
    expect(crc32Of(view), getCrc32(view));
  });
}
