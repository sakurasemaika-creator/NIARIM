import 'helpers/project_storage.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/pump_real_async.dart';

const _w = 64;
const _h = 48;

/// The selection layer on the canvas (the owner's choice, 2026-11-27,
/// judgement card J4): while it is the layer in use, its mask is drawn half
/// see-through so the picture under it shows; while another layer is in use,
/// it is a dashed outline and the inside shows the picture. Before, the mask
/// was drawn in its own (opaque) colour while in use and covered the
/// picture.
void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the selection layer: see-through in use, dashed otherwise', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = await tester.runAsync(buildAppProviders);
    final boundary = GlobalKey();
    late ProjectService ps;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers!,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              ps = context.read<ProjectService>();
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'selection-display',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: _w,
        exportHeight: _h,
      ),
    ))!;
    final sceneId = ps.scenesOf(project.id).first.id;
    final picture = ps.layersOf(project.id, sceneId, 0).first;
    final selection = ps.addLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      type: LayerType.selection,
      name: 'mask',
    );
    final tm = ps.tileManagerOf(project.id);
    // The picture: a green square in the middle; the mask: an opaque black
    // rectangle over the left part of it.
    final art = Uint8List(_w * _h * 4);
    final mask = Uint8List(_w * _h * 4);
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final i = (y * _w + x) * 4;
        if (x >= 16 && x < 48 && y >= 8 && y < 40) {
          art.setAll(i, [0, 200, 0, 255]);
        }
        if (x >= 12 && x < 40 && y >= 12 && y < 36) {
          mask.setAll(i, [0, 0, 0, 255]);
        }
      }
    }
    tm.replaceLayerPixels(
      ps.tileKeyFor(project.id, sceneId, 0, picture.id),
      art,
    );
    tm.replaceLayerPixels(
      ps.tileKeyFor(project.id, sceneId, 0, selection.id),
      mask,
    );

    Widget canvas(String layerId) => MultiProvider(
      providers: providers,
      child: MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: boundary,
            child: CanvasArea(
              key: ValueKey(layerId),
              project: ps.projects.firstWhere((p) => p.id == project.id),
              currentLayerId: layerId,
              currentTool: DrawingTool.pen,
              currentFrame: 0,
              sceneId: sceneId,
            ),
          ),
        ),
      ),
    );

    // The colour at canvas pixel (x, y), or [dx] screen pixels left of its
    // left edge.
    Future<List<int>> at(int x, int y, {double? dx}) async {
      final bytes = await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final rect = tester.getRect(find.byType(CanvasArea));
        // The drawing fills the area at its aspect ratio, centred.
        final scale = [
          rect.width / _w,
          rect.height / _h,
        ].reduce((a, b) => a < b ? a : b);
        final left = rect.left + (rect.width - _w * scale) / 2;
        final top = rect.top + (rect.height - _h * scale) / 2;
        final px = dx == null
            ? (left + (x + .5) * scale).floor()
            : (left + x * scale - dx).floor();
        final py = (top + (y + .5) * scale).floor();
        final i = (py * image.width + px) * 4;
        image.dispose();
        return data!.buffer.asUint8List().sublist(i, i + 4);
      });
      return bytes!;
    }

    bool black(List<int> c) => c[0] < 40 && c[1] < 40 && c[2] < 40;

    // In use: the mask is not drawn black; the green under it shows through
    // the half see-through selection colour.
    await tester.pumpWidget(canvas(selection.id));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final overGreen = await at(24, 24);
    final overPaper = await at(13, 24);
    expect(black(overGreen), isFalse, reason: 'the mask does not cover it');
    expect(black(overPaper), isFalse);
    // The picture under the mask shows: the mask over the green looks
    // different from the mask over the paper.
    final difference = [
      for (var c = 0; c < 3; c++) (overGreen[c] - overPaper[c]).abs(),
    ].reduce((a, b) => a > b ? a : b);
    expect(difference, greaterThan(40), reason: 'the green shows through');

    // Another layer in use: inside the mask the picture is as it is, and
    // the edge is a dashed line of the selection colours.
    await tester.pumpWidget(canvas(picture.id));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final inside = await at(30, 24);
    expect(inside.sublist(0, 3), [0, 200, 0], reason: 'the picture, untouched');
    final paper = await at(4, 4);
    expect(paper.sublist(0, 3), [255, 255, 255]);
    // Just outside the mask's left edge (x = 12), the line is drawn: some
    // pixels differ from the paper.
    var marked = 0;
    for (var y = 12; y < 36; y++) {
      final c = await at(12, y, dx: 1);
      if (c[0] != 255 || c[1] != 255 || c[2] != 255) marked++;
    }
    expect(marked, greaterThan(4), reason: 'a dashed outline');
    expect(tester.takeException(), isNull);
  });
}
