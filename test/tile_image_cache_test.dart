// TileManagerのタイル画像キャッシュが「速くなる」だけでなく
// 「古い絵を出さない」ことを検証する。
//
// 合成キャッシュはレイヤー1枚ぶんの画像なので、1ドット描くだけで丸ごと
// 無効になり、再合成では全タイルをデコードし直していた。タイル単位でも
// デコード結果を持つよう変更したが、無効化を1箇所でも取りこぼすと
// 「描いたのに画面が変わらない」という最悪の不具合になる。ここでは
// 実際の画素を読み出して、書き込みが必ず反映されることを確かめる。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/tile_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 合成結果から1画素を読む（RGBA）。
  Future<List<int>> pixelAt(
    TileManager tm,
    String layerId,
    int x,
    int y,
  ) async {
    final image = await tm.compositeLayerToImage(layerId);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final bytes = data!.buffer.asUint8List();
    final i = (y * tm.canvasWidth + x) * 4;
    return [bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]];
  }

  void paint(
    TileManager tm,
    String layerId,
    int x,
    int y,
    int r,
    int g,
    int b,
  ) {
    final (tx, ty) = tm.getTileCoord(x.toDouble(), y.toDouble());
    final tile = tm.getOrCreateTile(layerId, tx, ty);
    tm.blendPixel(
      tile,
      x - tx * TileManager.tileSize,
      y - ty * TileManager.tileSize,
      r,
      g,
      b,
      255,
    );
  }

  testWidgets('同じタイルへの再描画が合成結果へ必ず反映される', (tester) async {
    // 複数タイルにまたがる大きさにして、「他のタイルはキャッシュを使い回す」
    // 状況を作る（tileSize=256なので3x2タイル）。
    final tm = TileManager(canvasWidth: 700, canvasHeight: 400);
    addTearDown(tm.dispose);
    const layer = 'scene#0#layer';

    await tester.runAsync(() async {
      paint(tm, layer, 10, 10, 255, 0, 0);
      expect(await pixelAt(tm, layer, 10, 10), [
        255,
        0,
        0,
        255,
      ], reason: '最初の描画が出ていない');

      // 同じタイルへ別の色を重ねる。ここでタイル画像キャッシュが
      // 捨てられていないと、赤のままになる。
      paint(tm, layer, 20, 20, 0, 0, 255);
      expect(await pixelAt(tm, layer, 20, 20), [
        0,
        0,
        255,
        255,
      ], reason: '2回目の描画がタイル画像キャッシュに隠されている');
      expect(await pixelAt(tm, layer, 10, 10), [
        255,
        0,
        0,
        255,
      ], reason: '既存の画素が失われている');

      // 別タイル（tx=2）へ描く。こちらは初回なのでキャッシュ無し経路。
      paint(tm, layer, 600, 300, 0, 255, 0);
      expect(await pixelAt(tm, layer, 600, 300), [0, 255, 0, 255]);
      expect(await pixelAt(tm, layer, 20, 20), [
        0,
        0,
        255,
        255,
      ], reason: '他タイルへの描画で既存タイルが壊れている');
    });
  });

  testWidgets('getTileのバッファ直接書き換えはinvalidateTileで反映される', (tester) async {
    final tm = TileManager(canvasWidth: 300, canvasHeight: 300);
    addTearDown(tm.dispose);
    const layer = 'scene#0#layer';

    await tester.runAsync(() async {
      paint(tm, layer, 5, 5, 255, 0, 0);
      // ここで一度合成し、タイル画像をキャッシュへ載せる。
      expect(await pixelAt(tm, layer, 5, 5), [255, 0, 0, 255]);

      // ピクセルモードの色数丸めと同じく、バッファを直接書き換える。
      final (tx, ty) = tm.getTileCoord(5, 5);
      final tile = tm.getTile(layer, tx, ty)!;
      final idx = (5 * TileManager.tileSize + 5) * 4;
      tile[idx] = 0;
      tile[idx + 1] = 255;
      tile[idx + 2] = 0;
      tile[idx + 3] = 255;

      // 無効化前はキャッシュ済みの古い画像が返る（この挙動自体が、
      // invalidateTileの呼び忘れが実害になることの裏付け）。
      expect(await pixelAt(tm, layer, 5, 5), [255, 0, 0, 255]);

      tm.invalidateTile(layer, tx, ty);
      expect(await pixelAt(tm, layer, 5, 5), [
        0,
        255,
        0,
        255,
      ], reason: 'invalidateTile後も古いタイル画像が使われている');
    });
  });

  testWidgets('レイヤー全体の差し替え（Undo等）でタイル画像も捨てられる', (tester) async {
    final tm = TileManager(canvasWidth: 300, canvasHeight: 300);
    addTearDown(tm.dispose);
    const layer = 'scene#0#layer';

    await tester.runAsync(() async {
      paint(tm, layer, 5, 5, 255, 0, 0);
      expect(await pixelAt(tm, layer, 5, 5), [255, 0, 0, 255]);

      // 全面を緑にしたタイルへ差し替える（Undo/Redoと同じ経路）。
      final (tx, ty) = tm.getTileCoord(5, 5);
      final green = Uint8List(TileManager.tileSize * TileManager.tileSize * 4);
      for (var i = 0; i < green.length; i += 4) {
        green[i + 1] = 255;
        green[i + 3] = 255;
      }
      tm.applyTileSnapshot(layer, {'$tx,$ty': green});
      expect(await pixelAt(tm, layer, 5, 5), [
        0,
        255,
        0,
        255,
      ], reason: 'レイヤー差し替え後も古いタイル画像が使われている');
    });
  });
}
