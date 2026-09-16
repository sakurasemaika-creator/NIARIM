import 'dart:typed_data';

/// ピクセルモード（ブラシ）・ドット絵フィルター（描画フィルター／演出
/// フィルター）で共通して使う配色方式。
///
/// - [none]：色数を制限せず、元の色（描画色・元画像の色）をそのまま使う。
/// - [count]：使用する色の「数」だけを指定する（1〜256）。実際に使う色は
///   元の画像・描画色から自動で決まる（指定はできない）。
/// - [explicit]：ユーザーが個別に指定した色のリストだけを使う（各画素は
///   最も近い色へスナップする）。「色を指定する」を選ぶと黒いカラー
///   チップが1つ表示され、タップで色を変更・＋ボタンで追加・ゴミ箱
///   ボタンで削除できる。
/// - [palette]：ユーザーが保存したドット絵専用パレット（[PixelArtPalette]）
///   の色だけを使う。仕組みは[explicit]と同じで、色の出所がパレットに
///   なる。
enum PixelColorMode { none, count, explicit, palette }

/// ドット絵変換の共通実装。
///
/// 従来のドット絵フィルターはモザイク処理を先に行っていたため、RGBだけで
/// なくalphaまでセル平均され、透明な背景との境界に半透明の四角いにじみが
/// 生じていた。ここではセル内の代表RGBだけを求め、alphaは各キャンバス画素
/// の元値を一切変更しない。これにより完全不透明な入力は隅まで完全不透明の
/// まま、透明画素は透明のまま保たれる。モザイクはFilterEngine.applyMosaic
/// として別効果のまま残す。
extension TruePixelArtFilter on Object {
  Uint8List applyPixelate(
    Uint8List data,
    int width,
    int height, {
    required int mosaicSize,
    required PixelColorMode colorMode,
    int colorLevels = 6,
    List<int> paletteColors = const [],
  }) {
    final size = mosaicSize.clamp(1, 64);
    final result = Uint8List.fromList(data);

    for (int y = 0; y < height; y += size) {
      for (int x = 0; x < width; x += size) {
        int weightedR = 0, weightedG = 0, weightedB = 0, alphaWeight = 0;
        for (int dy = 0; dy < size && y + dy < height; dy++) {
          for (int dx = 0; dx < size && x + dx < width; dx++) {
            final i = ((y + dy) * width + (x + dx)) * 4;
            final a = data[i + 3];
            if (a == 0) continue;
            weightedR += data[i] * a;
            weightedG += data[i + 1] * a;
            weightedB += data[i + 2] * a;
            alphaWeight += a;
          }
        }
        if (alphaWeight == 0) continue;

        var r = (weightedR / alphaWeight).round().clamp(0, 255);
        var g = (weightedG / alphaWeight).round().clamp(0, 255);
        var b = (weightedB / alphaWeight).round().clamp(0, 255);

        switch (colorMode) {
          case PixelColorMode.none:
            break;
          case PixelColorMode.count:
            final step = (256 / colorLevels.clamp(1, 256)).round().clamp(1, 256);
            r = ((r / step).round() * step).clamp(0, 255);
            g = ((g / step).round() * step).clamp(0, 255);
            b = ((b / step).round() * step).clamp(0, 255);
            break;
          case PixelColorMode.explicit:
          case PixelColorMode.palette:
            if (paletteColors.isNotEmpty) {
              var best = paletteColors.first;
              var bestDistance = 1 << 30;
              for (final color in paletteColors) {
                final pr = (color >> 16) & 0xFF;
                final pg = (color >> 8) & 0xFF;
                final pb = color & 0xFF;
                final dr = r - pr;
                final dg = g - pg;
                final db = b - pb;
                final distance = dr * dr + dg * dg + db * db;
                if (distance < bestDistance) {
                  bestDistance = distance;
                  best = color;
                }
              }
              r = (best >> 16) & 0xFF;
              g = (best >> 8) & 0xFF;
              b = best & 0xFF;
            }
            break;
        }

        for (int dy = 0; dy < size && y + dy < height; dy++) {
          for (int dx = 0; dx < size && x + dx < width; dx++) {
            final i = ((y + dy) * width + (x + dx)) * 4;
            if (data[i + 3] == 0) continue;
            result[i] = r;
            result[i + 1] = g;
            result[i + 2] = b;
            // result[i + 3] intentionally remains the original source alpha.
          }
        }
      }
    }
    return result;
  }
}
