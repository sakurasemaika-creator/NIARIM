import 'dart:ui' show Offset, Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/utils/desktop_window_snap.dart';

void main() {
  const size = Size(200, 160);
  const other = Rect.fromLTWH(300, 120, 200, 160);

  test('side-by-side edges magnetically touch within 12 logical pixels', () {
    expect(
      snapDesktopWindow(const Offset(89, 160), size, [other]),
      const Offset(100, 160),
    );
    expect(
      snapDesktopWindow(const Offset(511, 160), size, [other]),
      const Offset(500, 160),
    );
  });

  test('top and bottom edges attach when their horizontal spans overlap', () {
    expect(
      snapDesktopWindow(const Offset(310, -31), size, [other]),
      const Offset(310, -40),
    );
    expect(
      snapDesktopWindow(const Offset(310, 289), size, [other]),
      const Offset(310, 280),
    );
  });

  test('overlaps, distant windows and off-axis neighbours are not forced', () {
    expect(
      snapDesktopWindow(const Offset(350, 170), size, [other]),
      const Offset(350, 170),
    );
    expect(
      snapDesktopWindow(const Offset(20, 20), size, [other]),
      const Offset(20, 20),
    );
    expect(
      snapDesktopWindow(const Offset(89, 400), size, [other]),
      const Offset(89, 400),
    );
  });
}
