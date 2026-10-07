import 'dart:io';
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

/// The canvas shows blend modes as the export does: the paper takes part
/// (a Linear Dodge layer such as Prism's glow brightens a grey paper rather
/// than showing its own dark colours), a CPU-only mode on the layer being
/// edited is shown exactly, and a Multiply layer above it darkens it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('blend modes on the canvas match the export', (tester) async {
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
        name: 'blend-display',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFF808080,
        exportWidth: _w,
        exportHeight: _h,
      ),
    ))!;
    final sceneId = ps.scenesOf(project.id).first.id;
    final glow = ps.layersOf(project.id, sceneId, 0).first;
    final tm = ps.tileManagerOf(project.id);
    Uint8List solid(int r, int g, int b) {
      final out = Uint8List(_w * _h * 4);
      for (var i = 0; i < out.length; i += 4) {
        out.setAll(i, [r, g, b, 255]);
      }
      return out;
    }

    // The layer being edited: Prism-like dark colour in Linear Dodge.
    tm.replaceLayerPixels(
      ps.tileKeyFor(project.id, sceneId, 0, glow.id),
      solid(60, 40, 20),
    );
    ps.updateLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      layer: glow.copyWith(blendMode: LayerBlendMode.linearDodge),
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

    Future<List<int>> centre() async {
      final bytes = await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/blend-display').createSync(recursive: true);
        File(
          'build/blend-display/canvas.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        final rect = tester.getRect(find.byType(CanvasArea));
        final x = rect.center.dx.round(), y = rect.center.dy.round();
        final i = (y * image.width + x) * 4;
        image.dispose();
        return data!.buffer.asUint8List().sublist(i, i + 4);
      });
      return bytes!;
    }

    await tester.pumpWidget(canvas(glow.id));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final lit = await centre();
    expect(lit[0], closeTo(128 + 60, 3), reason: 'red added to the paper');
    expect(lit[1], closeTo(128 + 40, 3));
    expect(lit[2], closeTo(128 + 20, 3));

    // A Multiply layer above it darkens what the canvas shows below.
    final shade = ps.addLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'shade',
    );
    tm.replaceLayerPixels(
      ps.tileKeyFor(project.id, sceneId, 0, shade.id),
      solid(128, 255, 255),
    );
    ps.updateLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      layer: ps
          .layersOf(project.id, sceneId, 0)
          .firstWhere((l) => l.id == shade.id)
          .copyWith(blendMode: LayerBlendMode.multiply),
    );
    await tester.pumpWidget(canvas(glow.id));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final shaded = await centre();
    expect(shaded[0], closeTo((128 + 60) * 128 / 255, 3));
    expect(shaded[1], closeTo(128 + 40, 3), reason: 'green × 255 unchanged');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a layer clipped to the current layer stays inside it', (
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
        name: 'clip-display',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: _w,
        exportHeight: _h,
      ),
    ))!;
    final sceneId = ps.scenesOf(project.id).first.id;
    final base = ps.layersOf(project.id, sceneId, 0).first;
    final tm = ps.tileManagerOf(project.id);
    // The current layer: a black square in the middle third.
    final square = Uint8List(_w * _h * 4);
    for (var y = _h ~/ 3; y < _h * 2 ~/ 3; y++) {
      for (var x = _w ~/ 3; x < _w * 2 ~/ 3; x++) {
        square.setAll((y * _w + x) * 4, [0, 0, 0, 255]);
      }
    }
    tm.replaceLayerPixels(
      ps.tileKeyFor(project.id, sceneId, 0, base.id),
      square,
    );
    // Above it, clipped to it: solid red everywhere.
    final red = ps.addLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'red',
    );
    final redPixels = Uint8List(_w * _h * 4);
    for (var i = 0; i < redPixels.length; i += 4) {
      redPixels.setAll(i, [220, 30, 30, 255]);
    }
    tm.replaceLayerPixels(
      ps.tileKeyFor(project.id, sceneId, 0, red.id),
      redPixels,
    );
    ps.updateLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      layer: ps
          .layersOf(project.id, sceneId, 0)
          .firstWhere((l) => l.id == red.id)
          .copyWith(hasClipping: true),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: providers,
        child: MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: CanvasArea(
                project: ps.projects.firstWhere((p) => p.id == project.id),
                currentLayerId: base.id,
                currentTool: DrawingTool.pen,
                currentFrame: 0,
                sceneId: sceneId,
              ),
            ),
          ),
        ),
      ),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    final shot = await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width;
      image.dispose();
      return (data!.buffer.asUint8List(), width);
    });
    final (pixels, width) = shot!;
    final rect = tester.getRect(find.byType(CanvasArea));
    final drawing = canvasDrawingRectFor(
      rect.size,
      ps.projects.firstWhere((p) => p.id == project.id),
    );
    List<int> at(double fx, double fy) {
      final x = (rect.left + drawing.left + drawing.width * fx).round();
      final y = (rect.top + drawing.top + drawing.height * fy).round();
      final i = (y * width + x) * 4;
      return pixels.sublist(i, i + 3);
    }

    expect(at(0.5, 0.5)[0], greaterThan(180), reason: 'red inside the square');
    expect(at(0.5, 0.5)[1], lessThan(60));
    expect(at(0.1, 0.1), [255, 255, 255], reason: 'paper outside it');
    await tester.pumpWidget(const SizedBox());
  });
}
