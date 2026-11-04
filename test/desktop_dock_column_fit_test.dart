import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/utils/desktop_dock_column_fit.dart';

void main() {
  test('each entire dock column shares a width and leaves canvas space', () {
    final widths = DesktopDockColumnFit.columnWidths(
      availableWidth: 900,
      leftDesired: 480,
      rightDesired: 480,
      leftVisible: true,
      rightVisible: true,
    );
    expect(widths.left, closeTo(widths.right, 0.001));
    expect(widths.left + widths.right + 60 + 160 + 36,
        lessThanOrEqualTo(900.001));

    final folded = DesktopDockColumnFit.columnWidths(
      availableWidth: 700,
      leftDesired: 52,
      rightDesired: 480,
      leftVisible: true,
      rightVisible: true,
    );
    expect(folded.left, 52);
    expect(folded.left + folded.right + 60 + 160 + 18,
        lessThanOrEqualTo(700.001));
    expect(
      DesktopDockColumnFit.columnWidths(
        availableWidth: 1200,
        leftDesired: 350,
        rightDesired: 420,
        leftVisible: true,
        rightVisible: true,
      ).left,
      350,
    );
  });

  test('windows fit vertically above frame strip when enough room', () {
    const panels = [
      CanvasDockPanel.brush,
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer,
    ];
    final heights = DesktopDockColumnFit.bodyHeights(
      availableHeight: 560,
      visible: panels,
      isCollapsed: (_) => false,
      preferredHeight: (_) => 260,
    );
    expect(heights.length, 3);
    final content = heights.values.fold<double>(0, (sum, h) => sum + h);
    final used = content + panels.length * 56 + (panels.length - 1) * 8;
    expect(used, lessThanOrEqualTo(560.001));
    expect(heights.values.every((v) => v >= 80), isTrue);
    expect(heights[CanvasDockPanel.brush],
        closeTo(heights[CanvasDockPanel.layer]!, 0.001));
  });

  test('collapsed windows reserve just 48 px and give others height', () {
    const panels = [
      CanvasDockPanel.brush,
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer,
    ];
    final heights = DesktopDockColumnFit.bodyHeights(
      availableHeight: 560,
      visible: panels,
      isCollapsed: (p) => p == CanvasDockPanel.colorPicker,
      preferredHeight: (_) => 260,
    );
    expect(heights.containsKey(CanvasDockPanel.colorPicker), isFalse);
    final used = heights.values.fold<double>(0, (s, h) => s + h) +
        2 * 56 + 48 + 2 * 8;
    expect(used, lessThanOrEqualTo(560.001));
  });

  test('overfull dock keeps minimum bodies and uses column scrolling', () {
    final panels = CanvasDockPanel.values.take(9).toList();
    final heights = DesktopDockColumnFit.bodyHeights(
      availableHeight: 450,
      visible: panels,
      isCollapsed: (_) => false,
      preferredHeight: (_) => 700,
    );
    expect(heights.length, 9);
    expect(heights.values.every((h) => h == 80), isTrue);
    expect(
      heights.values.fold<double>(0, (s, h) => s + h) +
          9 * 56 + 8 * 8,
      greaterThan(450),
      reason: 'full windows stay inside the clipped scrollable dock viewport',
    );
  });
}
