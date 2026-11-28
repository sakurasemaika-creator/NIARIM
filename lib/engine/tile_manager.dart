import 'dart:async' show scheduleMicrotask;
import 'dart:collection' show HashMap, HashSet, UnmodifiableMapBase;
import 'dart:io' show File, RawZLibFilter, ZLibCodec;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute, visibleForTesting;

import 'brightness_alpha_engine.dart';
import 'fast_crc32.dart';
import 'filter_engine.dart';
import 'mesh_warp_engine.dart';

/// `value.round()` (the nearest integer, halves away from zero) without the
/// native call [double.round] makes: the same integer for every finite
/// [value] in the integer range, and the same error for NaN and infinity.
@pragma('vm:prefer-inline')
int roundHalfAway(double value) {
  final whole = value.truncateToDouble();
  final rest = value - whole;
  final n = whole.toInt();
  if (rest >= 0.5) return n + 1;
  if (rest <= -0.5) return n - 1;
  return n;
}

/// `i.toDouble()` for every byte `i` (looked up rather than converted).
final Float64List byteDoubles = Float64List.fromList([
  for (var i = 0; i < 256; i++) i.toDouble(),
]);

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

/// One tile's pixels as a [TileManager] holds them: expanded (256×256
/// premultiplied RGBA) while they are in use, or only as a raw DEFLATE stream
/// while the expanded tiles of every manager would not fit
/// [TileManager.expandedTileBudget]. A compressed tile is expanded again the
/// next time it is read or written.
///
/// Layer snapshots ([TileManager.structuralSnapshot]) hold these rather than
/// the pixel buffers, so that keeping a layer for Undo does not keep its
/// tiles expanded.
final class StoredTile {
  StoredTile._(Uint8List pixels) : _pixels = pixels;

  /// A tile kept compressed only (its [_deflated] is set by the maker).
  StoredTile._compressed() : _pixels = null;

  Uint8List? _pixels;

  /// The raw DEFLATE stream of the pixels as they are, or null when the
  /// pixels changed since it was made.
  Uint8List? _deflated;

  /// [_deflated] was made by [TileManager.tileCodec] from the pixels, and
  /// [_crc] is their CRC-32: a save writes the stream as it is.
  bool _ownDeflate = false;
  int _crc = 0;

  /// Held under more than one key, or by a snapshot: written through a copy
  /// (copy-on-write).
  bool _shared = false;

  /// When the pixels were last used (for compressing the least recently used
  /// tiles first).
  int _lastUse = 0;

  void _dropDeflated() {
    _deflated = null;
    _ownDeflate = false;
  }
}

/// The pixels of one layer's tiles, read through the tile manager: a
/// compressed tile is expanded into a buffer of its own each time it is read
/// (it is not kept expanded).
final class _LayerPixelsView extends UnmodifiableMapBase<String, Uint8List> {
  _LayerPixelsView(this._tiles);

  final Map<String, StoredTile> _tiles;

  @override
  Uint8List? operator [](Object? key) {
    final tile = _tiles[key];
    return tile == null ? null : TileManager._peek(tile);
  }

  @override
  Iterable<String> get keys => _tiles.keys;

  @override
  int get length => _tiles.length;

  @override
  bool get isEmpty => _tiles.isEmpty;

  @override
  bool get isNotEmpty => _tiles.isNotEmpty;

  @override
  bool containsKey(Object? key) => _tiles.containsKey(key);
}

/// Every layer's [_LayerPixelsView] (the layers as they were when the view
/// was made).
final class _AllPixelsView
    extends UnmodifiableMapBase<String, Map<String, Uint8List>> {
  _AllPixelsView(this._layers);

  final Map<String, Map<String, StoredTile>> _layers;

  @override
  Map<String, Uint8List>? operator [](Object? key) {
    final tiles = _layers[key];
    return tiles == null ? null : _LayerPixelsView(tiles);
  }

  @override
  Iterable<String> get keys => _layers.keys;

  @override
  int get length => _layers.length;

  @override
  bool get isEmpty => _layers.isEmpty;

  @override
  bool get isNotEmpty => _layers.isNotEmpty;

  @override
  bool containsKey(Object? key) => _layers.containsKey(key);
}

/// Sparse Tile 方式のキャンバスバッファ管理。
/// 描画済みタイルのみメモリに保持し、未描画タイルは保持しない。
class TileManager {
  static const int _tileBytes = tileSize * tileSize * 4;

  /// The raw DEFLATE that work files store tiles with (level 6, the
  /// platform's zlib). A tile compressed with it to be kept in memory is
  /// written to a file as it is: the same pixels give the same bytes.
  static final ZLibCodec tileCodec = ZLibCodec(raw: true, level: 6);

  /// How many tiles every manager together keeps expanded: an eighth of this
  /// device's memory (`MemTotal` in `/proc/meminfo`), between 256 MiB and
  /// 2 GiB of tiles (256 MiB when the memory cannot be read). Past it, the
  /// least recently used tiles are kept compressed until they are used again.
  static int expandedTileBudget() =>
      debugExpandedTileBudget ??
      (_deviceTileBudget ??= _tileBudgetFromMemory());

  /// Replaces [expandedTileBudget] (tests: a small budget compresses tiles).
  @visibleForTesting
  static int? debugExpandedTileBudget;

  static int? _deviceTileBudget;

  static const int _fewestBudgetTiles = (256 << 20) ~/ _tileBytes;
  static const int _mostBudgetTiles = (2048 << 20) ~/ _tileBytes;

  static int _tileBudgetFromMemory() {
    try {
      for (final line in File('/proc/meminfo').readAsLinesSync()) {
        final match = RegExp(r'^MemTotal:\s+(\d+)\s+kB').firstMatch(line);
        if (match == null) continue;
        final tiles = int.parse(match.group(1)!) * 1024 ~/ 8 ~/ _tileBytes;
        if (tiles < _fewestBudgetTiles) return _fewestBudgetTiles;
        if (tiles > _mostBudgetTiles) return _mostBudgetTiles;
        return tiles;
      }
    } catch (_) {
      // Not readable on this platform: the smallest budget.
    }
    return _fewestBudgetTiles;
  }

  // At least the tiles every manager holds expanded (tiles dropped from a
  // manager are still counted until the next [_trim] counts them again).
  static int _expandedTiles = 0;
  static int _useClock = 0;
  static bool _trimScheduled = false;
  static final List<WeakReference<TileManager>> _managers = [];
  static int _pruneManagersAt = 64;

  static void _register(TileManager manager) {
    if (_managers.length >= _pruneManagersAt) {
      _managers.removeWhere((ref) => ref.target == null);
      _pruneManagersAt = _managers.length * 2 < 64 ? 64 : _managers.length * 2;
    }
    _managers.add(WeakReference(manager));
  }

  /// A tile of fresh [pixels] (counted as expanded).
  static StoredTile _newTile(Uint8List pixels) {
    final tile = StoredTile._(pixels).._lastUse = ++_useClock;
    _countExpanded();
    return tile;
  }

  static void _countExpanded() {
    if (++_expandedTiles > expandedTileBudget()) _scheduleTrim();
  }

  /// The pixels of [tile] to work on: a compressed tile is expanded and kept
  /// expanded.
  @pragma('vm:prefer-inline')
  static Uint8List _pixelsOf(StoredTile tile) {
    tile._lastUse = ++_useClock;
    return tile._pixels ?? _expand(tile);
  }

  static Uint8List _expand(StoredTile tile) {
    debugExpansions++;
    final pixels = _inflate(tile._deflated!);
    tile._pixels = pixels;
    _countExpanded();
    return pixels;
  }

  /// The pixels of [tile] to read once: a compressed tile is expanded into a
  /// buffer that is not kept.
  static Uint8List _peek(StoredTile tile) =>
      tile._pixels ?? _inflate(tile._deflated!);

  /// A copy of the pixels of [tile] (a compressed tile's expanded bytes are
  /// already a copy).
  static Uint8List _copyOf(StoredTile tile) {
    final pixels = tile._pixels;
    return pixels == null
        ? _inflate(tile._deflated!)
        : Uint8List.fromList(pixels);
  }

  /// The pixels a tile's raw DEFLATE stream [deflated] expands to, with the
  /// platform's zlib.
  static Uint8List _inflate(Uint8List deflated) {
    final filter = RawZLibFilter.inflateFilter(raw: true);
    final out = Uint8List(_tileBytes);
    var at = 0;
    filter.process(deflated, 0, deflated.length);
    for (final end in const [false, true]) {
      for (
        var chunk = filter.processed(end: end);
        chunk != null;
        chunk = filter.processed(end: end)
      ) {
        out.setRange(at, at + chunk.length, chunk);
        at += chunk.length;
      }
    }
    if (at != _tileBytes) {
      throw StateError('A compressed tile expanded to $at bytes');
    }
    return out;
  }

  /// How many tiles were expanded to be kept expanded again, and how many
  /// were kept compressed only, by every manager (tests and measurements).
  static int debugExpansions = 0;
  static int debugCompressions = 0;

  /// Keeps [tile] compressed only (it is expanded again when it is used).
  static void _compress(StoredTile tile) {
    debugCompressions++;
    _anyDeflated = true;
    final pixels = tile._pixels!;
    if (tile._deflated == null) {
      tile
        .._deflated = _encoded(pixels)
        .._crc = crc32Of(pixels)
        .._ownDeflate = true;
    }
    tile._pixels = null;
  }

  static Uint8List _encoded(Uint8List pixels) {
    final encoded = tileCodec.encode(pixels);
    return encoded is Uint8List ? encoded : Uint8List.fromList(encoded);
  }

  static void _scheduleTrim() {
    if (_trimScheduled) return;
    _trimScheduled = true;
    // After the code that expanded the tiles has finished: a caller may hold
    // a tile's buffer while it reads or writes several tiles.
    scheduleMicrotask(_trim);
  }

  /// The expanded tiles of every manager: the tiles of a layer being drawn
  /// on (recording Undo; strokes hold their buffers between pointer events)
  /// and the others.
  static ({Set<StoredTile> kept, List<StoredTile> others}) _expandedNow() {
    final live = <TileManager>[];
    _managers.removeWhere((ref) {
      final manager = ref.target;
      if (manager == null) return true;
      live.add(manager);
      return false;
    });
    _pruneManagersAt = _managers.length * 2 < 64 ? 64 : _managers.length * 2;
    final kept = HashSet<StoredTile>.identity();
    for (final manager in live) {
      final drawn = manager._recordingUndo ? manager._recordingLayerId : null;
      final tiles = drawn == null ? null : manager._tiles[drawn];
      if (tiles == null) continue;
      for (final tile in tiles.values) {
        if (tile._pixels != null) kept.add(tile);
      }
    }
    final seen = HashSet<StoredTile>.identity();
    final others = <StoredTile>[];
    for (final manager in live) {
      for (final tiles in manager._tiles.values) {
        for (final tile in tiles.values) {
          if (tile._pixels == null || kept.contains(tile) || !seen.add(tile)) {
            continue;
          }
          others.add(tile);
        }
      }
    }
    return (kept: kept, others: others);
  }

  /// Counts the tiles every manager holds expanded again (dropped tiles are
  /// no longer counted).
  static int _recountExpanded() {
    final now = _expandedNow();
    return _expandedTiles = now.kept.length + now.others.length;
  }

  /// When more tiles are expanded than [expandedTileBudget], compresses the
  /// least recently used ones until 9/10 of the budget are.
  static void _trim() {
    _trimScheduled = false;
    final budget = expandedTileBudget();
    final now = _expandedNow();
    var expanded = now.kept.length + now.others.length;
    _expandedTiles = expanded;
    if (expanded <= budget) return;
    final target = budget - budget ~/ 10;
    final others = now.others..sort((a, b) => a._lastUse.compareTo(b._lastUse));
    for (final tile in others) {
      if (expanded <= target) break;
      // Only a whole tile expands back to its pixels.
      if (tile._pixels!.length != _tileBytes) continue;
      _compress(tile);
      expanded--;
    }
    _expandedTiles = expanded;
  }

  /// How many more tiles may be kept expanded now (a reader of a work file
  /// keeps the rest compressed).
  static int expandedTileRoom() {
    final room = expandedTileBudget() - _recountExpanded();
    return room < 0 ? 0 : room;
  }

  /// A tile read from a work file ([pixels], as read) for
  /// [importStoredTiles]. [keepExpanded] false keeps only its compressed
  /// stream: [deflated] when given (the file's raw DEFLATE stream of exactly
  /// these pixels, which the tile keeps; it is not written to a file as it
  /// is), otherwise the pixels compressed with [tileCodec]. [deflated] is
  /// kept by an expanded tile too (compressing it later costs nothing).
  static StoredTile readTile(
    Uint8List pixels, {
    Uint8List? deflated,
    required bool keepExpanded,
  }) {
    if (keepExpanded) {
      if (deflated != null) _anyDeflated = true;
      return _newTile(pixels).._deflated = deflated;
    }
    final tile = StoredTile._(pixels).._lastUse = ++_useClock;
    if (deflated != null) tile._deflated = deflated;
    _compress(tile);
    return tile;
  }

  /// The pixels of [tile] (from [readTile]) to read once.
  static Uint8List readTilePixels(StoredTile tile) => _peek(tile);

  /// Whether [tile] holds its pixels expanded (tests).
  @visibleForTesting
  static bool isExpanded(StoredTile tile) => tile._pixels != null;

  /// Whether some tile may keep a compressed stream next to its pixels (then
  /// writing through [getTile]'s buffer must also drop the stream). Never
  /// set while every work fits the budget.
  static bool _anyDeflated = false;

  static const int tileSize = 256;

  final int canvasWidth;
  final int canvasHeight;
  final int tilesX;
  final int tilesY;

  // layerId → tileKey → タイル（展開したピクセルバッファ tileSize*tileSize*4
  // bytes、または圧縮したもの。[StoredTile]）
  final Map<String, Map<String, StoredTile>> _tiles = {};
  // Tiles changed since the work file was last written (the work file's
  // save rewrites these and copies the rest from the file as stored).
  final Set<String> _dirtyTiles = {};
  // Tiles changed since the last automatic save of this session (the next
  // one rewrites these and copies the rest from that save as stored).
  final Set<String> _autosaveDirtyTiles = {};
  // Tiles changed or removed since the making recorder last took them
  // (`layerId:tileKey`). Removed tiles are listed too: the making records
  // that they are gone.
  final Set<String> _makingDirtyTiles = {};
  // CRC-32 of the tiles exactly as the work file holds them (taken from the
  // archive when the work is opened). A tile drops out when it changes.
  final Map<String, int> _storedCrc = {};

  /// Marks the tile under the composite key [key] (`layerId:tileKey`) as
  /// changed for both the work file and the automatic save.
  void _markTileChanged(String key) {
    _dirtyTiles.add(key);
    _autosaveDirtyTiles.add(key);
    _makingDirtyTiles.add(key);
    _storedCrc.remove(key);
  }

  /// Marks every tile of [layerId] as gone for the making recorder (the layer
  /// or its key is dropped without the tiles being changed one by one).
  void _markMakingRemoved(String layerId, Map<String, StoredTile>? tiles) {
    if (tiles == null) return;
    for (final tileKey in tiles.keys) {
      final key = '$layerId:$tileKey';
      _makingDirtyTiles.add(key);
      _storedCrc.remove(key);
    }
  }

  /// Tiles changed or removed since the last call (`layerId:tileKey`), for the
  /// making recorder.
  Set<String> consumeMakingDirtyTiles() {
    if (_makingDirtyTiles.isEmpty) return const {};
    final taken = Set<String>.of(_makingDirtyTiles);
    _makingDirtyTiles.clear();
    return taken;
  }

  /// The CRC-32 of the tile as the work file holds it, or null when it changed
  /// since the work was opened (or was not read from the work file).
  int? storedCrc(String layerId, String tileKey) =>
      _storedCrc['$layerId:$tileKey'];

  /// The tiles of [layerId] (read only; the buffers change as it is drawn on).
  /// A tile kept compressed is expanded into a buffer of its own each time
  /// it is read.
  Map<String, Uint8List> layerTiles(String layerId) =>
      _LayerPixelsView(_tiles[layerId] ?? const {});

  /// Changes each time every tile is replaced at once ([importAll]).
  int get importGeneration => _importGeneration;
  int _importGeneration = 0;

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

  /// Changes when cached layer pixels may have been replaced or edited.
  int get rasterRevision => _rasterRevision;
  int _rasterRevision = 0;

  /// レイヤー1枚ぶんの合成結果のみを捨てる（タイル画像は残す）。
  void _invalidateComposite(String layerId) {
    _rasterRevision++;
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
    final previous = _tileImageCache.remove(key);
    // 同じタイルを同時に作った別の合成の画像（もう使わない）を捨てる。
    if (previous != null && !identical(previous, image)) previous.dispose();
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
    for (final listener in List.of(_layerContentListeners)) {
      listener(layerId);
    }
  }

  final List<void Function(String layerId)> _layerContentListeners = [];

  /// Calls [listener] with a layer's key whenever its pixels change as a
  /// whole (replaced by a filter, moved, restored by Undo...). Strokes, which
  /// write tile by tile, do not call it; whoever draws them redraws itself.
  void addLayerContentListener(void Function(String layerId) listener) =>
      _layerContentListeners.add(listener);

  void removeLayerContentListener(void Function(String layerId) listener) =>
      _layerContentListeners.remove(listener);

  final List<void Function(String layerId)> _strokeCommitListeners = [];

  /// A tile-by-tile edit has finished and previews may render its final pixels.
  void notifyStrokeCommitted(String layerId) {
    for (final listener in List.of(_strokeCommitListeners)) {
      listener(layerId);
    }
  }

  void addStrokeCommitListener(void Function(String layerId) listener) =>
      _strokeCommitListeners.add(listener);

  void removeStrokeCommitListener(void Function(String layerId) listener) =>
      _strokeCommitListeners.remove(listener);

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
    _rasterRevision++;
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
    _rasterRevision++;
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

  // Copy-on-Write：copyLayer等で参照共有されたタイルは[StoredTile._shared]。
  // 実際に書き込みが発生するまで複製しない。

  // Undo記録：1回の描画操作（ストローク・バケツ・投げ縄・変形等）で実際に
  // 触れたタイルのみを差分記録する（スパースタイル方式に合わせ、
  // レイヤー全体ではなく変更のあったタイルだけをUndo/Redo対象とする）。
  bool _recordingUndo = false;

  bool get isRecordingUndo => _recordingUndo;
  String? _recordingLayerId;
  final Map<String, Uint8List?> _undoBefore = {};
  final Map<Uint8List, Uint8List> _paintedPixels = {};
  // 記録中の操作に不透明度ロックをかけるか（[beginUndoRecording]）。
  bool _recordingLocksOpacity = false;
  Uint8List? _recordingSelection;

  TileManager({
    required this.canvasWidth,
    required this.canvasHeight,
    this.compositeCacheMax = 16,
    int? tileImageCacheMax,
  }) : tilesX = (canvasWidth / tileSize).ceil(),
       tilesY = (canvasHeight / tileSize).ceil(),
       // 既定はキャンバス2枚ぶんのタイル数（合成キャッシュの上限に連動させず、
       // 「今描いているレイヤーと直前のレイヤー」が丸ごと載る程度）に収める。
       // ただし128枚で頭打ちにすると、それより多いタイルのレイヤー（3840×2160は
       // 135枚）は合成のたびに古い順に追い出し合い、描く1回ごとに全部のタイルを
       // デコードし直した。少なくともレイヤー1枚の全部のタイル（と8枚）は残す
       // （7680×4320の510枚まで。それより大きいキャンバスでは画像だけで
       // 130MBを超えるので、前と同じく追い出し合う）。
       tileImageCacheMax =
           tileImageCacheMax ??
           _defaultTileImageCacheMax(
             (canvasWidth / tileSize).ceil() * (canvasHeight / tileSize).ceil(),
           ) {
    _register(this);
  }

  static int _defaultTileImageCacheMax(int tiles) {
    final twoLayers = (tiles * 2).clamp(8, 128);
    final oneLayer = tiles + 8 < 518 ? tiles + 8 : 518;
    return twoLayers > oneLayer ? twoLayers : oneLayer;
  }

  String _tileKey(int tx, int ty) => '$tx,$ty';

  (int, int) getTileCoord(double x, double y) => (x ~/ tileSize, y ~/ tileSize);

  // ─── タイルバッファ取得・生成 ─────────────────────────────────────────

  /// 指定タイルのピクセルバッファを返す（書き込み用）。存在しない場合は透明で初期化して返す。
  /// Copy-on-Write：返すバッファが他レイヤーと共有中（copyLayer直後で未実体化）の場合は
  /// ここで初めて複製し、以後はこのレイヤー専用のバッファとして書き込む。
  Uint8List getOrCreateTile(String layerId, int tx, int ty) {
    final key = _tileKey(tx, ty);
    _markTileChanged('$layerId:$key');
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
      final fresh = Uint8List(_tileBytes); // 透明（全ゼロ）
      layerMap[key] = _newTile(fresh);
      return fresh;
    }
    if (existing._shared) {
      final materialized = _copyOf(existing);
      layerMap[key] = _newTile(materialized);
      return materialized;
    }
    final pixels = _pixelsOf(existing);
    // The pixels are about to change: the compressed stream no longer is
    // theirs.
    existing._dropDeflated();
    return pixels;
  }

  /// 指定タイルのピクセルバッファを読み取り用に返す。
  ///
  /// 返るのはキャッシュ本体ではなく実バッファそのもの。書き換えるときは
  /// [getOrCreateTile]で受け取ったバッファに書くこと：このバッファはほかの
  /// タイル（複製したレイヤー・コマ）と共有していることがあり（Copy-on-Write）、
  /// 書くとそのタイルの絵も変わる。アサーションの入ったビルドでは、共有して
  /// いるバッファは読み取り専用のビューで返るので、書き込むと例外になる。
  /// 共有していないバッファを直接書き換えたときは必ず[invalidateTile]を
  /// 呼ぶこと（呼ばないと、そのタイルのデコード済み画像・レイヤーの合成結果が
  /// 古いまま再利用され、変更が画面に出ない。圧縮して持っていたタイルは、
  /// 次に圧縮するときに変更が消える）。圧縮して持っているタイルは展開して
  /// 持ち直す。
  Uint8List? getTile(String layerId, int tx, int ty) {
    final tile = _tiles[layerId]?[_tileKey(tx, ty)];
    if (tile == null) return null;
    final pixels = _pixelsOf(tile);
    if (_guardsSharedTiles && tile._shared) return pixels.asUnmodifiableView();
    return pixels;
  }

  static final bool _guardsSharedTiles = () {
    var guards = false;
    assert(guards = true);
    return guards;
  }();

  /// Reads a pixel by canvas coordinates without creating a tile or invalidating
  /// drawing caches. Returns null when the pixel is outside the canvas or fully
  /// transparent (油彩風混色 picks up the paint under the brush with it).
  ui.Color? getPixelColorAt(String layerId, int x, int y) {
    if (x < 0 || y < 0 || x >= canvasWidth || y >= canvasHeight) return null;
    final tx = x ~/ tileSize;
    final ty = y ~/ tileSize;
    final stored = _tiles[layerId]?[_tileKey(tx, ty)];
    if (stored == null) return null;
    final tile = _pixelsOf(stored);
    final localX = x % tileSize;
    final localY = y % tileSize;
    final index = (localY * tileSize + localX) * 4;
    final alpha = tile[index + 3];
    if (alpha == 0) return null;
    // タイルは乗算済みなので、色は不透明度で割り戻す。
    int straight(int c) => (c * 255 / alpha).round().clamp(0, 255);
    return ui.Color.fromARGB(
      alpha,
      straight(tile[index]),
      straight(tile[index + 1]),
      straight(tile[index + 2]),
    );
  }

  /// [getTile]で得たバッファを直接書き換えたあとに呼び、そのタイルの
  /// キャッシュ（デコード済み画像とレイヤーの合成結果）を捨てる。
  void invalidateTile(String layerId, int tx, int ty) {
    markDirty(layerId, tx, ty);
    _invalidateComposite(layerId);
    _invalidateTileImage(layerId, _tileKey(tx, ty));
  }

  void markDirty(String layerId, int tx, int ty) {
    final key = _tileKey(tx, ty);
    _markTileChanged('$layerId:$key');
    // Written through [getTile]'s buffer: a compressed stream kept for the
    // tile is no longer its pixels.
    if (_anyDeflated) _tiles[layerId]?[key]?._dropDeflated();
  }

  Set<String> consumeDirtyTiles() {
    final dirty = Set<String>.from(_dirtyTiles);
    _dirtyTiles.clear();
    return dirty;
  }

  /// Whether any tile changed since the work file was last written.
  bool get hasDirtyTiles => _dirtyTiles.isNotEmpty;

  /// Whether the tile under [layerId] / [tileKey] changed since the work
  /// file was last written.
  bool isTileDirty(String layerId, String tileKey) =>
      _dirtyTiles.contains('$layerId:$tileKey');

  /// Whether any tile changed since [consumeAutosaveDirtyTiles] (the last
  /// automatic save of this session).
  bool get hasAutosaveDirtyTiles => _autosaveDirtyTiles.isNotEmpty;

  /// Whether the tile under [layerId] / [tileKey] changed since the last
  /// automatic save of this session.
  bool isTileAutosaveDirty(String layerId, String tileKey) =>
      _autosaveDirtyTiles.contains('$layerId:$tileKey');

  /// An automatic save now holds every tile as it is.
  void consumeAutosaveDirtyTiles() => _autosaveDirtyTiles.clear();

  // ─── ピクセル操作 ─────────────────────────────────────────────────────

  /// タイル内の (px, py) へ、色 (r, g, b)（乗算前）を不透明度 a で重ねる
  /// （source-over）。
  ///
  /// タイルの画素は乗算済み（premultiplied）RGBA：画像にするとき
  /// （`ImageDescriptor.raw`）もそう読まれる。以前はここで乗算前の色を
  /// 書いていたため、半透明の所（不透明度を下げた線・線の柔らかい縁）は
  /// RGBが不透明度より大きい不正な画素になり、暗い紙や暗い絵の上で明るく
  /// 光って見えた（黒い紙の上の不透明度50%の赤が真っ赤に出た）。
  void blendPixel(Uint8List tile, int px, int py, int r, int g, int b, int a) {
    if (px < 0 || px >= tileSize || py < 0 || py >= tileSize) return;
    if (a <= 0) return;
    final idx = (py * tileSize + px) * 4;
    final bytes = byteDoubles;
    // Bytes as doubles are looked up (the same values as converted).
    final inBytes = (r | g | b | a) & ~0xFF == 0;
    final aD = inBytes ? bytes[a] : a.toDouble();
    final srcA = aD / 255.0;
    final keep = 1.0 - srcA;
    final outA = _atMost(roundHalfAway(aD + bytes[tile[idx + 3]] * keep), 255);
    tile[idx] = _atMost(
      roundHalfAway(
        (inBytes ? bytes[r] : r.toDouble()) * srcA + bytes[tile[idx]] * keep,
      ),
      outA,
    );
    tile[idx + 1] = _atMost(
      roundHalfAway(
        (inBytes ? bytes[g] : g.toDouble()) * srcA +
            bytes[tile[idx + 1]] * keep,
      ),
      outA,
    );
    tile[idx + 2] = _atMost(
      roundHalfAway(
        (inBytes ? bytes[b] : b.toDouble()) * srcA +
            bytes[tile[idx + 2]] * keep,
      ),
      outA,
    );
    tile[idx + 3] = outA;
  }

  /// `value.clamp(0, upper)` for `upper ≥ 0` (integers: compared only).
  @pragma('vm:prefer-inline')
  static int _atMost(int value, int upper) =>
      value < 0 ? 0 : (value > upper ? upper : value);

  /// [blendPixel]の、重ねる色が乗算済み（r, g, b ≤ a）のもの。
  void blendPremultipliedPixel(
    Uint8List tile,
    int px,
    int py,
    int r,
    int g,
    int b,
    int a,
  ) {
    if (px < 0 || px >= tileSize || py < 0 || py >= tileSize) return;
    if (a <= 0) return;
    final idx = (py * tileSize + px) * 4;
    final keep = 1.0 - a / 255.0;
    final outA = _atMost(
      roundHalfAway(a.toDouble() + tile[idx + 3].toDouble() * keep),
      255,
    );
    tile[idx] = _atMost(
      roundHalfAway(r.toDouble() + tile[idx].toDouble() * keep),
      outA,
    );
    tile[idx + 1] = _atMost(
      roundHalfAway(g.toDouble() + tile[idx + 1].toDouble() * keep),
      outA,
    );
    tile[idx + 2] = _atMost(
      roundHalfAway(b.toDouble() + tile[idx + 2].toDouble() * keep),
      outA,
    );
    tile[idx + 3] = outA;
  }

  /// 消しゴム：タイル内の (px, py) を透明にする。
  void erasePixel(Uint8List tile, int px, int py, int a) {
    if (px < 0 || px >= tileSize || py < 0 || py >= tileSize) return;
    final idx = (py * tileSize + px) * 4;
    final keep = 1.0 - a / 255.0;
    final newA = _atMost(roundHalfAway(tile[idx + 3].toDouble() * keep), 255);
    tile[idx + 3] = newA;
    // 乗算済みなので色も同じ割合で薄くする（不透明度だけ下げると、色が
    // 不透明度より大きい不正な画素になり、消した縁が光って見える）。
    tile[idx] = _atMost(roundHalfAway(tile[idx].toDouble() * keep), newA);
    tile[idx + 1] = _atMost(
      roundHalfAway(tile[idx + 1].toDouble() * keep),
      newA,
    );
    tile[idx + 2] = _atMost(
      roundHalfAway(tile[idx + 2].toDouble() * keep),
      newA,
    );
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
  Future<ui.Image> compositeLayerToImage(
    String layerId, {
    ui.Size? rasterSize,
  }) async {
    final cached = rasterSize == null ? _compositeCache[layerId] : null;
    if (cached != null) {
      _touchCache(layerId, cached); // LRU順を更新（末尾へ移動）
      return cached.clone();
    }

    final revision = _rasterRevision;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final width = rasterSize?.width.toInt() ?? canvasWidth;
    final height = rasterSize?.height.toInt() ?? canvasHeight;
    final paint = ui.Paint();
    if (rasterSize != null) {
      canvas.scale(width / canvasWidth, height / canvasHeight);
      canvas.clipRect(
        ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()),
      );
      paint.filterQuality = ui.FilterQuality.medium;
    }
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
        final stored = entry.value;
        final ui.Image img;
        if (stored._pixels == null) {
          final decoded = await _compressedTileImage(
            layerId,
            entry.key,
            stored,
            revision,
          );
          if (decoded == null) continue;
          img = decoded;
        } else {
          final pixels = _viewOf(layerId, entry.key, _pixelsOf(stored));
          if (pixels == null) continue;
          img = await _tileImage(layerId, entry.key, pixels, revision);
        }
        canvas.drawImage(
          img,
          ui.Offset(tx * tileSize.toDouble(), ty * tileSize.toDouble()),
          paint,
        );
        img.dispose();
      }
    }
    final picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
    if (rasterSize != null || revision != _rasterRevision) return image;
    final handle = image.clone();
    _compositeCache.remove(layerId)?.dispose();
    _touchCache(layerId, image);
    return handle;
  }

  /// 合成に使うタイルの画素。不透明度ロックで記録中の操作が触れたタイルは、
  /// ロックをかけた結果（[opacityLocked]）を返す（描いている途中も、確定後と
  /// 同じ見え方にする。nullは何も描かない）。
  Uint8List? _viewOf(String layerId, String tileKey, Uint8List pixels) {
    if (!_recordingUndo ||
        layerId != _recordingLayerId ||
        !_undoBefore.containsKey(tileKey)) {
      return pixels;
    }
    return _restrictedPixels(pixels, _undoBefore[tileKey], tileKey);
  }

  /// The image of a tile kept compressed for a composite (null draws
  /// nothing): its decoded image when there is one (the tile is not
  /// expanded for it), otherwise the tile expanded as [_viewOf] gives it.
  Future<ui.Image?> _compressedTileImage(
    String layerId,
    String tileKey,
    StoredTile tile,
    int revision,
  ) async {
    final restricted =
        _recordingUndo &&
        layerId == _recordingLayerId &&
        _undoBefore.containsKey(tileKey);
    if (!restricted && revision == _rasterRevision) {
      final cacheKey = _tileImageKey(layerId, tileKey);
      final cached = _tileImageCache[cacheKey];
      if (cached != null) {
        tile._lastUse = ++_useClock;
        _touchTileImage(cacheKey, cached); // LRU順を更新
        return cached.clone();
      }
    }
    final pixels = _viewOf(layerId, tileKey, _pixelsOf(tile));
    if (pixels == null) return null;
    return _tileImage(layerId, tileKey, pixels, revision);
  }

  Uint8List? _restrictedPixels(
    Uint8List? after,
    Uint8List? before,
    String tileKey,
  ) {
    final locked = _recordingLocksOpacity
        ? opacityLocked(after, before)
        : after;
    final selection = _recordingSelection;
    if (selection == null || (before == null && locked == null)) return locked;
    final coordinates = tileKey.split(",");
    final tileX = int.parse(coordinates.first);
    final tileY = int.parse(coordinates.last);
    final output = locked == null
        ? Uint8List(tileSize * tileSize * 4)
        : Uint8List.fromList(locked);
    var nonempty = false;
    for (var y = 0; y < tileSize; y++) {
      for (var x = 0; x < tileSize; x++) {
        final worldX = tileX * tileSize + x;
        final worldY = tileY * tileSize + y;
        final offset = (y * tileSize + x) * 4;
        if (worldX >= canvasWidth ||
            worldY >= canvasHeight ||
            selection[worldY * canvasWidth + worldX] == 0) {
          for (var channel = 0; channel < 4; channel++) {
            output[offset + channel] = before?[offset + channel] ?? 0;
          }
        }
        nonempty |= output[offset + 3] != 0;
      }
    }
    return nonempty ? output : null;
  }

  /// 不透明度ロック：操作後のタイル[after]（乗算済みRGBA、nullは透明）を、
  /// 各画素の不透明度が操作前の[before]（nullは透明）のまま変わらないように
  /// 直した画素を返す（[before]がnullならnull＝何も無い）。
  ///
  /// 色は「操作後の画素を、操作前の色を不透明にしたものの上へ重ねた色」で、
  /// 不透明度は操作前のまま。乗算済みでは `a0·P1 + (1−a1)·P0`
  /// （P0・a0が操作前、P1・a1が操作後）になる。普通に塗った所はsource-atop
  /// （ロックした不透明度の中にだけ色が乗る）と一致し、透明な所には何も
  /// 描かれず、消しゴムは何も変えない。
  static Uint8List? opacityLocked(Uint8List? after, Uint8List? before) {
    if (before == null) return null;
    if (after == null || identical(after, before)) {
      return Uint8List.fromList(before);
    }
    final out = Uint8List(before.length);
    for (int i = 0; i < before.length; i += 4) {
      final a0 = before[i + 3];
      final a1 = after[i + 3];
      out[i + 3] = a0;
      if (a0 == 0) continue;
      final keep = 255 - a1;
      out[i] = (a0 * after[i] + keep * before[i] + 127) ~/ 255;
      out[i + 1] = (a0 * after[i + 1] + keep * before[i + 1] + 127) ~/ 255;
      out[i + 2] = (a0 * after[i + 2] + keep * before[i + 2] + 127) ~/ 255;
    }
    return out;
  }

  /// タイル1枚のデコード済み画像を返す（キャッシュ済みならそれを使う）。
  ///
  /// 返すのはキャッシュの画像の複製（clone）で、呼び出し側が描いた後に
  /// disposeする。キャッシュ本体を返すと、呼び出し側が受け取ってから描く
  /// までの間（awaitの続きが動くまで）に、同時に走っている別の合成が
  /// キャッシュから追い出して破棄し、破棄済みの画像を描いてしまう
  /// （小さいキャンバスで油彩風のストローク中に実際に起きた）。
  Future<ui.Image> _tileImage(
    String layerId,
    String tileKey,
    Uint8List pixels,
    int revision,
  ) async {
    // A composite may still hold a tile from before a write or replacement.
    // Its decoded tiles must not populate the current cache.
    if (revision != _rasterRevision) return _tileToImage(pixels);
    final cacheKey = _tileImageKey(layerId, tileKey);
    final cached = _tileImageCache[cacheKey];
    if (cached != null) {
      _touchTileImage(cacheKey, cached); // LRU順を更新
      return cached.clone();
    }
    final image = await _tileToImage(pixels);
    if (revision != _rasterRevision) return image;
    final handle = image.clone();
    _touchTileImage(cacheKey, image);
    return handle;
  }

  /// How many tile images were decoded, by every tile manager (for tests:
  /// a repeated composite of an unchanged layer decodes none).
  static int debugTileImageDecodes = 0;

  Future<ui.Image> _tileToImage(Uint8List pixels) async {
    debugTileImageDecodes++;
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: tileSize,
      height: tileSize,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    // Codecはネイティブ資源を持つ。フレームを取り出したら必ず解放する
    // （ここはタイルキャッシュが外れるたびにタイル枚数ぶん通る最も熱い経路で、
    // 取り出したframe.imageはCodecを破棄しても有効なまま）。画素の写し
    // （buffer、1枚256KB）とdescriptorも、ガベージコレクションを待たずに
    // 放す（dart:uiのdecodeImageFromPixelsと同じ）。
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    return frame.image;
  }

  // ─── レイヤー管理 ─────────────────────────────────────────────────────

  /// レイヤーを複製する（Copy-on-Write方式）。
  /// タイルバッファは複製時点ではコピーせず参照を共有し、
  /// どちらか一方に書き込みが発生した時点（getOrCreateTile）で初めて実体化する。
  void copyLayer(String sourceLayerId, String targetLayerId) {
    final source = _tiles[sourceLayerId];
    if (source == null) return;
    final target = <String, StoredTile>{};
    for (final e in source.entries) {
      e.value._shared = true;
      target[e.key] = e.value;
      _markTileChanged('$targetLayerId:${e.key}');
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
    final transformed = await brightnessToAlphaPixels(
      layerId,
      grayMode: grayMode,
    );
    if (transformed != null) replaceLayerPixels(layerId, transformed);
  }

  Future<Uint8List?> brightnessToAlphaPixels(
    String layerId, {
    required bool grayMode,
  }) async {
    final composite = await compositeLayerToImage(layerId);
    final byteData = await composite.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    composite.dispose();
    if (byteData == null) return null;
    return compute(
      runBrightnessToAlphaInIsolate,
      BrightnessToAlphaParams(byteData.buffer.asUint8List(), grayMode),
    );
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
  void replaceLayerPixels(
    String layerId,
    Uint8List bytes, {
    Uint8List? selection,
  }) {
    final recording = _recordingUndo && layerId == _recordingLayerId;
    final mask = selection ?? (recording ? _recordingSelection : null);
    if (mask != null && mask.length != canvasWidth * canvasHeight) return;
    final oldLayerTiles = _tiles[layerId];
    final newLayerTiles = <String, StoredTile>{};
    for (int ty = 0; ty < tilesY; ty++) {
      for (int tx = 0; tx < tilesX; tx++) {
        final key = _tileKey(tx, ty);
        final oldStored = oldLayerTiles?[key];
        // Read once: an unchanged tile keeps its stored form (expanded or not).
        final oldTile = oldStored == null ? null : _peek(oldStored);
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
          if (mask == null) {
            tile.setRange(rowDst, rowDst + maxLocalX * 4, bytes, rowSrc);
            continue;
          }
          for (int x = 0; x < maxLocalX; x++) {
            final src = rowSrc + x * 4;
            final dst = rowDst + x * 4;
            if (mask[src ~/ 4] != 0) {
              tile.setRange(dst, dst + 4, bytes, src);
            } else if (oldTile != null) {
              tile.setRange(dst, dst + 4, oldTile, dst);
            }
          }
        }
        for (int i = 3; i < tile.length; i += 4) {
          if (tile[i] != 0) {
            hasContent = true;
            break;
          }
        }
        final changed = hasContent
            ? oldTile == null || !_tileBytesEqual(oldTile, tile)
            : oldTile != null;
        if (changed && recording) _recordBeforeIfNeeded(layerId, key);
        if (hasContent) {
          newLayerTiles[key] = changed ? _newTile(tile) : oldStored!;
        }
        if (changed) _markTileChanged('$layerId:$key');
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
    _markMakingRemoved(layerId, _tiles.remove(layerId));
    _invalidateCache(layerId);
  }

  /// 指定シーンに属する全ての合成キー（frameLayerKeyでsceneIdがプレフィックス
  /// された全フレーム・全レイヤー分）のタイルデータを削除する（シーン削除時に使用）。
  void removeSceneTiles(String sceneId) {
    final prefix = '$sceneId#';
    _tiles.removeWhere((key, tiles) {
      if (!key.startsWith(prefix)) return false;
      _markMakingRemoved(key, tiles);
      return true;
    });
    _invalidateCachePrefix(prefix);
  }

  /// 合成キーを付け替える（フレーム削除に伴う後続フレームの再インデックス等で使用）。
  /// 移動先に既存データがあれば上書きし、移動した全タイルを次の保存対象にする。
  void renameKey(String oldKey, String newKey) {
    if (oldKey == newKey) return;
    final tiles = _tiles.remove(oldKey);
    if (tiles != null) {
      // The making's tiles move: gone under the old key, and what the new key
      // held before is replaced.
      _markMakingRemoved(oldKey, tiles);
      _markMakingRemoved(newKey, _tiles[newKey]);
      _tiles[newKey] = tiles;
      // A saved destination may contain different pixels under these same keys.
      for (final tileKey in tiles.keys) {
        _markTileChanged('$newKey:$tileKey');
      }
    }
    _invalidateCache(oldKey);
    _invalidateCache(newKey);
    final prefix = '$oldKey:';
    for (final set in [_dirtyTiles, _autosaveDirtyTiles]) {
      final toRename = set.where((d) => d.startsWith(prefix)).toList();
      for (final d in toRename) {
        set.remove(d);
        set.add('$newKey:${d.substring(prefix.length)}');
      }
    }
  }

  bool hasLayer(String layerId) => _tiles.containsKey(layerId);

  /// The smallest canvas rectangle holding every visible pixel of
  /// [layerId], or null when the layer is empty (the timeline's handles go
  /// around a material's drawn part, not the whole canvas).
  ui.Rect? contentBounds(String layerId) {
    final layerTiles = _tiles[layerId];
    if (layerTiles == null) return null;
    var left = canvasWidth, top = canvasHeight, right = -1, bottom = -1;
    for (final entry in layerTiles.entries) {
      final comma = entry.key.indexOf(',');
      final tx = int.parse(entry.key.substring(0, comma));
      final ty = int.parse(entry.key.substring(comma + 1));
      final tile = _pixelsOf(entry.value);
      for (var y = 0; y < tileSize; y++) {
        final row = y * tileSize * 4;
        for (var x = 0; x < tileSize; x++) {
          if (tile[row + x * 4 + 3] == 0) continue;
          final cx = tx * tileSize + x;
          final cy = ty * tileSize + y;
          if (cx < left) left = cx;
          if (cx > right) right = cx;
          if (cy < top) top = cy;
          if (cy > bottom) bottom = cy;
        }
      }
    }
    if (right < 0) return null;
    return ui.Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right + 1.0,
      bottom + 1.0,
    );
  }

  Map<String, Uint8List> getDirtyTilesForLayer(String layerId) {
    final result = <String, Uint8List>{};
    final layerTiles = _tiles[layerId];
    if (layerTiles == null) return result;
    for (final dirtyKey in _dirtyTiles) {
      if (dirtyKey.startsWith('$layerId:')) {
        final tileKey = dirtyKey.substring(layerId.length + 1);
        if (layerTiles[tileKey] case final tile?) {
          result[tileKey] = _peek(tile);
        }
      }
    }
    return result;
  }

  // ─── Undo記録 ─────────────────────────────────────────────────────────

  /// 1回の描画操作（ストローク・バケツ・投げ縄・トーン・スタンプ・移動・
  /// 変形等）の直前に呼び、以後実際に変更されたタイルのみを記録する。
  ///
  /// [lockOpacity]が真なら、この操作に不透明度ロックをかける：記録中の
  /// 合成（[compositeLayerToImage]）は[opacityLocked]をかけた見え方になり、
  /// [endUndoRecording]で触れたタイルへ実際にかける。
  void beginUndoRecording(
    String layerId, {
    bool lockOpacity = false,
    Uint8List? selection,
  }) {
    _recordingUndo = true;
    _recordingLayerId = layerId;
    _recordingLocksOpacity = lockOpacity;
    assert(selection == null || selection.length == canvasWidth * canvasHeight);
    _recordingSelection = selection;
    _undoBefore.clear();
    _paintedPixels.clear();
    // 記録の前に作った見え方（ロックの有無が違う）を使い回さない。
    _invalidateComposite(layerId);
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

  /// While recording [layerId], puts the tiles [tileKeys] ("tx,ty") back as
  /// they were when the recording began, keeping the recording (its record
  /// of what they were stays as it is): for drawing part of an operation
  /// again, as putting back every tile with [applyTileSnapshot] and recording
  /// again would. Tiles the operation has not touched are left alone.
  void restoreRecordedTiles(String layerId, Iterable<String> tileKeys) {
    if (!_recordingUndo || layerId != _recordingLayerId) return;
    final layerMap = _tiles.putIfAbsent(layerId, () => {});
    var restored = false;
    for (final key in tileKeys) {
      if (!_undoBefore.containsKey(key)) continue;
      final before = _undoBefore[key];
      final current = layerMap[key]?._pixels;
      if (current != null) _paintedPixels.remove(current);
      if (before == null) {
        layerMap.remove(key);
      } else {
        layerMap[key] = _newTile(Uint8List.fromList(before));
      }
      _markTileChanged('$layerId:$key');
      restored = true;
    }
    if (layerMap.isEmpty) _tiles.remove(layerId);
    if (restored) _invalidateCache(layerId);
  }

  /// Like [restoreRecordedTiles] for parts of one tile kept as it is: puts
  /// back the [cellSize] px cells of tile ([tx], [ty]) in [cellMask] (bit
  /// `row * cells + column`) as they were before the stroke, and forgets
  /// that they were painted.
  void restoreRecordedCells(
    String layerId,
    int tx,
    int ty,
    int cellMask,
    int cellSize,
  ) {
    if (!_recordingUndo || layerId != _recordingLayerId) return;
    final key = '$tx,$ty';
    if (!_undoBefore.containsKey(key)) return;
    final stored = _tiles[layerId]?[key];
    if (stored == null) return;
    final current = _pixelsOf(stored);
    stored._dropDeflated();
    final before = _undoBefore[key];
    final painted = _paintedPixels[current];
    final perRow = tileSize ~/ cellSize;
    for (var bit = 0; bit < perRow * perRow; bit++) {
      if (cellMask & 1 << bit == 0) continue;
      final x0 = bit % perRow * cellSize;
      final y0 = bit ~/ perRow * cellSize;
      for (var y = y0; y < y0 + cellSize; y++) {
        final pixel = y * tileSize + x0;
        if (before == null) {
          current.fillRange(pixel * 4, (pixel + cellSize) * 4, 0);
        } else {
          current.setRange(
            pixel * 4,
            (pixel + cellSize) * 4,
            before,
            pixel * 4,
          );
        }
        painted?.fillRange(pixel, pixel + cellSize, 0);
      }
    }
    _markTileChanged('$layerId:$key');
    _invalidateCache(layerId);
  }

  /// Records brush coverage even when painting leaves an identical color.
  void markPaintedPixel(Uint8List tile, int pixelIndex) {
    if (!_recordingUndo) return;
    final coverage = _paintedPixels.putIfAbsent(
      tile,
      () => Uint8List(tileSize * tileSize),
    );
    coverage[pixelIndex] = 1;
  }

  /// Whether [markPaintedPixel] has recorded pixel [pixelIndex] of [tile].
  bool isPaintedPixel(Uint8List tile, int pixelIndex) =>
      _paintedPixels[tile]?[pixelIndex] == 1;

  /// Puts back what [isPaintedPixel] returned (a pixel painted for a moment
  /// and then taken back).
  void setPaintedPixel(Uint8List tile, int pixelIndex, bool painted) {
    if (!_recordingUndo) return;
    if (painted) {
      markPaintedPixel(tile, pixelIndex);
    } else {
      _paintedPixels[tile]?[pixelIndex] = 0;
    }
  }

  /// Includes only the stroke's pixels in a color post-process.
  void transformRecordingPixels(Uint8List Function(Uint8List) transform) {
    final layerId = _recordingLayerId;
    if (!_recordingUndo || layerId == null) return;
    for (final entry in _undoBefore.entries) {
      final stored = _tiles[layerId]?[entry.key];
      if (stored == null) continue;
      final tile = _pixelsOf(stored);
      final before = entry.value;
      final painted = _paintedPixels[tile];
      final changed = <int>[];
      for (var i = 0; i < tile.length; i += 4) {
        // Cleared pixels have no color left to transform.
        if (tile[i + 3] == 0) continue;
        if (painted?[i ~/ 4] == 1 ||
            before == null ||
            tile[i] != before[i] ||
            tile[i + 1] != before[i + 1] ||
            tile[i + 2] != before[i + 2] ||
            tile[i + 3] != before[i + 3]) {
          changed.add(i);
        }
      }
      if (changed.isEmpty) continue;
      final input = Uint8List(tile.length);
      for (final i in changed) {
        input.setRange(i, i + 4, tile, i);
      }
      final output = transform(input);
      for (final i in changed) {
        tile.setRange(i, i + 4, output, i);
      }
      final coordinates = entry.key.split(',');
      final tx = int.parse(coordinates[0]);
      final ty = int.parse(coordinates[1]);
      invalidateTile(layerId, tx, ty);
    }
  }

  /// 記録中であれば、指定タイルの変更前状態を（操作中の初回のみ）記録する。
  /// 未記録のタイルが対象の場合、存在しなければnullを記録する（Undo時は
  /// 「未描画状態」への復元を意味する）。
  void _recordBeforeIfNeeded(String layerId, String tileKey) {
    if (!_recordingUndo || layerId != _recordingLayerId) return;
    if (_undoBefore.containsKey(tileKey)) return;
    final existing = _tiles[layerId]?[tileKey];
    _undoBefore[tileKey] = existing == null ? null : _copyOf(existing);
  }

  /// Undo記録を終了し、変更前後のタイルスナップショットを返す（変更が無ければ空）。
  ({Map<String, Uint8List?> before, Map<String, Uint8List?> after})
  endUndoRecording() {
    final restricted = _recordingLocksOpacity || _recordingSelection != null;
    _recordingUndo = false;
    _paintedPixels.clear();
    final layerId = _recordingLayerId;
    _recordingLayerId = null;
    if (layerId != null && restricted && _undoBefore.isNotEmpty) {
      _restrictTouchedTiles(layerId);
    }
    _recordingLocksOpacity = false;
    _recordingSelection = null;
    if (layerId == null || _undoBefore.isEmpty) {
      _undoBefore.clear();
      return (before: const {}, after: const {});
    }
    final after = <String, Uint8List?>{};
    for (final key in _undoBefore.keys) {
      final current = _tiles[layerId]?[key];
      after[key] = current == null ? null : _copyOf(current);
    }
    final before = Map<String, Uint8List?>.from(_undoBefore);
    _undoBefore.clear();
    return (before: before, after: after);
  }

  /// 不透明度ロックの操作を終えるとき、触れたタイルへロックを実際にかける。
  void _restrictTouchedTiles(String layerId) {
    final layerMap = _tiles.putIfAbsent(layerId, () => {});
    final unchanged = <String>[];
    for (final entry in _undoBefore.entries) {
      final current = layerMap[entry.key];
      final locked = _restrictedPixels(
        current == null ? null : _pixelsOf(current),
        entry.value,
        entry.key,
      );
      if (locked == null) {
        layerMap.remove(entry.key);
      } else {
        layerMap[entry.key] = _newTile(locked);
      }
      final before = entry.value;
      if (locked == null
          ? before == null
          : before != null && _tileBytesEqual(before, locked)) {
        unchanged.add(entry.key);
      }
      _markTileChanged('$layerId:${entry.key}');
    }
    for (final key in unchanged) {
      _undoBefore.remove(key);
    }
    if (layerMap.isEmpty) _tiles.remove(layerId);
    _invalidateCache(layerId);
  }

  /// Undo記録中の操作をキャンセルし、変更済みタイルを記録開始直前へ
  /// 即座に戻す。選択変形の浮動画像生成が間に合わずpointer-upされた場合や、
  /// 変形途中でフレームを切り替えた場合など「操作自体を成立させない」用途。
  /// Undo履歴へは登録せず、操作前状態へ完全復元する。
  void cancelUndoRecordingAndRestore() {
    final layerId = _recordingLayerId;
    final before = Map<String, Uint8List?>.from(_undoBefore);
    _recordingUndo = false;
    _paintedPixels.clear();
    _recordingLocksOpacity = false;
    _recordingSelection = null;
    _recordingLayerId = null;
    _undoBefore.clear();
    if (layerId == null || before.isEmpty) return;
    applyTileSnapshot(layerId, before);
  }

  /// Replaces one tile ([pixels] null removes it) and drops only what was
  /// drawn from it (the layer's composite and that tile's image), unlike
  /// [applyTileSnapshot], which redraws the whole layer. For a player that
  /// changes a few tiles at a time (the making's playback).
  void putTile(String layerId, String tileKey, Uint8List? pixels) {
    final layerMap = _tiles.putIfAbsent(layerId, () => {});
    if (pixels == null) {
      layerMap.remove(tileKey);
      if (layerMap.isEmpty) _tiles.remove(layerId);
    } else {
      layerMap[tileKey] = _newTile(pixels);
    }
    _markTileChanged('$layerId:$tileKey');
    _invalidateComposite(layerId);
    _invalidateTileImage(layerId, tileKey);
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
        layerMap[entry.key] = _newTile(Uint8List.fromList(entry.value!));
      }
      _markTileChanged('$layerId:${entry.key}');
    }
    if (layerMap.isEmpty) _tiles.remove(layerId);
    _invalidateCache(layerId);
  }

  /// A different TileManager was last persisted. The same archive paths can
  /// now contain different pixels, so the next save must write every tile.
  void markAllTilesDirty() {
    for (final layer in _tiles.entries) {
      for (final tileKey in layer.value.keys) {
        _markTileChanged('${layer.key}:$tileKey');
      }
    }
  }

  /// The tiles of [layerId] as they are now, kept apart from the layer:
  /// later drawing on the layer, or removing it, leaves them unchanged (they
  /// are shared copy-on-write, so no pixels are copied). Null when the layer
  /// has no tiles. [putLayerTiles] puts them under a layer again.
  Map<String, Uint8List>? shareLayerTiles(String layerId) {
    final tiles = _tiles[layerId];
    if (tiles == null) return null;
    return Map.unmodifiable({
      for (final entry in tiles.entries)
        entry.key: _peek(entry.value.._shared = true),
    });
  }

  /// Puts tiles taken with [shareLayerTiles] under [layerId], replacing
  /// what it had.
  void putLayerTiles(String layerId, Map<String, Uint8List> tiles) =>
      restoreStructuralLayers({
        layerId: {
          for (final entry in tiles.entries)
            entry.key: _newTile(entry.value).._shared = true,
        },
      });

  /// Records the layer maps for a structural edit without copying pixel bytes
  /// (a compressed tile stays compressed).
  Map<String, Map<String, StoredTile>> structuralSnapshot() => {
    for (final entry in _tiles.entries) entry.key: Map.of(entry.value),
  };

  void protectHistoryTiles(Map<String, Map<String, StoredTile>?> layers) {
    for (final tiles in layers.values) {
      if (tiles == null) continue;
      for (final tile in tiles.values) {
        tile._shared = true;
      }
    }
  }

  void restoreStructuralLayers(Map<String, Map<String, StoredTile>?> layers) {
    for (final entry in layers.entries) {
      removeLayer(entry.key);
      final tiles = entry.value;
      if (tiles == null) continue;
      for (final tile in tiles.values) {
        tile._shared = true;
      }
      _tiles[entry.key] = Map.of(tiles);
      for (final key in tiles.keys) {
        _markTileChanged('${entry.key}:$key');
      }
      _invalidateCache(entry.key);
    }
  }

  /// 全タイルデータをシリアライズ（保存用）。圧縮して持っているタイルは、
  /// 読むたびにその場で展開したバッファを返す（展開したまま持たない）。
  Map<String, Map<String, Uint8List>> exportAll() =>
      _AllPixelsView(Map.of(_tiles));

  /// The keys of the layers that hold tiles, in the order of [exportAll].
  Iterable<String> get layerKeys => _tiles.keys;

  /// The tile keys ("tx,ty") of [layerId], in the order of [exportAll].
  Iterable<String> tileKeysOf(String layerId) =>
      _tiles[layerId]?.keys ?? const <String>[];

  /// The tile [tileKey] of [layerId] as a file stores it: its pixels
  /// compressed with [tileCodec] and their CRC-32. A tile kept compressed
  /// with [tileCodec] gives its stream as it is (the same bytes compressing
  /// its pixels gives); any other tile is compressed now.
  ({Uint8List deflated, int crc, int size}) deflatedTile(
    String layerId,
    String tileKey,
  ) {
    final tile = _tiles[layerId]![tileKey]!;
    final own = tile._ownDeflate ? tile._deflated : null;
    if (own != null) return (deflated: own, crc: tile._crc, size: _tileBytes);
    final pixels = _peek(tile);
    return (
      deflated: _encoded(pixels),
      crc: crc32Of(pixels),
      size: pixels.length,
    );
  }

  /// シリアライズデータから復元（読み込み用）
  ///
  /// [asStoredInWorkFile]: the tiles were just read from the work file (the
  /// work is opened), so they are what the file holds: none needs to be
  /// written again at the next save of the work file (the save copies them
  /// as stored). The buffers are fresh from the reader and are kept as they
  /// are; one given under several keys is shared copy-on-write. Otherwise
  /// (restoring an automatic or manual save) every tile is written at the
  /// next save. [storedCrcs] (`layerId:tileKey` → CRC-32) are the work
  /// file's checksums of those tiles, kept for the making recorder.
  void importAll(
    Map<String, Map<String, Uint8List>> data, {
    bool asStoredInWorkFile = false,
    Map<String, int>? storedCrcs,
  }) {
    final Map<String, Map<String, StoredTile>> tiles;
    if (asStoredInWorkFile) {
      // A buffer the reader gave under more than one key (identical tiles of
      // copied frames) is one tile, shared copy-on-write like the tiles of a
      // copied layer.
      final byBuffer = HashMap<Uint8List, StoredTile>.identity();
      tiles = {
        for (final layer in data.entries)
          layer.key: {
            for (final tile in layer.value.entries)
              tile.key: byBuffer.putIfAbsent(
                tile.value,
                () => _newTile(tile.value),
              ),
          },
      };
    } else {
      tiles = {
        for (final layer in data.entries)
          layer.key: {
            for (final tile in layer.value.entries)
              tile.key: _newTile(Uint8List.fromList(tile.value)),
          },
      };
    }
    _importTiles(
      tiles,
      asStoredInWorkFile: asStoredInWorkFile,
      storedCrcs: storedCrcs,
    );
  }

  /// [importAll] with `asStoredInWorkFile` for tiles read from the work file
  /// with [readTile] (a tile kept compressed stays compressed). A tile given
  /// under more than one key is shared copy-on-write.
  void importStoredTiles(
    Map<String, Map<String, StoredTile>> data, {
    Map<String, int>? storedCrcs,
  }) => _importTiles(data, asStoredInWorkFile: true, storedCrcs: storedCrcs);

  /// [importAll] of [source]'s tiles ([source]`.exportAll()`, every tile
  /// independent of [source]'s) without expanding the tiles [source] keeps
  /// compressed: their streams, which are never written into, are shared.
  void importAllFrom(TileManager source) {
    StoredTile copy(StoredTile tile) {
      final pixels = tile._pixels;
      final copied = pixels == null
          ? (StoredTile._compressed().._lastUse = ++_useClock)
          : _newTile(Uint8List.fromList(pixels));
      return copied
        .._deflated = tile._deflated
        .._ownDeflate = tile._ownDeflate
        .._crc = tile._crc;
    }

    _importTiles({
      for (final layer in source._tiles.entries)
        layer.key: {
          for (final tile in layer.value.entries) tile.key: copy(tile.value),
        },
    });
  }

  void _importTiles(
    Map<String, Map<String, StoredTile>> data, {
    bool asStoredInWorkFile = false,
    Map<String, int>? storedCrcs,
  }) {
    // 前にあったレイヤーと読み込んだレイヤーの両方が「まとめて変わった」。
    final changed = {..._tiles.keys, ...data.keys};
    // Every tile there was is gone for the making, unless the work is being
    // opened (then there was nothing yet, and the opened tiles are as stored).
    _makingDirtyTiles.clear();
    if (!asStoredInWorkFile) {
      for (final entry in _tiles.entries) {
        _markMakingRemoved(entry.key, entry.value);
      }
    }
    _storedCrc.clear();
    _importGeneration++;
    _tiles.clear();
    _dirtyTiles.clear();
    _autosaveDirtyTiles.clear();
    // A tile given under more than one key is shared copy-on-write.
    final kept = HashSet<StoredTile>.identity();
    for (final layerEntry in data.entries) {
      _tiles[layerEntry.key] = Map.of(layerEntry.value);
      for (final tile in layerEntry.value.values) {
        if (!kept.add(tile)) tile._shared = true;
      }
      for (final tileKey in layerEntry.value.keys) {
        final key = '${layerEntry.key}:$tileKey';
        // No automatic save of this session holds these tiles yet.
        _autosaveDirtyTiles.add(key);
        if (asStoredInWorkFile) {
          if (storedCrcs?[key] case final crc?) _storedCrc[key] = crc;
        } else {
          _makingDirtyTiles.add(key);
        }
        // Restoring an autosave can replace tiles at paths already present
        // in the normal archive. Every restored tile must participate in the
        // next save.
        if (!asStoredInWorkFile) _dirtyTiles.add(key);
      }
    }
    _invalidateCacheAll();
    // 開いているキャンバスに描き直させる（自動保存からの復元で、絵は戻って
    // いるのに画面は前の絵のままだった）。
    for (final layerId in changed) {
      for (final listener in List.of(_layerContentListeners)) {
        listener(layerId);
      }
    }
  }
}
