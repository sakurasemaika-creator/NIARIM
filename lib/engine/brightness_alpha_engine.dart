import 'dart:math' as math;
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

/// [src]・戻り値とも乗算済み（premultiplied）のRGBA（レイヤーの画素の形）。
/// 色は不透明度で割り戻してから明るさを測り、書くときに新しい不透明度を
/// 掛け直す（以前は乗算済みの値をそのまま色として扱い、不透明度だけを
/// 下げていたため、どのチャンネルも不透明度より大きい壊れた画素になり、
/// 色が白っぽく光った）。
Uint8List applyBrightnessToAlpha(Uint8List src, {required bool grayMode}) {
  final out = Uint8List.fromList(src);
  for (int i = 0; i < out.length; i += 4) {
    final a = out[i + 3];
    if (a == 0) continue;
    // 乗算前の色（0〜255）。
    final unmul = 255.0 / a;
    final r = (out[i] * unmul).clamp(0.0, 255.0);
    final g = (out[i + 1] * unmul).clamp(0.0, 255.0);
    final b = (out[i + 2] * unmul).clamp(0.0, 255.0);

    double nr, ng, nb;
    int newAlpha;
    if (grayMode) {
      // 輝度（人の目の感度に近い加重平均）が高いほど＝白に近いほど
      // 透明にする。色そのものは変更しない。
      final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
      newAlpha = (a * (1.0 - luminance)).round().clamp(0, 255);
      nr = r;
      ng = g;
      nb = b;
    } else {
      // GIMP「色を透明に」（対象色＝白）と同じ考え方：
      // 各チャンネルが白（255）からどれだけ離れているかの割合のうち
      // 最大値を不透明度とし、色は白の外側へ引き伸ばして復元する。
      final alphaR = (255 - r) / 255.0;
      final alphaG = (255 - g) / 255.0;
      final alphaB = (255 - b) / 255.0;
      final resultAlpha = math.max(alphaR, math.max(alphaG, alphaB));
      if (resultAlpha > 0.0001) {
        nr = (255 - (255 - r) / resultAlpha).clamp(0.0, 255.0);
        ng = (255 - (255 - g) / resultAlpha).clamp(0.0, 255.0);
        nb = (255 - (255 - b) / resultAlpha).clamp(0.0, 255.0);
      } else {
        nr = 255;
        ng = 255;
        nb = 255;
      }
      newAlpha = (a * resultAlpha).round().clamp(0, 255);
    }
    // 乗算済みへ掛け直す（透明になった画素は色も0）。
    final mul = newAlpha / 255.0;
    out[i] = (nr * mul).round().clamp(0, newAlpha);
    out[i + 1] = (ng * mul).round().clamp(0, newAlpha);
    out[i + 2] = (nb * mul).round().clamp(0, newAlpha);
    out[i + 3] = newAlpha;
  }
  return out;
}
