import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';

void main() {
  Brush baseBrush() => const Brush(
        id: 'test',
        name: 'test',
        size: 20,
        opacity: 100,
        spacing: 10,
        stabilization: false,
        stabilizationStrength: 0,
        pixelMode: false,
        fadeMode: FadeMode.off,
        strokeDecay: false,
      );

  test('brush extension defaults are safe and disabled', () {
    final brush = baseBrush();
    expect(brush.lateralRepeatEnabled, isFalse);
    expect(brush.lateralRepeatCount, 1);
    expect(brush.outlineEnabled, isFalse);
    expect(brush.outlineColor, 0xff000000);
    expect(brush.foldEnabled, isFalse);
    expect(brush.tipShape, BrushTipShape.round);
  });

  test('lateral repeat count is clamped to 1 through 10', () {
    expect(baseBrush().copyWith(lateralRepeatCount: 0).lateralRepeatCount, 1);
    expect(baseBrush().copyWith(lateralRepeatCount: 99).lateralRepeatCount, 10);
  });

  test('extension fields survive json round trip', () {
    final configured = baseBrush().copyWith(
      lateralRepeatEnabled: true,
      lateralRepeatCount: 7,
      lateralRepeatSpacing: 1.25,
      outlineEnabled: true,
      outlineWidth: 2.5,
      outlineColor: 0xff1267ab,
      foldEnabled: true,
      foldTriggerAngle: 110,
      yBranchAngle: 55,
      yBranchLengthRatio: .75,
      yBranchWidthRatio: .12,
      yBranchEndTaperRatio: .65,
      tipShape: BrushTipShape.hollowSquare,
    );
    final decoded = Brush.fromJson(configured.toJson());
    expect(decoded.lateralRepeatEnabled, isTrue);
    expect(decoded.lateralRepeatCount, 7);
    expect(decoded.lateralRepeatSpacing, 1.25);
    expect(decoded.outlineEnabled, isTrue);
    expect(decoded.outlineWidth, 2.5);
    expect(decoded.outlineColor, 0xff1267ab);
    expect(decoded.foldEnabled, isTrue);
    expect(decoded.foldTriggerAngle, 110);
    expect(decoded.yBranchAngle, 55);
    expect(decoded.yBranchLengthRatio, .75);
    expect(decoded.yBranchWidthRatio, .12);
    expect(decoded.yBranchEndTaperRatio, .65);
    expect(decoded.tipShape, BrushTipShape.hollowSquare);
    expect(decoded.toJson().containsKey('fillColor'), isFalse);
  });

  test('missing extension fields retain disabled defaults', () {
    final json = baseBrush().toJson()
      ..remove('lateralRepeatEnabled')
      ..remove('lateralRepeatCount')
      ..remove('lateralRepeatSpacing')
      ..remove('outlineEnabled')
      ..remove('outlineWidth')
      ..remove('outlineColor')
      ..remove('foldEnabled')
      ..remove('foldTriggerAngle')
      ..remove('yBranchAngle')
      ..remove('yBranchLengthRatio')
      ..remove('yBranchWidthRatio')
      ..remove('yBranchEndTaperRatio')
      ..remove('tipShape');
    final decoded = Brush.fromJson(json);
    expect(decoded.lateralRepeatEnabled, isFalse);
    expect(decoded.lateralRepeatCount, 1);
    expect(decoded.outlineEnabled, isFalse);
    expect(decoded.outlineColor, 0xff000000);
    expect(decoded.foldEnabled, isFalse);
  });
}
