import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('single-frame canvas-only automation exposes current/all-frame scope', () {
    final item = CustomAutomation(
      id: 'a',
      name: 'same frame',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      steps: const [
        CustomAutomationStep(
          id: '1',
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.tool',
          label: 'tool',
        ),
        CustomAutomationStep(
          id: '2',
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.brushSize',
          label: 'size',
        ),
      ],
    );
    expect(item.supportsFrameScopeChoice, isTrue);
  });

  test('frame navigation disables all-frame scope even for canvas-only recording', () {
    final item = CustomAutomation(
      id: 'a',
      name: 'moves frame',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      steps: const [
        CustomAutomationStep(
          id: '1',
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.selectFrame',
          label: 'frame',
          changesFrame: true,
        ),
      ],
    );
    expect(item.isCanvasOnly, isTrue);
    expect(item.supportsFrameScopeChoice, isFalse);
  });

  test('scene navigation disables all-frame scope', () {
    final item = CustomAutomation(
      id: 'a',
      name: 'moves scene',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      steps: const [
        CustomAutomationStep(
          id: '1',
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.selectScene',
          label: 'scene',
          changesScene: true,
        ),
      ],
    );
    expect(item.supportsFrameScopeChoice, isFalse);
  });

  test('timeline step disables current/all-frame radio choice', () {
    final item = CustomAutomation(
      id: 'a',
      name: 'timeline',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      steps: const [
        CustomAutomationStep(
          id: '1',
          surface: CustomAutomationSurface.timeline,
          command: 'timeline.addFrame',
          label: 'add',
        ),
      ],
    );
    expect(item.supportsFrameScopeChoice, isFalse);
  });

  test('record, reorder, save, export and import round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final service = CustomAutomationService();
    await service.init();
    service.beginDraft(name: 'My action', surface: CustomAutomationSurface.canvas);
    service.recordStep(
      surface: CustomAutomationSurface.canvas,
      command: 'canvas.tool',
      label: 'Pen',
      args: const {'tool': 'pen'},
    );
    service.recordStep(
      surface: CustomAutomationSurface.canvas,
      command: 'canvas.brushSize',
      label: 'Size',
      args: const {'value': 8.0},
    );
    service.stopRecording();
    service.reorderDraftStep(1, 0);
    final saved = await service.saveDraft();
    expect(saved, isNotNull);
    expect(saved!.steps.first.command, 'canvas.brushSize');

    final raw = service.exportJson(saved.id);
    final imported = await service.importJson(raw);
    expect(imported.id, isNot(saved.id));
    expect(imported.name, saved.name);
    expect(imported.steps.length, 2);

    final reloaded = CustomAutomationService();
    await reloaded.init();
    expect(reloaded.items.length, 2);
  });

  test('invalid or future-format automation is rejected', () async {
    SharedPreferences.setMockInitialValues({});
    final service = CustomAutomationService();
    await service.init();
    expect(
      () => service.importJson('{"format":"other","version":1,"steps":[]}'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => service.importJson(
        '{"format":"niarim-custom-automation","version":999,"name":"x","steps":[{}]}',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
