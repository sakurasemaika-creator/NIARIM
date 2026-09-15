import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/custom_automation_presets.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('seeds the two requested Canvas presets on first launch', () async {
    final service = CustomAutomationService();
    await service.init();

    expect(service.items.map((item) => item.name), ['デジタル線画作成', 'アナログ線画作成']);
    expect(service.items, hasLength(2));
    expect(service.items.every((item) => item.supportsFrameScopeChoice), isTrue);
  });

  test('digital line-art preset applies auto-line-art then ink pooling', () {
    final preset = builtInCanvasAutomationPresets().singleWhere(
      (item) => item.name == 'デジタル線画作成',
    );

    expect(preset.steps.map((step) => step.command), ['canvas.filter', 'canvas.filter']);
    final first = FilterDef.fromJson(
      Map<String, dynamic>.from(preset.steps[0].args['filter']! as Map),
    );
    final second = FilterDef.fromJson(
      Map<String, dynamic>.from(preset.steps[1].args['filter']! as Map),
    );
    expect(first.kind, FilterKind.autoLineart);
    expect(first.id, 'Filter0023');
    expect(second.kind, FilterKind.inkPool);
    expect(second.id, 'Filter0021');
  });

  test('analog line-art preset thresholds then converts brightness to alpha', () {
    final preset = builtInCanvasAutomationPresets().singleWhere(
      (item) => item.name == 'アナログ線画作成',
    );

    expect(preset.steps.map((step) => step.command), [
      'canvas.filter',
      'canvas.brightnessToAlpha',
    ]);
    final threshold = FilterDef.fromJson(
      Map<String, dynamic>.from(preset.steps[0].args['filter']! as Map),
    );
    expect(threshold.kind, FilterKind.threshold);
    expect(threshold.id, 'Filter0015');
    expect(preset.steps[1].args['grayMode'], isTrue);
  });

  test('persisted automation list is authoritative after first launch', () async {
    final first = CustomAutomationService();
    await first.init();
    await first.delete(digitalLineartAutomationPresetId);

    final second = CustomAutomationService();
    await second.init();
    expect(
      second.items.any((item) => item.id == digitalLineartAutomationPresetId),
      isFalse,
    );
  });

  test('an intentionally empty persisted list remains empty', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'custom_automations_v1': <String>[],
    });

    final service = CustomAutomationService();
    await service.init();
    expect(service.items, isEmpty);
  });
}
