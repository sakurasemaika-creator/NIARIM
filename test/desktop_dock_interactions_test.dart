import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/canvas_dock_panel.dart';
import 'package:niarim/screens/settings/widgets/pc_workspace_layout_preview.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('each dock collapses independently and restores after restart', () async {
    final settings = SettingsService();
    await settings.init();
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isFalse);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.layer), isFalse);
    await settings.setDesktopDockWidth(CanvasDockPanel.brush, 360);
    expect(settings.desktopToolPanelWidth, 360);
    expect(settings.desktopDockWidth(CanvasDockPanel.penSubTool, right: false), 360);
    expect(settings.desktopPanelWidth, 280);
    await settings.setDesktopDockWidth(CanvasDockPanel.colorPicker, 340);
    expect(settings.desktopPanelWidth, 340);
    expect(settings.desktopDockWidth(CanvasDockPanel.layer, right: true), 340);
    expect(settings.desktopToolPanelWidth, 360);
    await settings.setDesktopDockHeight(CanvasDockPanel.brush, 340);
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, true);
    await settings.setDesktopDockCollapsed(CanvasDockPanel.layer, true);
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, false);

    final reloaded = SettingsService();
    await reloaded.init();
    expect(reloaded.isDesktopDockCollapsed(CanvasDockPanel.brush), isFalse);
    expect(reloaded.isDesktopDockCollapsed(CanvasDockPanel.layer), isTrue);
    expect(reloaded.desktopDockWidth(CanvasDockPanel.brush, right: false), 360);
    expect(reloaded.desktopDockWidth(CanvasDockPanel.layer, right: true), 340);
    expect(reloaded.desktopDockHeight(CanvasDockPanel.brush), 340);
    await reloaded.setDesktopDockCollapsed(CanvasDockPanel.layer, false);
    final reopened = SettingsService();
    await reopened.init();
    expect(reopened.isDesktopDockCollapsed(CanvasDockPanel.layer), isFalse);
  });

  testWidgets('preview folds left and right windows toward their outer edges',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsService();
    await settings.init();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PcWorkspaceLayoutPreview(labelOf: (panel) => panel.name),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pcPreviewCollapse-brush')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPreviewCollapse-layer')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPreviewDrag-brush')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPreviewWidth-brush')), findsNothing);
    expect(find.byKey(const ValueKey('pcPreviewWidth-layer')), findsNothing);
    expect(find.byKey(const ValueKey('pcPreviewToolColumnResize')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPreviewRightColumnResize')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPreviewHeight-brush')), findsOneWidget);

    // A single column drag changes every window on that side, not the other.
    await tester.drag(
      find.byKey(const ValueKey('pcPreviewToolColumnResize')),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();
    expect(settings.desktopToolPanelWidth, greaterThan(280));
    expect(settings.desktopPanelWidth, 280);

    // Handedness moves ONLY the outer toolbar. Both dock columns keep
    // their left/right order, and the column resize grip direction stays fixed.
    final toolColumn = find.byKey(const ValueKey('pcPreviewToolColumn'));
    final rightColumn = find.byKey(const ValueKey('pcPreviewRightColumn'));
    final outerToolbar = find.byKey(const ValueKey('pcPreviewToolbar'));
    expect(
      tester.getRect(outerToolbar).right,
      lessThanOrEqualTo(tester.getRect(toolColumn).left),
    );
    await settings.setLeftHanded(true);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(toolColumn).right,
      lessThan(tester.getRect(rightColumn).left),
    );
    expect(
      tester.getRect(outerToolbar).left,
      greaterThanOrEqualTo(tester.getRect(rightColumn).right),
    );
    await settings.setLeftHanded(false);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pcPreviewCollapse-brush')));
    await tester.pump();
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    expect(find.byKey(const ValueKey('pcPreviewExpand-brush')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pcPreviewCollapsedDrag-brush')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pcPreviewCollapse-layer')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pcPreviewCollapse-layer')));
    await tester.pump();
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.layer), isTrue);
    expect(find.byKey(const ValueKey('pcPreviewExpand-layer')), findsOneWidget);

    // Drag the collapsed brush icon to the RIGHT column before the
    // navigator, without expanding it or losing the saved folded state.
    final dragIcon =
        find.byKey(const ValueKey('pcPreviewCollapsedDrag-brush'));
    final target = find.byKey(const ValueKey('pcPreviewDrop-canvasPreview'));
    await tester.drag(
      dragIcon,
      tester.getCenter(target) - tester.getCenter(dragIcon),
    );
    await tester.pumpAndSettle();
    expect(settings.rightDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.brush), isFalse);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    expect(
      settings.rightDockOrder.indexOf(CanvasDockPanel.brush),
      lessThan(settings.rightDockOrder.indexOf(CanvasDockPanel.canvasPreview)),
    );
    expect(find.byKey(const ValueKey('pcPreviewExpand-brush')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcPreviewExpand-brush')));
    await tester.pump();
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isFalse);
    expect(find.byKey(const ValueKey('pcPreviewCollapse-brush')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPreviewExpand-layer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
