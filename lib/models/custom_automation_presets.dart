import 'custom_automation.dart';
import 'filter_def.dart';

const digitalLineartAutomationPresetId = 'preset_digital_lineart';
const analogLineartAutomationPresetId = 'preset_analog_lineart';
final DateTime _presetTimestamp = DateTime.utc(2026, 1, 1);

List<CustomAutomation> builtInCanvasAutomationPresets() => [
  _preset(
    id: digitalLineartAutomationPresetId,
    name: 'デジタル線画作成',
    steps: const [
      FilterDef(
        id: 'Filter0023',
        name: '自動線画',
        kind: FilterKind.autoLineart,
      ),
      FilterDef(
        id: 'Filter0021',
        name: '墨溜まり',
        kind: FilterKind.inkPool,
      ),
    ],
  ),
  _preset(
    id: analogLineartAutomationPresetId,
    name: 'アナログ線画作成',
    steps: const [
      FilterDef(
        id: 'Filter0014',
        name: '二値化',
        kind: FilterKind.threshold,
      ),
    ],
    appendBrightnessToAlpha: true,
  ),
];

CustomAutomation _preset({
  required String id,
  required String name,
  required List<FilterDef> steps,
  bool appendBrightnessToAlpha = false,
}) {
  return CustomAutomation(
    id: id,
    name: name,
    recordingStartFrame: 0,
    createdAt: _presetTimestamp,
    updatedAt: _presetTimestamp,
    steps: [
      for (var i = 0; i < steps.length; i++)
        CustomAutomationStep(
          id: '${id}_filter_${i + 1}',
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.filter',
          label: steps[i].name,
          args: {'filter': steps[i].toJson()},
          recordedFrame: 0,
        ),
      if (appendBrightnessToAlpha)
        CustomAutomationStep(
          id: '${id}_brightness_to_alpha',
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.brightnessToAlpha',
          label: '明度で透過',
          args: const {'grayMode': true},
          recordedFrame: 0,
        ),
    ],
  );
}
