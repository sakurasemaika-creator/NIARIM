import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/initial-composite');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('既存レイヤー画素がCanvasArea初回表示だけ真っ黒にならず描画される', (tester) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ps = ProjectService();
    final undo = app_undo.UndoManager();
    ps.setUndoManager(undo);
    final p = (await tester.runAsync(
      () => ps.createProject(
        name: 'initial-composite-visual',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0x00000000,
        exportWidth: 96,
        exportHeight: 80,
      ),
    ))!;
    final scene = ps.scenesOf(p.id).first;
    final layer = ps.layersOf(p.id, scene.id, 0).first;
    final key = ps.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = ps.tileManagerOf(p.id);
    final initial = Uint8List(96 * 80 * 4);
    for (var y = 44; y < 68; y++) {
      for (var x = 54; x < 86; x++) {
        final i = (y * 96 + x) * 4;
        initial[i] = 220;
        initial[i + 1] = 55;
        initial[i + 2] = 40;
        initial[i + 3] = 255;
      }
    }
    tm.replaceLayerPixels(key, initial);

    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          ChangeNotifierProvider<ProjectService>.value(value: ps),
          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: 288,
                  height: 240,
                  child: CanvasArea(
                    project: p,
                    currentLayerId: layer.id,
                    currentTool: DrawingTool.selectRect,
                    currentFrame: 0,
                    sceneId: scene.id,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final observations = <String>[];
    for (final checkpoint in const <(String, Duration)>[
      ('0200ms', Duration(milliseconds: 200)),
      ('1000ms', Duration(milliseconds: 800)),
      ('3000ms', Duration(seconds: 2)),
    ]) {
      await tester.pump(checkpoint.$2);
      final rgba = await tester.runAsync(
        () => _captureRgba(boundaryKey, '${out.path}/${checkpoint.$1}.png'),
      );
      final pixel = _pixel(rgba!, 288, 200, 165);
      observations.add('${checkpoint.$1}: rgba=$pixel');
    }
    // This position lies inside the preloaded red rectangle in project coordinates.
    // By 3 seconds it must be visibly composited without requiring user interaction.
    final finalRgba = await tester.runAsync(
      () => _captureRgba(boundaryKey, '${out.path}/final.png'),
    );
    final finalPixel = _pixel(finalRgba!, 288, 200, 165);
    // ignore: avoid_print
    print(
      'INITIAL_COMPOSITE_CHECKPOINTS ${observations.join(' | ')} final=$finalPixel',
    );
    expect(finalPixel.$1, greaterThan(140), reason: '既存の赤画素が初回表示へ合成されること');
    expect(
      finalPixel.$1,
      greaterThan(finalPixel.$2 + 70),
      reason: '黒背景ではなく赤矩形が見えること',
    );
  }, timeout: const Timeout(Duration(seconds: 20)));
}

Future<Uint8List?> _captureRgba(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bytes = raw?.buffer.asUint8List();
  image.dispose();
  return bytes;
}

(int, int, int, int) _pixel(Uint8List rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return (rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]);
}
