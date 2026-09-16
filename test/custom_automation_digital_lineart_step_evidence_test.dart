import 'dart:typed_data';

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
      (_) async => '${Directory.systemTemp.path}/niarim_digital_lineart_step_evidence',
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('digital lineart preset preserves visible pixels at each generated step',
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
    for (var y = 8; y < 88; y++) {
      for (var x = 8; x < 88; x++) {
        final i = (y * 256 + x) * 4;
        var shade = 20 + ((x - 8) * 225 ~/ 79);
        if ((x > 26 && x < 36) || (y > 45 && y < 55)) shade = 18;
        if (x > 58 && x < 78 && y > 22 && y < 42) shade = 235;
        tile[i] = shade;
        tile[i + 1] = shade;
        tile[i + 2] = shade;
        tile[i + 3] = 255;
      }
    }
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
    final autoPixels = _layerPixels(projects, projectId, sceneId, frameIndex, autoLayerId);
    final autoVisible = _visiblePixels(autoPixels);
    // ignore: avoid_print
    print('DIGITAL_LINEART_STEP auto_lineart_visible_pixels=$autoVisible');
    expect(autoVisible, greaterThan(20), reason: 'Auto Lineart itself must produce visible pixels before Ink Pool runs');

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
    final inkPixels = _layerPixels(projects, projectId, sceneId, frameIndex, inkLayerId);
    final inkVisible = _visiblePixels(inkPixels);
    // ignore: avoid_print
    print('DIGITAL_LINEART_STEP ink_pool_visible_pixels=$inkVisible');
    expect(inkVisible, greaterThan(20), reason: 'Ink Pool must preserve visible output when fed the generated Auto Lineart layer');
  });
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
