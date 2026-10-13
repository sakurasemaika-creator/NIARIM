import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('本番Provider配線のCanvasAreaは既存画素を初期表示し、表示タイミングをPNGで記録する', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final providers = await tester.runAsync(buildAppProviders);
    expect(providers, isNotNull);

    ProjectService? projects;
    dynamic project;
    String? layerId;
    String? sceneId;
    StateSetter? rebuildHost;
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MultiProvider(
        providers: providers!,
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF777777),
            body: StatefulBuilder(
              builder: (context, setState) {
                projects ??= context.read<ProjectService>();
                rebuildHost = setState;
                if (project == null) return const SizedBox.expand();
                return Center(
                  child: SizedBox(
                    width: 288,
                    height: 288,
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: CanvasArea(
                        project: project,
                        currentLayerId: layerId,
                        currentTool: DrawingTool.pen,
                        currentFrame: 0,
                        sceneId: sceneId!,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(projects, isNotNull, reason: '本番ProviderからProjectServiceを取得できること');

    project = await tester.runAsync(
      () => projects!.createProject(
        name: 'initial-composite-production-provider',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0x00000000,
        exportWidth: 96,
        exportHeight: 96,
      ),
    );
    expect(project, isNotNull);
    final scene = projects!.scenesOf(project.id).first;
    final layer = projects!.layersOf(project.id, scene.id, 0).first;
    sceneId = scene.id;
    layerId = layer.id;
    final key = projects!.tileKeyFor(project.id, scene.id, 0, layer.id);
    final tm = projects!.tileManagerOf(project.id);

    final pixels = Uint8List(96 * 96 * 4);
    // 非対称な赤矩形。CanvasAreaの初期合成が成功すれば中央左寄りに見える。
    for (var y = 30; y < 62; y++) {
      for (var x = 18; x < 48; x++) {
        final i = (y * 96 + x) * 4;
        pixels[i] = 235;
        pixels[i + 1] = 35;
        pixels[i + 2] = 25;
        pixels[i + 3] = 255;
      }
    }
    tm.replaceLayerPixels(key, pixels);
    rebuildHost!(() {});
    await tester.pump();

    final samples = <String, int>{};
    var elapsedMs = 0;
    for (final targetMs in const [100, 250, 500, 1000, 2000]) {
      final delta = targetMs - elapsedMs;
      await tester.pump(Duration(milliseconds: delta));
      elapsedMs = targetMs;
      samples['${targetMs}ms'] =
          await tester.runAsync(
            () => _captureAndCountRed(
              boundaryKey,
              '${out.path}/canvas_initial_composite_${targetMs}ms.png',
            ),
          ) ??
          0;
    }

    // 元画素自体があることと、初期合成が短時間で実Canvasへ反映されることを別々に確認。
    final tile = tm.getTile(key, 0, 0);
    expect(tile, isNotNull);
    expect(
      tile![(40 * 256 + 30) * 4 + 3],
      255,
      reason: '入力した既存画素はTileManager上に存在すること',
    );
    expect(
      samples['250ms']!,
      greaterThan(50),
      reason: '本番Provider配線では既存画素が250ms以内に実Canvasへ表示されること。samples=$samples',
    );
    expect(
      samples['1000ms']!,
      greaterThan(50),
      reason: '1秒時点でも既存画素が実Canvasへ表示されること。samples=$samples',
    );
    expect(
      samples['2000ms']!,
      greaterThan(50),
      reason: '表示後に既存画素が消えないこと。samples=$samples',
    );

    await tester.runAsync(
      () =>
          File('${out.path}/canvas_initial_composite_counts.txt').writeAsString(
            samples.entries.map((e) => '${e.key}=${e.value}').join('\n'),
          ),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}

Future<int> _captureAndCountRed(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final rgba = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final png = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
  var red = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if (rgba[i] > 170 &&
        rgba[i] > rgba[i + 1] + 70 &&
        rgba[i] > rgba[i + 2] + 70 &&
        rgba[i + 3] > 180) {
      red++;
    }
  }
  await File(path).writeAsBytes(png, flush: true);
  image.dispose();
  return red;
}
