import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/custom_automation_presets.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  test('digital line creation runs auto lineart then ink pool', () {
    final preset = builtInCanvasAutomationPresets().singleWhere(
      (item) => item.id == lineCreationAutomationPresetId,
    );

    final filters = preset.steps
        .map(
          (step) => FilterDef.fromJson(
            (step.args['filter'] as Map).cast<String, dynamic>(),
          ),
        )
        .toList();

    expect(filters.map((filter) => filter.kind), [
      FilterKind.autoLineart,
      FilterKind.inkPool,
    ]);
    expect(filters.map((filter) => filter.id), ['Filter0023', 'Filter0021']);
  });

  test('analog line extraction keeps color adjust then threshold in order', () {
    final preset = builtInCanvasAutomationPresets().singleWhere(
      (item) => item.id == lineExtractionAutomationPresetId,
    );

    final filters = preset.steps
        .map(
          (step) => FilterDef.fromJson(
            (step.args['filter'] as Map).cast<String, dynamic>(),
          ),
        )
        .toList();

    expect(filters.length, greaterThanOrEqualTo(2));
    expect(filters[0].kind, FilterKind.colorAdjust);
    expect(filters[1].kind, FilterKind.threshold);
  });
}
