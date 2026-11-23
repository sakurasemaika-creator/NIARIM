import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/brush.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/shared_asset_card_preview.dart';

// The stroke on a shared brush card (the image made when a brush is
// shared) shows a custom fade-out the way the canvas draws it.
//
// A custom fade-out is only known once the stroke is complete, so the stroke
// is drawn again at the end. The canvas takes the first pass back first; the
// card drew the final pass over the first, so the full-width end of the first
// pass stayed and the brush looked as if it had no fade-out.

/// The pen at one width all along (the card simulates pen pressure, which
/// would thin the ends on its own).
final _evenPen = BrushService.builtInBrushes.first.copyWith(
  size: 16,
  pressureOn: BrushPressureOnSettings.defaults,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// How many rows of column [x] have ink.
  int thickness(ByteData pixels, int width, int height, int x) {
    var rows = 0;
    for (var y = 0; y < height; y++) {
      if (pixels.getUint8((y * width + x) * 4 + 3) > 32) rows++;
    }
    return rows;
  }

  /// The ink thickness across the card: at the middle and near the end.
  Future<(int, int)> middleAndEnd(WidgetTester tester, Brush brush) async {
    final measured = await tester.runAsync(() async {
      final image = await SharedAssetCardPreview.render(brush: brush);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final w = image.width, h = image.height;
      image.dispose();
      // The stroke runs from x = 12 to x = w - 12.
      var middle = 0;
      for (var x = w ~/ 2 - 6; x <= w ~/ 2 + 6; x++) {
        middle = middle > thickness(data, w, h, x)
            ? middle
            : thickness(data, w, h, x);
      }
      var end = 0;
      for (var x = w - 20; x <= w - 12; x++) {
        end = end > thickness(data, w, h, x) ? end : thickness(data, w, h, x);
      }
      return (middle, end);
    });
    return measured!;
  }

  testWidgets('a custom fade-out ends thin on the card', (tester) async {
    final pen = _evenPen.copyWith(
      fadeMode: FadeMode.custom,
      fadeIn: const FadeEndpointSettings(value: 100, rangePx: 0),
      fadeOut: const FadeEndpointSettings(value: 0, rangePx: 120),
    );
    final (middle, end) = await middleAndEnd(tester, pen);
    expect(middle, greaterThan(4));
    expect(
      end,
      lessThan(middle * 0.6),
      reason: 'the end is as thick as the middle (middle $middle, end $end)',
    );
  });

  testWidgets('a brush without a fade keeps its width to the end', (
    tester,
  ) async {
    final pen = _evenPen.copyWith(fadeMode: FadeMode.off);
    final (middle, end) = await middleAndEnd(tester, pen);
    expect(end, greaterThanOrEqualTo(middle * 0.7));
  });
}
