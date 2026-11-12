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
}