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

  test('hair preset uses current fill plus black outline and folds', () {
    final hair = brushExtensionPresets().singleWhere((b) => b.id == 'Brush0023');
    expect(hair.name, '髪の毛');
    expect(hair.outlineEnabled, isTrue);
    expect(hair.outlineColor, 0xff000000);
    expect(hair.outlineWidth, 1.5);
    expect(hair.foldEnabled, isTrue);
    expect(hair.foldTriggerAngle, 90);
    expect(hair.yBranchAngle, 45);
    expect(hair.yBranchLengthRatio, .6);
    expect(hair.yBranchWidthRatio, .08);
    expect(hair.yBranchEndTaperRatio, .4);
    expect(hair.toJson().containsKey('fillColor'), isFalse);
  });

  test('extension preset ids are unique', () {
    final ids = brushExtensionPresets().map((b) => b.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
