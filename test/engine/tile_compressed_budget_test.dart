// 展開して持つタイルの数の上限（TileManager.expandedTileBudget）を越えると、
// 長く使っていないタイルから圧縮して持ち、使うときに展開し直す。
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/fast_crc32.dart';
import 'package:niarim/engine/tile_manager.dart';

const _size = TileManager.tileSize;

Uint8List _tile(int seed) {
  final pixels = Uint8List(_size * _size * 4);
  for (var i = 0; i < _size * _size; i++) {
    final alpha = (i * 7 + seed * 13) % 256;
    pixels[i * 4] = alpha ~/ 2;
    pixels[i * 4 + 1] = (alpha * seed) % (alpha + 1);
    pixels[i * 4 + 2] = alpha;
    pixels[i * 4 + 3] = alpha;
  }
  return pixels;
}

/// Lets the tile manager compress the tiles past the budget.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

bool _expanded(TileManager tiles, String layer, String tileKey) =>
    TileManager.isExpanded(tiles.structuralSnapshot()[layer]![tileKey]!);

int _expandedCount(TileManager tiles) {
  final seen = <StoredTile>{};
  for (final layer in tiles.structuralSnapshot().values) {
    for (final tile in layer.values) {
      if (TileManager.isExpanded(tile)) seen.add(tile);
    }
  }
  return seen.length;
}

/// A 1024×512 manager (8 tiles a layer) with [layers] layers of distinct
/// tiles.
TileManager _filled(int layers) {
  final tiles = TileManager(canvasWidth: 1024, canvasHeight: 512);
  for (var l = 0; l < layers; l++) {
    for (var t = 0; t < 8; t++) {
      tiles.getOrCreateTile('L$l', t % 4, t ~/ 4).setAll(0, _tile(l * 8 + t));
    }
  }
  return tiles;
}

void main() {
  setUp(() => TileManager.debugExpandedTileBudget = 4);
  tearDown(() => TileManager.debugExpandedTileBudget = null);

  test('the least recently used tiles past the budget are kept compressed, '
      'and read back to the same pixels', () async {
    final tiles = _filled(3);
    await _settle();
    expect(_expandedCount(tiles), lessThanOrEqualTo(4));
    // The tiles used last stay expanded.
    expect(_expanded(tiles, 'L2', '3,1'), isTrue);
    expect(_expanded(tiles, 'L0', '0,0'), isFalse);

    final all = tiles.exportAll();
    for (var l = 0; l < 3; l++) {
      for (var t = 0; t < 8; t++) {
        expect(all['L$l']!['${t % 4},${t ~/ 4}'], _tile(l * 8 + t));
      }
    }
    // Reading them all once keeps none of them expanded.
    expect(_expanded(tiles, 'L0', '0,0'), isFalse);
    // Reading one to work on keeps it expanded.
    expect(tiles.getTile('L0', 0, 0), _tile(0));
    expect(_expanded(tiles, 'L0', '0,0'), isTrue);
  });

  test('a compressed tile written through getOrCreateTile keeps the write '
      'when it is compressed again', () async {
    final tiles = _filled(3);
    await _settle();
    expect(_expanded(tiles, 'L0', '1,0'), isFalse);
    tiles.getOrCreateTile('L0', 1, 0).setRange(0, 4, [9, 8, 7, 255]);
    for (var t = 0; t < 8; t++) {
      tiles.getTile('L2', t % 4, t ~/ 4);
    }
    await _settle();
    expect(_expanded(tiles, 'L0', '1,0'), isFalse);
    expect(tiles.exportAll()['L0']!['1,0']!.sublist(0, 4), [9, 8, 7, 255]);
  });

  test('a compressed tile written through getTile and marked keeps the '
      'write when it is compressed again', () async {
    final tiles = _filled(3);
    await _settle();
    expect(_expanded(tiles, 'L0', '2,0'), isFalse);
    tiles.getTile('L0', 2, 0)!.setRange(0, 4, [1, 2, 3, 255]);
    tiles.invalidateTile('L0', 2, 0);
    for (var t = 0; t < 8; t++) {
      tiles.getTile('L2', t % 4, t ~/ 4);
    }
    await _settle();
    expect(_expanded(tiles, 'L0', '2,0'), isFalse);
    expect(tiles.exportAll()['L0']!['2,0']!.sublist(0, 4), [1, 2, 3, 255]);
  });

  test('the layer being drawn on keeps its tiles expanded (a stroke holds '
      'their buffers between pointer events)', () async {
    final tiles = _filled(3);
    await _settle();
    tiles.beginUndoRecording('L0');
    final buffers = [
      for (var t = 0; t < 8; t++) tiles.getOrCreateTile('L0', t % 4, t ~/ 4),
    ];
    for (var l = 1; l < 3; l++) {
      for (var t = 0; t < 8; t++) {
        tiles.getTile('L$l', t % 4, t ~/ 4);
      }
    }
    await _settle();
    for (var t = 0; t < 8; t++) {
      expect(identical(tiles.getTile('L0', t % 4, t ~/ 4), buffers[t]), isTrue);
    }
    tiles.endUndoRecording();
    await _settle();
    // Once the stroke is over, they may be compressed again.
    for (var l = 1; l < 3; l++) {
      for (var t = 0; t < 8; t++) {
        tiles.getTile('L$l', t % 4, t ~/ 4);
      }
    }
    await _settle();
    expect(_expanded(tiles, 'L0', '0,0'), isFalse);
  });

  test('a copied layer shares its compressed tiles copy-on-write', () async {
    final tiles = _filled(3);
    tiles.copyLayer('L0', 'C');
    await _settle();
    expect(_expanded(tiles, 'C', '0,0'), isFalse);
    tiles.getOrCreateTile('C', 0, 0).setRange(0, 4, [5, 5, 5, 255]);
    await _settle();
    expect(tiles.exportAll()['L0']!['0,0'], _tile(0));
    expect(tiles.exportAll()['C']!['0,0']!.sublist(0, 4), [5, 5, 5, 255]);
    expect(tiles.exportAll()['C']!['1,0'], _tile(1));
  });

  test('a layer snapshot keeps compressed tiles compressed and puts them '
      'back', () async {
    final tiles = _filled(3);
    await _settle();
    final snapshot = tiles.structuralSnapshot();
    tiles.protectHistoryTiles(snapshot);
    tiles.removeLayer('L0');
    expect(tiles.hasLayer('L0'), isFalse);
    tiles.restoreStructuralLayers({'L0': snapshot['L0']});
    expect(_expanded(tiles, 'L0', '0,0'), isFalse);
    for (var t = 0; t < 8; t++) {
      expect(tiles.exportAll()['L0']!['${t % 4},${t ~/ 4}'], _tile(t));
    }
  });

  test('a tile kept compressed is written to a file as the same bytes its '
      'pixels compress to', () async {
    final tiles = _filled(3);
    await _settle();
    expect(_expanded(tiles, 'L0', '0,0'), isFalse);
    final written = tiles.deflatedTile('L0', '0,0');
    expect(written.deflated, TileManager.tileCodec.encode(_tile(0)));
    expect(written.crc, crc32Of(_tile(0)));
    expect(written.size, _size * _size * 4);
  });

  test('a copy of the tiles shares the compressed streams and is '
      'independent', () async {
    final tiles = _filled(3);
    await _settle();
    final copy = TileManager(canvasWidth: 1024, canvasHeight: 512)
      ..importAllFrom(tiles);
    expect(copy.exportAll(), tiles.exportAll());
    copy.getOrCreateTile('L0', 0, 0).setRange(0, 4, [7, 7, 7, 255]);
    expect(tiles.exportAll()['L0']!['0,0'], _tile(0));
    expect(copy.isTileDirty('L0', '1,0'), isTrue);
  });

  test('the budget is an eighth of the device memory, 256 MiB to 2 GiB of '
      'tiles', () {
    TileManager.debugExpandedTileBudget = null;
    expect(TileManager.expandedTileBudget(), inInclusiveRange(1024, 8192));
  });

  test('within the budget nothing is compressed', () async {
    TileManager.debugExpandedTileBudget = 64;
    final before = TileManager.debugCompressions;
    final tiles = _filled(3);
    await _settle();
    expect(_expandedCount(tiles), 24);
    expect(TileManager.debugCompressions, before);
  });
}
