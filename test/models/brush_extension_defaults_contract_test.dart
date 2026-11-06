import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush_extension_defaults.dart';

void main() {
  test('canonical brush extension contract matches approved spec', () {
    expect(BrushExtensionDefaults.minLateralRepeatCount, 1);
    expect(BrushExtensionDefaults.maxLateralRepeatCount, 10);
    expect(BrushExtensionDefaults.outlineWidth, 1.5);
    expect(BrushExtensionDefaults.outlineColor, 0xff000000);
    expect(BrushExtensionDefaults.foldTriggerAngle, 90);
    expect(BrushExtensionDefaults.yBranchAngle, 45);
    expect(BrushExtensionDefaults.yBranchLengthRatio, .6);
    expect(BrushExtensionDefaults.yBranchWidthRatio, .08);
    expect(BrushExtensionDefaults.yBranchEndTaperRatio, .4);
  });

  test('canonical repeat clamp is bounded', () {
    expect(BrushExtensionDefaults.clampLateralRepeatCount(0), 1);
    expect(BrushExtensionDefaults.clampLateralRepeatCount(5), 5);
    expect(BrushExtensionDefaults.clampLateralRepeatCount(11), 10);
  });
}
