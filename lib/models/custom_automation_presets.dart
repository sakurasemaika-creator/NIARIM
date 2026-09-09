import 'custom_automation.dart';
import 'filter_def.dart';

const auroraHologramAutomationPresetId = 'preset_aurora_hologram';
const lineExtractionAutomationPresetId = 'preset_line_extraction';
const lineCreationAutomationPresetId = 'preset_line_creation';

final DateTime _presetTimestamp = DateTime.utc(2026, 1, 1);

/// The three starter Canvas automations requested for NIARIM.
///
/// They are normal [CustomAutomation] values so users can rename, re-record,
/// export, or delete them after first-launch initialization. Each preset records
/// a semantic drawing-filter snapshot rather than screen coordinates, so replay
/// remains stable across device sizes and layouts.
List<CustomAutomation> builtInCanvasAutomationPresets() => [
  _filterPreset(
    id: auroraHologramAutomationPresetId,
    name: 'オーロラホログラム',
    filter: const FilterDef(
      id: 'Filter0019',
      name: 'オーロラホログラム',
      kind: FilterKind.auroraHologram,
      strength: 60,
    ),
  ),
  _filterPreset(
    id: lineExtractionAutomationPresetId,
    name: '線画抽出',
    filter: const FilterDef(
      id: 'Filter0023',
      name: '自動線画',
      kind: FilterKind.autoLineart,
      autoLineartRoughWidth: 12,
      autoLineartOutputWidth: 2,
      autoLineartTaperLength: 8,
      autoLineartSmoothing: 5,
      autoLineartColor: 0xFF000000,
    ),
  ),
  _filterPreset(
    id: lineCreationAutomationPresetId,
    name: '線画作成',
    filter: const FilterDef(
      id: 'Filter0006',
      name: '縁取り',
      kind: FilterKind.outline,
      outlineColor: 0xFF000000,
      outlineWidth: 6,
    ),
  ),
];

CustomAutomation _filterPreset({
  required String id,
  required String name,
  required FilterDef filter,
}) {
  return CustomAutomation(
    id: id,
    name: name,
    recordingStartFrame: 0,
    createdAt: _presetTimestamp,
    updatedAt: _presetTimestamp,
    steps: [
      CustomAutomationStep(
        id: '${id}_filter',
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.filterApply',
        label: filter.name,
        args: {'filter': filter.toJson()},
        recordedFrame: 0,
      ),
    ],
  );
}
