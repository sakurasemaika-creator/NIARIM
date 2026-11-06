import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';

void main() {
  test(
    'pixel grid appears only once project pixels are visually separable',
    () {
      expect(shouldPaintPixelGrid(2.99), isFalse);
      expect(shouldPaintPixelGrid(3.0), isTrue);
      expect(shouldPaintPixelGrid(12.0), isTrue);
    },
  );
}
