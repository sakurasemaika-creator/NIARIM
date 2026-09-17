import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

Brush _baseBrush({
  String? customImagePath,
  List<String> customImagePaths = const [],
  BrushImageSelectionMode customImageSelectionMode = BrushImageSelectionMode.random,
}) => Brush(
      id: 'test',
      name: 'test',
      size: 20,
      opacity: 100,
      spacing: 1,
      stabilization: false,
      stabilizationStrength: 0,
      pixelMode: false,
      fadeMode: FadeMode.off,
      strokeDecay: false,
      customImagePath: customImagePath,
      customImagePaths: customImagePaths,
      customImageSelectionMode: customImageSelectionMode,
    );

void main() {
  test('net preset uses lateral repetition and hollow square tip', () {
    final net = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0022');
    expect(net.name, 'ネット');
    expect(net.spacing, 100);
    expect(net.lateralRepeatEnabled, isTrue);
    expect(net.lateralRepeatCount, 4);
    expect(net.tipShape, BrushTipShape.hollowSquare);
  });

  test('hair preset uses current fill, outline, straight fold and 30% endpoint wave', () {
    final hair = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0023');
    expect(hair.name, '髪の毛');
    expect(hair.outlineEnabled, isTrue);
    expect(hair.outlineColor, 0xff000000);
    expect(hair.outlineWidth, 1.5);
    expect(hair.foldEnabled, isTrue);
    expect(hair.foldTriggerAngle, 90);
    expect(hair.foldCurveStartRatio, .25);
    expect(hair.foldDepthRatio, .55);
    expect(hair.foldLengthRatio, .8);
    expect(hair.foldEndTaperRatio, .35);
    expect(hair.foldWaveEnabled, isTrue);
    expect(hair.foldWaveEndRatio, .30);
    expect(hair.foldWaveTriggerAngle, 45);
    expect(hair.toJson().containsKey('fillColor'), isFalse);
  });

  test('bangs preset uses multiple random textures and keeps wave disabled', () {
    final bangs = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0024');
    expect(bangs.name, '前髪');
    expect(bangs.customImagePaths.length, greaterThanOrEqualTo(4));
    expect(bangs.customImageSelectionMode, BrushImageSelectionMode.random);
    expect(bangs.outlineEnabled, isTrue);
    expect(bangs.foldEnabled, isTrue);
    expect(bangs.foldWaveEnabled, isFalse);
    expect(bangs.foldWaveEndRatio, 0);
    expect(bangs.pressureOn.size.enabled, isTrue);
    expect(bangs.toJson().containsKey('fillColor'), isFalse);
  });

  test('multiple texture selection survives brush json round trip', () {
    final brush = _baseBrush(
      customImagePaths: const ['a.png', 'b.png', 'c.png'],
      customImageSelectionMode: BrushImageSelectionMode.sequential,
    );
    final restored = Brush.fromJson(brush.toJson());
    expect(restored.customImagePaths, const ['a.png', 'b.png', 'c.png']);
    expect(restored.customImageSelectionMode, BrushImageSelectionMode.sequential);
  });

  test('legacy single custom image remains available as one texture', () {
    final restored = Brush.fromJson(_baseBrush(customImagePath: 'legacy.png').toJson());
    expect(restored.customImagePath, 'legacy.png');
    expect(restored.resolvedCustomImagePaths, const ['legacy.png']);
  });

  test('extension preset ids are unique', () {
    final ids = brushExtensionPresets().map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
