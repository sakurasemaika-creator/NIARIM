import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/fisheye_perspective.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/ruler.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/screens/canvas/widgets/ruler_panel.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 200;
const _h = 160;
const _centre = Offset(100, 80);
const _radius = 70.0;

/// The fisheye perspective ruler on the real canvas: the ruler panel adds
/// it, a stroke drawn straight across bends onto the lens's arc, and its
/// handles move the centre, change the radius and tilt it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the ruler panel adds a fisheye ruler filling the canvas', (
    tester,
  ) async {
    Ruler? ruler;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => RulerPanel(
                activeRuler: ruler,
                onRulerChanged: (value) => setState(() => ruler = value),
                onClose: () {},
                canvasWidth: 1920,
                canvasHeight: 1080,
              ),
            ),
          ),
        ),
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(RulerPanel)))!;
    await tester.tap(find.text(l10n.rulerTypeFisheye));
    await tester.pump();
    expect(ruler!.type, RulerType.fisheyePerspective);
    expect(ruler!.position, const Offset(960, 540));
    expect(ruler!.settings.radiusX, closeTo(1080 * 0.45, 1e-9));
  });

  testWidgets('a stroke bends onto the arc; the handles reshape the lens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final brushes = BrushService();
    await brushes.init();
    final p = (await tester.runAsync(
      () => projects.createProject(
        name: 'fisheye-ruler',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: _w,
        exportHeight: _h,
      ),
    ))!;
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = projects.tileManagerOf(p.id);
    final providers = await tester.runAsync(buildAppProviders);

    var ruler = const Ruler(
      type: RulerType.fisheyePerspective,
      position: _centre,
      settings: RulerSettings(radiusX: _radius),
    );
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          ChangeNotifierProvider<ProjectService>.value(value: projects),
          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
          ChangeNotifierProvider<BrushService>.value(value: brushes),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: StatefulBuilder(
                builder: (context, setState) => CanvasArea(
                  project: p,
                  currentLayerId: layer.id,
                  currentTool: DrawingTool.ruler,
                  currentFrame: 0,
                  sceneId: scene.id,
                  activeRuler: ruler,
                  onRulerChanged: (value) {
                    if (value != null) setState(() => ruler = value);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    final area = find.byType(CanvasArea);
    Offset onScreen(Offset canvasPoint) {
      final rect = canvasDrawingRectFor(tester.getSize(area), p);
      return tester.getTopLeft(area) +
          rect.topLeft +
          canvasPoint * (rect.width / _w);
    }

    final out = Directory('build/fisheye-ruler')..createSync(recursive: true);
    Future<void> capture(String name) async {
      final bytes = await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      File('${out.path}/$name.png').writeAsBytesSync(bytes!);
    }

    await capture('1_guide');

    // ── Draw straight across, above the horizon ──
    const y = -35.0;
    final g = await tester.startGesture(
      onScreen(_centre + const Offset(-40, y)),
      kind: PointerDeviceKind.touch,
    );
    for (var x = -36.0; x <= 40; x += 4) {
      await g.moveTo(onScreen(_centre + Offset(x, y)));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    final rgba = _read(tm, key, _w, _h);
    bool inked(Offset canvasPoint) {
      final i = (canvasPoint.dy.round() * _w + canvasPoint.dx.round()) * 4;
      return rgba[i + 3] > 0;
    }

    final arc = fisheyeCurveThrough(
      FisheyeDirection.horizontal,
      const Offset(-40, y),
      _radius,
    );
    final arcTop = arc.project(const Offset(0, y));
    expect(arcTop.dy, lessThan(y - 8), reason: 'the arc bows up 9 px');
    expect(inked(_centre + arcTop), isTrue, reason: 'drawn on the arc');
    expect(
      inked(_centre + const Offset(0, y)),
      isFalse,
      reason: 'not where the finger went',
    );
    var offArc = 0;
    var onArc = 0;
    for (var py = 0; py < _h; py++) {
      for (var px = 0; px < _w; px++) {
        final i = (py * _w + px) * 4;
        if (rgba[i + 3] == 0) continue;
        final local = Offset(px.toDouble(), py.toDouble()) - _centre;
        if ((arc.project(local) - local).distance <= 4) {
          onArc++;
        } else {
          offArc++;
        }
      }
    }
    expect(onArc, greaterThan(40));
    expect(offArc, 0, reason: 'every pixel of the stroke is on the arc');
    await capture('2_stroke');

    // ── The handles: radius on the right of the circle, tilt at the top ──
    Future<void> dragHandle(Offset from, Offset to) async {
      final drag = await tester.startGesture(
        onScreen(from),
        kind: PointerDeviceKind.touch,
      );
      for (var i = 1; i <= 4; i++) {
        await drag.moveTo(onScreen(Offset.lerp(from, to, i / 4)!));
        await tester.pump();
      }
      await drag.up();
      await tester.pump();
    }

    await dragHandle(
      _centre + const Offset(_radius, 0),
      _centre + const Offset(50, 0),
    );
    expect(ruler.settings.radiusX, closeTo(50, 0.5));
    expect(ruler.rotation, 0);
    await dragHandle(
      _centre + const Offset(0, -50),
      _centre + Offset.fromDirection(-math.pi / 2 + 0.4, 50),
    );
    expect(ruler.rotation, closeTo(0.4, 1e-6));
    expect(ruler.settings.radiusX, closeTo(50, 0.5));
    await dragHandle(_centre, _centre + const Offset(-20, 10));
    expect(ruler.position, _centre + const Offset(-20, 10));
    await capture('3_reshaped');
    await tester.pumpWidget(const SizedBox());
  });
}

Uint8List _read(dynamic tm, String key, int w, int h) {
  final o = Uint8List(w * h * 4);
  final tile = tm.getTile(key, 0, 0) as Uint8List?;
  if (tile == null) return o;
  for (var y = 0; y < h; y++) {
    o.setRange(y * w * 4, (y + 1) * w * 4, tile, y * 256 * 4);
  }
  return o;
}
