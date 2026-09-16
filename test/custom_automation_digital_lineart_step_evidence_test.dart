import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/custom_automation_filter_runner.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      pathProviderChannel,
      (_) async =>
          '${Directory.systemTemp.path}/niarim_digital_lineart_step_evidence',
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets(
    'digital lineart preset preserves visible pixels at each generated step',
    (tester) async {
      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(
          providers: providers!,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(),
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(SizedBox));
      final projects = context.read<ProjectService>();
      final project = (await tester.runAsync(
        () => projects.createProject(
          name: 'digital-lineart-step-evidence',
          fps: 24,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 96,
          exportHeight: 96,
        ),
      ))!;
      final projectId = project.id;
      final sceneId = projects.scenesOf(projectId).first.id;
      const frameIndex = 0;
      final sourceLayerId = projects
          .layersOf(projectId, sceneId, frameIndex)
          .firstWhere((layer) => layer.type == model.LayerType.normal)
          .id;
      final tm = projects.tileManagerOf(projectId);
      final sourceKey =
          projects.tileKeyFor(projectId, sceneId, frameIndex, sourceLayerId);
      final tile = tm.getOrCreateTile(sourceKey, 0, 0);
      tile.fillRange(0, tile.length, 0);

      // Production-like rough: opaque dark strokes on a transparent drawing
      // layer. The Auto Lineart engine intentionally treats alpha as foreground
      // for this common canvas case.
      void paintDisc(int cx, int cy, int radius) {
        for (var y = cy - radius; y <= cy + radius; y++) {
          if (y < 0 || y >= 96) continue;
          for (var x = cx - radius; x <= cx + radius; x++) {
            if (x < 0 || x >= 96) continue;
            final dx = x - cx;
            final dy = y - cy;
            if (dx * dx + dy * dy > radius * radius) continue;
            final i = (y * 256 + x) * 4;
            tile[i] = 24;
            tile[i + 1] = 24;
            tile[i + 2] = 24;
            tile[i + 3] = 255;
          }
        }
      }

      void paintStroke(int x0, int y0, int x1, int y1, int radius) {
        final steps = (x1 - x0).abs() + (y1 - y0).abs();
        for (var step = 0; step <= steps; step++) {
          final t = steps == 0 ? 0.0 : step / steps;
          paintDisc(
            (x0 + (x1 - x0) * t).round(),
            (y0 + (y1 - y0) * t).round(),
            radius,
          );
        }
      }

      paintStroke(14, 20, 78, 72, 4);
      paintStroke(18, 70, 76, 26, 4);
      paintStroke(46, 14, 46, 82, 3);
      tm.invalidateTile(sourceKey, 0, 0);

      const autoLineart = FilterDef(
        id: 'Filter0023',
        name: '自動線画',
        kind: FilterKind.autoLineart,
      );
      const inkPool = FilterDef(
        id: 'Filter0021',
        name: '墨溜まり',
        kind: FilterKind.inkPool,
      );

      final autoLayerId = (await tester.runAsync(
        () => CustomAutomationFilterRunner.apply(
          projectService: projects,
          projectId: projectId,
          sceneId: sceneId,
          frameIndex: frameIndex,
          sourceLayerId: sourceLayerId,
          filter: autoLineart,
        ),
      ))!;
      final autoPixels =
          _layerPixels(projects, projectId, sceneId, frameIndex, autoLayerId);
      final autoVisible = _visiblePixels(autoPixels);
      // ignore: avoid_print
      print('DIGITAL_LINEART_STEP auto_lineart_visible_pixels=$autoVisible');
      expect(
        autoVisible,
        greaterThan(20),
        reason:
            'Auto Lineart must produce visible pixels from a transparent rough-line layer',
      );

      final inkLayerId = (await tester.runAsync(
        () => CustomAutomationFilterRunner.apply(
          projectService: projects,
          projectId: projectId,
          sceneId: sceneId,
          frameIndex: frameIndex,
          sourceLayerId: autoLayerId,
          filter: inkPool,
        ),
      ))!;
      final inkPixels =
          _layerPixels(projects, projectId, sceneId, frameIndex, inkLayerId);
      final inkVisible = _visiblePixels(inkPixels);
      // ignore: avoid_print
      print('DIGITAL_LINEART_STEP ink_pool_visible_pixels=$inkVisible');
      expect(
        inkVisible,
        greaterThan(20),
        reason:
            'Ink Pool must preserve visible output when fed the generated Auto Lineart layer',
      );
    },
  );
}

Uint8List _layerPixels(
  ProjectService projects,
  String projectId,
  String sceneId,
  int frameIndex,
  String layerId,
) {
  final tm = projects.tileManagerOf(projectId);
  final key = projects.tileKeyFor(projectId, sceneId, frameIndex, layerId);
  final snapshot = Uint8List(tm.canvasWidth * tm.canvasHeight * 4);
  for (var y = 0; y < tm.canvasHeight; y++) {
    for (var x = 0; x < tm.canvasWidth; x++) {
      final tile = tm.getTile(key, x ~/ 256, y ~/ 256);
      if (tile == null) continue;
      final src = ((y % 256) * 256 + (x % 256)) * 4;
      final dst = (y * tm.canvasWidth + x) * 4;
      snapshot.setRange(dst, dst + 4, tile, src);
    }
  }
  return snapshot;
}

int _visiblePixels(Uint8List pixels) {
  var count = 0;
  for (var i = 3; i < pixels.length; i += 4) {
    if (pixels[i] != 0) count++;
  }
  return count;
}
