import 'custom_automation.dart';
import 'filter_def.dart';

const auroraHologramAutomationPresetId = 'preset_aurora_hologram';
const lineExtractionAutomationPresetId = 'preset_line_extraction';
const lineCreationAutomationPresetId = 'preset_line_creation';
final DateTime _presetTimestamp = DateTime.utc(2026, 1, 1);

List<CustomAutomation> builtInCanvasAutomationPresets() => [
  _filterPreset(
    id: auroraHologramAutomationPresetId,
    name: '質感変更フィルター',
    filters: const [
      FilterDef(
        id: 'Filter0019',
        name: '質感変更フィルター',
        kind: FilterKind.auroraHologram,
        strength: 60,
      ),
    ],
  ),
  _filterPreset(
    id: lineExtractionAutomationPresetId,
    name: '線画抽出',
    filters: const [
      FilterDef(
        id: 'automation_color_adjust',
        name: '色調調整',
        kind: FilterKind.colorAdjust,
        caBrightness: 35,
        caContrast: 55,
      ),
      FilterDef(
        id: 'Filter0014',
        name: '二値化',
        kind: FilterKind.threshold,
        thresholdValue: 190,
      ),
    ],
  ),
  _filterPreset(
    id: lineCreationAutomationPresetId,
    name: '線画作成',
    filters: const [
      FilterDef(
        id: 'Filter0006',
        name: '縁取り',
        kind: FilterKind.outline,
        outlineColor: 0xFF000000,
        outlineWidth: 6,
      ),
    ],
  ),
];

CustomAutomation _filterPreset({
  required String id,
  required String name,
  required List<FilterDef> filters,
}) {
  return CustomAutomation(
    id: id,
    name: name,
    recordingStartFrame: 0,
    createdAt: _presetTimestamp,
    updatedAt: _presetTimestamp,
    steps: [
      for (var i = 0; i < filters.length; i++)
        CustomAutomationStep(
          id: '${id}_filter_${i + 1}',
          surface: CustomAutomationSurface.canvas,
          command: 'canvas.filterApply',
          label: filters[i].name,
          args: {'filter': filters[i].toJson()},
          recordedFrame: 0,
        ),
    ],
  );
}
