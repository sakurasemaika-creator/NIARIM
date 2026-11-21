import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/tile_manager.dart';

void main() {
  test('stroke modifies only selected pixels including at a tile boundary', () {
    final width = TileManager.tileSize + 1;
    final tiles = TileManager(canvasWidth: width, canvasHeight: 1);
    addTearDown(tiles.dispose);
    const layer = 'test';
    final selection = Uint8List(width)..[width - 1] = 255;
    tiles.setPixel(tiles.getOrCreateTile(layer, 0, 0), 0, 0, 255, 0, 0, 255);
    tiles.beginUndoRecording(layer, selection: selection);
    tiles.erasePixel(tiles.getOrCreateTile(layer, 0, 0), 0, 0, 255);
    tiles.setPixel(tiles.getOrCreateTile(layer, 1, 0), 0, 0, 0, 0, 255, 255);
    final stroke = tiles.endUndoRecording();

    expect(tiles.getTile(layer, 0, 0)!.take(4).toList(), [255, 0, 0, 255]);
    expect(tiles.getTile(layer, 1, 0)!.take(4).toList(), [0, 0, 255, 255]);
    tiles.applyTileSnapshot(layer, stroke.before);
    expect(tiles.getTile(layer, 1, 0), isNull);
    expect(tiles.getTile(layer, 0, 0)!.take(4).toList(), [255, 0, 0, 255]);
  });
}
