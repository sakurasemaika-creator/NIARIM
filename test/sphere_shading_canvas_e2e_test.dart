import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/filter_canvas_gizmo.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/pick_filter_card.dart';
import 'helpers/pump_real_async.dart';

const _size = 256;
const _disc = [40, 120, 200];

/// Sphere shading and the fisheye on the real canvas screen: the filter's
/// light (or centre) is drawn on the canvas and dragged there, each drag is
/// one step of the filter's Undo, the panel's controls work, applying it
/// changes the layer and the canvas Undo takes that back. Also: while the
/// panel picks a colour from the canvas, the tap reaches the canvas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sphere shading and the fisheye are edited on the canvas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tempDir = Directory.systemTemp.createTempSync('niarim_sphere_e2e_');
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
    final boundary = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: Builder(
          builder: (context) {
            providerContext = context;
            return RepaintBoundary(
              key: boundary,
              child: ValueListenableBuilder<String?>(
                valueListenable: activeProject,
                builder: (context, id, _) => MaterialApp(
                  theme: context.watch<ThemeService>().themeData,
                  locale: const Locale('ja'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: id == null
                      ? const Scaffold(body: SizedBox.expand())
                      : CanvasScreen(projectId: id),
                ),
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
        name: 'Sphere shading E2E',
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
    final disc = Uint8List(_size * _size * 4);
    for (var y = 0; y < _size; y++) {
      for (var x = 0; x < _size; x++) {
        final dx = x - 128, dy = y - 140;
        if (dx * dx + dy * dy > 90 * 90) continue;
        disc.setAll((y * _size + x) * 4, [..._disc, 255]);
      }
    }
    tm.replaceLayerPixels(key, disc);
    activeProject.value = project.id;
    await pumpRealAsync(tester, const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);

    final out = Directory('build/sphere-shading')..createSync(recursive: true);
    Future<void> capture(String name) async {
      await pumpRealAsync(tester, const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File(
          '${out.path}/$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    final canvasFinder = find.byType(CanvasArea);
    Project currentProject() =>
        ps.projects.firstWhere((p) => p.id == project.id);

    /// Where canvas pixel [p] is on the screen (the view is not zoomed).
    Offset onScreen(Offset p) {
      final area = tester.getRect(canvasFinder);
      final rect = canvasDrawingRectFor(area.size, currentProject());
      final scale = rect.width / _size;
      return area.topLeft + rect.topLeft + p * scale;
    }

    double screenScale() {
      final area = tester.getRect(canvasFinder);
      return canvasDrawingRectFor(area.size, currentProject()).width / _size;
    }

    Future<void> drag(Offset from, Offset by) async {
      final gesture = await tester.startGesture(
        from,
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 1; i <= 4; i++) {
        await gesture.moveTo(from + by * (i / 4));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }

    FilterCanvasGizmo? gizmoOnCanvas() =>
        tester.widget<CanvasArea>(canvasFinder).filterGizmo;

    // ── Open the panel from the canvas menu and pick sphere shading ──
    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pump(const Duration(milliseconds: 250));
    final filterMenuEntry = find.byIcon(Icons.blur_on);
    await tester.ensureVisible(filterMenuEntry);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.tap(filterMenuEntry);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(find.byType(FilterPanel), findsOneWidget);
    expect(gizmoOnCanvas(), isNull, reason: 'nothing to drag yet');
    await pickFilterCard(tester, FilterService.sphereShadingFilterId);
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    FilterDef sphere() => fs.currentFilter!;
    expect(sphere().kind, FilterKind.sphereShading);
    expect(gizmoOnCanvas(), filterCanvasGizmoFor(sphere(), _size, _size));
    final l10n = AppLocalizations.of(tester.element(canvasFinder))!;
    expect(find.text(l10n.filterSphereCanvasHint), findsOneWidget);
    await capture('canvas_1_opened');

    // ── Drag the light's + on the canvas ──
    final before = sphere();
    final centre = gizmoOnCanvas()!.center;
    await drag(onScreen(centre), const Offset(-60, 40));
    final scale = screenScale();
    expect(
      sphere().sphereLightX,
      closeTo(before.sphereLightX - 60 / scale / _size * 100, 0.6),
    );
    expect(
      sphere().sphereLightY,
      closeTo(before.sphereLightY + 40 / scale / _size * 100, 0.6),
    );
    expect(sphere().sphereLightWidth, before.sphereLightWidth);
    expect(gizmoOnCanvas(), filterCanvasGizmoFor(sphere(), _size, _size));
    // Nothing was drawn on the layer by the drag.
    final afterDrag = await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    expect(afterDrag, orderedEquals(disc));

    // ── Drag the height handle (below the centre) ──
    final moved = sphere();
    final heightHandle = gizmoOnCanvas()!.handles[FilterGizmoHandle.radiusY]!;
    await drag(onScreen(heightHandle), const Offset(0, -30));
    expect(
      sphere().sphereLightHeight,
      closeTo(moved.sphereLightHeight - 30 / scale * 200 / _size, 0.6),
    );
    expect(sphere().sphereLightX, moved.sphereLightX);
    await capture('canvas_2_dragged');

    // A touch away from the handles neither draws nor closes the panel.
    await drag(onScreen(const Offset(40, 230)), const Offset(30, 0));
    expect(find.byType(FilterPanel), findsOneWidget);
    expect(sphere().sphereLightHeight, isNot(moved.sphereLightHeight));

    // Each drag is one Undo step of the filter.
    fs.undoFilterEdit();
    await tester.pump();
    expect(sphere().sphereLightHeight, moved.sphereLightHeight);
    expect(sphere().sphereLightX, moved.sphereLightX);
    fs.undoFilterEdit();
    await tester.pump();
    expect(sphere().sphereLightX, before.sphereLightX);
    fs.redoFilterEdit();
    fs.redoFilterEdit();
    await tester.pump();

    // ── The panel's own controls ──
    final panel = find.byType(FilterPanel);
    expect(
      find.descendant(
        of: panel,
        matching: find.text(l10n.filterSphereShadowBlend),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: panel,
        matching: find.text(l10n.filterSphereModeCombined),
      ),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(sphere().sphereCombined, isTrue);
    expect(find.text(l10n.filterSphereCombinedHint), findsOneWidget);
    expect(find.text(l10n.filterSphereShadowBlend), findsNothing);
    expect(find.text(l10n.filterSphereBlend), findsOneWidget);
    await capture('canvas_3_combined');
    fs.undoFilterEdit();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(sphere().sphereCombined, isFalse);

    // ── Apply: the layer is shaded; the canvas Undo takes it back ──
    final shaded = sphere();
    await tester.tap(find.byKey(const ValueKey('filter-apply-button')));
    await pumpRealAsync(tester, const Duration(milliseconds: 1200));
    expect(find.byType(FilterPanel), findsNothing);
    expect(gizmoOnCanvas(), isNull, reason: 'gone with the panel');
    Future<Uint8List> layerPixels() async => (await tester.runAsync(() async {
      final image = await tm.compositeLayerToImage(key);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;
    final applied = await layerPixels();
    final light = shaded.sphereLight(_size, _size);
    int at(Uint8List data, double x, double y) =>
        data[((y.round() * _size) + x.round()) * 4 + 2];
    expect(
      at(applied, light.centerX, light.centerY),
      greaterThan(_disc[2]),
      reason: 'lit by Screen',
    );
    expect(
      at(applied, 128, 225),
      lessThan(_disc[2]),
      reason: 'shadowed by Multiply',
    );
    expect(applied.sublist(0, 4), [0, 0, 0, 0], reason: 'nothing drawn there');
    await capture('canvas_4_applied');
    undo.undo();
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(await layerPixels(), orderedEquals(disc));

    // ── The fisheye's centre is dragged the same way ──
    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(filterMenuEntry);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.tap(filterMenuEntry);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await pickFilterCard(tester, 'Filter0015');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final eye = gizmoOnCanvas()!;
    expect(eye.resizable, isFalse);
    expect(eye.center, const Offset(_size / 2, _size / 2));
    expect(find.text(l10n.filterFisheyeCanvasHint), findsOneWidget);
    // On a phone the panel covers the middle of the canvas: fold it away to
    // reach the centre. Folded, only the name and Undo / Redo / Apply stay.
    final collapse = find.byKey(const ValueKey('filter-collapse-button'));
    await tester.tap(collapse);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(find.text(l10n.filterFisheyeCanvasHint), findsNothing);
    expect(find.byKey(const ValueKey('filter-apply-button')), findsOneWidget);
    expect(tester.getSize(panel).height, lessThan(200));
    await capture('canvas_5_fisheye_folded');
    await drag(onScreen(eye.center), const Offset(-50, 0));
    expect(
      fs.currentFilter!.fisheyeCenterX,
      closeTo(-50 / scale / _size * 100, 0.6),
    );
    await tester.tap(collapse);
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(find.text(l10n.filterFisheyeCanvasHint), findsOneWidget);
    await capture('canvas_6_fisheye_moved');

    // ── Picking a colour from the canvas reaches the canvas ──
    await tester.tap(find.byKey(const ValueKey('filter-back-to-list')));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await pickFilterCard(tester, 'Filter0006');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await tester.tap(
      find.descendant(of: panel, matching: find.byIcon(Icons.colorize)).first,
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.tapAt(onScreen(const Offset(70, 140)));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    expect(find.byType(FilterPanel), findsOneWidget);
    expect(
      fs.currentFilter!.outlineColor,
      0xFF000000 | (_disc[0] << 16) | (_disc[1] << 8) | _disc[2],
    );

    activeProject.value = null;
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 5)));
}
