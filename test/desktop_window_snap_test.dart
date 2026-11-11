import 'dart:ui' show Offset, Rect, Size;
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  test('detached positions persist across projects and can be redocked', () async {
    SharedPreferences.setMockInitialValues({});
    final first = SettingsService();
    await first.init();
    await first.floatDesktopDockPanel(
      CanvasDockPanel.brush, const Offset(120, 165),
    );
    await first.floatDesktopDockPanel(
      CanvasDockPanel.layer, const Offset(345, 205),
    );
    await first.moveDesktopFloatingPanel(
      CanvasDockPanel.brush, const Offset(220, 205),
    );

    final reopened = SettingsService();
    await reopened.init();
    expect(reopened.desktopFloatingPosition(CanvasDockPanel.brush),
        const Offset(220, 205));
    expect(reopened.desktopFloatingPosition(CanvasDockPanel.layer),
        const Offset(345, 205));

    await reopened.redockDesktopFloatingPanel(CanvasDockPanel.brush);
    final redocked = SettingsService();
    await redocked.init();
    expect(redocked.desktopFloatingPosition(CanvasDockPanel.brush), isNull);
    expect(redocked.desktopFloatingPosition(CanvasDockPanel.layer),
        const Offset(345, 205));
    await redocked.resetDesktopWorkspaceLayout();
    final reset = SettingsService();
    await reset.init();
    expect(reset.desktopFloatingPositions, isEmpty);
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
