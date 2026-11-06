import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/utils/desktop_dock_column_fit.dart';

void main() {
  test(
    'physical sides select mirrored saved dock groups in left-handed mode',
    () {
      expect(
        DesktopDockColumnFit.storedRightForPhysicalSide(
          physicalRight: false,
          leftHanded: false,
        ),
        isFalse,
      );
      expect(
        DesktopDockColumnFit.storedRightForPhysicalSide(
          physicalRight: true,
          leftHanded: false,
        ),
        isTrue,
      );
      expect(
        DesktopDockColumnFit.storedRightForPhysicalSide(
          physicalRight: false,
          leftHanded: true,
        ),
        isTrue,
      );
      expect(
        DesktopDockColumnFit.storedRightForPhysicalSide(
          physicalRight: true,
          leftHanded: true,
        ),
        isFalse,
      );
    },
  );

  test(
    'automatic folding starts only after minimum body heights are exhausted',
    () {
      const panels = [
        CanvasDockPanel.brush,
        CanvasDockPanel.colorPicker,
        CanvasDockPanel.layer,
      ];
      final roomy = DesktopDockColumnFit.layout(
        availableHeight: 440,
        visible: panels,
        isManuallyCollapsed: (_) => false,
        preferredHeight: (_) => 600,
        autoCollapseEnabled: true,
      );
      expect(roomy.automaticallyCollapsed, isEmpty);
      expect(roomy.bodyHeights.length, 3);
      expect(roomy.bodyHeights.values.every((h) => h >= 80), isTrue);

      final cramped = DesktopDockColumnFit.layout(
        availableHeight: 370,
        visible: panels,
        isManuallyCollapsed: (_) => false,
        preferredHeight: (_) => 600,
        autoCollapseEnabled: true,
        activePanel: CanvasDockPanel.brush,
      );
      expect(cramped.automaticallyCollapsed, {CanvasDockPanel.layer});
      expect(cramped.bodyHeights.containsKey(CanvasDockPanel.brush), isTrue);
      expect(cramped.bodyHeights.containsKey(CanvasDockPanel.layer), isFalse);
    },
  );

  test(
    'least recently used window folds first and active panel never folds',
    () {
      const panels = [
        CanvasDockPanel.brush,
        CanvasDockPanel.colorPicker,
        CanvasDockPanel.layer,
        CanvasDockPanel.tone,
      ];
      final fitted = DesktopDockColumnFit.layout(
        availableHeight: 350,
        visible: panels,
        isManuallyCollapsed: (_) => false,
        preferredHeight: (_) => 260,
        autoCollapseEnabled: true,
        lastUsed: {
          CanvasDockPanel.tone: 10,
          CanvasDockPanel.colorPicker: 20,
          CanvasDockPanel.layer: 30,
          CanvasDockPanel.brush: 40,
        },
        activePanel: CanvasDockPanel.tone,
      );
      expect(fitted.automaticallyCollapsed, {
        CanvasDockPanel.colorPicker,
        CanvasDockPanel.layer,
        CanvasDockPanel.brush,
      });
      expect(
        fitted.automaticallyCollapsed.contains(CanvasDockPanel.tone),
        isFalse,
      );

      final expandedAgain = DesktopDockColumnFit.layout(
        availableHeight: 900,
        visible: panels,
        isManuallyCollapsed: (_) => false,
        preferredHeight: (_) => 260,
        autoCollapseEnabled: true,
      );
      expect(expandedAgain.automaticallyCollapsed, isEmpty);
    },
  );

  test('manual folds are preserved and disabling automation uses scroll', () {
    final panels = CanvasDockPanel.values.toList();
    DesktopDockLayout fit(bool auto) => DesktopDockColumnFit.layout(
      availableHeight: 400,
      visible: panels,
      isManuallyCollapsed: (p) => p == CanvasDockPanel.layer,
      preferredHeight: (_) => 260,
      autoCollapseEnabled: auto,
      activePanel: CanvasDockPanel.brush,
    );
    final on = fit(true);
    expect(on.isCollapsed(CanvasDockPanel.layer, true), isTrue);
    expect(on.automaticallyCollapsed.contains(CanvasDockPanel.layer), isFalse);
    expect(on.automaticallyCollapsed.contains(CanvasDockPanel.brush), isFalse);
    final off = fit(false);
    expect(off.automaticallyCollapsed, isEmpty);
    expect(off.bodyHeights.length, panels.length - 1);
    expect(off.bodyHeights.values.every((h) => h == 80), isTrue);
  });

  test('each entire dock column shares a width and leaves canvas space', () {
    final widths = DesktopDockColumnFit.columnWidths(
      availableWidth: 900,
      leftDesired: 480,
      rightDesired: 480,
      leftVisible: true,
      rightVisible: true,
    );
    expect(widths.left, closeTo(widths.right, 0.001));
    expect(
      widths.left + widths.right + 60 + 160 + 36,
      lessThanOrEqualTo(900.001),
    );

    final folded = DesktopDockColumnFit.columnWidths(
      availableWidth: 700,
      leftDesired: 52,
      rightDesired: 480,
      leftVisible: true,
      rightVisible: true,
    );
    expect(folded.left, 52);
    expect(
      folded.left + folded.right + 60 + 160 + 18,
      lessThanOrEqualTo(700.001),
    );
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
    expect(
      heights[CanvasDockPanel.brush],
      closeTo(heights[CanvasDockPanel.layer]!, 0.001),
    );
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
    final used =
        heights.values.fold<double>(0, (s, h) => s + h) + 2 * 56 + 48 + 2 * 8;
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
      heights.values.fold<double>(0, (s, h) => s + h) + 9 * 56 + 8 * 8,
      greaterThan(450),
      reason: 'full windows stay inside the clipped scrollable dock viewport',
    );
  });
}
