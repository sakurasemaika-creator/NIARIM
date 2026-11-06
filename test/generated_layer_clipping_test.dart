import 'dart:io';

import 'package:flutter/services.dart' hide UndoManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/recorded_filter_apply_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A filter's new layer (outline and ink pool beneath the source, auto line
/// art above it) fits where it goes: it joins the source's folder, and it
/// never becomes another layer's clipping base: next to a clipped layer it
/// is clipped too, so every clipped layer keeps its base, through Undo and
/// Redo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProjectService service;
  late UndoManager undo;
  late String projectId;
  late String sceneId;

  setUp(() async {
    final directory = Directory.systemTemp.createTempSync('niarim-clip-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      directory.deleteSync(recursive: true);
    });
    SharedPreferences.setMockInitialValues({});
    service = ProjectService();
    undo = UndoManager();
    service.setUndoManager(undo);
    addTearDown(service.dispose);
    addTearDown(undo.dispose);
    await service.init();
    final project = await service.createProject(
      name: 'clip',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 48,
      exportHeight: 48,
    );
    projectId = project.id;
    sceneId = service.scenesOf(projectId).first.id;
  });

  List<Layer> layers() => service.layersOf(projectId, sceneId, 0);
  Layer byId(String id) => layers().firstWhere((l) => l.id == id);
  String? baseOf(String id) =>
      findClipSourceLayerId(layers(), layers().indexWhere((l) => l.id == id));

  /// Gives [id] a filled square so the filters have something to work on.
  void paint(String id) {
    final tm = service.tileManagerOf(projectId);
    final pixels = Uint8List(tm.canvasWidth * tm.canvasHeight * 4);
    for (var y = 16; y < 32; y++) {
      for (var x = 16; x < 32; x++) {
        pixels.setAll((y * tm.canvasWidth + x) * 4, [0, 0, 0, 255]);
      }
    }
    tm.replaceLayerPixels(
      service.tileKeyFor(projectId, sceneId, 0, id),
      pixels,
    );
  }

  void update(Layer layer) => service.updateLayer(
    projectId: projectId,
    sceneId: sceneId,
    frameIndex: 0,
    layer: layer,
  );

  Layer add(String name, {int insertIndex = 0}) => service.addLayer(
    projectId: projectId,
    sceneId: sceneId,
    frameIndex: 0,
    type: LayerType.normal,
    name: name,
    insertIndex: insertIndex,
  );

  Future<String> apply(String sourceId, FilterKind kind) async {
    final id = await RecordedFilterApplyService.apply(
      projectService: service,
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: 0,
      layerId: sourceId,
      filterSnapshot: FilterDef(id: 'f', name: kind.name, kind: kind).toJson(),
    );
    return id!;
  }

  for (final kind in [FilterKind.outline, FilterKind.inkPool]) {
    test(
      '${kind.name} beneath a clipped layer keeps its clipping base',
      () async {
        // Top to bottom: source (clipped) / base.
        final base = layers().single;
        final source = add('source');
        update(byId(source.id).copyWith(hasClipping: true));
        paint(source.id);
        undo.clear();
        expect(baseOf(source.id), base.id);

        final generated = await apply(source.id, kind);
        expect(layers().map((l) => l.id), [source.id, generated, base.id]);
        expect(byId(generated).hasClipping, isTrue);
        expect(baseOf(source.id), base.id, reason: 'still clipped to the base');
        expect(baseOf(generated), base.id);

        undo.undo();
        expect(layers().map((l) => l.id), [source.id, base.id]);
        undo.redo();
        expect(byId(generated).hasClipping, isTrue, reason: 'after Redo');
        expect(baseOf(source.id), base.id);
      },
    );
  }

  test('an unclipped source keeps an unclipped outline', () async {
    final source = layers().single;
    paint(source.id);
    final generated = await apply(source.id, FilterKind.outline);
    expect(byId(generated).hasClipping, isFalse);
  });

  test(
    'auto line art below a clipped layer keeps that layer\'s base',
    () async {
      // Top to bottom: shade (clipped to source) / source.
      final source = layers().single;
      paint(source.id);
      final shade = add('shade');
      update(byId(shade.id).copyWith(hasClipping: true));
      expect(baseOf(shade.id), source.id);

      final generated = await apply(source.id, FilterKind.autoLineart);
      expect(layers().map((l) => l.id), [shade.id, generated, source.id]);
      expect(byId(generated).hasClipping, isTrue);
      expect(baseOf(shade.id), source.id, reason: 'not the new line art');
    },
  );

  test('the new layer joins the source\'s folder', () async {
    final source = layers().single;
    paint(source.id);
    update(byId(source.id).copyWith(parentFolderId: 'folder-1'));
    final generated = await apply(source.id, FilterKind.outline);
    expect(byId(generated).parentFolderId, 'folder-1');
  });
}
