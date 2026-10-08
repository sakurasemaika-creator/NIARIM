import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _w = 120, _h = 100;

/// Dots between the lasso and the outline: left, top, right and bottom.
const _decoys = [(25, 49), (44, 26), (84, 50), (60, 72)];

/// The real canvas: a rough lasso drawn around an outlined shape with
/// 「線に吸着」 on selects the shape up to the middle of its outline, like a
/// bucket fill would fill it, so a dot lying between the finger's path and
/// the outline is left out, while the inside is selected. (Without snapping
/// the same lasso takes the dot.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/lasso-snap');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final snap in [true, false]) {
    testWidgets(
      'a rough lasso ${snap ? 'snaps to the outline' : 'without '
                'snapping keeps the finger\'s path'}',
      (tester) async {
        tester.view.physicalSize = const Size(480, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final projects = ProjectService();
        final undo = app_undo.UndoManager();
        projects.setUndoManager(undo);
        final p = (await tester.runAsync(
          () => projects.createProject(
            name: 'lasso-snap',
            fps: 24,
            durationSeconds: 1,
            backgroundColor: 0x00000000,
            exportWidth: _w,
            exportHeight: _h,
          ),
        ))!;
        final scene = projects.scenesOf(p.id).first;
        final layer = projects.layersOf(p.id, scene.id, 0).first;
        final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
        final tm = projects.tileManagerOf(p.id);

        final art = Uint8List(_w * _h * 4);
        // A 2px outline from (30,30) to (80,70).
        _rect(art, 30, 30, 81, 32, 0, 0, 0);
        _rect(art, 30, 68, 81, 70, 0, 0, 0);
        _rect(art, 30, 30, 32, 70, 0, 0, 0);
        _rect(art, 79, 30, 81, 70, 0, 0, 0);
        // A stroke crossing the top edge at right angles, out past the lasso.
        _rect(art, 55, 14, 57, 40, 0, 0, 0);
        // Inside: a red dot. Between the lasso and the outline, on every
        // side: blue dots.
        _rect(art, 40, 48, 43, 51, 230, 40, 40);
        for (final (x, y) in _decoys) {
          _rect(art, x, y, x + 2, y + 2, 40, 80, 230);
        }
        tm.replaceLayerPixels(key, art);
        final before = _read(tm, key);

        final providers = await tester.runAsync(buildAppProviders);
        final boundaryKey = GlobalKey();
        var active = false;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ...providers!,
              ChangeNotifierProvider<ProjectService>.value(value: projects),
              ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: _w * 3,
                    height: _h * 3,
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: CanvasArea(
                        project: p,
                        currentLayerId: layer.id,
                        currentTool: DrawingTool.selectLasso,
                        currentFrame: 0,
                        sceneId: scene.id,
                        lassoSnapToLines: snap,
                        onSelectionActiveChanged: (v) => active = v,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final origin = tester.getTopLeft(find.byType(CanvasArea));
        Offset at(Offset canvas) => origin + canvas * 3;

        // A loose rectangle 6-7 px outside the outline, drawn with a mouse so
        // the screen-edge frame-switch zones do not swallow it.
        const corners = [
          Offset(23, 24),
          Offset(87, 23),
          Offset(88, 77),
          Offset(24, 76),
          Offset(23, 24),
        ];
        final lasso = await tester.startGesture(
          at(corners.first),
          kind: PointerDeviceKind.touch,
        );
        // The reference image loads asynchronously, as on a device.
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        final beforeLasso = await tester.runAsync(() => _pixels(boundaryKey));
        for (var c = 0; c + 1 < corners.length; c++) {
          for (var k = 1; k <= 16; k++) {
            await lasso.moveTo(
              at(Offset.lerp(corners[c], corners[c + 1], k / 16)!),
            );
            await tester.pump();
          }
        }
        // While the lasso is drawn it follows the finger; the selection
        // snaps to the line art once it is let go.
        final preview = await tester.runAsync(() => _pixels(boundaryKey));
        await tester.runAsync(
          () => _shot(
            boundaryKey,
            '${out.path}/canvas_${snap ? 'snap' : 'raw'}_preview.png',
          ),
        );
        final drawn = _changedCanvasPixels(beforeLasso!, preview!);
        expect(drawn, isNotEmpty, reason: 'the lasso preview is drawn');
        final onOutline = drawn.where((p) => _distanceToOutline(p) <= 2);
        expect(
          onOutline.length / drawn.length,
          lessThan(.1),
          reason: 'the preview follows the finger',
        );
        await lasso.up();
        // The snap runs in the background.
        for (var i = 0; i < 100 && !active; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        expect(active, isTrue, reason: 'the lasso makes a selection');
        await tester.runAsync(
          () => _shot(
            boundaryKey,
            '${out.path}/canvas_${snap ? 'snap' : 'raw'}.png',
          ),
        );

        // Drag the selection 10 px to the right.
        final move = await tester.startGesture(
          at(const Offset(50, 55)),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump();
        // Lifting the selection off the layer is asynchronous.
        for (
          var i = 0;
          i < 100 && _pixel(_read(tm, key), 41, 49)[3] != 0;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump();
        await move.moveTo(at(const Offset(60, 55)));
        await tester.pump(const Duration(milliseconds: 40));
        await move.up();
        await tester.pump();
        await _waitUndo(tester, undo, 1);
        final after = _read(tm, key);

        expect(
          _pixel(after, 51, 49),
          _pixel(before, 41, 49),
          reason: 'the red dot inside the outline moved with the selection',
        );
        for (final (x, y) in _decoys) {
          expect(
            _pixel(after, x, y),
            snap ? _pixel(before, x, y) : [0, 0, 0, 0],
            reason: snap
                ? 'the blue dot at ($x, $y) outside the outline stays put'
                : 'without snapping the lasso took the dot at ($x, $y) along',
          );
        }
      },
    );
  }
}

List<int> _pixel(Uint8List rgba, int x, int y) {
  final i = (y * _w + x) * 4;
  return rgba.sublist(i, i + 4);
}

/// The boundary's image as RGBA bytes ([_w] * 3 by [_h] * 3).
Future<Uint8List> _pixels(GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// Where [after] differs from [before], in canvas px.
List<Offset> _changedCanvasPixels(Uint8List before, Uint8List after) {
  const width = _w * 3;
  return [
    for (var i = 0; i < before.length ~/ 4; i++)
      if (before[i * 4] != after[i * 4] ||
          before[i * 4 + 1] != after[i * 4 + 1] ||
          before[i * 4 + 2] != after[i * 4 + 2])
        Offset((i % width + .5) / 3, (i ~/ width + .5) / 3),
  ];
}

/// Distance from [p] to the middle of the 2px outline, in canvas px.
double _distanceToOutline(Offset p) {
  const left = 31.0, right = 80.0, top = 31.0, bottom = 69.0;
  final dx = p.dx < left
      ? left - p.dx
      : p.dx > right
      ? p.dx - right
      : 0.0;
  final dy = p.dy < top
      ? top - p.dy
      : p.dy > bottom
      ? p.dy - bottom
      : 0.0;
  if (dx > 0 || dy > 0) return Offset(dx, dy).distance;
  return [
    p.dx - left,
    right - p.dx,
    p.dy - top,
    bottom - p.dy,
  ].reduce((a, b) => a < b ? a : b);
}

Future<void> _shot(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
}

void _rect(Uint8List d, int x0, int y0, int x1, int y1, int r, int g, int b) {
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * _w + x) * 4;
      d[i] = r;
      d[i + 1] = g;
      d[i + 2] = b;
      d[i + 3] = 255;
    }
  }
}

Future<void> _waitUndo(WidgetTester t, app_undo.UndoManager u, int n) async {
  for (var i = 0; i < 300 && u.undoCount < n; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump();
  }
  expect(u.undoCount, n);
}

Uint8List _read(TileManager tm, String key) {
  final o = Uint8List(_w * _h * 4);
  final tile = tm.getTile(key, 0, 0);
  if (tile == null) return o;
  for (var y = 0; y < _h; y++) {
    o.setRange(
      y * _w * 4,
      (y + 1) * _w * 4,
      tile,
      y * TileManager.tileSize * 4,
    );
  }
  return o;
}
