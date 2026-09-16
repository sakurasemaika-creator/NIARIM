import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
    expect(
      ids,
      equals(CustomAutomationBuiltinPresets.all().map((e) => e.id).toSet()),
    );
    expect(ids, isNot(contains(digitalLineartAutomationPresetId)));
    expect(ids, isNot(contains(analogLineartAutomationPresetId)));
  });

  test(
    'exact legacy defaults migrate and favorite follows replacement',
    () async {
      final legacy = builtInCanvasAutomationPresets();
      SharedPreferences.setMockInitialValues({
        'custom_automations_v1': legacy
            .map((e) => jsonEncode(e.toJson()))
            .toList(),
        'custom_automation_favorites_v1': [digitalLineartAutomationPresetId],
      });

      final service = CustomAutomationService();
      await service.init();

      final ids = service.items.map((item) => item.id).toSet();
      expect(ids, isNot(contains(digitalLineartAutomationPresetId)));
      expect(ids, isNot(contains(analogLineartAutomationPresetId)));
      expect(ids, contains('builtin_draft_to_lineart'));
      expect(ids, contains('builtin_analog_lineart_extract'));
      expect(service.isFavorite('builtin_draft_to_lineart'), isTrue);
    },
  );

  test(
    'user-edited legacy preset is preserved while official presets are added',
    () async {
      final old = builtInCanvasAutomationPresets().firstWhere(
        (item) => item.id == digitalLineartAutomationPresetId,
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
          (item) =>
              item.id == digitalLineartAutomationPresetId &&
              item.name == '自分用の線画作成',
        ),
        isTrue,
      );
      expect(
        service.items.any((item) => item.id == 'builtin_draft_to_lineart'),
        isTrue,
      );
    },
  );

  test(
    'an existing semantic library is not repopulated after preset deletion',
    () async {
      final retained = CustomAutomationBuiltinPresets.all().singleWhere(
        (item) => item.id == 'builtin_aurora_hologram',
      );
      SharedPreferences.setMockInitialValues({
        'custom_automations_v1': [jsonEncode(retained.toJson())],
      });

      final service = CustomAutomationService();
      await service.init();

      expect(service.items, hasLength(1));
      expect(service.items.single.id, 'builtin_aurora_hologram');
    },
  );
  test(
    'legacy migration preserves an edited semantic preset without duplicate IDs',
    () async {
      final legacy = builtInCanvasAutomationPresets().firstWhere(
        (item) => item.id == digitalLineartAutomationPresetId,
      );
      final edited = CustomAutomationBuiltinPresets.all().first.copyWith(
        name: 'my edited recipe',
      );
      for (final entries in [
        [legacy, edited],
        [edited, legacy],
      ]) {
        SharedPreferences.setMockInitialValues({
          'custom_automations_v1': entries
              .map((e) => jsonEncode(e.toJson()))
              .toList(),
        });
        final service = CustomAutomationService();
        await service.init();
        expect(service.items.where((e) => e.id == edited.id), hasLength(1));
        expect(
          service.items.singleWhere((e) => e.id == edited.id).name,
          'my edited recipe',
        );
      }
    },
  );

  test('legacy libraries receive newly shipped recipes only once', () async {
    final edited = builtInCanvasAutomationPresets().first.copyWith(
      name: 'custom',
    );
    SharedPreferences.setMockInitialValues({
      'custom_automations_v1': [jsonEncode(edited.toJson())],
    });
    final service = CustomAutomationService();
    await service.init();
    expect(
      service.items.map((e) => e.id),
      containsAll(['builtin_lineart_color_trace', 'builtin_aurora_hologram']),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_automations_v1', [
      jsonEncode(edited.toJson()),
    ]);
    final reopened = CustomAutomationService();
    await reopened.init();
    expect(
      reopened.items.map((e) => e.id),
      isNot(contains('builtin_lineart_color_trace')),
    );
    expect(
      reopened.items.map((e) => e.id),
      isNot(contains('builtin_aurora_hologram')),
    );
  });
}
