import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute;

import 'brightness_alpha_engine.dart';
import 'filter_engine.dart';
import 'mesh_warp_engine.dart';

/// シーンID・フレームIndex・レイヤーIDから、TileManager内部で使用する
/// 合成キーを生成する。
///
/// TileManagerはlayerIdを不透明な文字列としてのみ扱うため、これ単体では
/// フレーム間で描画データが独立しない（同じlayerIdを複数フレームが共有すると
/// 同一のタイルバッファを指してしまう）。アプリ側（キャンバス描画・書き出し・
/// 自動塗り・保存）は必ずこの関数で生成したキーをTileManagerへ渡すことで、
/// フレームごとに独立した描画データを保持する（フレームはレイヤー構成
/// 〔ID〕を引き継ぐが、描画データ自体は各フレーム独立である）。
String frameLayerKey(String sceneId, int frameIndex, String layerId) =>
    '$sceneId#$frameIndex#$layerId';

/// [frameLayerKey] の逆変換。フォーマットに一致しない場合（新規保存前の
/// 旧形式データ等）はnullを返す。
typedef FrameLayerKeyParts = ({String sceneId, int frameIndex, String layerId});

FrameLayerKeyParts? parseFrameLayerKey(String key) {
  final parts = key.split('#');
  if (parts.length != 3) return null;
  final frameIndex = int.tryParse(parts[1]);
  if (frameIndex == null) return null;
  return (sceneId: parts[0], frameIndex: frameIndex, layerId: parts[2]);
}

/// Sparse Tile 方式のキャンバスバッファ管理。
/// 描画済みタイルのみメモリに保持し、未描画タイルは保持しない。
class TileManager {
  static const int tileSize = 256;

  final int canvasWidth;
  final int canvasHeight;
  final int tilesX;
  final int tilesY;

  // layerId → tileKey → ARGB8888 ピクセルバッファ (tileSize*tileSize*4 bytes)
  final Map<String, Map<String, Uint8List>> _tiles = {};
  final Set<String> _dirtyTiles = {};

  // タイルキャッシュ：compositeLayerToImage()の合成結果（レイヤー1枚分の
  // ui.Image、キャンバス全体サイズ）をlayerIdごとにキャッシュし、そのレイヤーの
  // タイルに変更が無い限り再デコード・再合成しない。呼び出し元は返された画像を
  // 自由にdispose()できるよう、キャッシュ本体ではなく都度clone()を返す
  // （ui.Imageはネイティブ側で参照カウントされるため、clone()した
  // ハンドルの破棄はキャッシュ本体に影響しない）。
  // 無効化は_tilesを変更するメソッド側で個別に行う（markDirtyは一部の
  // 描画パスでしか呼ばれておらず、キャッシュ無効化の単一の信頼できる
  // シグナルにはできないため、_tiles変更箇所ごとに明示的に呼ぶ）。
  //
  // キャッシュ画像はキャンバス全体サイズのRGBAを保持する（例：1080×1920なら
  // 1枚あたり約8MB）。低スペック端末での無制限なメモリ増加を避けるため、
  // LRU方式で一定件数（compositeCacheMax）を超えたら最も古いものから破棄
  // する。通常の描画・スクラブ操作で同時にアクティブなレイヤー数は少数
  // （1フレーム分の表示レイヤー程度）のため、この上限で実用上のキャッシュ
  // 効果は十分に得られる。書き出し等、多数の異なるレイヤーを1回ずつしか
  // 触れない処理ではキャッシュ効果は薄いが、上限があるためメモリへの
  // 悪影響も出ない。既定値16（最大概算約130MB程度）は変更していないが、
  // 端末性能判定（PerformanceService）に応じてProjectService
  // 経由で小さい値へ絞れるよう、コンストラクタで上書きできるようにしてある
  // （見た目・機能は変わらず、再合成の頻度がわずかに増えるのみ）。
  final int compositeCacheMax;
  final Map<String, ui.Image> _compositeCache =
      {}; // 挿入順=LRU順（Dart既定のMapはLinkedHashMap）

  // タイル画像キャッシュ：タイル1枚（256x256）をデコードしたui.Imageを
  // 「レイヤーキー|タイルキー」単位でキャッシュする。
  //
  // 上の合成キャッシュはレイヤー1枚ぶんの画像なので、そのレイヤーへ1ドット
  // でも描くと丸ごと無効になる。無効化後の再合成は全タイルを1枚ずつ
  // ImageDescriptor→instantiateCodec→getNextFrameでデコードし直しており、
  // 1080x1920のキャンバスなら最大40枚ぶんのネイティブ往復が、ストローク中の
  // 再合成のたびに走っていた（実際に触れたタイルは1〜2枚だけでも）。
  // タイル単位でもデコード結果を持ち、書き込みのあったタイルだけ捨てる
  // ことで、再合成時のデコードを変更ぶんのみに絞る。
  //
  // 1枚あたり256*256*4≒256KB。合成キャッシュと同様にLRUで件数を抑える。
  final int tileImageCacheMax;
  final Map<String, ui.Image> _tileImageCache = {};

  String _tileImageKey(String layerId, String tileKey) => '$layerId|$tileKey';

  /// レイヤー1枚ぶんの合成結果のみを捨てる（タイル画像は残す）。
  void _invalidateComposite(String layerId) {
    _compositeCache.remove(layerId)?.dispose();
  }

  /// 指定タイルのデコード済み画像だけを捨てる。
  void _invalidateTileImage(String layerId, String tileKey) {
    _tileImageCache.remove(_tileImageKey(layerId, tileKey))?.dispose();
  }

  void _invalidateTileImagesWhere(bool Function(String key) test) {
    final keys = _tileImageCache.keys.where(test).toList();
    for (final k in keys) {
      _tileImageCache.remove(k)?.dispose();
    }
  }

  void _touchTileImage(String key, ui.Image image) {
    _tileImageCache.remove(key);
    _tileImageCache[key] = image;
    while (_tileImageCache.length > tileImageCacheMax) {
      final oldest = _tileImageCache.keys.first;
      _tileImageCache.remove(oldest)?.dispose();
    }
  }

  /// レイヤーの内容がまとめて変わったときの無効化（合成結果＋そのレイヤーの
  /// 全タイル画像）。タイル単位の書き込みでこれを呼ぶとタイル画像キャッシュが
  /// 毎回全滅するため、[getOrCreateTile]だけは狭い無効化を使う。
  void _invalidateCache(String layerId) {
    _invalidateComposite(layerId);
    final prefix = '$layerId|';
    _invalidateTileImagesWhere((k) => k.startsWith(prefix));
  }

  void _touchCache(String layerId, ui.Image image) {
    // 既存エントリを削除してから再挿入することでLRU順（末尾=最新）を保つ
    _compositeCache.remove(layerId);
    _compositeCache[layerId] = image;
    while (_compositeCache.length > compositeCacheMax) {
      final oldestKey = _compositeCache.keys.first;
      _compositeCache.remove(oldestKey)?.dispose();
    }
  }

  void _invalidateCachePrefix(String prefix) {
    final keys = _compositeCache.keys
        .where((k) => k.startsWith(prefix))
        .toList();
    for (final k in keys) {
      _compositeCache.remove(k)?.dispose();
    }
    // タイル画像のキーは「レイヤーキー|タイルキー」なので、レイヤーキーへの
    // 前方一致がそのまま使える。
    _invalidateTileImagesWhere((k) => k.startsWith(prefix));
  }

  void _invalidateCacheAll() {
    for (final img in _compositeCache.values) {
      img.dispose();
    }
    _compositeCache.clear();
    for (final img in _tileImageCache.values) {
      img.dispose();
    }
    _tileImageCache.clear();
  }

  /// このTileManagerが保持するネイティブリソース（キャッシュ画像）を解放する。
  void dispose() {
    _invalidateCacheAll();
  }

  // Copy-on-Write：copyLayerで参照共有されたタイルバッファの集合。
  // 実際に書き込みが発生するまで複製しない。
  final Set<Uint8List> _sharedTiles = {};

  // Undo記録：1回の描画操作（ストローク・バケツ・投げ縄・変形等）で実際に
  // 触れたタイルのみを差分記録する（スパースタイル方式に合わせ、
  // レイヤー全体ではなく変更のあったタイルだけをUndo/Redo対象とする）。
  bool _recordingUndo = false;
  String? _recordingLayerId;
  final Map<String, Uint8List?> _undoBefore = {};

  TileManager({
    required this.canvasWidth,
    required this.canvasHeight,
    this.compositeCacheMax = 16,
    int? tileImageCacheMax,
  }) : tilesX = (canvasWidth / tileSize).ceil(),
       tilesY = (canvasHeight / tileSize).ceil(),
       // 既定はキャンバス2枚ぶんのタイル数（合成キャッシュの上限に連動させず、
       // 「今描いているレイヤーと直前のレイヤー」が丸ごと載る程度）に収める。
       tileImageCacheMax =
           tileImageCacheMax ??
           ((canvasWidth / tileSize).ceil() *
                   (canvasHeight / tileSize).ceil() *
                   2)
               .clamp(8, 128);

  String _tileKey(int tx, int ty) => '$tx,$ty';

  (int, int) getTileCoord(double x, double y) => (x ~/ tileSize, y ~/ tileSize);

  // ─── タイルバッファ取得・生成 ─────────────────────────────────────────

  /// 指定タイルのピクセルバッファを返す（書き込み用）。存在しない場合は透明で初期化して返す。
  /// Copy-on-Write：返すバッファが他レイヤーと共有中（copyLayer直後で未実体化）の場合は
  /// ここで初めて複製し、以後はこのレイヤー専用のバッファとして書き込む。
  Uint8List getOrCreateTile(String layerId, int tx, int ty) {
    final key = _tileKey(tx, ty);
    _dirtyTiles.add('$layerId:$key');
    _recordBeforeIfNeeded(layerId, key);
    // 呼び出し規約上、getOrCreateTileは必ず書き込み目的で呼ばれる
    // （返したバッファへ直後にblendPixel/erasePixelで書き込まれる）ため、
    // ここでキャッシュを無効化する。ただし無効になるのは「レイヤー1枚ぶんの
    // 合成結果」と「これから書き込むタイルのデコード済み画像」だけで、
    // 同じレイヤーの他のタイルの画像はそのまま使い回せる。
    _invalidateComposite(layerId);
    _invalidateTileImage(layerId, key);
    final layerMap = _tiles.putIfAbsent(layerId, () => {});
    final existing = layerMap[key];
    if (existing == null) {
      final fresh = Uint8List(tileSize * tileSize * 4); // 透明（全ゼロ）
      layerMap[key] = fresh;
      return fresh;
    }
    if (_sharedTiles.contains(existing)) {
      final materialized = Uint8List.fromList(existing);
      layerMap[key] = materialized;
      return materialized;
    }
    return existing;
  }

  /// 指定タイルのピクセルバッファを読み取り用に返す。
  ///
  /// 返るのはキャッシュ本体ではなく実バッファそのものなので、**書き換えた
  /// 場合は必ず[invalidateTile]を呼ぶこと**。呼ばないと、そのタイルの
  /// デコード済み画像・レイヤーの合成結果が古いまま再利用され、変更が
  /// 画面に出ない。
  Uint8List? getTile(String layerId, int tx, int ty) =>
      _tiles[layerId]?[_tileKey(tx, ty)];

  /// [getTile]で得たバッファを直接書き換えたあとに呼び、そのタイルの
  /// キャッシュ（デコード済み画像とレイヤーの合成結果）を捨てる。
  void invalidateTile(String layerId, int tx, int ty) {
    markDirty(layerId, tx, ty);
    _invalidateComposite(layerId);
    _invalidateTileImage(layerId, _tileKey(tx, ty));
  }

  void markDirty(String layerId, int tx, int ty) {
    _dirtyTiles.add('$layerId:${_tileKey(tx, ty)}');
  }

  Set<String> consumeDirtyTiles() {
    final dirty = Set<String>.from(_dirtyTiles);
    _dirtyTiles.clear();
    return dirty;
  }

  // ─── ピクセル操作 ─────────────────────────────────────────────────────

  /// タイル内の (px, py) に ARGB 値を alpha-composite で書き込む。
  void blendPixel(Uint8List tile, int px, int py, int r, int g, int b, int a) {
    if (px < 0 || px >= tileSize || py < 0 || py >= tileSize) return;
    final idx = (py * tileSize + px) * 4;
    final srcA = a / 255.0;
    final dstA = tile[idx + 3] / 255.0;
    final outA = srcA + dstA * (1.0 - srcA);
    if (outA <= 0) return;
    tile[idx] = ((r * srcA + tile[idx] * dstA * (1.0 - srcA)) / outA)
        .round()
        .clamp(0, 255);
    tile[idx + 1] = ((g * srcA + tile[idx + 1] * dstA * (1.0 - srcA)) / outA)
        .round()
        .clamp(0, 255);
    tile[idx + 2] = ((b * srcA + tile[idx + 2] * dstA * (1.0 - srcA)) / outA)
        .round()
        .clamp(0, 255);
    tile[idx + 3] = (outA * 255).round().clamp(0, 255);
  }

  /// 消しゴム：タイル内の (px, py) を透明にする。
  void erasePixel(Uint8List tile, int px, int py, int a) {
    if (px < 0 || px >= tileSize || py < 0 || py >= tileSize) return;
    final idx = (py * tileSize + px) * 4;
    final eraseStrength = a / 255.0;
    final newA = (tile[idx + 3] * (1.0 - eraseStrength)).round().clamp(0, 255);
    tile[idx + 3] = newA;
    if (newA == 0) {
      tile[idx] = 0;
      tile[idx + 1] = 0;
      tile[idx + 2] = 0;
    }
  }

  /// タイル内の (px, py) をRGBA値でそのまま上書きする（アルファブレンドしない）。
  /// 指ツール（歪み）のように既存ピクセルを別の場所へ再配置する用途向け。
  void setPixel(Uint8List tile, int px, int py, int r, int g, int b, int a) {
    if (px < 0 || px >= tileSize || py < 0 || py >= tileSize) return;
    final idx = (py * tileSize + px) * 4;
    tile[idx] = r;
    tile[idx + 1] = g;
    tile[idx + 2] = b;
    tile[idx + 3] = a;
  }

  // ─── レイヤー合成 → ui.Image ─────────────────────────────────────────

  /// 指定レイヤーの全タイルを合成した ui.Image を生成する。
  /// 非同期だが描画ループから呼ぶため Future を返す。
  /// タイルキャッシュ：直前の呼び出しからそのレイヤーのタイルに変更が
  /// 無ければ、全タイルの再デコード・再合成を省略しキャッシュ済み画像の
  /// clone()を返す（呼び出し元は返された画像を自由にdispose()できる）。
  Future<ui.Image> compositeLayerToImage(String layerId) async {
    final cached = _compositeCache[layerId];
    if (cached != null) {
      _touchCache(layerId, cached); // LRU順を更新（末尾へ移動）
      return cached.clone();
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final layerTiles = _tiles[layerId];
    if (layerTiles != null) {
      // 【不具合修正】entriesを直接for-inすると、このループ内のawait
      // （_tileToImage）で処理が中断している間に、進行中のストローク等が
      // 同じレイヤーへ新規タイルを書き込んだ場合（描画中にブラシが新しい
      // タイル領域へ入った等）、マップが変更されてConcurrentModification
      // Errorになる（Task#128の自律ジェスチャーテストで実際に検出）。
      // toList()でこの合成呼び出し用のスナップショットを取ってから
      // 反復することで、ループ中のマップ変更の影響を受けないようにする
      // （新しく増えたタイルは次回のcompositeLayerToImage呼び出しで
      // 反映されるため、プレビュー用の非破壊な合成としては問題ない）。
      for (final entry in layerTiles.entries.toList()) {
        final parts = entry.key.split(',');
        final tx = int.parse(parts[0]);
        final ty = int.parse(parts[1]);
        final img = await _tileImage(layerId, entry.key, entry.value);
        canvas.drawImage(
          img,
          ui.Offset(tx * tileSize.toDouble(), ty * tileSize.toDouble()),
          ui.Paint(),
        );
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasWidth, canvasHeight);
    picture.dispose();
    _touchCache(layerId, image);
    return image.clone();
  }

  /// タイル1枚のデコード済み画像を返す（キャッシュ済みならそれを使う）。
  ///
  /// 返す画像はキャッシュ本体なので**呼び出し側でdisposeしてはいけない**
  /// （破棄はキャッシュの追い出し・無効化側で行う）。合成へdrawImageする
  /// だけの用途を想定している。
  Future<ui.Image> _tileImage(
    String layerId,
    String tileKey,
    Uint8List pixels,
  ) async {
    final cacheKey = _tileImageKey(layerId, tileKey);
    final cached = _tileImageCache[cacheKey];
    if (cached != null) {
      _touchTileImage(cacheKey, cached); // LRU順を更新
      return cached;
    }
    final image = await _tileToImage(pixels);
    _touchTileImage(cacheKey, image);
    return image;
  }

  Future<ui.Image> _tileToImage(Uint8List pixels) async {
    final codec = await ui.ImageDescriptor.raw(
      await ui.ImmutableBuffer.fromUint8List(pixels),
      width: tileSize,
      height: tileSize,
      pixelFormat: ui.PixelFormat.rgba8888,
    ).instantiateCodec();
    final frame = await codec.getNextFrame();
    // Codecはネイティブ資源を持つ。フレームを取り出したら必ず解放する
    // （ここはタイルキャッシュが外れるたびにタイル枚数ぶん通る最も熱い経路で、
    // 取り出したframe.imageはCodecを破棄しても有効なまま）。
    codec.dispose();
    return frame.image;
  }

  // ─── レイヤー管理 ─────────────────────────────────────────────────────

  /// レイヤーを複製する（Copy-on-Write方式）。
  /// タイルバッファは複製時点ではコピーせず参照を共有し、
  /// どちらか一方に書き込みが発生した時点（getOrCreateTile）で初めて実体化する。
  void copyLayer(String sourceLayerId, String targetLayerId) {
    final source = _tiles[sourceLayerId];
    if (source == null) return;
    final target = <String, Uint8List>{};
    for (final e in source.entries) {
      _sharedTiles.add(e.value);
      target[e.key] = e.value;
      _dirtyTiles.add('$targetLayerId:${e.key}');
    }
    _tiles[targetLayerId] = target;
    _invalidateCache(targetLayerId);
  }

  /// レイヤー全体を指定した4x4行列（Matrix4.storage形式・列優先）で変換し、
  /// 結果をタイルへ書き戻す（移動・変形ツール用）。
  Future<void> transformLayer(String layerId, Float64List matrix) async {
    final composite = await compositeLayerToImage(layerId);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.save();
    canvas.transform(matrix);
    canvas.drawImage(composite, ui.Offset.zero, ui.Paint());
    canvas.restore();
    composite.dispose();
    final picture = recorder.endRecording();
    final transformed = await picture.toImage(canvasWidth, canvasHeight);
    picture.dispose();
    final byteData = await transformed.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    transformed.dispose();
    if (byteData == null) return;
    replaceLayerPixels(layerId, byteData.buffer.asUint8List());
  }

  /// レイヤー全体をメッシュ変形（自由変形・格子状の制御点をドラッグして
  /// 変形する新機能）で変換し、結果をタイルへ書き戻す。[controlPoints]は
  /// (rows+1)*(cols+1)点、行優先、canvasWidth×canvasHeight座標系
  /// （[MeshWarpEngine]参照）。
  Future<void> meshTransformLayer(
    String layerId,
    int rows,
    int cols,
    List<ui.Offset> controlPoints,
  ) async {
    final composite = await compositeLayerToImage(layerId);
    final warped = await MeshWarpEngine.warp(
      image: composite,
      rows: rows,
      cols: cols,
      controlPoints: controlPoints,
      outputWidth: canvasWidth,
      outputHeight: canvasHeight,
    );
    composite.dispose();
    final byteData = await warped.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    warped.dispose();
    if (byteData == null) return;
    replaceLayerPixels(layerId, byteData.buffer.asUint8List());
  }

  /// 「明度で透過」（レイヤーパネル三点メニュー）：レイヤー全体の各ピクセルの
  /// 明るさから不透明度を作り直し、結果をタイルへ書き戻す。
  /// 下描きレイヤーに誤って線画を描いてしまった時、白い部分を透明にして
  /// 線画だけを取り出す用途などに使う。[grayMode]がtrueならグレー（色は
  /// そのまま・輝度ベースの単純な不透明度化）、falseならカラー（GIMPの
  /// 「色を透明に」と同じアルゴリズムで、色を白の外側へ復元しながら透過）。
  /// 低スペック端末でのUIスレッドブロックを防ぐため、計算自体は別Isolateで行う。
  Future<void> applyBrightnessToAlpha(
    String layerId, {
    required bool grayMode,
  }) async {
    final composite = await compositeLayerToImage(layerId);
    final byteData = await composite.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    composite.dispose();
    if (byteData == null) return;
    final transformed = await compute(
      runBrightnessToAlphaInIsolate,
      BrightnessToAlphaParams(byteData.buffer.asUint8List(), grayMode),
    );
    replaceLayerPixels(layerId, transformed);
  }

  /// 「色調調整」（キャンバス上部バーの設定/編集メニュー）：彩度・明度・
  /// コントラストの調整結果をレイヤーへ直接（非フィルターとして）焼き込む。
  /// フィルターとして保存せず「そのまま適用」した場合に使う。
  Future<void> applyColorAdjustToLayer(
    String layerId, {
    required double saturation,
    required double brightness,
    required double contrast,
  }) async {
    final composite = await compositeLayerToImage(layerId);
    final byteData = await composite.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    composite.dispose();
    if (byteData == null) return;
    final engine = FilterEngine();
    final transformed = engine.applyColorAdjust(
      byteData.buffer.asUint8List(),
      canvasWidth,
      canvasHeight,
      saturation: saturation,
      brightness: brightness,
      contrast: contrast,
    );
    replaceLayerPixels(layerId, transformed);
  }

  /// レイヤーの全ピクセルを、キャンバス全体サイズのRGBA8888バッファで置き換える。
  /// 自動塗りエンジンの結果書き戻しや transformLayer の内部実装で使用する。
  void replaceLayerPixels(String layerId, Uint8List bytes) {
    final oldLayerTiles = _tiles[layerId];
    final recording = _recordingUndo && layerId == _recordingLayerId;
    final newLayerTiles = <String, Uint8List>{};
    for (int ty = 0; ty < tilesY; ty++) {
      for (int tx = 0; tx < tilesX; tx++) {
        final tile = Uint8List(tileSize * tileSize * 4);
        bool hasContent = false;
        final originY = ty * tileSize;
        final originX = tx * tileSize;
        final maxLocalY = (canvasHeight - originY).clamp(0, tileSize);
        final maxLocalX = (canvasWidth - originX).clamp(0, tileSize);
        for (int y = 0; y < maxLocalY; y++) {
          final worldY = originY + y;
          final rowSrc = (worldY * canvasWidth + originX) * 4;
          final rowDst = (y * tileSize) * 4;
          final byteLen = maxLocalX * 4;
          tile.setRange(rowDst, rowDst + byteLen, bytes, rowSrc);
        }
        for (int i = 3; i < tile.length; i += 4) {
          if (tile[i] != 0) {
            hasContent = true;
            break;
          }
        }
        final key = _tileKey(tx, ty);
        if (recording) {
          final oldTile = oldLayerTiles?[key];
          final changed = hasContent
              ? (oldTile == null || !_tileBytesEqual(oldTile, tile))
              : oldTile != null;
          if (changed) _recordBeforeIfNeeded(layerId, key);
        }
        if (hasContent) {
          newLayerTiles[key] = tile;
          _dirtyTiles.add('$layerId:$key');
        }
      }
    }
    _tiles[layerId] = newLayerTiles;
    _invalidateCache(layerId);
  }

  bool _tileBytesEqual(Uint8List a, Uint8List b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// レイヤー全体を(dx, dy)だけ平行移動する（移動ツール用）。
  Future<void> translateLayer(String layerId, double dx, double dy) {
    final m = Float64List.fromList(const [
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    ]);
    m[12] = dx;
    m[13] = dy;
    return transformLayer(layerId, m);
  }

  void removeLayer(String layerId) {
    _tiles.remove(layerId);
    _invalidateCache(layerId);
  }

  /// 指定シーンに属する全ての合成キー（frameLayerKeyでsceneIdがプレフィックス
  /// された全フレーム・全レイヤー分）のタイルデータを削除する（シーン削除時に使用）。
  void removeSceneTiles(String sceneId) {
    final prefix = '$sceneId#';
    _tiles.removeWhere((key, _) => key.startsWith(prefix));
    _invalidateCachePrefix(prefix);
  }

  /// 合成キーを付け替える（フレーム削除に伴う後続フレームの再インデックス等で使用）。
  /// 移動先に既存データがあれば上書きし、移動した全タイルを次の保存対象にする。
  void renameKey(String oldKey, String newKey) {
    if (oldKey == newKey) return;
    final tiles = _tiles.remove(oldKey);
    if (tiles != null) {
      _tiles[newKey] = tiles;
      // A saved destination may contain different pixels under these same keys.
      for (final tileKey in tiles.keys) {
        _dirtyTiles.add('$newKey:$tileKey');
      }
    }
    _invalidateCache(oldKey);
    _invalidateCache(newKey);
    final prefix = '$oldKey:';
    final toRename = _dirtyTiles.where((d) => d.startsWith(prefix)).toList();
    for (final d in toRename) {
      _dirtyTiles.remove(d);
      _dirtyTiles.add('$newKey:${d.substring(prefix.length)}');
    }
  }

  bool hasLayer(String layerId) => _tiles.containsKey(layerId);

  Map<String, Uint8List> getDirtyTilesForLayer(String layerId) {
    final result = <String, Uint8List>{};
    final layerTiles = _tiles[layerId];
    if (layerTiles == null) return result;
    for (final dirtyKey in _dirtyTiles) {
      if (dirtyKey.startsWith('$layerId:')) {
        final tileKey = dirtyKey.substring(layerId.length + 1);
        if (layerTiles.containsKey(tileKey)) {
          result[tileKey] = layerTiles[tileKey]!;
        }
      }
    }
    return result;
  }

  // ─── Undo記録 ─────────────────────────────────────────────────────────

  /// 1回の描画操作（ストローク・バケツ・投げ縄・トーン・スタンプ・移動・
  /// 変形等）の直前に呼び、以後実際に変更されたタイルのみを記録する。
  void beginUndoRecording(String layerId) {
    _recordingUndo = true;
    _recordingLayerId = layerId;
    _undoBefore.clear();
  }

  /// 現在Undo記録中の対象レイヤーIDと、既に変更が記録された（＝今回の
  /// 操作で実際に触れられた）タイルキー（"tx,ty"形式）の集合を返す。
  /// 記録中でなければnullを返す。ブラシのピクセルモード配色（ストローク
  /// 確定直後の色スナップ）のように、endUndoRecording()でUndo登録を
  /// 確定させる前に「今回変更された範囲だけ」へ後処理を行いたい場合に使う
  /// （canvas_area.dart参照）。
  ({String layerId, Set<String> tileKeys})? get recordingTouchedTiles {
    final layerId = _recordingLayerId;
    if (!_recordingUndo || layerId == null) return null;
    return (layerId: layerId, tileKeys: _undoBefore.keys.toSet());
  }

  /// 記録中であれば、指定タイルの変更前状態を（操作中の初回のみ）記録する。
  /// 未記録のタイルが対象の場合、存在しなければnullを記録する（Undo時は
  /// 「未描画状態」への復元を意味する）。
  void _recordBeforeIfNeeded(String layerId, String tileKey) {
    if (!_recordingUndo || layerId != _recordingLayerId) return;
    if (_undoBefore.containsKey(tileKey)) return;
    final existing = _tiles[layerId]?[tileKey];
    _undoBefore[tileKey] = existing == null
        ? null
        : Uint8List.fromList(existing);
  }

  /// Undo記録を終了し、変更前後のタイルスナップショットを返す（変更が無ければ空）。
  ({Map<String, Uint8List?> before, Map<String, Uint8List?> after})
  endUndoRecording() {
    _recordingUndo = false;
    final layerId = _recordingLayerId;
    _recordingLayerId = null;
    if (layerId == null || _undoBefore.isEmpty) {
      _undoBefore.clear();
      return (before: const {}, after: const {});
    }
    final after = <String, Uint8List?>{};
    for (final key in _undoBefore.keys) {
      final current = _tiles[layerId]?[key];
      after[key] = current == null ? null : Uint8List.fromList(current);
    }
    final before = Map<String, Uint8List?>.from(_undoBefore);
    _undoBefore.clear();
    return (before: before, after: after);
  }

  /// Undo記録中の操作をキャンセルし、変更済みタイルを記録開始直前へ
  /// 即座に戻す。選択変形の浮動画像生成が間に合わずpointer-upされた場合や、
  /// 変形途中でフレームを切り替えた場合など「操作自体を成立させない」用途。
  /// Undo履歴へは登録せず、操作前状態へ完全復元する。
  void cancelUndoRecordingAndRestore() {
    final layerId = _recordingLayerId;
    final before = Map<String, Uint8List?>.from(_undoBefore);
    _recordingUndo = false;
    _recordingLayerId = null;
    _undoBefore.clear();
    if (layerId == null || before.isEmpty) return;
    applyTileSnapshot(layerId, before);
  }

  /// Undo/Redo用：タイルスナップショットをレイヤーへ適用する。
  /// 値がnullのキーはタイルを削除する（記録時点で未描画だったことを意味する）。
  void applyTileSnapshot(String layerId, Map<String, Uint8List?> snapshot) {
    if (snapshot.isEmpty) return;
    final layerMap = _tiles.putIfAbsent(layerId, () => {});
    for (final entry in snapshot.entries) {
      if (entry.value == null) {
        layerMap.remove(entry.key);
      } else {
        layerMap[entry.key] = Uint8List.fromList(entry.value!);
      }
      _dirtyTiles.add('$layerId:${entry.key}');
    }
    if (layerMap.isEmpty) _tiles.remove(layerId);
    _invalidateCache(layerId);
  }

  /// 全タイルデータをシリアライズ（保存用）
  Map<String, Map<String, Uint8List>> exportAll() => Map.unmodifiable(_tiles);

  /// シリアライズデータから復元（読み込み用）
  void importAll(Map<String, Map<String, Uint8List>> data) {
    _tiles.clear();
    _dirtyTiles.clear();
    _sharedTiles.clear();
    for (final layerEntry in data.entries) {
      _tiles[layerEntry.key] = {
        for (final tileEntry in layerEntry.value.entries)
          tileEntry.key: Uint8List.fromList(tileEntry.value),
      };
      // Restoring an autosave can replace tiles at paths already present in the
      // normal archive. Every restored tile must participate in the next save.
      for (final tileKey in layerEntry.value.keys) {
        _dirtyTiles.add('${layerEntry.key}:$tileKey');
      }
    }
    _invalidateCacheAll();
  }
}
