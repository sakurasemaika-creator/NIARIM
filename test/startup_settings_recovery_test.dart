import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/app_theme_preset.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a damaged size preset must not prevent loading valid settings',
    () async {
      final good = jsonEncode({
        'id': 'kept',
        'name': '保存済み',
        'width': 1920,
        'height': 1080,
      });
      final originals = [good, '{broken', '{"id":42}'];
      SharedPreferences.setMockInitialValues({
        'custom_size_presets': originals,
        'language': 'fr',
        'undo_limit': 80,
      });
      final service = SettingsService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.language, 'fr');
      expect(service.undoLimit, 80);
      expect(service.customSizePresets.map((p) => p.id), ['kept']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('custom_size_presets'), originals);
    },
  );

  test(
    'damaged current theme falls back without overwriting saved JSON',
    () async {
      SharedPreferences.setMockInitialValues({'theme_current_json': '{broken'});
      final service = ThemeService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.presets, isNotEmpty);
      expect(service.current.id, service.presets.first.id);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_current_json'), '{broken');
    },
  );

  test(
    'a damaged saved theme does not discard valid neighboring themes',
    () async {
      final custom = AppThemePreset.defaultLight.copyWith(
        id: 'kept_custom',
        name: '保存済みカスタム',
      );
      final originals = [jsonEncode(custom.toJson()), '{broken', '{"id":42}'];
      SharedPreferences.setMockInitialValues({'theme_presets': originals});
      final service = ThemeService();
      addTearDown(service.dispose);
      await service.init();
      expect(service.presets.any((p) => p.id == 'kept_custom'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('theme_presets'), originals);
    },
  );
}
