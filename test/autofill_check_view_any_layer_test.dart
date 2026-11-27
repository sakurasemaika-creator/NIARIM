// 自動塗り確認表示（パーツ分け・シルエット）は、どのレイヤーを選んでいても、
// すべての自動塗りレイヤーを確認の色で出す。
//
// 実際に使ってみたとき（2026-11-27）、選んでいる自動塗りレイヤーと、それより
// 上の自動塗りレイヤーは元の色のままだった（下のレイヤーだけを確認の色で
// 合成し、選んだレイヤーと上のレイヤーを普通の色で重ねていた）。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/autofill_engine.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/screens/canvas/canvas_screen.dart' show DrawingTool;
import 'package:niarim/screens/canvas/widgets/canvas_area.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/project_storage.dart';
import 'helpers/pump_real_async.dart';

const _w = 64;
const _h = 48;

void main() {
  useTemporaryProjectStorage();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('every autofill layer takes its check colour, whatever is '
      'selected', (tester) async {
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
        name: 'autofill-check',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: _w,
        exportHeight: _h,
      ),
    ))!;
    final sceneId = ps.scenesOf(project.id).first.id;
    final tm = ps.tileManagerOf(project.id);
    Uint8List half({required bool left, required List<int> rgb}) {
      final out = Uint8List(_w * _h * 4);
      for (var y = 0; y < _h; y++) {
        for (var x = 0; x < _w; x++) {
          if ((x < _w ~/ 2) != left) continue;
          out.setAll((y * _w + x) * 4, [...rgb, 255]);
        }
      }
      return out;
    }

    // From the bottom: the first layer (empty), the right fill, the left
    // fill, the line art on top.
    final bottom = ps.layersOf(project.id, sceneId, 0).first;
    Layer add(LayerType type, String name) => ps.addLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      type: type,
      name: name,
    );
    final right = add(LayerType.autoFill, 'right');
    final left = add(LayerType.autoFill, 'left');
    final line = add(LayerType.normal, 'line');
    tm.replaceLayerPixels(
      ps.tileKeyFor(project.id, sceneId, 0, right.id),
      half(left: false, rgb: [30, 60, 220]),
    );
    tm.replaceLayerPixels(
      ps.tileKeyFor(project.id, sceneId, 0, left.id),
      half(left: true, rgb: [220, 40, 40]),
    );
    final order = ps.layersOf(project.id, sceneId, 0).map((l) => l.id);
    expect(order, [line.id, left.id, right.id, bottom.id]);

    Widget canvas(String layerId, AutofillCheckMode mode) => MultiProvider(
      providers: providers,
      child: MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: boundary,
            child: CanvasArea(
              key: ValueKey('$layerId-$mode'),
              project: ps.projects.firstWhere((p) => p.id == project.id),
              currentLayerId: layerId,
              currentTool: DrawingTool.pen,
              currentFrame: 0,
              sceneId: sceneId,
              autofillCheckMode: mode,
            ),
          ),
        ),
      ),
    );

    Future<(int, int)> leftAndRight() async {
      final result = await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final rect = tester.getRect(find.byType(CanvasArea));
        final scale = (rect.width / _w) < (rect.height / _h)
            ? rect.width / _w
            : rect.height / _h;
        final drawing = Rect.fromCenter(
          center: rect.center,
          width: _w * scale,
          height: _h * scale,
        );
        int at(double fx) {
          final x = (drawing.left + drawing.width * fx).round();
          final y = drawing.center.dy.round();
          final i = (y * image.width + x) * 4;
          final b = data!.buffer.asUint8List();
          return 0xFF000000 | (b[i] << 16) | (b[i + 1] << 8) | b[i + 2];
        }

        final out = (at(0.25), at(0.75));
        image.dispose();
        return out;
      });
      return result!;
    }

    for (final mode in [
      AutofillCheckMode.partSeparation,
      AutofillCheckMode.silhouette,
    ]) {
      // Numbered from the bottom: the right fill is part 0, the left part 1.
      final expected = (
        autofillCheckColor(mode, 1),
        autofillCheckColor(mode, 0),
      );
      for (final selected in [line, left, right, bottom]) {
        await tester.pumpWidget(canvas(selected.id, mode));
        await pumpRealAsync(tester, const Duration(milliseconds: 600));
        await pumpRealAsync(tester, const Duration(milliseconds: 300));
        expect(
          await leftAndRight(),
          expected,
          reason: '$mode with ${selected.name} selected',
        );
      }
    }

    // The normal view keeps the layers' own colours.
    await tester.pumpWidget(canvas(left.id, AutofillCheckMode.normal));
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(await leftAndRight(), (0xFFDC2828, 0xFF1E3CDC));
  });
}
