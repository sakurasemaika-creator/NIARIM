import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'single-frame canvas-only automation exposes current/all-frame scope',
    () {
      final item = CustomAutomation(
        id: 'a',
        name: 'same frame',
        recordingStartFrame: 3,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        steps: const [
          CustomAutomationStep(
            id: '1',
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.tool',
            label: 'tool',
            recordedFrame: 3,
          ),
          CustomAutomationStep(
            id: '2',
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.brushSize',
            label: 'size',
            recordedFrame: 3,
          ),
        ],
      );
      expect(item.supportsFrameScopeChoice, isTrue);
    },
  );

  test('recording an action on another frame disables all-frame scope', () {
    final item = CustomAutomation(
      id: 'a',
      name: 'cross frame',
      recordingStartFrame: 2,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      steps: const [
        CustomAutomationStep(
          id: '1',
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.tool',
          label: 'tool',
          recordedFrame: 2,
        ),
        CustomAutomationStep(
          id: '2',
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.brushSize',
          label: 'size',
          recordedFrame: 3,
        ),
      ],
    );
    expect(item.supportsFrameScopeChoice, isFalse);
  });

  test(
    'frame-navigation metadata does not hide scope when recorded frame stays the same',
    () {
      final item = CustomAutomation(
        id: 'a',
        name: 'moves frame',
        recordingStartFrame: 3,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        steps: const [
          CustomAutomationStep(
            id: '1',
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.selectFrame',
            label: 'frame',
            changesFrame: true,
            recordedFrame: 3,
          ),
        ],
      );
      expect(item.isCanvasOnly, isTrue);
      expect(item.supportsFrameScopeChoice, isTrue);
    },
  );

  test('timeline step disables current/all-frame radio choice', () {
    final item = CustomAutomation(
      id: 'a',
      name: 'timeline',
      recordingStartFrame: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      steps: const [
        CustomAutomationStep(
          id: '1',
          surface: CustomAutomationSurface.timeline,
          command: 'timeline.addFrame',
          label: 'add',
          recordedFrame: 0,
        ),
      ],
    );
    expect(item.supportsFrameScopeChoice, isFalse);
  });

  test(
    'deleting navigation step cannot hide cross-frame recording context',
    () {
      final remainingAfterDelete = CustomAutomation(
        id: 'a',
        name: 'edited macro',
        recordingStartFrame: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        steps: const [
          CustomAutomationStep(
            id: 'before',
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.tool',
            label: 'Pen',
            recordedFrame: 0,
          ),
          CustomAutomationStep(
            id: 'after',
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.color',
            label: 'Color',
            recordedFrame: 1,
          ),
        ],
      );
      expect(remainingAfterDelete.supportsFrameScopeChoice, isFalse);
    },
  );

  test('recorded frame metadata is sufficient even when draft start frame is absent', () {
    final item = CustomAutomation(
      id: 'a',
      name: 'legacy',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      steps: const [
        CustomAutomationStep(
          id: '1',
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.tool',
          label: 'Pen',
          recordedFrame: 0,
        ),
      ],
    );
    expect(item.supportsFrameScopeChoice, isTrue);
  });

  test(
    'record, coalesce, reorder, save, export and import round-trip',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = CustomAutomationService();
      await service.init();
      final seededItemCount = service.items.length;
      expect(seededItemCount, greaterThan(0));
      service.beginDraft(
        name: 'My action',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: 0,
      );
      service.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.tool',
        label: 'Pen',
        args: const {'tool': 'pen'},
        recordedFrame: 0,
      );
      service.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.brushSize',
        label: 'Size',
        args: const {'value': 7.0},
        recordedFrame: 0,
      );
      service.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.brushSize',
        label: 'Size',
        args: const {'value': 8.0},
        recordedFrame: 0,
      );
      expect(service.draft!.steps.length, 2);
      expect(service.draft!.steps.last.args['value'], 8.0);
      service.stopRecording();
      service.reorderDraftStep(1, 0);
      final saved = await service.saveDraft();
      expect(saved, isNotNull);
      expect(saved!.steps.first.command, 'canvas.brushSize');
      expect(saved.recordingStartFrame, 0);
      expect(saved.supportsFrameScopeChoice, isTrue);

      final raw = service.exportJson(saved.id);
      final imported = await service.importJson(raw);
      expect(imported.id, isNot(saved.id));
      expect(imported.name, saved.name);
      expect(imported.steps.length, 2);
      expect(imported.recordingStartFrame, 0);
      expect(imported.supportsFrameScopeChoice, isTrue);

      final reloaded = CustomAutomationService();
      await reloaded.init();
      expect(reloaded.items.length, seededItemCount + 2);
      expect(reloaded.items.map((item) => item.id), contains(saved.id));
      expect(reloaded.items.map((item) => item.id), contains(imported.id));
    },
  );

  test('invalid, oversized or future-format automation is rejected', () async {
    SharedPreferences.setMockInitialValues({});
    final service = CustomAutomationService();
    await service.init();
    await expectLater(
      service.importJson('{"format":"other","version":1,"steps":[]}'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      service.importJson(
        '{"format":"niarim-custom-automation","version":999,"name":"x","steps":[{}]}',
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      service.importJson('x' * (2 * 1024 * 1024 + 1)),
      throwsA(isA<FormatException>()),
    );
  });
}
