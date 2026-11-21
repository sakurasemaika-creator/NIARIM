import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/custom_automation.dart';

void main() {
  CustomAutomation automation({
    required List<CustomAutomationStep> steps,
    int? recordingStartFrame,
  }) {
    final now = DateTime(2026, 1, 1);
    return CustomAutomation(
      id: 'test',
      name: 'test',
      steps: steps,
      recordingStartFrame: recordingStartFrame,
      createdAt: now,
      updatedAt: now,
    );
  }

  CustomAutomationStep step({
    required String id,
    CustomAutomationSurface surface = CustomAutomationSurface.canvas,
    int? frame,
    bool changesFrame = false,
  }) => CustomAutomationStep(
    id: id,
    surface: surface,
    command: 'canvas.tool',
    label: id,
    recordedFrame: frame,
    changesFrame: changesFrame,
  );

  test(
    'scope choice is allowed when every canvas operation recorded same frame',
    () {
      final item = automation(
        recordingStartFrame: 99,
        steps: [
          step(id: 'a', frame: 4),
          step(id: 'b', frame: 4, changesFrame: true),
          step(id: 'c', frame: 4),
        ],
      );

      expect(item.staysInRecordingStartFrame, isTrue);
      expect(item.supportsFrameScopeChoice, isTrue);
    },
  );

  test('scope choice is rejected when recorded frame numbers differ', () {
    final item = automation(
      steps: [
        step(id: 'a', frame: 4),
        step(id: 'b', frame: 5),
      ],
    );

    expect(item.staysInRecordingStartFrame, isFalse);
    expect(item.supportsFrameScopeChoice, isFalse);
  });

  test('scope choice is rejected when a recorded frame is missing', () {
    final item = automation(
      steps: [
        step(id: 'a', frame: 4),
        step(id: 'b'),
      ],
    );

    expect(item.supportsFrameScopeChoice, isFalse);
  });

  test('scope choice is canvas-only even when frame numbers match', () {
    final item = automation(
      steps: [
        step(id: 'a', frame: 4),
        step(id: 'b', frame: 4, surface: CustomAutomationSurface.timeline),
      ],
    );

    expect(item.staysInRecordingStartFrame, isTrue);
    expect(item.supportsFrameScopeChoice, isFalse);
  });
}
