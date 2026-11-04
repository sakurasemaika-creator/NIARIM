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
    await settings.setDesktopDockHeight(CanvasDockPanel.brush, 340);
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, true);
    await settings.setDesktopDockCollapsed(CanvasDockPanel.layer, true);
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, false);

    final reloaded = SettingsService();
    await reloaded.init();
    expect(reloaded.isDesktopDockCollapsed(CanvasDockPanel.brush), isFalse);
    expect(reloaded.isDesktopDockCollapsed(CanvasDockPanel.layer), isTrue);
    expect(reloaded.desktopDockWidth(CanvasDockPanel.brush, right: false), 360);
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
    expect(find.byKey(const ValueKey('pcPreviewWidth-brush')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPreviewHeight-brush')), findsOneWidget);

    // The layout preview must mirror the real dock on left-handed workspaces.
    final toolColumn = find.byKey(const ValueKey('pcPreviewToolColumn'));
    final leftPosition = tester.getRect(toolColumn).left;
    await settings.setLeftHanded(true);
    await tester.pumpAndSettle();
    expect(tester.getRect(toolColumn).left, greaterThan(leftPosition + 150));
    await settings.setLeftHanded(false);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pcPreviewCollapse-brush')));
    await tester.pump();
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    expect(find.byKey(const ValueKey('pcPreviewExpand-brush')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPreviewCollapse-layer')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pcPreviewCollapse-layer')));
    await tester.pump();
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.layer), isTrue);
    expect(find.byKey(const ValueKey('pcPreviewExpand-layer')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pcPreviewExpand-brush')));
    await tester.pump();
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isFalse);
    expect(find.byKey(const ValueKey('pcPreviewCollapse-brush')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPreviewExpand-layer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
