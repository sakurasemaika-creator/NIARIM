#!/usr/bin/env python3
from pathlib import Path

p = Path('lib/engine/tile_manager.dart')
text = p.read_text(encoding='utf-8')

def replace_exact(old: str, new: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'guard failed, expected 1 occurrence, got {count}: {old[:80]!r}')
    text = text.replace(old, new)

replace_exact(
"""  final int compositeCacheMax;
  final Map<String, ui.Image> _compositeCache =
      {}; // 挿入順=LRU順（Dart既定のMapはLinkedHashMap）

  void _invalidateCache(String layerId) {
    _compositeCache.remove(layerId)?.dispose();
  }
""",
"""  final int compositeCacheMax;
  final Map<String, ui.Image> _compositeCache =
      {}; // 挿入順=LRU順（Dart既定のMapはLinkedHashMap）

  // 非同期compositeLayerToImage()の途中でタイルが変更された場合、変更前に
  // 開始した古い合成結果をキャッシュへ戻さないための世代番号。キャッシュ
  // 無効化のたびに増やし、合成開始時の世代と完了時の世代が一致する場合だけ
  // キャッシュ可能とする。これが無いと、無効化後に古い合成Futureが完了して
  // stale画像を再キャッシュし、選択移動等で「切り取った元画像が復活する」
  // レースが起きる。
  int _compositeCacheGeneration = 0;

  void _invalidateCache(String layerId) {
    _compositeCacheGeneration++;
    _compositeCache.remove(layerId)?.dispose();
  }
""",
)

replace_exact(
"""  void _invalidateCachePrefix(String prefix) {
    final keys = _compositeCache.keys
        .where((k) => k.startsWith(prefix))
        .toList();
""",
"""  void _invalidateCachePrefix(String prefix) {
    // キャッシュMapに対象がまだ無くても、同prefixの合成処理が非同期で
    // 進行中かもしれないため世代は必ず進める。
    _compositeCacheGeneration++;
    final keys = _compositeCache.keys
        .where((k) => k.startsWith(prefix))
        .toList();
""",
)

replace_exact(
"""  void _invalidateCacheAll() {
    for (final img in _compositeCache.values) {
""",
"""  void _invalidateCacheAll() {
    _compositeCacheGeneration++;
    for (final img in _compositeCache.values) {
""",
)

replace_exact(
"""  Future<ui.Image> compositeLayerToImage(String layerId) async {
    final cached = _compositeCache[layerId];
    if (cached != null) {
      _touchCache(layerId, cached); // LRU順を更新（末尾へ移動）
      return cached.clone();
    }

    final recorder = ui.PictureRecorder();
""",
"""  Future<ui.Image> compositeLayerToImage(String layerId) async {
    final cached = _compositeCache[layerId];
    if (cached != null) {
      _touchCache(layerId, cached); // LRU順を更新（末尾へ移動）
      return cached.clone();
    }

    // この合成を開始した時点の世代を保持する。下のawait中にタイル変更が
    // 入れば_invalid*が世代を進めるので、完成画像は古いスナップショットと
    // 判断できる。古い画像を呼び出し元へ返すこと自体は進行中プレビューの
    // 1フレームとして許容するが、後続処理が再利用するキャッシュには残さない。
    final generationAtStart = _compositeCacheGeneration;
    final recorder = ui.PictureRecorder();
""",
)

replace_exact(
"""    final image = await picture.toImage(canvasWidth, canvasHeight);
    picture.dispose();
    _touchCache(layerId, image);
    return image.clone();
  }
""",
"""    final image = await picture.toImage(canvasWidth, canvasHeight);
    picture.dispose();
    if (generationAtStart == _compositeCacheGeneration) {
      _touchCache(layerId, image);
      return image.clone();
    }
    // 合成中にタイルが変わった。imageの所有権をそのまま呼び出し元へ渡し、
    // stale結果をキャッシュへ再登録しない。
    return image;
  }
""",
)

p.write_text(text, encoding='utf-8', newline='\n')
print('patched TileManager composite cache generation guard')
