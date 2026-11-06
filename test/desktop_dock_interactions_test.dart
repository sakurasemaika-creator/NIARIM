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

  test('pristine dock defaults mirror by hand, but never after a user edit',
      () async {
    final settings = SettingsService();
    await settings.init();
    expect(settings.desktopDockLayoutCustomized, isFalse);
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.rightDockOrder.contains(CanvasDockPanel.layer), isTrue);

    await settings.setLeftHanded(true);
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.layer), isTrue);
    expect(settings.rightDockOrder.contains(CanvasDockPanel.brush), isTrue);
    await settings.setLeftHanded(false);
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.brush), isTrue);

    await settings.setLeftHanded(true);
    await settings.moveDesktopDockPanel(CanvasDockPanel.brush, toRight: false);
    expect(settings.desktopDockLayoutCustomized, isTrue);
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.layer), isTrue);

    final physicalLeft = settings.toolOptionDockOrder.toList();
    final physicalRight = settings.rightDockOrder.toList();
    await settings.setLeftHanded(false);
    expect(settings.toolOptionDockOrder, physicalLeft);
    expect(settings.rightDockOrder, physicalRight);
    await settings.setLeftHanded(true);
    expect(settings.toolOptionDockOrder, physicalLeft);
    expect(settings.rightDockOrder, physicalRight);

    final restarted = SettingsService();
    await restarted.init();
    expect(restarted.isLeftHanded, isTrue);
    expect(restarted.desktopDockLayoutCustomized, isTrue);
    expect(restarted.toolOptionDockOrder, physicalLeft);
    expect(restarted.rightDockOrder, physicalRight);
  });

  test('latest workspace visibility, sizes, folds and reset', () async {
    final settings = SettingsService();
    await settings.init();
    await settings.setLeftHanded(true);
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.layer,
      CanvasDockPanel.canvasPreview,
    });
    await settings.setDesktopDockCollapsed(CanvasDockPanel.layer, true);
    await settings.setDesktopDockHeight(CanvasDockPanel.layer, 330);
    await settings.setDesktopPanelWidth(360);
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.layer), isTrue);
    expect(settings.desktopDockLayoutCustomized, isTrue);
    final left = settings.toolOptionDockOrder.toList();
    final right = settings.rightDockOrder.toList();
    final reopened = SettingsService();
    await reopened.init();
    expect(reopened.defaultDockedPanels,
        {CanvasDockPanel.layer, CanvasDockPanel.canvasPreview});
    expect(reopened.desktopPanelWidth, 360);
    expect(reopened.desktopDockHeight(CanvasDockPanel.layer), 330);
    expect(reopened.isDesktopDockCollapsed(CanvasDockPanel.layer), isTrue);
    expect(reopened.toolOptionDockOrder, left);
    expect(reopened.rightDockOrder, right);
    await reopened.setLeftHanded(false);
    expect(reopened.toolOptionDockOrder, left);
    expect(reopened.rightDockOrder, right);

    await reopened.setLeftHanded(true);
    await reopened.resetDesktopWorkspaceLayout();
    expect(reopened.desktopDockLayoutCustomized, isFalse);
    expect(reopened.toolOptionDockOrder.contains(CanvasDockPanel.layer), isTrue);
    expect(reopened.rightDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(reopened.desktopPanelWidth, 280);
    expect(reopened.desktopToolPanelWidth, 280);
    expect(reopened.desktopDockHeight(CanvasDockPanel.layer), 260);
    expect(reopened.isDesktopDockCollapsed(CanvasDockPanel.layer), isFalse);
    expect(reopened.defaultDockedPanels,
        {CanvasDockPanel.brush, CanvasDockPanel.colorPicker,
         CanvasDockPanel.layer});
    await reopened.setLeftHanded(false);
    expect(reopened.toolOptionDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(reopened.rightDockOrder.contains(CanvasDockPanel.layer), isTrue);
  });


  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('automatic dock folding defaults ON and persists the user toggle',
      () async {
    final settings = SettingsService();
    await settings.init();
    expect(settings.desktopDockAutoCollapseEnabled, isTrue);
    await settings.setDesktopDockAutoCollapseEnabled(false);
    final reloaded = SettingsService();
    await reloaded.init();
    expect(reloaded.desktopDockAutoCollapseEnabled, isFalse);
    await reloaded.setDesktopDockAutoCollapseEnabled(true);
    final reopened = SettingsService();
    await reopened.init();
    expect(reopened.desktopDockAutoCollapseEnabled, isTrue);
  });

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

  testWidgets('preview auto folds only under pressure and manual toggle stays intact',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsService();
    await settings.init();
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush,
      CanvasDockPanel.tone,
      CanvasDockPanel.stamp,
      CanvasDockPanel.penSubTool,
      CanvasDockPanel.colorPicker,
      CanvasDockPanel.layer,
    });
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
    // Four expanded tools need more than the preview's left column height.
    expect(
      find.byKey(const ValueKey('pcPreviewExpand-stamp')),
      findsOneWidget,
    );
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.stamp), isFalse);
    await tester.tap(find.byKey(const ValueKey('pcPreviewExpand-stamp')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pcPreviewCollapse-stamp')),
      findsOneWidget,
    );
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.stamp), isFalse);

    await settings.setDesktopDockAutoCollapseEnabled(false);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('pcPreviewExpand-stamp')),
      findsNothing,
    );
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.stamp), isFalse);
    expect(tester.takeException(), isNull);
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

    // A resized column is already customized: handedness only moves the
    // outer toolbar and must never relocate its physical dock windows.
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
      tester.getRect(find.byKey(const ValueKey('pcPreviewDrop-brush'))).right,
      lessThanOrEqualTo(tester.getRect(toolColumn).right),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('pcPreviewDrop-layer'))).left,
      greaterThanOrEqualTo(tester.getRect(rightColumn).left),
    );
    expect(
      tester.getRect(outerToolbar).left,
      greaterThanOrEqualTo(tester.getRect(rightColumn).right),
    );
    await settings.setLeftHanded(false);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('pcPreviewDrop-brush'))).right,
      lessThanOrEqualTo(tester.getRect(toolColumn).right),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('pcPreviewDrop-layer'))).left,
      greaterThanOrEqualTo(tester.getRect(rightColumn).left),
    );

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

    // Drag the collapsed brush icon into the RIGHT column before the
    // layer. Default workspace does not open the navigator.
    final dragIcon =
        find.byKey(const ValueKey('pcPreviewCollapsedDrag-brush'));
    final target = find.byKey(const ValueKey('pcPreviewDrop-layer'));
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
      lessThan(settings.rightDockOrder.indexOf(CanvasDockPanel.layer)),
    );
    expect(find.byKey(const ValueKey('pcPreviewExpand-brush')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pcPreviewExpand-brush')));
    await tester.pump();
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isFalse);
    expect(find.byKey(const ValueKey('pcPreviewCollapse-brush')), findsOneWidget);
    expect(find.byKey(const ValueKey('pcPreviewExpand-layer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('empty dock assignment persists on both sides without duplicates',
      () async {
    final settings = SettingsService();
    await settings.init();
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, true);

    for (final panel in List<CanvasDockPanel>.of(settings.toolOptionDockOrder)) {
      await settings.moveDesktopDockPanel(panel, toRight: true);
    }
    expect(settings.toolOptionDockOrder, isEmpty);
    final reloaded = SettingsService();
    await reloaded.init();
    expect(reloaded.toolOptionDockOrder, isEmpty);
    expect(reloaded.rightDockOrder.toSet(), CanvasDockPanel.values.toSet());
    expect(reloaded.rightDockOrder.length, CanvasDockPanel.values.length);
    expect(reloaded.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);

    for (final panel in List<CanvasDockPanel>.of(reloaded.rightDockOrder)) {
      await reloaded.moveDesktopDockPanel(panel, toRight: false);
    }
    expect(reloaded.rightDockOrder, isEmpty);
    final restored = SettingsService();
    await restored.init();
    expect(restored.rightDockOrder, isEmpty);
    expect(restored.toolOptionDockOrder.toSet(), CanvasDockPanel.values.toSet());
    expect(restored.toolOptionDockOrder.length, CanvasDockPanel.values.length);
    expect(restored.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
  });

  testWidgets('an empty preview column reappears only for drag and drop',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsService();
    await settings.init();
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush,
      CanvasDockPanel.layer,
    });
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, true);
    await settings.moveDesktopDockPanel(CanvasDockPanel.brush, toRight: true);

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

    final left = find.byKey(const ValueKey('pcPreviewToolColumn'));
    final right = find.byKey(const ValueKey('pcPreviewRightColumn'));
    expect(tester.getSize(left).width, 0);
    expect(find.byKey(const ValueKey('pcPreviewToolColumnResize')), findsNothing);

    final fromRight =
        find.byKey(const ValueKey('pcPreviewCollapsedDrag-brush'));
    final dragLeft = await tester.startGesture(tester.getCenter(fromRight));
    await dragLeft.moveBy(const Offset(-50, 0));
    await tester.pump();
    expect(tester.getSize(left).width, 52);
    await dragLeft.moveTo(tester.getCenter(left));
    await tester.pump();
    await dragLeft.up();
    await tester.pumpAndSettle();
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.rightDockOrder.contains(CanvasDockPanel.brush), isFalse);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    expect(tester.getSize(left).width, 52);

    await settings.moveDesktopDockPanel(CanvasDockPanel.layer, toRight: false);
    await tester.pumpAndSettle();
    expect(tester.getSize(right).width, 0);
    final fromLeft =
        find.byKey(const ValueKey('pcPreviewCollapsedDrag-brush'));
    final dragRight = await tester.startGesture(tester.getCenter(fromLeft));
    await dragRight.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(tester.getSize(right).width, 52);
    await dragRight.moveTo(tester.getCenter(right));
    await tester.pump();
    await dragRight.up();
    await tester.pumpAndSettle();
    expect(settings.rightDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.brush), isFalse);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('left-handed docks mirror the saved groups, resizing and drag',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsService();
    await settings.init();
    await settings.setLeftHanded(true);
    await settings.setDesktopDockAutoCollapseEnabled(false);
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush,
      CanvasDockPanel.layer,
    });
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, true);
    await settings.setDesktopDockCollapsed(CanvasDockPanel.layer, true);
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

    final left = find.byKey(const ValueKey('pcPreviewToolColumn'));
    final right = find.byKey(const ValueKey('pcPreviewRightColumn'));
    final brush = find.byKey(const ValueKey('pcPreviewDrop-brush'));
    final layer = find.byKey(const ValueKey('pcPreviewDrop-layer'));
    expect(
      tester.getRect(layer).right,
      lessThanOrEqualTo(tester.getRect(left).right),
    );
    expect(
      tester.getRect(brush).left,
      greaterThanOrEqualTo(tester.getRect(right).left),
    );

    // The physical left grip now belongs to the saved right dock group.
    await settings.setDesktopDockCollapsed(CanvasDockPanel.layer, false);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('pcPreviewToolColumnResize')),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();
    expect(settings.desktopToolPanelWidth, greaterThan(280));
    expect(settings.desktopPanelWidth, 280);

    // Physical right -> physical left must update the SAVED physical left list.
    final dragIcon =
        find.byKey(const ValueKey('pcPreviewCollapsedDrag-brush'));
    await tester.drag(
      dragIcon,
      tester.getCenter(layer) - tester.getCenter(dragIcon),
    );
    await tester.pumpAndSettle();
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.rightDockOrder.contains(CanvasDockPanel.brush), isFalse);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    expect(
      tester.getRect(brush).left,
      lessThanOrEqualTo(tester.getRect(left).right),
    );

    // Changing handedness does not rewrite the user's saved dock order.
    final savedRight = settings.rightDockOrder.toList();
    final savedLeft = settings.toolOptionDockOrder.toList();
    await settings.setLeftHanded(false);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(brush).right,
      lessThanOrEqualTo(tester.getRect(left).right),
    );
    expect(settings.rightDockOrder, savedRight);
    expect(settings.toolOptionDockOrder, savedLeft);
    final restored = SettingsService();
    await restored.init();
    expect(restored.rightDockOrder, savedRight);
    expect(restored.toolOptionDockOrder, savedLeft);
    expect(restored.isLeftHanded, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('left-handed empty physical right dock accepts a dropped tool',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsService();
    await settings.init();
    await settings.setLeftHanded(true);
    await settings.setDefaultDockedPanels({
      CanvasDockPanel.brush,
      CanvasDockPanel.layer,
    });
    await settings.setDesktopDockCollapsed(CanvasDockPanel.brush, true);
    await settings.moveDesktopDockPanel(CanvasDockPanel.brush, toRight: false);
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

    final physicalRight = find.byKey(const ValueKey('pcPreviewRightColumn'));
    expect(tester.getSize(physicalRight).width, 0);
    final dragIcon =
        find.byKey(const ValueKey('pcPreviewCollapsedDrag-brush'));
    final drag = await tester.startGesture(tester.getCenter(dragIcon));
    await drag.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(tester.getSize(physicalRight).width, 52);
    await drag.moveTo(tester.getCenter(physicalRight));
    await tester.pump();
    await drag.up();
    await tester.pumpAndSettle();

    expect(settings.rightDockOrder.contains(CanvasDockPanel.brush), isTrue);
    expect(settings.toolOptionDockOrder.contains(CanvasDockPanel.brush), isFalse);
    expect(settings.isDesktopDockCollapsed(CanvasDockPanel.brush), isTrue);
    expect(tester.takeException(), isNull);
  });
}
