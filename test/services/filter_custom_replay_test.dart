import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/engine/custom_automation_filter_runner.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/recorded_filter_apply_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final legacy in [false, true]) {
    test(
      'prism custom replay preserves pixels and Linear Dodge (legacy=$legacy)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final projects = ProjectService();
        addTearDown(projects.dispose);
        final project = await projects.createProject(
          name: 'custom-prism',
          fps: 1,
          durationSeconds: 1,
          backgroundColor: 0,
          exportWidth: 32,
          exportHeight: 32,
        );
        const scene = 'Scene0001';
        final layer = projects.layersOf(project.id, scene, 0).single;
        final tiles = projects.tileManagerOf(project.id);
        final key = projects.tileKeyFor(project.id, scene, 0, layer.id);
        final source = Uint8List.fromList([
          for (var i = 0; i < 32 * 32; i++) ...[100, 80, 30, 255],
        ]);
        Uint8List? reference;
        for (final id in ['Filter0022', 'custom-prism']) {
          tiles.replaceLayerPixels(key, source);
          final filter = FilterDef(
            id: id,
            name: 'Prism',
            kind: FilterKind.prism,
            prismBlurPx: 3,
            prismDirectionDegrees: 45,
          );
          if (legacy) {
            await RecordedFilterApplyService.apply(
              projectService: projects,
              projectId: project.id,
              sceneId: scene,
              frameIndex: 0,
              layerId: layer.id,
              filterSnapshot: filter.toJson(),
            );
          } else {
            await CustomAutomationFilterRunner.apply(
              projectService: projects,
              projectId: project.id,
              sceneId: scene,
              frameIndex: 0,
              sourceLayerId: layer.id,
              filter: filter,
            );
          }
          expect(
            projects.layersOf(project.id, scene, 0).single.blendMode,
            LayerBlendMode.linearDodge,
          );
          final image = await tiles.compositeLayerToImage(key);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          final pixels = data!.buffer.asUint8List();
          if (reference != null) expect(pixels, orderedEquals(reference));
          reference = Uint8List.fromList(pixels);
        }
      },
    );
  }
}
