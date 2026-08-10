import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/tile_manager.dart';

/// TileManagerのタイルキャッシュ（Task#73）が安全かどうかを検証するテスト。
/// 実機での目視確認ができない開発環境のため、キャッシュの正しさ（変更後に
/// 古い画像を返さないこと・disposeしたクローンが他のクローンやキャッシュ本体に
/// 影響しないこと）を機械的に検証する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Color> pixelAt(ui.Image image, int x, int y, int width) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final idx = (y * width + x) * 4;
    return ui.Color.fromARGB(bytes[idx + 3], bytes[idx], bytes[idx + 1], bytes[idx + 2]);
  }

  test('compositeLayerToImageはブレンド後のピクセルを正しく反映する', () async {
    final tm = TileManager(canvasWidth: 8, canvasHeight: 8);
    final tile = tm.getOrCreateTile('layerA', 0, 0);
    tm.blendPixel(tile, 0, 0, 255, 0, 0, 255); // 赤・不透明

    final img1 = await tm.compositeLayerToImage('layerA');
    expect(await pixelAt(img1, 0, 0, 8), const ui.Color.fromARGB(255, 255, 0, 0));
    img1.dispose();
  });

  test('キャッシュヒット時もdispose済みの画像を再利用しない（clone()による独立ハンドル）', () async {
    final tm = TileManager(canvasWidth: 8, canvasHeight: 8);
    final tile = tm.getOrCreateTile('layerA', 0, 0);
    tm.blendPixel(tile, 0, 0, 255, 0, 0, 255);

    // 1回目：キャッシュへ格納される
    final img1 = await tm.compositeLayerToImage('layerA');
    expect(await pixelAt(img1, 0, 0, 8), const ui.Color.fromARGB(255, 255, 0, 0));
    img1.dispose(); // 呼び出し元が自由にdispose()してよい設計であることを確認

    // 2回目：キャッシュヒット。img1をdisposeした後でも正しく読み出せる
    // （キャッシュ本体ではなくclone()されたハンドルが返っているため）。
    final img2 = await tm.compositeLayerToImage('layerA');
    expect(await pixelAt(img2, 0, 0, 8), const ui.Color.fromARGB(255, 255, 0, 0));

    // 3回目：img2がまだ生きている状態で同時に取得しても問題ない
    final img3 = await tm.compositeLayerToImage('layerA');
    expect(await pixelAt(img3, 0, 0, 8), const ui.Color.fromARGB(255, 255, 0, 0));

    img2.dispose();
    img3.dispose();
  });

  test('getOrCreateTileでの書き込み後はキャッシュが無効化され最新状態を返す', () async {
    final tm = TileManager(canvasWidth: 8, canvasHeight: 8);
    final tile1 = tm.getOrCreateTile('layerA', 0, 0);
    tm.blendPixel(tile1, 0, 0, 255, 0, 0, 255); // 赤

    final imgBefore = await tm.compositeLayerToImage('layerA'); // キャッシュされる
    expect(await pixelAt(imgBefore, 0, 0, 8), const ui.Color.fromARGB(255, 255, 0, 0));
    imgBefore.dispose();

    // 同じピクセルを青で上書き（in-place変更）
    final tile2 = tm.getOrCreateTile('layerA', 0, 0);
    tm.erasePixel(tile2, 0, 0, 255); // まず透明に戻す
    tm.blendPixel(tile2, 0, 0, 0, 0, 255, 255); // 青

    final imgAfter = await tm.compositeLayerToImage('layerA');
    expect(await pixelAt(imgAfter, 0, 0, 8), const ui.Color.fromARGB(255, 0, 0, 255),
        reason: 'getOrCreateTile経由の書き込み後は再合成され、キャッシュされた古い赤ピクセルを'
            '返してはならない');
    imgAfter.dispose();
  });

  test('replaceLayerPixelsはキャッシュを無効化し新しいデータを反映する', () async {
    final tm = TileManager(canvasWidth: 4, canvasHeight: 4);
    final tile = tm.getOrCreateTile('layerA', 0, 0);
    tm.blendPixel(tile, 0, 0, 255, 0, 0, 255);
    final imgBefore = await tm.compositeLayerToImage('layerA');
    expect(await pixelAt(imgBefore, 0, 0, 4), const ui.Color.fromARGB(255, 255, 0, 0));
    imgBefore.dispose();

    final bytes = Uint8List(4 * 4 * 4);
    // 全ピクセルを緑・不透明にする
    for (int i = 0; i < bytes.length; i += 4) {
      bytes[i] = 0;
      bytes[i + 1] = 255;
      bytes[i + 2] = 0;
      bytes[i + 3] = 255;
    }
    tm.replaceLayerPixels('layerA', bytes);

    final imgAfter = await tm.compositeLayerToImage('layerA');
    expect(await pixelAt(imgAfter, 0, 0, 4), const ui.Color.fromARGB(255, 0, 255, 0));
    imgAfter.dispose();
  });

  test('renameKeyは旧キー・新キー双方のキャッシュを無効化する', () async {
    final tm = TileManager(canvasWidth: 4, canvasHeight: 4);
    final tile = tm.getOrCreateTile('old', 0, 0);
    tm.blendPixel(tile, 0, 0, 255, 0, 0, 255);
    final imgOld = await tm.compositeLayerToImage('old'); // キャッシュされる
    imgOld.dispose();

    tm.renameKey('old', 'new');
    expect(tm.hasLayer('old'), isFalse);
    expect(tm.hasLayer('new'), isTrue);

    final imgNew = await tm.compositeLayerToImage('new');
    expect(await pixelAt(imgNew, 0, 0, 4), const ui.Color.fromARGB(255, 255, 0, 0));
    imgNew.dispose();
  });

  test('removeLayer後にgetOrCreateTileで再生成しても正しい状態を合成する', () async {
    final tm = TileManager(canvasWidth: 4, canvasHeight: 4);
    final tile = tm.getOrCreateTile('layerA', 0, 0);
    tm.blendPixel(tile, 0, 0, 255, 0, 0, 255);
    final imgBefore = await tm.compositeLayerToImage('layerA');
    imgBefore.dispose();

    tm.removeLayer('layerA');
    expect(tm.hasLayer('layerA'), isFalse);

    final tile2 = tm.getOrCreateTile('layerA', 0, 0);
    tm.blendPixel(tile2, 0, 0, 0, 255, 0, 255); // 緑
    final imgAfter = await tm.compositeLayerToImage('layerA');
    expect(await pixelAt(imgAfter, 0, 0, 4), const ui.Color.fromARGB(255, 0, 255, 0));
    imgAfter.dispose();
  });

  test('多数の異なるレイヤーを合成してもLRU上限を超えてクラッシュしない', () async {
    final tm = TileManager(canvasWidth: 4, canvasHeight: 4);
    // _compositeCacheMax(16)を超える件数のレイヤーを合成する
    for (int i = 0; i < 40; i++) {
      final layerId = 'layer$i';
      final tile = tm.getOrCreateTile(layerId, 0, 0);
      tm.blendPixel(tile, 0, 0, i % 256, 0, 0, 255);
      final img = await tm.compositeLayerToImage(layerId);
      expect(img.width, 4);
      expect(img.height, 4);
      img.dispose();
    }
    // 古いレイヤーを再度合成しても（キャッシュから追い出されていても）
    // タイルデータ自体は_tilesに残っているため正しく再構築できる
    final img0Again = await tm.compositeLayerToImage('layer0');
    expect(await pixelAt(img0Again, 0, 0, 4), const ui.Color.fromARGB(255, 0, 0, 0));
    img0Again.dispose();
  });

  test('applyTileSnapshotはキャッシュを無効化する（Undo/Redo）', () async {
    final tm = TileManager(canvasWidth: 4, canvasHeight: 4);
    final tile = tm.getOrCreateTile('layerA', 0, 0);
    tm.blendPixel(tile, 0, 0, 255, 0, 0, 255);
    final imgBefore = await tm.compositeLayerToImage('layerA');
    imgBefore.dispose();

    // Undo相当：該当タイルをnull（未描画）へ戻す
    tm.applyTileSnapshot('layerA', {'0,0': null});

    final imgAfter = await tm.compositeLayerToImage('layerA');
    expect(await pixelAt(imgAfter, 0, 0, 4), const ui.Color.fromARGB(0, 0, 0, 0));
    imgAfter.dispose();
  });

  test('importAllは全キャッシュを無効化する', () async {
    final tm = TileManager(canvasWidth: 4, canvasHeight: 4);
    final tile = tm.getOrCreateTile('layerA', 0, 0);
    tm.blendPixel(tile, 0, 0, 255, 0, 0, 255);
    final imgBefore = await tm.compositeLayerToImage('layerA');
    imgBefore.dispose();

    final newTile = Uint8List(TileManager.tileSize * TileManager.tileSize * 4);
    newTile[3] = 255; // (0,0)のみ不透明・黒
    tm.importAll({
      'layerA': {'0,0': newTile},
    });

    final imgAfter = await tm.compositeLayerToImage('layerA');
    expect(await pixelAt(imgAfter, 0, 0, 4), const ui.Color.fromARGB(255, 0, 0, 0));
    imgAfter.dispose();
  });
}
