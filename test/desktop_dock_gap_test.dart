import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/utils/desktop_dock_column_fit.dart';

void main() {
  test('desktop panels stack with no vertical separator gap', () {
    expect(DesktopDockColumnFit.gap, 0);
    final fitted = DesktopDockColumnFit.layout(
      availableHeight: 850,
      visible: [CanvasDockPanel.brush, CanvasDockPanel.colorPicker],
      isManuallyCollapsed: (_) => false,
      preferredHeight: (_) => 240,
      autoCollapseEnabled: true,
    );
    expect(fitted.automaticallyCollapsed, isEmpty);
    expect(fitted.bodyHeights[CanvasDockPanel.brush], isNotNull);
    expect(fitted.bodyHeights[CanvasDockPanel.colorPicker], isNotNull);
  });
}
