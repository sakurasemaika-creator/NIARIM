import 'custom_automation.dart';
import 'filter_def.dart';

/// Official, editable Custom Automation presets shipped with NIARIM.
/// They are semantic recipes, not coordinate recordings, so they remain stable
/// across device sizes and can run on current/all frames when eligible.
class CustomAutomationBuiltinPresets {
  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static List<CustomAutomation> all() => [
    _draftToLineart(),
    _analogLineartExtraction(),
    _lineartColorTrace(),
    _auroraHologram(),
  ];

  static CustomAutomation _draftToLineart() => CustomAutomation(
    id: 'builtin_draft_to_lineart',
    name: '下書きから線画',
    recordingStartFrame: 0,
    createdAt: _epoch,
    updatedAt: _epoch,
    steps: [
      _filterStep(
        '1',
        const FilterDef(
          id: 'Filter0023',
          name: '自動線画',
          kind: FilterKind.autoLineart,
          autoLineartRoughWidth: 12,
          autoLineartOutputWidth: 2,
          autoLineartTaperLength: 8,
          autoLineartSmoothing: 5,
          autoLineartColor: 0xFF000000,
        ),
        '自動線画',
      ),
      _filterStep(
        '2',
        const FilterDef(
          id: 'Filter0021',
          name: '墨溜まり',
          kind: FilterKind.inkPool,
          inkPoolColor: 0xFF000000,
          inkPoolRange: 12,
          inkPoolCenterWidth: 6,
        ),
        '墨溜まり',
      ),
    ],
  );

  static CustomAutomation _analogLineartExtraction() => CustomAutomation(
    id: 'builtin_analog_lineart_extract',
    name: 'アナログ線画抽出',
    recordingStartFrame: 0,
    createdAt: _epoch,
    updatedAt: _epoch,
    steps: [
      _filterStep(
        '1',
        const FilterDef(
          id: 'Filter0014',
          name: '二値化',
          kind: FilterKind.threshold,
          thresholdValue: 128,
        ),
        '二値化',
      ),
      _filterStep(
        '2',
        const FilterDef(
          id: 'builtin_color_adjust',
          name: '色調補正',
          kind: FilterKind.colorAdjust,
          caSaturation: -100,
          caBrightness: 0,
          caContrast: 20,
        ),
        '色調補正',
      ),
      const CustomAutomationStep(
        id: 'builtin_analog_lineart_extract_3',
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.brightnessToAlpha',
        label: '明度で透過（グレー）',
        args: {'grayMode': true},
        recordedFrame: 0,
      ),
    ],
  );

  static CustomAutomation _lineartColorTrace() => CustomAutomation(
    id: 'builtin_lineart_color_trace',
    name: '線画色トレス',
    recordingStartFrame: 0,
    createdAt: _epoch,
    updatedAt: _epoch,
    steps: [
      const CustomAutomationStep(
        id: 'builtin_lineart_color_trace_1',
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.visibleCompositeToNewTop',
        label: '表示中レイヤーを複製した全統合',
        recordedFrame: 0,
      ),
      _filterStep(
        '2',
        const FilterDef(
          id: 'Filter0001',
          name: 'ガウスぼかし',
          kind: FilterKind.gaussianBlur,
          strength: 30,
        ),
        'ガウスぼかし 30px',
        prefix: 'builtin_lineart_color_trace',
      ),
      const CustomAutomationStep(
        id: 'builtin_lineart_color_trace_3',
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.layerDuplicate',
        label: 'レイヤーを複製',
        recordedFrame: 0,
      ),
      const CustomAutomationStep(
        id: 'builtin_lineart_color_trace_4',
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.layerDuplicate',
        label: 'レイヤーを複製',
        recordedFrame: 0,
      ),
      const CustomAutomationStep(
        id: 'builtin_lineart_color_trace_5',
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.mergeDown',
        label: '下のレイヤーと結合',
        recordedFrame: 0,
      ),
      const CustomAutomationStep(
        id: 'builtin_lineart_color_trace_6',
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.mergeDown',
        label: '下のレイヤーと結合',
        recordedFrame: 0,
      ),
      const CustomAutomationStep(
        id: 'builtin_lineart_color_trace_7',
        surface: CustomAutomationSurface.canvas,
        command: 'canvas.colorTraceAdjust',
        label: '色トレス補正',
        args: {
          'hue': -10.0,
          'saturation': 60.0,
          'lightness': -50.0,
        },
        recordedFrame: 0,
      ),
    ],
  );

  static CustomAutomation _auroraHologram() => CustomAutomation(
    id: 'builtin_aurora_hologram',
    name: 'オーロラホログラム',
    recordingStartFrame: 0,
    createdAt: _epoch,
    updatedAt: _epoch,
    steps: [
      _filterStep(
        '1',
        const FilterDef(
          id: 'Filter0019',
          name: 'オーロラホログラム',
          kind: FilterKind.auroraHologram,
          strength: 60,
          hologramBrightness: 0,
          hologramSaturation: 0,
          hologramPreset: AuroraHologramPreset.aurora,
        ),
        'オーロラホログラム',
        prefix: 'builtin_aurora_hologram',
      ),
    ],
  );

  static CustomAutomationStep _filterStep(
    String suffix,
    FilterDef filter,
    String label, {
    String prefix = 'builtin_draft_to_lineart',
  }) => CustomAutomationStep(
    id: '${prefix}_$suffix',
    surface: CustomAutomationSurface.canvas,
    command: 'canvas.filterApply',
    label: label,
    args: {'filter': filter.toJson()},
    recordedFrame: 0,
  );
}
