import 'dart:ui';

/// オニオンスキン設定モデル
class OnionSkinSettings {
  final bool enabled;
  final bool showPrev; // 前フレーム表示ON/OFF
  final bool showNext; // 後フレーム表示ON/OFF
  final int prevFrames; // 前表示枚数 1〜10
  final int nextFrames; // 後表示枚数 1〜10
  final int frameInterval; // フレーム間隔 1/2/3/5
  final Color prevColor;
  final Color nextColor;
  final double prevOpacity; // 前フレーム透明度 0〜1
  final double nextOpacity; // 後フレーム透明度 0〜1
  final bool fadeByDistance; // 近いほど濃く表示

  const OnionSkinSettings({
    this.enabled = false,
    this.showPrev = true,
    this.showNext = true,
    this.prevFrames = 3,
    this.nextFrames = 3,
    this.frameInterval = 1,
    this.prevColor = const Color(0xFFFF0000),
    this.nextColor = const Color(0xFF0000FF),
    this.prevOpacity = 0.35,
    this.nextOpacity = 0.35,
    this.fadeByDistance = true,
  });

  OnionSkinSettings copyWith({
    bool? enabled,
    bool? showPrev,
    bool? showNext,
    int? prevFrames,
    int? nextFrames,
    int? frameInterval,
    Color? prevColor,
    Color? nextColor,
    double? prevOpacity,
    double? nextOpacity,
    bool? fadeByDistance,
  }) {
    return OnionSkinSettings(
      enabled: enabled ?? this.enabled,
      showPrev: showPrev ?? this.showPrev,
      showNext: showNext ?? this.showNext,
      prevFrames: prevFrames ?? this.prevFrames,
      nextFrames: nextFrames ?? this.nextFrames,
      frameInterval: frameInterval ?? this.frameInterval,
      prevColor: prevColor ?? this.prevColor,
      nextColor: nextColor ?? this.nextColor,
      prevOpacity: prevOpacity ?? this.prevOpacity,
      nextOpacity: nextOpacity ?? this.nextOpacity,
      fadeByDistance: fadeByDistance ?? this.fadeByDistance,
    );
  }

  static const frameIntervalOptions = [1, 2, 3, 5];
}
