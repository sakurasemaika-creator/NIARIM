import 'dart:ui' as ui;

import '../models/onion_skin_settings.dart';

/// オニオンスキン描画エンジン
class OnionSkinEngine {
  /// 指定フレームオフセットの不透明度を計算
  double getOpacityForFrame(OnionSkinSettings settings, int frameDelta) {
    if (!settings.enabled || frameDelta == 0) return 0;
    final isPrev = frameDelta < 0;
    if (isPrev && !settings.showPrev) return 0;
    if (!isPrev && !settings.showNext) return 0;

    final absDelta = frameDelta.abs();
    final maxFrames = isPrev ? settings.prevFrames : settings.nextFrames;
    final baseOpacity = isPrev ? settings.prevOpacity : settings.nextOpacity;

    if (absDelta % settings.frameInterval != 0) return 0;
    final frameIndex = absDelta ~/ settings.frameInterval; // 1始まり
    if (frameIndex > maxFrames) return 0;

    if (settings.fadeByDistance) {
      final position = maxFrames == 1
          ? 0.0
          : (frameIndex - 1) / (maxFrames - 1).toDouble();
      return baseOpacity * (1.0 - position * 0.6);
    }
    return baseOpacity;
  }

  /// 指定フレームオフセットの色を取得
  ui.Color getColorForFrame(OnionSkinSettings settings, int frameDelta) =>
      frameDelta < 0 ? settings.prevColor : settings.nextColor;

  /// 表示すべきフレームオフセット一覧を取得
  List<int> getVisibleFrameOffsets(OnionSkinSettings settings) {
    if (!settings.enabled) return [];
    final offsets = <int>[];
    if (settings.showPrev) {
      for (int i = 1; i <= settings.prevFrames; i++) {
        offsets.add(-i * settings.frameInterval);
      }
    }
    if (settings.showNext) {
      for (int i = 1; i <= settings.nextFrames; i++) {
        offsets.add(i * settings.frameInterval);
      }
    }
    return offsets;
  }
}
