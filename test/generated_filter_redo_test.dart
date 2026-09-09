import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/recorded_filter_apply_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final kind in [FilterKind.outline, FilterKind.inkPool, FilterKind.autoLineart]) {
    test('recorded ${kind.name} creates at absolute top and keeps pixels through Redo', () async {
      final directory = Directory.systemTemp.createTempSync('niarim-filter-redo-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        directory.deleteSync(recursive: true);
      });
      SharedPreferences.setMockInitialValues({});
      final service = ProjectService();
      final undo = UndoManager();
      service.setUndoManager(undo);
      addTearDown(service.dispose);
      addTearDown(undo.dispose);
      await service.init();
      final project = await service.createProject(
        name: 'filter redo',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 64,
      );
      final scene = service.scenesOf(project.id).first;
      final source = service.layersOf(project.id, scene.id, 0).single;
      final below = service.addLayer(
        projectId: project.id, sceneId: scene.id, frameIndex: 0,
        type: LayerType.normal, name: 'below',
      );
      final above = service.addLayer(
        projectId: project.id, sceneId: scene.id, frameIndex: 0,
        type: LayerType.normal, name: 'above', insertIndex: 2,
      );
      final tm = service.tileManagerOf(project.id);
      addTearDown(tm.dispose);
      final pixels = Uint8List(tm.canvasWidth * tm.canvasHeight * 4);
      for (var y = 29; y <= 35; y++) {
        for (var x = 8; x <= 56; x++) {
          pixels[(y * tm.canvasWidth + x) * 4 + 3] = 255;
        }
      }
      tm.replaceLayerPixels(service.tileKeyFor(project.id, scene.id, 0, source.id), pixels);
      undo.clear();

      final generatedId = await RecordedFilterApplyService.apply(
        projectService: service, projectId: project.id, sceneId: scene.id,
        frameIndex: 0, layerId: source.id,
        filterSnapshot: FilterDef(id: 'regression', name: kind.name, kind: kind).toJson(),
      );
      expect(generatedId, isNotNull);
      List<String> order() => service.layersOf(project.id, scene.id, 0).map((layer) => layer.id).toList();
      final expectedOrder = [generatedId!, below.id, source.id, above.id];
      expect(order(), expectedOrder, reason: 'generated layer must be absolute front/top');
      expect(undo.undoCount, 1);
      Future<Uint8List> generatedPixels() async {
        final image = await tm.compositeLayerToImage(service.tileKeyFor(project.id, scene.id, 0, generatedId));
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          return bytes!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      }
      final before = await generatedPixels();
      expect(Iterable<int>.generate(before.length ~/ 4).any((i) => before[i * 4 + 3] > 0), isTrue);
      for (var cycle = 0; cycle < 2; cycle++) {
        undo.undo();
        expect(order(), [below.id, source.id, above.id]);
        undo.redo();
        expect(order(), expectedOrder);
        expect(await generatedPixels(), orderedEquals(before));
      }
    });
  }
}
