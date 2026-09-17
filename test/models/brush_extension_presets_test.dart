import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/models/brush_presets_extension.dart';

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

  test('bangs preset uses soft jagged flat tip and keeps wave disabled', () {
    final bangs = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0024');
    expect(bangs.name, '前髪');
    expect(bangs.tipShape, BrushTipShape.softJaggedFlat);
    expect(bangs.outlineEnabled, isTrue);
    expect(bangs.foldEnabled, isTrue);
    expect(bangs.foldWaveEnabled, isFalse);
    expect(bangs.foldWaveEndRatio, 0);
    expect(bangs.pressureOn.size.enabled, isTrue);
    expect(bangs.toJson().containsKey('fillColor'), isFalse);
  });

  test('soft jagged flat tip survives brush json round trip', () {
    final bangs = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0024');
    final restored = Brush.fromJson(bangs.toJson());
    expect(restored.tipShape, BrushTipShape.softJaggedFlat);
  });

  test('extension preset ids are unique', () {
    final ids = brushExtensionPresets().map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
