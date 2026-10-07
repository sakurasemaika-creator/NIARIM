import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/custom_automation_executor.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/custom_automation_builtin_presets.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _size = 96;

/// The official 「線画色トレス」 recipe, run on the line art: each line takes
/// a deeper tone of the colour painted beside it (dark red over red, dark
/// blue over blue), on a layer clipped to the line art, so nothing off the
/// lines changes and the line's own black is never sampled.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lines take a deeper tone of the colours beside them', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ProjectService();
    final project = await service.createProject(
      name: 'trace',
      fps: 1,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: _size,
      exportHeight: _size,
    );
    const sceneId = 'Scene0001';
    final lineId = service.layersOf(project.id, sceneId, 0).single.id;
    final tm = service.tileManagerOf(project.id);
    final w = tm.canvasWidth, h = tm.canvasHeight;
    // The fills beneath: red on the left, blue on the right.
    final fill = service.addLayer(
      projectId: project.id,
      sceneId: sceneId,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'fill',
      insertIndex: 1,
    );
    final colours = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        colours.setAll(
          (y * w + x) * 4,
          x < w ~/ 2 ? const [220, 60, 60, 255] : const [60, 90, 220, 255],
        );
      }
    }
    tm.replaceLayerPixels(
      service.tileKeyFor(project.id, sceneId, 0, fill.id),
      colours,
    );
    // Black line art: a horizontal line across both colours and a
    // vertical one inside the red.
    final lines = Uint8List(w * h * 4);
    void dot(int x, int y) => lines.setAll((y * w + x) * 4, [0, 0, 0, 255]);
    for (var x = 4; x < w - 4; x++) {
      for (var t = -1; t <= 1; t++) {
        dot(x, h ~/ 2 + t);
      }
    }
    for (var y = 8; y < h - 8; y++) {
      for (var t = -1; t <= 1; t++) {
        dot(w ~/ 4 + t, y);
      }
    }
    tm.replaceLayerPixels(
      service.tileKeyFor(project.id, sceneId, 0, lineId),
      lines,
    );

    Future<Uint8List> visible() async {
      final image = await LayerCompositor.composite(
        tm,
        service.layersOf(project.id, sceneId, 0),
        (l) => service.tileKeyFor(project.id, sceneId, 0, l.id),
        w,
        h,
        paperColor: 0xFFFFFFFF,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      Directory('build/lineart-color-trace').createSync(recursive: true);
      File(
        'build/lineart-color-trace/${service.layersOf(project.id, sceneId, 0).length == 2 ? 'before' : 'after'}.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
      return data!.buffer.asUint8List();
    }

    final before = await visible();
    final result = await CustomAutomationExecutor.executeCanvas(
      automation: CustomAutomationBuiltinPresets.all().singleWhere(
        (p) => p.id == 'builtin_lineart_color_trace',
      ),
      scope: CustomAutomationExecutionScope.currentFrame,
      projectService: service,
      projectId: project.id,
      sceneId: sceneId,
      currentFrame: 0,
      currentLayerId: lineId,
      handleCanvasStateCommand: (_, _) async {},
    );
    final layers = service.layersOf(project.id, sceneId, 0);
    expect(layers.map((l) => l.id), [result, lineId, fill.id]);
    expect(layers.first.hasClipping, isTrue);
    final after = await visible();

    List<int> at(Uint8List d, int x, int y) =>
        d.sublist((y * w + x) * 4, (y * w + x) * 4 + 3);
    // On the horizontal line over the red: a dark red.
    final overRed = at(after, w ~/ 8, h ~/ 2);
    expect(overRed[0], greaterThan(overRed[1] + 20), reason: '$overRed');
    expect(overRed[0], greaterThan(overRed[2] + 20));
    expect(overRed[0], lessThan(220), reason: 'deeper than the fill');
    // Over the blue: a dark blue.
    final overBlue = at(after, w * 7 ~/ 8, h ~/ 2);
    expect(overBlue[2], greaterThan(overBlue[0] + 20), reason: '$overBlue');
    expect(overBlue[2], lessThan(220));
    // Not black any more, and nothing off the lines changed.
    expect(overRed.reduce((a, b) => a + b), greaterThan(60));
    var changedOff = 0;
    for (var p = 0; p < w * h; p++) {
      if (lines[p * 4 + 3] != 0) continue;
      for (var c = 0; c < 3; c++) {
        if (after[p * 4 + c] != before[p * 4 + c]) {
          changedOff++;
          break;
        }
      }
    }
    expect(changedOff, 0, reason: 'clipped to the line art');
    service.dispose();
  });
}
