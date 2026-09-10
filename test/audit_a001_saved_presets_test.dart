import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/shortcut_binding.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:niarim/services/custom_automation_service.dart';
import 'package:niarim/services/quick_tool_service.dart';
import 'package:niarim/services/shortcut_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('intentionally empty quick tools survive repeated startup', () async {
    SharedPreferences.setMockInitialValues({'quick_tool_entries': <String>[]});
    for (var i = 0; i < 2; i++) {
      final service = QuickToolService();
      await service.init();
      expect(service.entries, isEmpty);
      expect(service.next(), isNull);
      service.dispose();
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('quick_tool_entries'), isEmpty);
  });

  test(
    'saved shortcut lists keep deliberately removed defaults removed',
    () async {
      final binding = ShortcutBinding(
        id: 'custom',
        label: 'Undo with Q',
        keyId: LogicalKeyboardKey.keyQ.keyId,
        command: ShortcutCommand.undo,
      );
      for (final raw in <List<String>>[
        [],
        [jsonEncode(binding.toJson())],
      ]) {
        SharedPreferences.setMockInitialValues({'shortcut_bindings': raw});
        final service = ShortcutService();
        await service.init();
        expect(service.bindings.map((b) => jsonEncode(b.toJson())), raw);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('shortcut_bindings'), raw);
        service.dispose();
      }
    },
  );

  test(
    'edited sample colours and part IDs survive startup migration',
    () async {
      for (final id in ['p1', 'p2']) {
        final preset = AutofillPreset(
          id: id,
          name: 'Edited sample',
          parts: const [
            AutofillPart(
              id: 'user_part',
              name: 'Original colour',
              color: 0xff123456,
            ),
          ],
        );
        SharedPreferences.setMockInitialValues({
          'autofill_presets': [jsonEncode(preset.toJson())],
        });
        final service = AutofillPresetService();
        await service.init();
        expect(
          service.presets.singleWhere((p) => p.id == id).toJson(),
          preset.toJson(),
        );
        final restored = AutofillPresetService();
        await restored.init();
        expect(
          restored.presets.singleWhere((p) => p.id == id).toJson(),
          preset.toJson(),
        );
        service.dispose();
        restored.dispose();
      }
    },
  );

  for (final invalid in ['{', '[]', '42']) {
    test(
      'invalid automation $invalid remains stored and blocks partial loading',
      () async {
        SharedPreferences.setMockInitialValues({
          'custom_automations_v1': [invalid],
        });
        final service = CustomAutomationService();
        await expectLater(service.init(), throwsA(isA<FormatException>()));
        expect(service.items, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('custom_automations_v1'), [invalid]);
        await prefs.setStringList('custom_automations_v1', []);
        await service.init();
        expect(service.items, isEmpty);
        service.dispose();
      },
    );
  }
}
