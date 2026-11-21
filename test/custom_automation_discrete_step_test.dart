import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'repeated discrete filter actions are preserved in recording order',
    () async {
      final service = CustomAutomationService();
      await service.init();
      service.beginDraft(
        name: 'digital lineart',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: 0,
      );

      service.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.filter',
        label: '自動線画',
        args: const {
          'filter': {'id': 'Filter0023'},
        },
        recordedFrame: 0,
      );
      service.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.filter',
        label: '墨溜まり',
        args: const {
          'filter': {'id': 'Filter0021'},
        },
        recordedFrame: 0,
      );

      expect(service.draft!.steps, hasLength(2));
      expect(service.draft!.steps[0].label, '自動線画');
      expect(service.draft!.steps[1].label, '墨溜まり');
    },
  );

  test(
    'continuous brush-size changes still coalesce to the latest value',
    () async {
      final service = CustomAutomationService();
      await service.init();
      service.beginDraft(
        name: 'brush',
        surface: CustomAutomationSurface.canvas,
        recordingStartFrame: 0,
      );

      service.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.brushSize',
        label: 'Size',
        args: const {'value': 4.0},
        recordedFrame: 0,
      );
      service.recordStep(
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.brushSize',
        label: 'Size',
        args: const {'value': 8.0},
        recordedFrame: 0,
      );

      expect(service.draft!.steps, hasLength(1));
      expect(service.draft!.steps.single.args['value'], 8.0);
    },
  );
}
