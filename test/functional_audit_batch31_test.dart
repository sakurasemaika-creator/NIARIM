import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
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
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('実CanvasAreaのマジックワンドで同色の非連結領域を分離選択し、タップ側だけ移動する', (tester) async {
    tester.view.physicalSize = const Size(480, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final p = (await tester.runAsync(
      () => projects.createProject(
        name: 'magicwand-functional',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0x00000000,
        exportWidth: 96,
        exportHeight: 80,
      ),
    ))!;
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = projects.tileManagerOf(p.id);

    final initial = Uint8List(96 * 80 * 4);
    // 完全に同色だが離れている2領域。左だけをワンドで選択する。
    _rect(initial, 96, 22, 25, 38, 41, 210, 55, 45);
    _rect(initial, 96, 66, 25, 82, 41, 210, 55, 45);
    tm.replaceLayerPixels(key, initial);
    final before = _read(tm, key, 96, 80);

    final providers = await tester.runAsync(buildAppProviders);
    var active = false;
    final boundaryKey = GlobalKey();
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
                width: 288,
                height: 240,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: CanvasArea(
                    project: p,
                    currentLayerId: layer.id,
                    currentTool: DrawingTool.selectMagicWand,
                    currentFrame: 0,
                    sceneId: scene.id,
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
    await tester.runAsync(
      () => _shot(boundaryKey, '${out.path}/selection_magicwand_00_before.png'),
    );
    final origin = tester.getTopLeft(find.byType(CanvasArea));
    Offset at(double x, double y) => origin + Offset(x * 3, y * 3);

    final tap = await tester.startGesture(
      at(30, 33),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await tap.up();
    await tester.pump();
    await _waitUntil(tester, () => active);
    await tester.runAsync(
      () =>
          _shot(boundaryKey, '${out.path}/selection_magicwand_01_selected.png'),
    );

    // 選択された左領域内を掴み、0,+22移動。
    final move = await tester.startGesture(
      at(30, 33),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    expect(tm.recordingTouchedTiles, isNotNull, reason: 'ワンド選択後に選択変形へ入れること');
    await _waitAlpha(tester, tm, key, 30, 33, 0);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await move.moveTo(at(30, 55));
    await tester.pump(const Duration(milliseconds: 40));
    await move.up();
    await tester.pump();
    await _waitUntil(tester, () => undo.undoCount == 1);
    await tester.runAsync(
      () => _shot(boundaryKey, '${out.path}/selection_magicwand_02_after.png'),
    );

    final actual = _read(tm, key, 96, 80);
    final expected = Uint8List.fromList(before);
    for (var y = 25; y < 41; y++)
      for (var x = 22; x < 38; x++) {
        final si = (y * 96 + x) * 4, di = ((y + 22) * 96 + x) * 4;
        expected.setRange(di, di + 4, before, si);
        expected.fillRange(si, si + 4, 0);
      }
    expect(
      actual,
      orderedEquals(expected),
      reason: '同色でも非連結の右領域は1byteも変えず、タップした連結領域だけ移動すること',
    );

    undo.undo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_read(tm, key, 96, 80), orderedEquals(before));
    await tester.runAsync(
      () => _shot(boundaryKey, '${out.path}/selection_magicwand_03_undo.png'),
    );
    undo.redo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_read(tm, key, 96, 80), orderedEquals(actual));
    await tester.runAsync(
      () => _shot(boundaryKey, '${out.path}/selection_magicwand_04_redo.png'),
    );
  });
}

Future<void> _shot(GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
}

void _rect(
  Uint8List d,
  int w,
  int x0,
  int y0,
  int x1,
  int y1,
  int r,
  int g,
  int b,
) {
  for (var y = y0; y < y1; y++)
    for (var x = x0; x < x1; x++) {
      final i = (y * w + x) * 4;
      d[i] = r;
      d[i + 1] = g;
      d[i + 2] = b;
      d[i + 3] = 255;
    }
}

Future<void> _waitUntil(WidgetTester t, bool Function() f) async {
  final e = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(e) && !f()) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump();
  }
  expect(f(), isTrue);
}

Future<void> _waitAlpha(
  WidgetTester t,
  dynamic tm,
  String key,
  int x,
  int y,
  int a,
) async {
  await _waitUntil(t, () {
    final tile = tm.getTile(key, 0, 0) as Uint8List?;
    return (tile == null ? 0 : tile[(y * 256 + x) * 4 + 3]) == a;
  });
}

Uint8List _read(dynamic tm, String key, int w, int h) {
  final o = Uint8List(w * h * 4);
  final tile = tm.getTile(key, 0, 0) as Uint8List?;
  if (tile == null) return o;
  for (var y = 0; y < h; y++)
    o.setRange(y * w * 4, (y + 1) * w * 4, tile, y * 256 * 4);
  return o;
}
