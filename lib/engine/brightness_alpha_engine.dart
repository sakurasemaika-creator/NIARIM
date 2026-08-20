import 'dart:typed_data';

/// 「明度で透過」機能（レイヤーパネルの三点メニュー）の実処理。
/// 下描きレイヤーへ誤って線画を描いてしまった時などに、白い部分ほど
/// 透明になるようレイヤーの不透明度をピクセルの明るさから作り直す。
/// 呼び出し規約上、低スペック端末でのUIスレッドブロックを防ぐため
/// compute()（別Isolate）経由での実行を想定する（TileManager側で対応）。
class BrightnessToAlphaParams {
  final Uint8List rgba;
  // true＝グレー：色は元のまま維持し、明るさだけから不透明度を作る
  //   （シンプルな輝度ベース。下描きの色みが薄く残っていても素直に
  //   透過させたい時向け）。
  // false＝カラー：GIMPの「色を透明に（対象＝白）」と同じアルゴリズムで、
  //   白へ近いほど透明にしつつ、残る色を白の外側へ引き伸ばして復元する
  //   （薄い色でも元の色みを保ったまま透過できる）。
  final bool grayMode;
  const BrightnessToAlphaParams(this.rgba, this.grayMode);
}

Uint8List runBrightnessToAlphaInIsolate(BrightnessToAlphaParams params) =>
    applyBrightnessToAlpha(params.rgba, grayMode: params.grayMode);

Uint8List applyBrightnessToAlpha(Uint8List src, {required bool grayMode}) {
  final out = Uint8List.fromList(src);
  for (int i = 0; i < out.length; i += 4) {
    final r = out[i];
    final g = out[i + 1];
    final b = out[i + 2];
    final a = out[i + 3];
    if (a == 0) continue;

    if (grayMode) {
      // 輝度（人の目の感度に近い加重平均）が高いほど＝白に近いほど
      // 透明にする。色そのものは変更しない。
      final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
      final newAlpha = (a * (1.0 - luminance)).round().clamp(0, 255);
      out[i + 3] = newAlpha;
    } else {
      // GIMP「色を透明に」（対象色＝白）と同じ考え方：
      // 各チャンネルが白（255）からどれだけ離れているかの割合のうち
      // 最大値を不透明度とし、色は白の外側へ引き伸ばして復元する。
      final alphaR = (255 - r) / 255.0;
      final alphaG = (255 - g) / 255.0;
      final alphaB = (255 - b) / 255.0;
      final resultAlpha = [alphaR, alphaG, alphaB].reduce((x, y) => x > y ? x : y);
      int nr, ng, nb;
      if (resultAlpha > 0.0001) {
        nr = (255 - (255 - r) / resultAlpha).round().clamp(0, 255);
        ng = (255 - (255 - g) / resultAlpha).round().clamp(0, 255);
        nb = (255 - (255 - b) / resultAlpha).round().clamp(0, 255);
      } else {
        nr = 255;
        ng = 255;
        nb = 255;
      }
      out[i] = nr;
      out[i + 1] = ng;
      out[i + 2] = nb;
      out[i + 3] = (a * resultAlpha).round().clamp(0, 255);
    }
  }
  return out;
}
