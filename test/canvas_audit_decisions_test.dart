import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/brush_size_slider.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/layer_panel.dart';
import 'package:niarim/screens/canvas/widgets/toolbar_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/shortcut_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/project_storage.dart';
import 'helpers/pump_real_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useTemporaryProjectStorage();

  test(
    'Ctrl+0 migration respects a custom assignment and a removed default',
    () async {
      final fit = ShortcutService();
      addTearDown(fit.dispose);
      SharedPreferences.setMockInitialValues({});
      await fit.init();
      final saved = fit.bindings
          .where((binding) => binding.command == ShortcutCommand.canvasFit)
          .single;
      expect(saved.key, LogicalKeyboardKey.digit0);
      expect(saved.control, isTrue);
      fit.removeBinding(saved.id);

      final restored = ShortcutService();
      addTearDown(restored.dispose);
      await restored.init();
      expect(
        restored.bindings.any((b) => b.command == ShortcutCommand.canvasFit),
        isFalse,
      );

      final occupied = ShortcutBinding(
        id: 'my-binding',
        label: 'play',
        keyId: LogicalKeyboardKey.digit0.keyId,
        control: true,
        command: ShortcutCommand.playPause,
      );
      SharedPreferences.setMockInitialValues({
        'shortcut_bindings': [jsonEncode(occupied.toJson())],
      });
      final migrated = ShortcutService();
      addTearDown(migrated.dispose);
      await migrated.init();
      expect(
        migrated.bindings
            .where((binding) => binding.sameKeyCombo(occupied))
            .single
            .id,
        occupied.id,
      );
    },
  );

  testWidgets('canvas shortcuts, remembered opacity and both layer locks', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final providers = (await tester.runAsync(buildAppProviders))!;
    final open = ValueNotifier<String?>(null);
    addTearDown(open.dispose);
    late ProjectService projects;
    late UndoManager history;
    late ShortcutService shortcuts;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              projects = context.read<ProjectService>();
              history = context.read<UndoManager>();
              shortcuts = context.read<ShortcutService>();
              return ValueListenableBuilder(
                valueListenable: open,
                builder: (_, id, _) => id == null
                    ? const SizedBox.expand()
                    : CanvasScreen(projectId: id),
              );
            },
          ),
        ),
      ),
    );
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'audit decisions',
        exportWidth: 128,
        exportHeight: 96,
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      ),
    ))!;
    final scene = projects.scenesOf(project.id).first;
    final layerId = scene.frames.first.layers.first.id;
    open.value = project.id;
    await pumpRealAsync(tester, const Duration(milliseconds: 500));
    final area = find.byType(CanvasArea);
    final toolbar = find.byType(ToolbarWidget);
    final size = find.byType(BrushSizeSlider);
    final l10n = lookupAppLocalizations(const Locale('ja'));

    Future<void> ctrl(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    final actions = {
      ShortcutCommand.canvasActualPixels: CanvasViewAction.actualPixels,
      ShortcutCommand.canvasZoomIn: CanvasViewAction.zoomIn,
      ShortcutCommand.canvasZoomOut: CanvasViewAction.zoomOut,
      ShortcutCommand.canvasRotateLeft: CanvasViewAction.rotateLeft,
      ShortcutCommand.canvasRotateRight: CanvasViewAction.rotateRight,
      ShortcutCommand.canvasResetRotation: CanvasViewAction.resetRotation,
    };
    final keys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ];
    for (final (index, entry) in actions.entries.indexed) {
      shortcuts.addBinding(
        ShortcutBinding(
          id: entry.key.name,
          label: entry.key.name,
          keyId: keys[index].keyId,
          control: true,
          command: entry.key,
        ),
      );
    }
    await tester.pump();
    for (final (index, expected) in actions.values.indexed) {
      await ctrl(keys[index]);
      expect(tester.widget<CanvasArea>(area).viewRequest?.action, expected);
    }
    await ctrl(LogicalKeyboardKey.digit0);
    await tester.pump();
    final canvas = tester.widget<CanvasArea>(area);
    expect(canvas.viewRequest?.action, CanvasViewAction.fit);
    final paint = tester
        .widgetList<CustomPaint>(
          find.descendant(of: area, matching: find.byType(CustomPaint)),
        )
        .firstWhere(
          (widget) => widget.painter.runtimeType.toString() == '_CanvasPainter',
        );
    final dynamic painter = paint.painter;
    final matrix = painter.transform as Matrix4;
    expect(canvasViewScaleOf(matrix), closeTo(1, .001));
    expect(canvasViewRotationDegOf(matrix), closeTo(0, .001));
    expect(history.undoCount, 0);

    Future<void> select(DrawingTool tool) async {
      tester.widget<ToolbarWidget>(toolbar).onToolSelected(tool);
      await tester.pump();
    }

    final penOpacity = tester.widget<BrushSizeSlider>(size).opacity;
    await select(DrawingTool.eraser);
    tester.widget<BrushSizeSlider>(size).onOpacityChanged(0);
    tester.widget<BrushSizeSlider>(size).onSizeChanged(23);
    await tester.pump();
    expect(tester.widget<CanvasArea>(area).toolBrushOpacity, 0);
    await select(DrawingTool.pen);
    expect(tester.widget<BrushSizeSlider>(size).opacity, penOpacity);
    await select(DrawingTool.eraser);
    expect(tester.widget<BrushSizeSlider>(size).opacity, 0);
    final reopened = SettingsService();
    addTearDown(reopened.dispose);
    await tester.runAsync(reopened.init);
    expect(reopened.toolOpacity('eraser'), 0);
    expect(reopened.toolThickness('eraser'), 23);
    await select(DrawingTool.pen);

    if (find.byType(LayerPanel).evaluate().isEmpty) {
      tester.widget<ToolbarWidget>(toolbar).onLayerTap();
      await tester.pumpAndSettle();
    }
    Future<void> toggleLock(String label) async {
      await tester.tap(
        find.byKey(ValueKey('canvasLayerMenu_$layerId')).hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, label).hitTestable(),
      );
      await tester.pumpAndSettle();
    }

    await toggleLock(l10n.layerPanelLockLabel);
    await toggleLock(l10n.layerPanelOpacityLockLabel);
    (bool, bool) locks() {
      final layer = projects.layersOf(project.id, scene.id, 0).first;
      return (layer.isLocked, layer.opacityLocked);
    }

    expect(locks(), (true, true));
    await ctrl(LogicalKeyboardKey.keyZ);
    expect(locks(), (true, false));
    await ctrl(LogicalKeyboardKey.keyZ);
    expect(locks(), (false, false));
    await ctrl(LogicalKeyboardKey.keyY);
    expect(locks(), (true, false));
    await ctrl(LogicalKeyboardKey.keyY);
    expect(locks(), (true, true));
    expect(tester.takeException(), isNull);
  });
}
