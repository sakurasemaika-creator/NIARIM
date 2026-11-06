import 'package:flutter/material.dart';

import 'color_contrast.dart';

/// 起動画面の導線ボタンのグラデーションの終点で、ボタンの文字・アイコンが
/// 保つAPCAのLc。
const double kSplashGradientMinLc = 45;

/// 起動画面の導線ボタン（とホーム画面のショートカットウィジェット）の
/// グラデーションの2色。
///
/// 塗り[fill]から、テーマが自動で作る色[container]（ライトでは淡い、
/// ダークでは暗い`primaryContainer`等）へ向かうが、ボタンの文字・アイコン
/// [ink]が読めなくなる手前で止める。白抜きの文字を淡い終点へ向かう
/// グラデーションに載せると、右下ほど文字が背景に溶けた。塗りの上で
/// そもそも読めない組み合わせ（利用者が選んだ色）は手を加えない。
List<Color> splashGradientColors(Color fill, Color container, Color ink) {
  bool readable(Color end) =>
      apcaContrast(ink, end).abs() >= kSplashGradientMinLc;
  if (readable(container) || !readable(fill)) return [fill, container];
  var reach = 0.0;
  var tooFar = 1.0;
  for (var i = 0; i < 12; i++) {
    final mid = (reach + tooFar) / 2;
    if (readable(Color.lerp(fill, container, mid)!)) {
      reach = mid;
    } else {
      tooFar = mid;
    }
  }
  return [fill, Color.lerp(fill, container, reach)!];
}
