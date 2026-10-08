import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/background_acclimation_engine.dart';

/// 背景馴染ませ lays the background's light and colour over the picture in
/// Hard Light: a light colour channel brightens (screen), a dark one deepens
/// (multiply), and a mid one leaves the picture's own tone, unlike a plain
/// mix towards the colour.
void main() {
  test('the colour is laid over in Hard Light', () {
    final (r, g, b) = BackgroundAcclimationEngine.blendForTest(
      200,
      200,
      200,
      0xFFFF8000,
      1,
    );
    expect(r, closeTo(255, 1), reason: 'a light channel screens to white');
    expect(g, closeTo(200, 2), reason: 'a mid channel keeps the picture');
    expect(b, closeTo(0, 1), reason: 'a dark channel multiplies to black');
  });

  test('half strength goes halfway towards the Hard Light result', () {
    final (r, g, b) = BackgroundAcclimationEngine.blendForTest(
      100,
      100,
      100,
      0xFF202020,
      .5,
    );
    // Hard Light of a dark grey (0.125) over 100: multiply by 0.25 = 25.
    expect(r, closeTo((100 + 25) / 2, 1.5));
    expect(g, r);
    expect(b, r);
  });
}
