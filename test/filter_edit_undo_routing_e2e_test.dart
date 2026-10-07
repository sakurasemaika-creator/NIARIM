import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/color_picker_panel.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pick_filter_card.dart';
import 'helpers/pump_real_async.dart';

const _size = 128;

/// While a filter is being adjusted on the real canvas screen, Undo and Redo
/// from the keyboard and the two-finger tap take back the filter's own
/// edits, never the drawing underneath; everything changed in one visit to
/// the colour picker is one of those steps, and so is one drag of a slider.
/// Once the panel is closed, the same keys reach the canvas's history again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Undo while adjusting a filter undoes the filter edit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tempDir = Directory.systemTemp.createTempSync('niarim_undo_route_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null),
    );
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    await loadAppFonts(tester);
    final providers = (await tester.runAsync(buildAppProviders))!;
    BuildContext? providerContext;
    final activeProject = ValueNotifier<String?>(null);
    addTearDown(activeProject.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            providerContext = context;
            return ValueListenableBuilder<String?>(
              valueListenable: activeProject,
              builder: (context, id, _) => MaterialApp(
                theme: context.watch<ThemeService>().themeData,
                scrollBehavior: const AppScrollBehavior(),
                locale: const Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: id == null
                    ? const Scaffold(body: SizedBox.expand())
                    : CanvasScreen(projectId: id),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final context = providerContext!;
    final ps = context.read<ProjectService>();
    final fs = context.read<FilterService>();
    final undo = context.read<UndoManager>();

    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'Undo routing E2E',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: _size,
        exportHeight: _size,
      ),
    ))!;
    final scene = ps.scenesOf(project.id).first;
    final layer = scene.frames.first.layers.first;
    final tm = ps.tileManagerOf(project.id);
    final key = ps.tileKeyFor(project.id, scene.id, 0, layer.id);
    // Something drawn as a canvas Undo step, so a misrouted Undo would show:
    // the layer would lose it.
    final drawn = Uint8List(_size * _size * 4);
    for (var y = 30; y < 100; y++) {
      for (var x = 30; x < 100; x++) {
        drawn.setAll((y * _size + x) * 4, const [40, 120, 200, 255]);
      }
    }
    ps.replaceLayerPixels(
      projectId: project.id,
      sceneId: scene.id,
      frameIndex: 0,
      layerId: layer.id,
      pixels: drawn,
    );
    expect(undo.undoCount, 1);
    activeProject.value = project.id;
    await pumpRealAsync(tester, const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);

    Future<Uint8List> layerPixels() async => (await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;

    Future<void> keys(List<LogicalKeyboardKey> combo) async {
      for (final k in combo) {
        await tester.sendKeyDownEvent(k);
      }
      for (final k in combo.reversed) {
        await tester.sendKeyUpEvent(k);
      }
      await tester.pump();
    }

    Future<void> ctrlZ() =>
        keys([LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyZ]);
    Future<void> ctrlY() =>
        keys([LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.keyY]);

    final canvasFinder = find.byType(CanvasArea);
    Future<void> twoFingerTap() async {
      final centre = tester.getCenter(canvasFinder);
      final a = await tester.startGesture(
        centre - const Offset(30, 0),
        kind: PointerDeviceKind.touch,
        pointer: 11,
      );
      final b = await tester.startGesture(
        centre + const Offset(30, 0),
        kind: PointerDeviceKind.touch,
        pointer: 12,
      );
      await tester.pump(const Duration(milliseconds: 40));
      await a.up();
      await b.up();
      await tester.pump();
    }

    // ── Open the panel and pick sphere shading ──
    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pump(const Duration(milliseconds: 250));
    final filterMenuEntry = find.byIcon(Icons.blur_on);
    await tester.ensureVisible(filterMenuEntry);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.tap(filterMenuEntry);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(find.byType(FilterPanel), findsOneWidget);
    await pickFilterCard(tester, FilterService.sphereShadingFilterId);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    FilterDef sphere() => fs.currentFilter!;
    expect(sphere().kind, FilterKind.sphereShading);
    final l10n = AppLocalizations.of(tester.element(canvasFinder))!;
    final original = sphere();
    expect(fs.canUndoFilterEdit, isFalse);

    // ── One visit to the colour picker is one step ──
    final lightRow = find
        .ancestor(
          of: find.text(l10n.filterSphereLightColor),
          matching: find.byType(Row),
        )
        .first;
    final chip = find
        .descendant(of: lightRow, matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final picker = tester.widget<ColorPickerPanel>(
      find.byType(ColorPickerPanel),
    );
    const picks = [Color(0xFFFF0000), Color(0xFF00FF00), Color(0xFF3355FF)];
    for (final c in picks) {
      picker.onColorChanged(c);
      await tester.pump();
    }
    expect(sphere().sphereLightColor, picks.last.toARGB32());
    picker.onClose();
    await tester.pumpAndSettle();
    expect(find.byType(ColorPickerPanel), findsNothing);

    await ctrlZ();
    expect(
      sphere().sphereLightColor,
      original.sphereLightColor,
      reason: 'the whole visit to the picker comes back in one Undo',
    );
    expect(fs.canUndoFilterEdit, isFalse);
    expect(undo.undoCount, 1, reason: 'the canvas history is left alone');
    expect(await layerPixels(), orderedEquals(drawn));

    await ctrlY();
    expect(sphere().sphereLightColor, picks.last.toARGB32());
    expect(undo.redoCount, 0);

    // ── One drag of a slider is one step, taken back by a two-finger tap ──
    final beforeDrag = sphere().sphereLightBlur;
    final blurRow = find
        .ancestor(
          of: find.textContaining(l10n.filterSphereLightBlur),
          matching: find.byType(Row),
        )
        .first;
    final slider = find.descendant(of: blurRow, matching: find.byType(Slider));
    await tester.ensureVisible(slider);
    await tester.pump();
    final track = tester.getRect(slider);
    final drag = await tester.startGesture(
      track.centerLeft + const Offset(24, 0),
    );
    for (var i = 1; i <= 5; i++) {
      await drag.moveTo(track.centerLeft + Offset(24 + track.width * i / 7, 0));
      await tester.pump();
    }
    await drag.up();
    await tester.pump();
    expect(sphere().sphereLightBlur, isNot(beforeDrag));

    await twoFingerTap();
    expect(
      sphere().sphereLightBlur,
      beforeDrag,
      reason: 'the whole drag comes back in one Undo',
    );
    expect(sphere().sphereLightColor, picks.last.toARGB32());
    expect(undo.undoCount, 1);
    expect(await layerPixels(), orderedEquals(drawn));

    await keys([
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.keyZ,
    ]);
    expect(sphere().sphereLightBlur, isNot(beforeDrag));
    await ctrlZ();
    await ctrlZ();
    expect(sphere().sphereLightBlur, beforeDrag);
    expect(sphere().sphereLightColor, original.sphereLightColor);
    // Nothing left of the filter's history: more Undo does nothing, and the
    // drawing still is not touched.
    await ctrlZ();
    expect(undo.undoCount, 1);
    expect(await layerPixels(), orderedEquals(drawn));

    // ── After closing the panel, Undo is the canvas's again ──
    tester.widget<FilterPanel>(find.byType(FilterPanel)).onClose();
    await pumpRealAsync(tester, const Duration(milliseconds: 400));
    expect(find.byType(FilterPanel), findsNothing);
    await ctrlZ();
    expect(undo.undoCount, 0);
    expect(undo.redoCount, 1);
    expect((await layerPixels()).any((v) => v != 0), isFalse);
    expect(tester.takeException(), isNull);
  });
}
