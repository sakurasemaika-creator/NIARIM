import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/services/autofill_preset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('new users receive the built-in gray underpaint preset', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AutofillPresetService();
    await service.init();

    final preset = service.presets.firstWhere(
      (item) => item.id == 'builtin_gray_underpaint',
    );
    expect(preset.name, 'グレー単色の下塗り');
    expect(preset.parts, hasLength(1));
    expect(preset.parts.single.name, '下塗り');
    expect(preset.parts.single.color, 0xFF808080);
  });

  test('existing user presets are preserved while missing built-in is added', () async {
    const custom = AutofillPreset(
      id: 'user_custom',
      name: '自作プリセット',
      parts: [
        AutofillPart(id: 'user_part', name: '自作', color: 0xFF123456),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'autofill_presets': [jsonEncode(custom.toJson())],
    });

    final service = AutofillPresetService();
    await service.init();

    expect(service.presets.where((p) => p.id == 'user_custom'), hasLength(1));
    expect(
      service.presets.where((p) => p.id == 'builtin_gray_underpaint'),
      hasLength(1),
    );
  });
}
