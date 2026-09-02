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
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('実CanvasAreaで前後フレームのオニオンスキンが指定色で表示されOFFでは消える', (tester) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ps = ProjectService();
    await ps.init();
    final undo = app_undo.UndoManager();
    ps.setUndoManager(undo);
    final p = await ps.createProject(
      name: 'onion-real-functional',
      fps: 3,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 96,
      exportHeight: 80,
    );
    final sceneId = ps.scenesOf(p.id).first.id;
    ps.addFrame(p.id, sceneId);
    ps.addFrame(p.id, sceneId);
    expect(ps.frameCount(p.id, sceneId), 3);

    // 前=左の白図形、現在=中央の緑、後=右の白図形。オニオン側は白を使い、
    // painterの指定色タイント結果をRGBで明確に判別する。
    final rects = <({int x0, int y0, int x1, int y1, int r, int g, int b})>[
      (x0: 12, y0: 25, x1: 28, y1: 41, r: 255, g: 255, b: 255),
      (x0: 40, y0: 25, x1: 56, y1: 41, r: 30, g: 220, b: 70),
      (x0: 68, y0: 25, x1: 84, y1: 41, r: 255, g: 255, b: 255),
    ];
    for (var fi = 0; fi < 3; fi++) {
      final layer = ps.layersOf(p.id, sceneId, fi).first;
      final key = ps.tileKeyFor(p.id, sceneId, fi, layer.id);
      final rgba = Uint8List(96 * 80 * 4);
      final q = rects[fi];
      for (var y = q.y0; y < q.y1; y++) {
        for (var x = q.x0; x < q.x1; x++) {
          final i = (y * 96 + x) * 4;
          rgba[i] = q.r; rgba[i + 1] = q.g; rgba[i + 2] = q.b; rgba[i + 3] = 255;
        }
      }
      ps.tileManagerOf(p.id).replaceLayerPixels(key, rgba);
    }

    final currentLayer = ps.layersOf(p.id, sceneId, 1).first;
    final providers = await tester.runAsync(buildAppProviders);
    final boundaryKey = GlobalKey();
    OnionSkinSettings settings = const OnionSkinSettings(enabled: false);
    StateSetter? hostSetState;

    await tester.pumpWidget(MultiProvider(
      providers: [
        ...providers!,
        ChangeNotifierProvider<ProjectService>.value(value: ps),
        ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(builder: (context, setState) {
              hostSetState = setState;
              return RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: 288,
                  height: 240,
                  child: CanvasArea(
                    project: p,
                    currentLayerId: currentLayer.id,
                    currentTool: DrawingTool.pen,
                    currentFrame: 1,
                    sceneId: sceneId,
                    onionSkinSettings: settings,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    final off = await _capture(boundaryKey);
    final offPrev = _pixel(off.rgba, off.width, 20 * 3, 33 * 3);
    final offCurrent = _pixel(off.rgba, off.width, 48 * 3, 33 * 3);
    final offNext = _pixel(off.rgba, off.width, 76 * 3, 33 * 3);
    expect(offPrev.sublist(0, 3), orderedEquals([255, 255, 255]));
    expect(offNext.sublist(0, 3), orderedEquals([255, 255, 255]));
    expect(offCurrent[1], greaterThan(offCurrent[0]));

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
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 50));

    final on = await _capture(boundaryKey);
    final prev = _pixel(on.rgba, on.width, 20 * 3, 33 * 3);
    final current = _pixel(on.rgba, on.width, 48 * 3, 33 * 3);
    final next = _pixel(on.rgba, on.width, 76 * 3, 33 * 3);
    expect(prev[0], greaterThan(prev[1] + 80), reason: '前フレーム領域が赤系タイントで実表示されること');
    expect(prev[0], greaterThan(prev[2] + 80));
    expect(next[2], greaterThan(next[0] + 80), reason: '後フレーム領域が青系タイントで実表示されること');
    expect(next[2], greaterThan(next[1] + 80));
    expect(current[1], greaterThan(current[0] + 80), reason: '現在フレームはオニオン色に置換されず元の緑を維持すること');
    expect(current[1], greaterThan(current[2] + 80));

    await File('${out.path}/onion_canvas_real.png').writeAsBytes(on.png);
  });
}

typedef _Capture = ({Uint8List rgba, Uint8List png, int width, int height});
Future<_Capture> _capture(GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final result = (rgba: raw!.buffer.asUint8List(), png: png!.buffer.asUint8List(), width: image.width, height: image.height);
  image.dispose();
  return result;
}
List<int> _pixel(Uint8List rgba, int w, int x, int y) {
  final i = (y * w + x) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
}
