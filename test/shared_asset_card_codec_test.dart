import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/shared_asset_card_codec.dart';

void main() {
  // Valid minimal 1x1 PNG. The displayed image remains a regular PNG.
  final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==');
  test('all three kinds are round-tripped losslessly in one PNG', () {
    for (final kind in ['brush', 'tone', 'stamp']) {
      final original = Uint8List.fromList(List<int>.generate(1024, (i) => i % 255));
      final card = SharedAssetCardCodec.embed(
        png: png, kind: kind, name: '共有素材・$kind', data: original,
      );
      expect(card.sublist(0, png.length - 12), png.sublist(0, png.length - 12));
      final parsed = SharedAssetCardCodec.extract(card);
      expect(parsed.kind, kind);
      expect(parsed.name, '共有素材・$kind');
      expect(parsed.data, original);
    }
  });
  test('ordinary pictures are rejected without changing any data', () {
    expect(() => SharedAssetCardCodec.extract(png), throwsFormatException);
  });
  test('payload corruption does not import silently', () {
    final card = SharedAssetCardCodec.embed(
      png: png, kind: 'brush', name: 'brush', data: Uint8List.fromList([42, 43, 44]),
    );
    final invalid = Uint8List.fromList(card);
    invalid[invalid.length - 18] ^= 0x1;
    expect(() => SharedAssetCardCodec.extract(invalid), throwsFormatException);
  });

  test('rejects non-PNG data and unsupported asset kinds', () {
    expect(
      () => SharedAssetCardCodec.extract(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      ),
      throwsFormatException,
    );
    expect(
      () => SharedAssetCardCodec.embed(
        png: png,
        kind: 'other',
        name: 'invalid',
        data: Uint8List.fromList([1]),
      ),
      throwsFormatException,
    );
  });

  test('rejects empty and oversized asset payloads', () {
    expect(
      () => SharedAssetCardCodec.embed(
        png: png,
        kind: 'brush',
        name: 'empty',
        data: Uint8List(0),
      ),
      throwsFormatException,
    );
    expect(
      () => SharedAssetCardCodec.embed(
        png: png,
        kind: 'brush',
        name: 'too large',
        data: Uint8List(SharedAssetCardCodec.maxAssetBytes + 1),
      ),
      throwsFormatException,
    );
  });

  test('prevents embedding a second payload into one PNG', () {
    final card = SharedAssetCardCodec.embed(
      png: png,
      kind: 'tone',
      name: 'original',
      data: Uint8List.fromList([1, 2, 3]),
    );
    expect(
      () => SharedAssetCardCodec.embed(
        png: card,
        kind: 'stamp',
        name: 'duplicate',
        data: Uint8List.fromList([4, 5]),
      ),
      throwsFormatException,
    );
  });

  test('rejects corrupted visible PNG chunks as well as payload', () {
    final card = SharedAssetCardCodec.embed(
      png: png,
      kind: 'stamp',
      name: 'test',
      data: Uint8List.fromList([1, 2, 3]),
    );
    final corruptedHeader = Uint8List.fromList(card);
    // The first IHDR width byte is covered by its CRC.
    corruptedHeader[19] ^= 1;
    expect(
      () => SharedAssetCardCodec.extract(corruptedHeader),
      throwsFormatException,
    );
  });

}