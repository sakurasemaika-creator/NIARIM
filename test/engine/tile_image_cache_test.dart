// レイヤーのタイル画像の覚え（デコード済みの画像）は、少なくともレイヤー1枚の
// 全部のタイルを残す。以前は128枚で頭打ちで、135枚の3840×2160のレイヤーは
// 合成のたびに古い順に追い出し合い、ペンを動かすたびに全部のタイルを
// デコードし直していた。覚えは合成の結果を変えないので、覚えを使った合成が
// 覚えの無い合成と1バイトも違わないことも確かめる。
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/tile_manager.dart';

void _fill(Uint8List tile, Random random) {
  for (var i = 0; i < tile.length; i += 4) {
    final alpha = random.nextInt(256);
    tile[i] = random.nextInt(alpha + 1);
    tile[i + 1] = random.nextInt(alpha + 1);
    tile[i + 2] = random.nextInt(alpha + 1);
    tile[i + 3] = alpha;
  }
}

Future<Uint8List> _composite(TileManager tiles, String layer) async {
  final image = await tiles.compositeLayerToImage(layer);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the default keeps a whole layer, up to 7680×4320', () {
    int cap(int w, int h) =>
        TileManager(canvasWidth: w, canvasHeight: h).tileImageCacheMax;
    expect(cap(256, 256), 9); // 1 tile
    expect(cap(1920, 1080), 80); // 40 tiles, two layers
    expect(cap(2560, 1440), 120); // 60 tiles
    expect(cap(2880, 1620), 128); // 84 tiles
    expect(cap(3840, 2160), 143); // 135 tiles
    expect(cap(7680, 4320), 518); // 510 tiles
    expect(cap(19200, 10800), 518);
  });

  testWidgets('a 3840×2160 layer is decoded once, and composites the same', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const width = 3840;
      const height = 2160;
      const layer = 'Scene0001#0#Layer0001';
      final tiles = TileManager(canvasWidth: width, canvasHeight: height);
      final random = Random(1127);
      for (var ty = 0; ty < tiles.tilesY; ty++) {
        for (var tx = 0; tx < tiles.tilesX; tx++) {
          _fill(tiles.getOrCreateTile(layer, tx, ty), random);
        }
      }
      final count = tiles.tilesX * tiles.tilesY;
      expect(count, 135);

      TileManager.debugTileImageDecodes = 0;
      await _composite(tiles, layer);
      expect(TileManager.debugTileImageDecodes, count);

      // One tile drawn on: only that tile is decoded again.
      _fill(tiles.getOrCreateTile(layer, 7, 4), random);
      TileManager.debugTileImageDecodes = 0;
      final drawnOn = await _composite(tiles, layer);
      expect(TileManager.debugTileImageDecodes, 1);
      _fill(tiles.getOrCreateTile(layer, 14, 8), random);
      _fill(tiles.getOrCreateTile(layer, 0, 0), random);
      TileManager.debugTileImageDecodes = 0;
      final drawnOnTwice = await _composite(tiles, layer);
      expect(TileManager.debugTileImageDecodes, 2);

      // The same pixels composited by a tile manager without any cached
      // image.
      final fresh = TileManager(canvasWidth: width, canvasHeight: height);
      for (final entry in tiles.exportAll()[layer]!.entries) {
        final [tx, ty] = entry.key.split(',').map(int.parse).toList();
        fresh.getOrCreateTile(layer, tx, ty).setAll(0, entry.value);
      }
      expect(await _composite(fresh, layer), drawnOnTwice);
      expect(drawnOn, isNot(drawnOnTwice));
      tiles.dispose();
      fresh.dispose();
    });
  });
}
