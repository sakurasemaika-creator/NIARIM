import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PC/DeXモードのドックの窓は、左右どちらかの列にだけ置く。反対側の列へ
/// 移した窓が、起動し直したとき元の列にも戻って2つ出ないこと。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> restart() async {
    final settings = SettingsService();
    await settings.init();
    return settings;
  }

  test('a window moved to the other column stays only there', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await restart();
    await first.moveDesktopDockPanel(CanvasDockPanel.layer, toRight: false);
    await first.moveDesktopDockPanel(
      CanvasDockPanel.brush,
      toRight: true,
      before: CanvasDockPanel.colorPicker,
    );

    final again = await restart();
    expect(again.toolOptionDockOrder, contains(CanvasDockPanel.layer));
    expect(again.rightDockOrder, isNot(contains(CanvasDockPanel.layer)));
    expect(again.rightDockOrder, [
      CanvasDockPanel.canvasPreview,
      CanvasDockPanel.brush,
      CanvasDockPanel.colorPicker,
    ]);
    expect(again.toolOptionDockOrder, isNot(contains(CanvasDockPanel.brush)));
    // どの窓もちょうど1つの列にある。
    for (final panel in CanvasDockPanel.values) {
      final count =
          again.toolOptionDockOrder.where((p) => p == panel).length +
          again.rightDockOrder.where((p) => p == panel).length;
      expect(count, 1, reason: panel.name);
    }
  });

  test('every window of the right column can move to the left', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await restart();
    for (final panel in List.of(first.rightDockOrder)) {
      await first.moveDesktopDockPanel(panel, toRight: false);
    }
    expect(first.rightDockOrder, isEmpty);
    final again = await restart();
    expect(again.rightDockOrder, isEmpty);
    expect(again.toolOptionDockOrder.toSet(), CanvasDockPanel.values.toSet());
  });

  test('older saved data with a window in both columns keeps one', () async {
    SharedPreferences.setMockInitialValues({
      'tool_option_dock_order': [
        CanvasDockPanel.penSubTool.name,
        CanvasDockPanel.layer.name,
      ],
      'right_dock_order': [
        CanvasDockPanel.canvasPreview.name,
        CanvasDockPanel.colorPicker.name,
        CanvasDockPanel.layer.name,
      ],
    });
    final settings = await restart();
    expect(settings.toolOptionDockOrder.take(2), [
      CanvasDockPanel.penSubTool,
      CanvasDockPanel.layer,
    ]);
    expect(settings.rightDockOrder, [
      CanvasDockPanel.canvasPreview,
      CanvasDockPanel.colorPicker,
    ]);
  });
}
