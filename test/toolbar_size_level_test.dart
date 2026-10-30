import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:niarim/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toolbar defaults to middle visual size', () async {
    final settings = SettingsService();
    await settings.init();
    expect(settings.toolbarSizeLevel, 3);
    expect(SettingsService.toolbarIconScaleForLevel(3), 1.0);
    settings.dispose();
  });

  test('five toolbar sizes stay distinct, clamp and survive relaunch', () async {
    final scales = <double>[];
    final settings = SettingsService();
    await settings.init();
    for (var level = 1; level <= 5; level++) {
      await settings.setToolbarSizeLevel(level);
      expect(settings.toolbarSizeLevel, level);
      scales.add(SettingsService.toolbarIconScaleForLevel(level));
      final reopened = SettingsService();
      await reopened.init();
      expect(reopened.toolbarSizeLevel, level);
      reopened.dispose();
    }
    for (var i = 1; i < scales.length; i++) {
      expect(scales[i], greaterThan(scales[i - 1]));
    }
    await settings.setToolbarSizeLevel(0);
    expect(settings.toolbarSizeLevel, 1);
    await settings.setToolbarSizeLevel(99);
    expect(settings.toolbarSizeLevel, 5);
    settings.dispose();
  });
}
