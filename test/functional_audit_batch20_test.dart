import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/models/project.dart';
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

  testWidgets(
      '実CanvasAreaで矩形選択→移動→再移動→Undo/Redoし、選択外全画素と選択追従を確認する',
      (tester) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final project = await tester.runAsync(() => projects.createProject(
          name: 'selection-functional',
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0x00000000,
          exportWidth: 96,
          exportHeight: 80,
        ));
    expect(project, isNotNull);
    final p = project!;
    final scene = projects.scenesOf(p.id).first;
    final layer = projects.layersOf(p.id, scene.id, 0).first;
    final key = projects.tileKeyFor(p.id, scene.id, 0, layer.id);
    final tm = projects.tileManagerOf(p.id);

    final initial = _makeInitial(96, 80);
    tm.replaceLayerPixels(key, initial);
    final before = _readCanvas(tm, key, 96, 80);
    await _save(before, 96, 80, '${out.path}/selection_real_before.png');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProjectService>.value(value: projects),
          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 96,
                height: 80,
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
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);

    final area = find.byType(CanvasArea);
    final origin = tester.getTopLeft(area);

    // 1) 実際のPointer down/move/upで矩形選択を作る。
    await _dragWithWait(
      tester,
      origin + const Offset(16, 14),
      origin + const Offset(48, 46),
      waitBeforeMove: Duration.zero,
    );
    expect(tester.takeException(), isNull);

    // 2) 選択内を掴む。浮動画像の非同期生成を待ってから16px右・10px下へ移動。
    await _dragWithWait(
      tester,
      origin + const Offset(30, 28),
      origin + const Offset(46, 38),
      waitBeforeMove: const Duration(milliseconds: 180),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    final moved1 = _readCanvas(tm, key, 96, 80);
    final expected1 = _translatedSelection(before, 96, 80,
        left: 16, top: 14, right: 48, bottom: 46, dx: 16, dy: 10);
    expect(moved1, orderedEquals(expected1),
        reason: '選択内だけが整数平行移動し、選択外全画素は1byteも変わらないこと');
    await _save(moved1, 96, 80, '${out.path}/selection_real_moved1.png');

    // 3) 選択マスク自体も移動先へ追従していることを、移動先をもう一度掴んで確認。
    await _dragWithWait(
      tester,
      origin + const Offset(46, 38),
      origin + const Offset(51, 38),
      waitBeforeMove: const Duration(milliseconds: 180),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    final moved2 = _readCanvas(tm, key, 96, 80);
    final expected2 = _translatedSelection(moved1, 96, 80,
        left: 32, top: 24, right: 64, bottom: 56, dx: 5, dy: 0);
    expect(moved2, orderedEquals(expected2),
        reason: '1回目の移動後も選択マスクが新位置へ追従し、2回目の移動対象になること');
    await _save(moved2, 96, 80, '${out.path}/selection_real_moved2.png');

    expect(undo.undoCount, 2);
    undo.undo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_readCanvas(tm, key, 96, 80), orderedEquals(moved1));
    undo.undo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_readCanvas(tm, key, 96, 80), orderedEquals(before));
    await _save(_readCanvas(tm, key, 96, 80), 96, 80,
        '${out.path}/selection_real_undo_original.png');

    undo.redo();
    undo.redo();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_readCanvas(tm, key, 96, 80), orderedEquals(moved2),
        reason: 'Redo 2回で2段階移動後の全RGBAへ完全一致すること');
  });
}

Future<void> _dragWithWait(
  WidgetTester tester,
  Offset from,
  Offset to, {
  required Duration waitBeforeMove,
}) async {
  final g = await tester.startGesture(from, kind: PointerDeviceKind.touch);
  await tester.pump();
  if (waitBeforeMove != Duration.zero) {
    await tester.pump(waitBeforeMove);
  }
  await g.moveTo(to);
  await tester.pump(const Duration(milliseconds: 40));
  await g.up();
  await tester.pump(const Duration(milliseconds: 40));
}

Uint8List _makeInitial(int w, int h) {
  final rgba = Uint8List(w * h * 4);
  // 選択対象: 非対称な赤系図形。矩形選択16..47 x 14..45の中に完全に収める。
  for (var y = 19; y < 38; y++) {
    for (var x = 20; x < 42; x++) {
      if (x > 35 && y < 27) continue; // 非対称な欠けを作る
      final i = (y * w + x) * 4;
      rgba[i] = 220;
      rgba[i + 1] = 35 + (y % 5) * 8;
      rgba[i + 2] = 25 + (x % 7) * 5;
      rgba[i + 3] = ((x + y) % 9 == 0) ? 160 : 255;
    }
  }
  // 選択外固定物: 移動先とも重ならない右下へ置く。全画素不変確認用。
  for (var y = 61; y < 75; y++) {
    for (var x = 76; x < 91; x++) {
      final i = (y * w + x) * 4;
      rgba[i] = 15;
      rgba[i + 1] = 80;
      rgba[i + 2] = 230;
      rgba[i + 3] = 255;
    }
  }
  return rgba;
}

Uint8List _translatedSelection(
  Uint8List src,
  int w,
  int h, {
  required int left,
  required int top,
  required int right,
  required int bottom,
  required int dx,
  required int dy,
}) {
  final out = Uint8List.fromList(src);
  final selected = <(int, int, int, int, int, int)>[];
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      if (x < 0 || y < 0 || x >= w || y >= h) continue;
      final i = (y * w + x) * 4;
      selected.add((x, y, src[i], src[i + 1], src[i + 2], src[i + 3]));
      out[i] = 0;
      out[i + 1] = 0;
      out[i + 2] = 0;
      out[i + 3] = 0;
    }
  }
  for (final p in selected) {
    final nx = p.$1 + dx;
    final ny = p.$2 + dy;
    if (nx < 0 || ny < 0 || nx >= w || ny >= h || p.$6 == 0) continue;
    final i = (ny * w + nx) * 4;
    _sourceOver(out, i, p.$3, p.$4, p.$5, p.$6);
  }
  return out;
}

void _sourceOver(Uint8List dst, int i, int r, int g, int b, int a) {
  final sa = a / 255.0;
  final da = dst[i + 3] / 255.0;
  final oa = sa + da * (1 - sa);
  if (oa <= 0) return;
  dst[i] = ((r * sa + dst[i] * da * (1 - sa)) / oa).round().clamp(0, 255);
  dst[i + 1] = ((g * sa + dst[i + 1] * da * (1 - sa)) / oa).round().clamp(0, 255);
  dst[i + 2] = ((b * sa + dst[i + 2] * da * (1 - sa)) / oa).round().clamp(0, 255);
  dst[i + 3] = (oa * 255).round().clamp(0, 255);
}

Uint8List _readCanvas(dynamic tm, String layer, int w, int h) {
  final result = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final tile = tm.getTile(layer, x ~/ 256, y ~/ 256) as Uint8List?;
      if (tile == null) continue;
      final src = ((y % 256) * 256 + (x % 256)) * 4;
      final dst = (y * w + x) * 4;
      result[dst] = tile[src];
      result[dst + 1] = tile[src + 1];
      result[dst + 2] = tile[src + 2];
      result[dst + 3] = tile[src + 3];
    }
  }
  return result;
}

Future<void> _save(Uint8List rgba, int w, int h, String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await desc.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  frame.image.dispose();
  codec.dispose();
  desc.dispose();
  buffer.dispose();
}
