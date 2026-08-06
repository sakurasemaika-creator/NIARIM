import 'dart:typed_data';
import 'dart:ui' as ui;

/// Sparse Tile 方式のキャンバスバッファ管理（仕様書26）
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

  TileManager({required this.canvasWidth, required this.canvasHeight})
      : tilesX = (canvasWidth / tileSize).ceil(),
        tilesY = (canvasHeight / tileSize).ceil();

  String _tileKey(int tx, int ty) => '$tx,$ty';

  (int, int) getTileCoord(double x, double y) => (x ~/ tileSize, y ~/ tileSize);

  // ─── タイルバッファ取得・生成 ─────────────────────────────────────────

  /// 指定タイルのピクセルバッファを返す。存在しない場合は透明で初期化して返す。
  Uint8List getOrCreateTile(String layerId, int tx, int ty) {
    final key = _tileKey(tx, ty);
    _tiles.putIfAbsent(layerId, () => {});
    return _tiles[layerId]!.putIfAbsent(
      key,
      () => Uint8List(tileSize * tileSize * 4), // 透明（全ゼロ）
    );
  }

  Uint8List? getTile(String layerId, int tx, int ty) =>
      _tiles[layerId]?[_tileKey(tx, ty)];

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
  void blendPixel(
    Uint8List tile,
    int px,
    int py,
    int r,
    int g,
    int b,
    int a,
  ) {
    if (px < 0 || px >= tileSize || py < 0 || py >= tileSize) return;
    final idx = (py * tileSize + px) * 4;
    final srcA = a / 255.0;
    final dstA = tile[idx + 3] / 255.0;
    final outA = srcA + dstA * (1.0 - srcA);
    if (outA <= 0) return;
    tile[idx]     = ((r * srcA + tile[idx]     * dstA * (1.0 - srcA)) / outA).round().clamp(0, 255);
    tile[idx + 1] = ((g * srcA + tile[idx + 1] * dstA * (1.0 - srcA)) / outA).round().clamp(0, 255);
    tile[idx + 2] = ((b * srcA + tile[idx + 2] * dstA * (1.0 - srcA)) / outA).round().clamp(0, 255);
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

  // ─── レイヤー合成 → ui.Image ─────────────────────────────────────────

  /// 指定レイヤーの全タイルを合成した ui.Image を生成する。
  /// 非同期だが描画ループから呼ぶため Future を返す。
  Future<ui.Image> compositeLayerToImage(String layerId) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final layerTiles = _tiles[layerId];
    if (layerTiles != null) {
      for (final entry in layerTiles.entries) {
        final parts = entry.key.split(',');
        final tx = int.parse(parts[0]);
        final ty = int.parse(parts[1]);
        final img = await _tileToImage(entry.value);
        canvas.drawImage(
          img,
          ui.Offset(tx * tileSize.toDouble(), ty * tileSize.toDouble()),
          ui.Paint(),
        );
        img.dispose();
      }
    }
    final picture = recorder.endRecording();
    return picture.toImage(canvasWidth, canvasHeight);
  }

  Future<ui.Image> _tileToImage(Uint8List pixels) async {
    final codec = await ui.ImageDescriptor.raw(
      await ui.ImmutableBuffer.fromUint8List(pixels),
      width: tileSize,
      height: tileSize,
      pixelFormat: ui.PixelFormat.rgba8888,
    ).instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  // ─── レイヤー管理 ─────────────────────────────────────────────────────

  void copyLayer(String sourceLayerId, String targetLayerId) {
    if (_tiles.containsKey(sourceLayerId)) {
      _tiles[targetLayerId] = {
        for (final e in _tiles[sourceLayerId]!.entries)
          e.key: Uint8List.fromList(e.value),
      };
    }
  }

  void removeLayer(String layerId) => _tiles.remove(layerId);

  bool hasLayer(String layerId) => _tiles.containsKey(layerId);

  Map<String, Uint8List> getDirtyTilesForLayer(String layerId) {
    final result = <String, Uint8List>{};
    final layerTiles = _tiles[layerId];
    if (layerTiles == null) return result;
    for (final dirtyKey in _dirtyTiles) {
      if (dirtyKey.startsWith('$layerId:')) {
        final tileKey = dirtyKey.substring(layerId.length + 1);
        if (layerTiles.containsKey(tileKey)) result[tileKey] = layerTiles[tileKey]!;
      }
    }
    return result;
  }

  /// 全タイルデータをシリアライズ（保存用）
  Map<String, Map<String, Uint8List>> exportAll() => Map.unmodifiable(_tiles);

  /// シリアライズデータから復元（読み込み用）
  void importAll(Map<String, Map<String, Uint8List>> data) {
    _tiles.clear();
    for (final layerEntry in data.entries) {
      _tiles[layerEntry.key] = {
        for (final tileEntry in layerEntry.value.entries)
          tileEntry.key: Uint8List.fromList(tileEntry.value),
      };
    }
  }
}
