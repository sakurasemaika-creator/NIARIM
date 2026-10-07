import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/custom_automation_executor.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/custom_automation_builtin_presets.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// An in-place filter recipe: replaces the selected layer's pixels without
// creating layers, so it isolates selection/frame handling in the executor.
final _inPlaceBlur = CustomAutomation(
  id: 'test_in_place_blur',
  name: 'blur',
  recordingStartFrame: 0,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  steps: [
    CustomAutomationStep(
      id: 'test_in_place_blur_1',
      surface: CustomAutomationSurface.canvas,
      command: 'canvas.filterApply',
      label: 'blur',
      args: {
        'filter': const FilterDef(
          id: 'Filter0001',
          name: 'blur',
          kind: FilterKind.gaussianBlur,
          strength: 8,
        ).toJson(),
      },
      recordedFrame: 0,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProjectService service;
  late String projectId;
  const sceneId = 'Scene0001';
  late String sourceId;
  late Uint8List original;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = ProjectService();
    final project = await service.createProject(
      name: 'recipe',
      fps: 2,
      durationSeconds: 1,
      backgroundColor: 0,
      exportWidth: 32,
      exportHeight: 32,
    );
    projectId = project.id;
    sourceId = service.layersOf(projectId, sceneId, 0).single.id;
    original = Uint8List(32 * 32 * 4);
    for (var y = 0; y < 32; y++) {
      for (var x = 0; x < 32; x++) {
        final offset = (y * 32 + x) * 4;
        original[offset] = 180;
        original[offset + 1] = 80;
        original[offset + 2] = 50;
        original[offset + 3] = x >= 8 && x < 24 && y >= 8 && y < 24 ? 255 : 0;
      }
    }
    for (var frame = 0; frame < 2; frame++) {
      service
          .tileManagerOf(projectId)
          .replaceLayerPixels(
            service.tileKeyFor(projectId, sceneId, frame, sourceId),
            original,
          );
    }
  });

  Future<Uint8List> pixels(String id, [int frame = 0]) async {
    final image = await service
        .tileManagerOf(projectId)
        .compositeLayerToImage(
          service.tileKeyFor(projectId, sceneId, frame, id),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  /// A green layer painted beneath the source (the line art), as the
  /// colour trace samples the colours under the lines.
  Future<String> addFillBelow() async {
    final fill = service.addLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: 0,
      type: LayerType.normal,
      name: 'fill',
      insertIndex:
          service
              .layersOf(projectId, sceneId, 0)
              .indexWhere((l) => l.id == sourceId) +
          1,
    );
    final green = Uint8List(32 * 32 * 4);
    for (var i = 0; i < green.length; i += 4) {
      green.setAll(i, const [40, 160, 90, 255]);
    }
    service
        .tileManagerOf(projectId)
        .replaceLayerPixels(
          service.tileKeyFor(projectId, sceneId, 0, fill.id),
          green,
        );
    return fill.id;
  }

  Future<String?> execute(CustomAutomation item) =>
      CustomAutomationExecutor.executeCanvas(
        automation: item,
        scope: CustomAutomationExecutionScope.currentFrame,
        projectService: service,
        projectId: projectId,
        sceneId: sceneId,
        currentFrame: 0,
        currentLayerId: sourceId,
        handleCanvasStateCommand: (_, _) async =>
            fail('Unexpected UI-only command'),
      );

  test(
    'color trace recolours the line art with the colours beneath it',
    () async {
      final fill = await addFillBelow();
      final before = await pixels(sourceId);
      final result = await execute(
        CustomAutomationBuiltinPresets.all().singleWhere(
          (item) => item.id == 'builtin_lineart_color_trace',
        ),
      );
      expect(result, isNot(sourceId));
      // Directly above the line art, clipped to it.
      final layers = service.layersOf(projectId, sceneId, 0);
      expect(layers.map((l) => l.id), [result, sourceId, fill]);
      expect(layers.first.hasClipping, isTrue);
      expect(await pixels(sourceId), before);
      final output = await pixels(result!);
      expect(output.where((byte) => byte != 0), isNotEmpty);
      // It takes the fill's green, deepened, not the line's own orange.
      const centre = (16 * 32 + 16) * 4;
      expect(output[centre + 3], greaterThan(0));
      expect(output[centre + 1], greaterThan(output[centre]));
      expect(output[centre + 1], greaterThan(output[centre + 2]));
      final straightGreen = output[centre + 1] * 255 / output[centre + 3];
      expect(straightGreen, lessThan(160), reason: 'darker than the fill');
    },
  );

  test(
    'color trace Undo removes its output without empty history entries and Redo preserves pixels',
    () async {
      final fill = await addFillBelow();
      final undo = UndoManager();
      service.setUndoManager(undo);
      addTearDown(undo.dispose);
      final earlier = service.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 0,
        type: LayerType.normal,
        name: 'earlier edit',
      );
      final sourceBefore = await pixels(sourceId);
      final result = await execute(
        CustomAutomationBuiltinPresets.all().singleWhere(
          (item) => item.id == 'builtin_lineart_color_trace',
        ),
      );
      final output = await pixels(result!);
      expect(output.where((byte) => byte != 0), isNotEmpty);

      for (var cycle = 0; cycle < 2; cycle++) {
        undo.undo();
        expect(
          service.layersOf(projectId, sceneId, 0).map((layer) => layer.id),
          [earlier.id, sourceId, fill],
          reason:
              'One Undo must remove the recipe output, not a merged-away duplicate',
        );
        expect(undo.undoCount, 1);
        expect(await pixels(sourceId), sourceBefore);
        undo.redo();
        expect(
          service.layersOf(projectId, sceneId, 0).map((layer) => layer.id),
          [earlier.id, result, sourceId, fill],
        );
        expect(
          service.layersOf(projectId, sceneId, 0)[1].hasClipping,
          isTrue,
          reason: 'still clipped after Redo',
        );
        expect(await pixels(result), output);
        expect(undo.redoCount, 0);
      }

      undo.undo();
      undo.undo();
      expect(service.layersOf(projectId, sceneId, 0).map((layer) => layer.id), [
        sourceId,
        fill,
      ], reason: 'The edit preceding the recipe must remain undoable');
    },
  );

  test(
    'color trace Redo never restores merged duplicates from another project',
    () async {
      final otherProject = await service.createProject(
        name: 'old history',
        fps: 1,
        durationSeconds: 1,
        backgroundColor: 0,
        exportWidth: 32,
        exportHeight: 32,
      );
      for (var i = 0; i < 3; i++) {
        final stale = service.addLayer(
          projectId: otherProject.id,
          sceneId: sceneId,
          frameIndex: 0,
          type: LayerType.normal,
          name: 'unrelated removed layer',
        );
        service.removeLayer(
          projectId: otherProject.id,
          sceneId: sceneId,
          frameIndex: 0,
          layerId: stale.id,
        );
      }
      final undo = UndoManager();
      service.setUndoManager(undo);
      addTearDown(undo.dispose);
      final result = await execute(
        CustomAutomationBuiltinPresets.all().singleWhere(
          (item) => item.id == 'builtin_lineart_color_trace',
        ),
      );
      final output = await pixels(result!);
      undo.undo();
      expect(service.layersOf(projectId, sceneId, 0).map((l) => l.id), [
        sourceId,
      ]);
      undo.redo();
      expect(service.layersOf(projectId, sceneId, 0).map((l) => l.id), [
        result,
        sourceId,
      ]);
      expect(await pixels(result), output);
    },
  );

  for (final startWithComposite in [false, true]) {
    test(
      '${startWithComposite ? 'unbalanced' : 'standalone'} duplication retains its Undo and Redo pixels',
      () async {
        final undo = UndoManager();
        service.setUndoManager(undo);
        addTearDown(undo.dispose);
        final recipe = CustomAutomationBuiltinPresets.all().singleWhere(
          (item) => item.id == 'builtin_lineart_color_trace',
        );
        final result = await execute(
          recipe.copyWith(
            steps: [
              if (startWithComposite) recipe.steps.first,
              recipe.steps[2],
            ],
          ),
        );
        final after = service
            .layersOf(projectId, sceneId, 0)
            .map((l) => l.id)
            .toList();
        expect(after, hasLength(startWithComposite ? 3 : 2));
        expect(after.first, result);
        final output = await pixels(result!);
        undo.undo();
        expect(service.layersOf(projectId, sceneId, 0).map((l) => l.id), [
          sourceId,
        ]);
        undo.redo();
        expect(service.layersOf(projectId, sceneId, 0).map((l) => l.id), after);
        expect(await pixels(result), output);
      },
    );
  }

  test(
    'failed recipes retain Undo and Redo for their partial output',
    () async {
      final undo = UndoManager();
      service.setUndoManager(undo);
      addTearDown(undo.dispose);
      final recipe = CustomAutomationBuiltinPresets.all().singleWhere(
        (item) => item.id == 'builtin_lineart_color_trace',
      );
      await expectLater(
        execute(
          recipe.copyWith(
            steps: [
              recipe.steps.first,
              recipe.steps[2],
              const CustomAutomationStep(
                id: 'unsupported',
                surface: CustomAutomationSurface.canvas,
                command: 'canvas.unsupported',
                label: 'failure',
                recordedFrame: 0,
              ),
            ],
          ),
        ),
        throwsA(isA<CustomAutomationExecutionException>()),
      );
      final after = service
          .layersOf(projectId, sceneId, 0)
          .map((l) => l.id)
          .toList();
      expect(after, hasLength(3));
      final output = await pixels(after.first);
      undo.undo();
      expect(service.layersOf(projectId, sceneId, 0).map((l) => l.id), [
        sourceId,
      ]);
      undo.redo();
      expect(service.layersOf(projectId, sceneId, 0).map((l) => l.id), after);
      expect(await pixels(after.first), output);
    },
  );

  test(
    'analog extraction runs brightness-to-alpha on the filtered source',
    () async {
      final result = await execute(
        CustomAutomationBuiltinPresets.all().singleWhere(
          (item) => item.id == 'builtin_analog_lineart_extract',
        ),
      );
      expect(result, sourceId);
      final output = await pixels(sourceId);
      expect(output[0 + 3], 0);
      expect(output[(16 * 32 + 16) * 4], 0);
      expect(output[(16 * 32 + 16) * 4 + 3], 255);
    },
  );

  test(
    'legacy and semantic filter steps replay together on generated output',
    () async {
      final base = CustomAutomationBuiltinPresets.all().first;
      final item = base.copyWith(
        steps: [
          CustomAutomationStep(
            id: 'legacy',
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.filter',
            label: 'outline',
            recordedFrame: 0,
            args: {
              'filter': const FilterDef(
                id: 'outline',
                name: 'outline',
                kind: FilterKind.outline,
              ).toJson(),
            },
          ),
          CustomAutomationStep(
            id: 'modern',
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.filterApply',
            label: 'threshold',
            recordedFrame: 0,
            args: {
              'filter': const FilterDef(
                id: 'threshold',
                name: 'threshold',
                kind: FilterKind.threshold,
              ).toJson(),
            },
          ),
        ],
      );
      final before = await pixels(sourceId);
      final result = await execute(item);
      expect(result, isNot(sourceId));
      expect(service.layersOf(projectId, sceneId, 0), hasLength(2));
      expect(await pixels(sourceId), before);
    },
  );
  test(
    'specified frames retain the selected source anchor across generated layers',
    () async {
      final chosen = service.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 0,
        type: LayerType.normal,
        name: 'chosen',
      );
      final corresponding = service.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 1,
        type: LayerType.normal,
        name: 'chosen',
      );
      for (final pair in [(0, chosen.id), (1, corresponding.id)]) {
        service
            .tileManagerOf(projectId)
            .replaceLayerPixels(
              service.tileKeyFor(projectId, sceneId, pair.$1, pair.$2),
              original,
            );
      }
      final base = CustomAutomationBuiltinPresets.all().first;
      final item = base.copyWith(
        steps: [
          CustomAutomationStep(
            id: 'outline',
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.filterApply',
            label: 'outline',
            recordedFrame: 0,
            args: {
              'filter': const FilterDef(
                id: 'outline',
                name: 'outline',
                kind: FilterKind.outline,
              ).toJson(),
            },
          ),
        ],
      );
      final selected = await CustomAutomationExecutor.executeCanvas(
        automation: item,
        scope: CustomAutomationExecutionScope.specifiedFrames,
        targetFrames: [0, 1],
        projectService: service,
        projectId: projectId,
        sceneId: sceneId,
        currentFrame: 0,
        currentLayerId: chosen.id,
        handleCanvasStateCommand: (_, _) async =>
            fail('Unexpected UI-only command'),
      );
      final current = service.layersOf(projectId, sceneId, 0);
      final other = service.layersOf(projectId, sceneId, 1);
      expect(current, hasLength(3));
      expect(other, hasLength(3));
      expect(current[1].id, selected);
      expect(other[1].name, contains('chosen'));
      expect(await pixels(corresponding.id, 1), await pixels(chosen.id));
    },
  );

  for (final type in [
    LayerType.autoFill,
    LayerType.autoFillLineart,
    LayerType.common,
    LayerType.text,
  ]) {
    test(
      'filter replay preserves the selected ${type.name} layer target',
      () async {
        final normalId = sourceId;
        final beforeNormal = await pixels(normalId);
        final chosen = service.addLayer(
          projectId: projectId,
          sceneId: sceneId,
          frameIndex: 0,
          type: type,
          name: 'selected',
        );
        service
            .tileManagerOf(projectId)
            .replaceLayerPixels(
              service.tileKeyFor(projectId, sceneId, 0, chosen.id),
              original,
            );
        sourceId = chosen.id;
        final result = await execute(_inPlaceBlur);
        expect(result, chosen.id);
        expect(await pixels(normalId), beforeNormal);
        expect(await pixels(chosen.id), isNot(beforeNormal));
      },
    );
  }
  test(
    'generated filters replay below their source and preserve neighbors',
    () async {
      final upper = service.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 0,
        type: LayerType.normal,
        name: 'upper',
      );
      final item = CustomAutomationBuiltinPresets.all().first.copyWith(
        steps: [
          CustomAutomationStep(
            id: 'outline',
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.filterApply',
            label: 'outline',
            recordedFrame: 0,
            args: {
              'filter': const FilterDef(
                id: 'outline',
                name: 'outline',
                kind: FilterKind.outline,
              ).toJson(),
            },
          ),
        ],
      );
      final generated = await execute(item);
      expect(service.layersOf(projectId, sceneId, 0).map((l) => l.id), [
        upper.id,
        sourceId,
        generated,
      ]);
    },
  );
  test(
    'color trace with frame navigation executes the subsequent filter on the new frame',
    () async {
      final secondBefore = await pixels(sourceId, 1);
      final recipe = CustomAutomationBuiltinPresets.all().singleWhere(
        (p) => p.id == 'builtin_lineart_color_trace',
      );
      final item = recipe.copyWith(
        steps: [
          ...recipe.steps,
          const CustomAutomationStep(
            id: 'next',
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.selectFrame',
            label: 'next',
            changesFrame: true,
            args: {'frame': 1},
            recordedFrame: 1,
          ),
          ..._inPlaceBlur.steps,
        ],
      );
      var selectedFrame = 0;
      final result = await CustomAutomationExecutor.executeCanvas(
        automation: item,
        scope: CustomAutomationExecutionScope.currentFrame,
        projectService: service,
        projectId: projectId,
        sceneId: sceneId,
        currentFrame: 0,
        currentLayerId: sourceId,
        handleCanvasStateCommand: (command, args) async {
          expect(command, 'canvas.selectFrame');
          selectedFrame = args['frame'] as int;
        },
      );
      expect(selectedFrame, 1);
      expect(result, sourceId);
      expect(await pixels(sourceId, 1), isNot(secondBefore));
      expect(service.layersOf(projectId, sceneId, 0), hasLength(2));
    },
  );
}
