import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 自作ブラシ画像（[Brush.customImagePath]、「ブラシ画像からの
/// ブラシ作成」）のデコード結果キャッシュ。
///
/// ブラシは常に「現在色」で描画する仕様のため、画像は
/// 色情報ではなく形状（アルファマスク）としてのみ使用する。輝度が低い
/// （暗い）ピクセルほど「インクあり」とみなしてアルファへ変換する。
///
/// [DrawingEngine._stampBrush]はポインタ移動のたびに同期的に呼ばれる
/// ホットパスのため、ここでのデコードは非同期の事前読み込み
/// （[preloadBrushTexture]）でのみ行い、描画時は同期の[getCachedBrushTexture]
/// でキャッシュを参照するだけにする。
const int brushTextureSize = 128;

final Map<String, Uint8List> _brushTextureCache = {};

/// キャッシュ済みのブラシテクスチャ（brushTextureSize×brushTextureSize、
/// RGBA・RGB=0でalphaのみ意味を持つ）を返す。未読み込みならnull。
Uint8List? getCachedBrushTexture(String path) => _brushTextureCache[path];

/// [path]の画像を読み込み、アルファマスクへ変換してキャッシュする。
/// ブラシ選択時・自作ブラシ作成時に呼び出しておくことで、実際の描画時には
/// 同期のキャッシュ参照のみで済むようにする。
Future<void> preloadBrushTexture(String path) async {
  if (_brushTextureCache.containsKey(path)) return;
  final file = File(path);
  if (!await file.exists()) return;
  try {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: brushTextureSize,
      targetHeight: brushTextureSize,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    if (byteData == null) return;
    final rgba = byteData.buffer.asUint8List();
    final mask = Uint8List(rgba.length);
    for (int i = 0; i < rgba.length; i += 4) {
      final luminance =
          rgba[i] * 0.299 + rgba[i + 1] * 0.587 + rgba[i + 2] * 0.114;
      final ink = ((255 - luminance) * rgba[i + 3] / 255).round();
      mask[i + 3] = ink.clamp(0, 255);
    }
    _brushTextureCache[path] = mask;
  } catch (_) {
    // 読み込み失敗時はキャッシュへ入れず、円形スタンプへフォールバックさせる。
  }
}
