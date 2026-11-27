import 'asset_tags.dart';
import 'brush.dart';

/// Painting brushes with bristle marks (毛のすじ・かすれ): oil-style brushes
/// that leave streaks along the stroke, break up as they dry and pick up the
/// paint underneath (油彩風混色). Their tip images come from
/// tool/gen_paint_brush_tips.py.
List<Brush> paintBrushPresets() => const [
  // 油彩筆：フィルバート（楕円の平筆）。毛のすじが線に沿って走り、下の色を
  // 拾って引きずる。乾くのは控えめで、線の終わりがかすれる程度。
  Brush(
    id: 'Brush0042',
    name: '油彩筆',
    size: 34,
    opacity: 100,
    spacing: 1,
    stabilization: false,
    stabilizationStrength: 0,
    pixelMode: false,
    pressureOn: BrushPressureOnSettings(
      size: PressureRangeSetting(enabled: true, weak: 55, strong: 100),
      opacity: PressureRangeSetting(enabled: false, weak: 100, strong: 100),
      blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
      edgeJitter: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
      mixing: PressureMixingOnSetting(
        enabled: true,
        mode: BrushMixingMode.oil,
        weakRate: 40,
        strongRate: 40,
        stretch: 35,
      ),
    ),
    pressureOff: BrushPressureOffSettings(
      blur: FixedBrushSetting(enabled: false, value: 0),
      edgeJitter: FixedBrushSetting(enabled: false, value: 0),
      mixing: PressureMixingOffSetting(
        enabled: true,
        mode: BrushMixingMode.oil,
        rate: 40,
        stretch: 35,
      ),
    ),
    fadeMode: FadeMode.off,
    strokeDecay: false,
    rotation: true,
    customImagePaths: ['assets/brushes/filbert_bristle_tip.png'],
    imageInkMode: BrushImageInkMode.alpha,
    bristleStreaks: 60,
    dryBrush: 25,
    tags: [AssetTagKeys.paint, AssetTagKeys.mixing, AssetTagKeys.analog],
  ),
  // かすれ筆：絵の具の少ない平筆。すぐに乾いて、毛のすじに沿ってかすれる。
  // 下の色はあまり拾わない（かすれの隙間から下の色が見える）。
  Brush(
    id: 'Brush0043',
    name: 'かすれ筆',
    size: 48,
    opacity: 100,
    spacing: 1,
    stabilization: false,
    stabilizationStrength: 0,
    pixelMode: false,
    pressureOn: BrushPressureOnSettings(
      size: PressureRangeSetting(enabled: true, weak: 70, strong: 100),
      opacity: PressureRangeSetting(enabled: false, weak: 100, strong: 100),
      blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
      edgeJitter: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
      mixing: PressureMixingOnSetting(
        enabled: true,
        mode: BrushMixingMode.oil,
        weakRate: 15,
        strongRate: 15,
        stretch: 20,
      ),
    ),
    pressureOff: BrushPressureOffSettings(
      blur: FixedBrushSetting(enabled: false, value: 0),
      edgeJitter: FixedBrushSetting(enabled: false, value: 0),
      mixing: PressureMixingOffSetting(
        enabled: true,
        mode: BrushMixingMode.oil,
        rate: 15,
        stretch: 20,
      ),
    ),
    fadeMode: FadeMode.off,
    strokeDecay: false,
    rotation: true,
    customImagePaths: ['assets/brushes/flat_bristle_tip.png'],
    imageInkMode: BrushImageInkMode.alpha,
    bristleStreaks: 70,
    dryBrush: 75,
    tags: [AssetTagKeys.paint, AssetTagKeys.rough, AssetTagKeys.analog],
  ),
  // ペインティングナイフ：刃の平らな面で絵の具を置く。縁はまっすぐで、
  // 下の色を遠くまで引きずる。刃が浮いた所は絵の具が切れる。
  Brush(
    id: 'Brush0044',
    name: 'ペインティングナイフ',
    size: 56,
    opacity: 100,
    spacing: 1,
    stabilization: false,
    stabilizationStrength: 0,
    pixelMode: false,
    pressureOn: BrushPressureOnSettings(
      size: PressureRangeSetting(enabled: false, weak: 100, strong: 100),
      opacity: PressureRangeSetting(enabled: false, weak: 100, strong: 100),
      blur: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
      edgeJitter: PressureRangeSetting(enabled: false, weak: 0, strong: 0),
      mixing: PressureMixingOnSetting(
        enabled: true,
        mode: BrushMixingMode.oil,
        weakRate: 55,
        strongRate: 55,
        stretch: 70,
      ),
    ),
    pressureOff: BrushPressureOffSettings(
      blur: FixedBrushSetting(enabled: false, value: 0),
      edgeJitter: FixedBrushSetting(enabled: false, value: 0),
      mixing: PressureMixingOffSetting(
        enabled: true,
        mode: BrushMixingMode.oil,
        rate: 55,
        stretch: 70,
      ),
    ),
    fadeMode: FadeMode.off,
    strokeDecay: false,
    rotation: true,
    customImagePaths: ['assets/brushes/palette_knife_tip.png'],
    imageInkMode: BrushImageInkMode.alpha,
    dryBrush: 35,
    tags: [AssetTagKeys.paint, AssetTagKeys.mixing, AssetTagKeys.analog],
  ),
];
