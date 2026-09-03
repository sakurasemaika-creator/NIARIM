import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/models/onion_skin_settings.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CanvasAreaのオニオンスキンを固定1点ではなく描画領域全体の色分布で検証する', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ps = ProjectService();
    await tester.runAsync(ps.init);
    final undo = app_undo.UndoManager();
    ps.setUndoManager(undo);
    final project = await ps.createProject(
      name: 'onion-diagnostic',
      fps: 3,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 96,
      exportHeight: 80,
    );
    final sceneId = ps.scenesOf(project.id).first.id;
    expect(ps.frameCount(project.id, sceneId), 3);

    const rects = [
      (x0: 12, y0: 25, x1: 28, y1: 41, r: 230, g: 30, b: 30),
      (x0: 40, y0: 25, x1: 56, y1: 41, r: 30, g: 220, b: 70),
      (x0: 68, y0: 25, x1: 84, y1: 41, r: 30, g: 30, b: 230),
    ];
    for (var fi = 0; fi < 3; fi++) {
      final layer = ps.layersOf(project.id, sceneId, fi).first;
      final key = ps.tileKeyFor(project.id, sceneId, fi, layer.id);
      final rgba = Uint8List(96 * 80 * 4);
      final q = rects[fi];
      for (var y = q.y0; y < q.y1; y++) {
        for (var x = q.x0; x < q.x1; x++) {
          final i = (y * 96 + x) * 4;
          rgba[i] = q.r;
          rgba[i + 1] = q.g;
          rgba[i + 2] = q.b;
          rgba[i + 3] = 255;
        }
      }
      ps.tileManagerOf(project.id).replaceLayerPixels(key, rgba);
    }

    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    OnionSkinSettings settings = const OnionSkinSettings(enabled: false);
    StateSetter? hostSetState;
    final currentLayer = ps.layersOf(project.id, sceneId, 1).first;

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
              child: StatefulBuilder(
                builder: (context, setState) {
                  hostSetState = setState;
                  return RepaintBoundary(
                    key: boundaryKey,
                    child: SizedBox(
                      width: 288,
                      height: 240,
                      child: CanvasArea(
                        project: project,
                        currentLayerId: currentLayer.id,
                        currentTool: DrawingTool.pen,
                        currentFrame: 1,
                        sceneId: sceneId,
                        onionSkinSettings: settings,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await _settleRealAsync(tester);
    final off = await _capture(tester, boundaryKey);
    final offCounts = _dominanceCounts(off.rgba);
    expect(
      offCounts.green,
      greaterThan(100),
      reason: 'OFFでも現在フレームの緑矩形が実CanvasAreaに描画されること',
    );
    expect(offCounts.red, lessThan(40), reason: 'OFFでは前フレームを描画しないこと');
    expect(offCounts.blue, lessThan(40), reason: 'OFFでは後フレームを描画しないこと');

    hostSetState!(() {
      settings = const OnionSkinSettings(
        enabled: true,
        showPrev: true,
        showNext: true,
        prevFrames: 1,
        nextFrames: 1,
        frameInterval: 1,
        prevColor: Color(0xFFFF0000),
        nextColor: Color(0xFF0000FF),
        prevOpacity: 0.8,
        nextOpacity: 0.8,
        fadeByDistance: false,
      );
    });
    await tester.pump();
    await _settleRealAsync(tester);
    final on = await _capture(tester, boundaryKey);
    final onCounts = _dominanceCounts(on.rgba);

    expect(onCounts.green, greaterThan(100), reason: 'ONでも現在フレームの元色は維持されること');
    expect(
      onCounts.red,
      greaterThan(offCounts.red + 100),
      reason: 'ONで前フレーム由来の赤優勢画素が増えること',
    );
    expect(
      onCounts.blue,
      greaterThan(offCounts.blue + 100),
      reason: 'ONで後フレーム由来の青優勢画素が増えること',
    );

    final out = Directory('build/functional-visual')
      ..createSync(recursive: true);
    await tester.runAsync(() async {
      await File('${out.path}/onion_diagnostic_off.png').writeAsBytes(off.png);
      await File('${out.path}/onion_diagnostic_on.png').writeAsBytes(on.png);
      await File('${out.path}/onion_diagnostic_counts.txt').writeAsString(
        'OFF red=${offCounts.red} green=${offCounts.green} blue=${offCounts.blue}\n'
        'ON red=${onCounts.red} green=${onCounts.green} blue=${onCounts.blue}\n',
      );
    });
  }, timeout: const Timeout(Duration(seconds: 120)));
}

Future<void> _settleRealAsync(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

typedef _Capture = ({Uint8List rgba, Uint8List png});

Future<_Capture> _capture(WidgetTester tester, GlobalKey key) async {
  return (await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final result = (
      rgba: raw!.buffer.asUint8List(),
      png: png!.buffer.asUint8List(),
    );
    image.dispose();
    return result;
  }))!;
}

({int red, int green, int blue}) _dominanceCounts(Uint8List rgba) {
  var red = 0;
  var green = 0;
  var blue = 0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 16) continue;
    final r = rgba[i];
    final g = rgba[i + 1];
    final b = rgba[i + 2];
    if (r > g + 35 && r > b + 35) red++;
    if (g > r + 35 && g > b + 35) green++;
    if (b > r + 35 && b > g + 35) blue++;
  }
  return (red: red, green: green, blue: blue);
}
