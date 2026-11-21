import 'dart:ui';

/// [Color]の8bitチャンネル値を読むための拡張。
///
/// Flutterは`Color.red`/`.green`/`.blue`（0〜255のint）を非推奨にし、
/// 0.0〜1.0のdoubleである`.r`/`.g`/`.b`へ移行した。ただしテストの多くは
/// ピクセルバッファ（`Uint8List`のRGBA）と突き合わせるため、比較相手は
/// 8bit整数のままであり、毎回`(c.r * 255.0).round().clamp(0, 255)`と
/// 書くとアサーションの意図が読み取りにくくなる。
///
/// 変換は非推奨APIの置換案そのままで、値も一致する
/// （`.r`は元の8bit値を255で割った値なので、255倍して四捨五入すると
/// 必ず元の整数へ戻る）。
extension ColorChannels8 on Color {
  int get red8 => (r * 255.0).round().clamp(0, 255);
  int get green8 => (g * 255.0).round().clamp(0, 255);
  int get blue8 => (b * 255.0).round().clamp(0, 255);
  int get alpha8 => (a * 255.0).round().clamp(0, 255);
}
