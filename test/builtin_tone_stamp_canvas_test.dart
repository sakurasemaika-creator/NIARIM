import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/undo_manager.dart' as app_undo;
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:niarim/screens/canvas/widgets/pen_sub_tool_panel.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/project_storage.dart';

const _w = 480;
const _h = 200;

void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'pen_pressure_enabled': false}),
  );

  testWidgets('all built-in tones and stamps reach the canvas', (tester) async {
    tester.view.physicalSize = const Size(900, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ProjectService();
    final undo = app_undo.UndoManager();
    projects.setUndoManager(undo);
    final brushes = BrushService();
    await tester.runAsync(brushes.init);
    brushes.setCurrentColor(const Color(0xFF2050C0));
    final p = (await tester.runAsync(
      () => projects.createProject(
        name: 'tone-stamp-sweep',
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
    final tones = ToneService();
    final stamps = StampService();
    await tester.runAsync(tones.init);
    await tester.runAsync(stamps.init);
    final mode = ValueNotifier(PenSubTool.tone);
    addTearDown(mode.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...providers!,
          ChangeNotifierProvider<ProjectService>.value(value: projects),
          ChangeNotifierProvider<app_undo.UndoManager>.value(value: undo),
          ChangeNotifierProvider<BrushService>.value(value: brushes),
          ChangeNotifierProvider<ToneService>.value(value: tones),
          ChangeNotifierProvider<StampService>.value(value: stamps),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: mode,
              builder: (context, subTool, _) => CanvasArea(
                project: p,
                currentLayerId: layer.id,
                currentTool: DrawingTool.pen,
                currentSubTool: subTool,
                currentFrame: 0,
                sceneId: scene.id,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final area = find.byType(CanvasArea);
    Offset at(Offset c) {
      final r = canvasDrawingRectFor(tester.getSize(area), p);
      return tester.getTopLeft(area) + r.topLeft + c * (r.width / _w);
    }

    Future<void> settle() async {
      for (var i = 0; i < 80; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump();
        if (undo.canUndo) return;
      }
    }

    expect(tones.tones, hasLength(72));
    expect(stamps.stamps, hasLength(29));
    brushes.updateCurrentBrushSize(76, remember: false);
    brushes.setCurrentColor(const Color(0xFF172639));
    for (final (id, name, tool) in [
      for (final tone in tones.tones) (tone.id, tone.name, PenSubTool.tone),
      for (final stamp in stamps.stamps)
        (stamp.id, stamp.name, PenSubTool.stamp),
    ]) {
      mode.value = tool;
      if (tool == PenSubTool.tone) {
        tones.selectTone(id);
      } else {
        stamps.selectStamp(id);
      }
      await tester.pump();
      final g = await tester.startGesture(
        at(const Offset(70, 100)),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      for (var i = 1; i <= 40; i++) {
        final x = 70 + i * 8.0;
        final y = 100 + (tool == PenSubTool.stamp ? 13 * math.sin(i / 6) : 0);
        await g.moveTo(at(Offset(x, y.toDouble())));
      }
      await g.up();
      await settle();
      expect(tester.takeException(), isNull, reason: name);
      expect(undo.canUndo, isTrue, reason: '$name did not commit a stroke');
      final rendered = (await tester.runAsync(() async {
        final image = await tm.compositeLayerToImage(key);
        try {
          final raw = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final centerAlpha = <int>{};
          var count = 0;
          for (var y = 0; y < _h; y++) {
            for (var x = 0; x < _w; x++) {
              final p = (y * _w + x) * 4;
              final alpha = raw[p + 3];
              if (alpha != 0) count++;
              if (x >= 90 && x < 130 && y >= 90 && y < 110) {
                centerAlpha.add(alpha);
              }
            }
          }
          return (count, centerAlpha);
        } finally {
          image.dispose();
        }
      }))!;
      expect(rendered.$1, greaterThan(0), reason: name);
      if (id == 'Tone0011') {
        expect(rendered.$2, containsAll([0, 255]));
        expect(rendered.$2.any((a) => a > 0 && a < 255), isTrue);
      } else if (id == 'Tone0065') {
        expect(rendered.$2, unorderedEquals([0, 255]));
      } else if (id == 'Stamp0025' || id == 'Stamp0026') {
        expect(rendered.$2.any((a) => a > 0), isTrue, reason: name);
      }
      undo.undo();
      undo.clear();
      await tester.pump();
    }
  });
}
