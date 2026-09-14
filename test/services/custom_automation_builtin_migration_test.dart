import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/custom_automation.dart';
import 'package:niarim/models/custom_automation_builtin_presets.dart';
import 'package:niarim/models/custom_automation_presets.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('clean install seeds only official semantic presets', () async {
    final service = CustomAutomationService();
    await service.init();

    final ids = service.items.map((item) => item.id).toSet();
    expect(ids, containsAll(CustomAutomationBuiltinPresets.all().map((e) => e.id)));
    expect(ids, isNot(contains(lineExtractionAutomationPresetId)));
    expect(ids, isNot(contains(lineCreationAutomationPresetId)));
    expect(ids, isNot(contains(auroraHologramAutomationPresetId)));
  });

  test('exact legacy defaults migrate and favorite follows replacement', () async {
    final legacy = builtInCanvasAutomationPresets();
    SharedPreferences.setMockInitialValues({
      'custom_automations_v1': legacy.map((e) => jsonEncode(e.toJson())).toList(),
      'custom_automation_favorites_v1': [lineCreationAutomationPresetId],
    });

    final service = CustomAutomationService();
    await service.init();

    final ids = service.items.map((item) => item.id).toSet();
    expect(ids, isNot(contains(lineCreationAutomationPresetId)));
    expect(ids, contains('builtin_draft_to_lineart'));
    expect(service.isFavorite('builtin_draft_to_lineart'), isTrue);
  });

  test('user-edited legacy preset is preserved while official presets are added', () async {
    final old = builtInCanvasAutomationPresets().firstWhere(
      (item) => item.id == lineCreationAutomationPresetId,
    );
    final edited = old.copyWith(
      name: '自分用の線画作成',
      updatedAt: DateTime.utc(2026, 9, 14),
    );
    SharedPreferences.setMockInitialValues({
      'custom_automations_v1': [jsonEncode(edited.toJson())],
    });

    final service = CustomAutomationService();
    await service.init();

    expect(
      service.items.any(
        (item) => item.id == lineCreationAutomationPresetId && item.name == '自分用の線画作成',
      ),
      isTrue,
    );
    expect(service.items.any((item) => item.id == 'builtin_draft_to_lineart'), isTrue);
  });
}
